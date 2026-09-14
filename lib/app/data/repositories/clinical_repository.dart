/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the encounter, as two collections and one clock
///
/// An appointment is a promise to see somebody; a consultation is the record of
/// having seen them. They are two routes with the same five verbs, so two
/// [CrudRepository] subclasses — and they live in one file because the write
/// screens of both ask the same three questions: which clinician, which patient,
/// and which slot in this site's day.
///
/// Deliberately **not** a `GetxService`. There is no state to hold — the
/// repositories read their client from the container at call time — and a
/// service registered in one binding and found in another is a lookup that
/// throws the first time somebody deep-links past the screen that registered it.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../models/appointment_model.dart';
import '../models/consultation_model.dart';
import '../models/consultation_record.dart';
import '../models/doctor_model.dart';
import '../models/drafts/appointment_draft.dart';
import '../models/patient_ref.dart';
import '../network/endpoints.dart';
import '../utils/api_envelope.dart';
import 'crud_repository.dart';

/// The eight states an appointment can be in.
///
/// Spelled exactly as the column stores them — `checked_in`, `in_progress`,
/// `no_show`, with underscores — because `UpdateAppointmentDto` runs `@IsIn`
/// over this list and any other spelling is a 400 on the PATCH that moves the
/// booking along.
///
/// No colours here. An appointment state *is* a clinical state, so `CaseStatus`
/// resolves it and the clinic board and this module agree by construction. A
/// second table would be a second opinion.
abstract final class AppointmentStatus {
  static const String scheduled = 'scheduled';
  static const String confirmed = 'confirmed';
  static const String checkedIn = 'checked_in';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String noShow = 'no_show';
  static const String rescheduled = 'rescheduled';

  static const List<String> all = [
    scheduled,
    confirmed,
    checkedIn,
    inProgress,
    completed,
    cancelled,
    noShow,
    rescheduled,
  ];

  /// The states a booking never leaves. Nothing is offered on one of these:
  /// reopening a closed appointment is an admin-console job, and a button that
  /// 400s is worse than no button.
  static const Set<String> _closed = {completed, cancelled, noShow};

  static String normalise(String? status) =>
      (status ?? '').trim().toLowerCase();

  static bool isClosed(String? status) => _closed.contains(normalise(status));

  /// Where a booking in [status] is allowed to go next, in the order a clinic
  /// desk would offer them.
  ///
  /// The ladder rather than the whole enum: offering "complete" on a patient
  /// who has not arrived is how a clinic's figures stop meaning anything, and
  /// offering "check in" twice is how one arrival is recorded as two.
  ///
  /// `rescheduled` is treated as a fresh booking, which is what it is — the
  /// server keeps the old row and points a new date at it.
  static List<String> nextFrom(String? status) => switch (normalise(status)) {
        scheduled => const [confirmed, checkedIn, noShow],
        rescheduled => const [confirmed, checkedIn, noShow],
        confirmed => const [checkedIn, noShow],
        checkedIn => const [inProgress, completed, noShow],
        inProgress => const [completed],
        _ => const [],
      };

  /// Whether [status] may be moved to [next] from where it is now.
  static bool allows(String? status, String next) =>
      nextFrom(status).contains(next);

  /// Whether a booking in [status] can still be moved to another slot.
  static bool canReschedule(String? status) => !isClosed(status);
}

/// Appointments.
///
/// `Endpoints.appointments` is PATCH, and the route answers PUT as well —
/// `CrudRepository.update` reads the verb off the [Crud] rather than assuming,
/// so this class never states which.
class AppointmentRepository extends CrudRepository<AppointmentModel> {
  const AppointmentRepository()
      : super(Endpoints.appointments, AppointmentModel.fromJson, entityName);

  /// What a write to a booking announces itself as on the `DataBus`. The same
  /// string the clinic board listens on, so a booking made here refreshes the
  /// list behind it.
  static const String entityName = 'appointments';

  /// Moves a booking along the ladder.
  ///
  /// Through [AppointmentDraft] rather than a hand-built map, because the
  /// update DTO runs `forbidNonWhitelisted` — and because the draft is the one
  /// place that knows `patientId` is a create-only key. The web console strips
  /// `priority` from this payload; the draft has no such field to strip.
  Future<AppointmentModel> setStatus(
    String id,
    String status, {
    String? cancellationReason,
  }) =>
      update(
        id,
        AppointmentDraft(
          status: status,
          cancellationReason: cancellationReason,
        ).toUpdateJson(),
      );

  /// Moves a booking to another slot.
  ///
  /// Date, time **and** status in one request. Sending the pair without the
  /// status leaves a row that reads `scheduled` on a day nobody agreed to, and
  /// sending the status without the pair leaves one marked `rescheduled` that
  /// never moved.
  Future<AppointmentModel> reschedule(
    String id, {
    required DateTime date,
    required String time,
  }) =>
      update(
        id,
        AppointmentDraft(
          appointmentDate: date,
          appointmentTime: time,
          status: AppointmentStatus.rescheduled,
        ).toUpdateJson(),
      );
}

/// Consultations.
class ConsultationRepository extends CrudRepository<ConsultationModel> {
  const ConsultationRepository()
      : super(Endpoints.consultations, ConsultationModel.fromJson, entityName);

  static const String entityName = 'consultations';

  /// One consultation with everything the encounter produced.
  ///
  /// `GET /api/consultations/:id` populates `prescriptions`, `labOrders` and
  /// `radiologyOrders` alongside the record itself, so the detail screen is one
  /// round trip rather than four — and, more importantly, the orders it lists
  /// are the ones the server joined rather than ones the app filtered for
  /// itself. Neither order list route accepts a `consultationId` filter, so
  /// there is no second way to ask.
  Future<ConsultationRecord> record(String id) async {
    final response = await client.get(routes.byId(id));
    return ConsultationRecord.fromJson(
      ApiEnvelope.of(response).orThrow().object,
    );
  }
}

/// The lookups both write screens fill their pickers from.
///
/// Patients are searched and never listed — a hospital has more of them than
/// any picker can hold. Clinicians are listed and never searched: the staff
/// route answers a bare array and takes no `search`.
abstract final class ClinicLookups {
  /// Patients, by name or MRN.
  static const CrudRepository<PatientRef> patients =
      CrudRepository<PatientRef>(
    Endpoints.patients,
    PatientRef.fromJson,
    'patients',
  );

  /// Everyone who can hold a clinic.
  ///
  /// `GET /api/users/staff?role=DOCTOR`. A bare array with no `meta`, which
  /// `ApiEnvelope` flattens like any other — and no pagination DTO at all, so
  /// `role` is the only parameter it will read.
  static Future<List<DoctorModel>> doctors() async {
    final response = await patients.client.get(
      Endpoints.staff,
      queryParameters: const {'role': 'DOCTOR'},
    );
    return ApiEnvelope.of(response).orThrow().listOf(DoctorModel.fromJson);
  }
}

/// The clinic's day, as this site has configured it.
///
/// Lives beside the repositories rather than on a controller because two
/// screens ask it the same question — the booking form and the reschedule sheet
/// — and a clinic whose two ways of choosing a slot offer different slots is a
/// clinic that double-books.
abstract final class ClinicSchedule {
  /// Every bookable time between [start] and [end], [minutes] apart.
  ///
  /// Generated rather than listed. A hard-coded 08:00–17:00 grid is correct for
  /// exactly one deployment: a site that opens at 07:00 cannot book its first
  /// hour, and one running 20-minute slots is offered times its diary does not
  /// have.
  ///
  /// [end] is the moment the clinic closes, so it is not itself a slot — the
  /// last one starts a full appointment before it. Anything unparseable falls
  /// back to the documented defaults rather than to an empty picker, because a
  /// picker with nothing in it reads as a broken screen rather than as a
  /// misconfigured site.
  static List<String> slots({
    required String start,
    required String end,
    required int minutes,
  }) {
    final from = minutesOf(start) ?? minutesOf('08:00')!;
    final to = minutesOf(end) ?? minutesOf('17:00')!;
    final step = minutes >= 5 ? minutes : 30;
    if (to <= from) return const [];

    final times = <String>[];
    for (var at = from; at + step <= to; at += step) {
      times.add(clockOf(at));
    }
    // A clinic whose whole day is shorter than one appointment still opens:
    // offer the moment it opens rather than nothing at all.
    return times.isEmpty ? [clockOf(from)] : times;
  }

  /// `"09:30"` → 570. Null when the text is not a clock time.
  ///
  /// Parsed rather than trusted. The backend zero-pads its hours, but a site
  /// setting is typed by an administrator, and `"9:30"` sorted lexicographically
  /// lands after `"17:00"`.
  static int? minutesOf(String? raw) {
    final parts = (raw ?? '').trim().split(':');
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final mins = int.tryParse(parts[1]);
    if (hours == null || mins == null) return null;
    if (hours < 0 || hours > 23 || mins < 0 || mins > 59) return null;
    return hours * 60 + mins;
  }

  /// 570 → `"09:30"`. Zero-padded, which is what the column stores.
  static String clockOf(int minutes) {
    final hours = (minutes ~/ 60) % 24;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}';
  }
}
