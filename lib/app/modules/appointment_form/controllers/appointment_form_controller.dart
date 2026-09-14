import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/unsaved_changes.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/drafts/appointment_draft.dart';
import '../../../data/models/patient_ref.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/repositories/clinical_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/formatters.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../appointments/appointment_routes.dart';

/// Booking a clinic slot, and editing one already booked.
///
/// One screen for both, because a booking is six answers either way and the
/// only difference is whether the patient can still be changed — which is not
/// a different screen, it is a field that stops being offered.
class AppointmentFormController extends GetxController
    with LoadStateMixin, UnsavedChanges {
  static AppointmentFormController get to =>
      Get.find<AppointmentFormController>();

  static const _appointments = AppointmentRepository();

  final formKey = GlobalKey<FormState>();

  final complaintController = TextEditingController();
  final notesController = TextEditingController();

  final patient = Rxn<PatientRef>();
  final doctor = Rxn<DoctorModel>();
  final date = Rx<DateTime>(_today());
  final time = RxnString();
  final duration = 30.obs;
  final type = 'new_patient'.obs;

  final doctors = <DoctorModel>[].obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// True once somebody has tried to save. Until then a blank required field is
  /// not an error — it is a form nobody has filled in yet, and a form that opens
  /// complaining has told its reader nothing.
  final showErrors = false.obs;

  /// The booking being edited, once it has loaded. Null on a new one.
  final existing = Rxn<AppointmentModel>();

  /// The id from the route, or empty when this is a new booking.
  String _id = '';

  /// A patient the caller already chose — from the clinic board's "book for
  /// this patient", or from a patient hub.
  String _incomingPatientId = '';

  bool get isEditing => _id.isNotEmpty;

  /// The three reasons a clinic books somebody in. A visit type is a category,
  /// not an acuity: `emergency` here means "came through the ED", and routing it
  /// through the status ramp would paint it red on a board where red means a
  /// deteriorating patient.
  static const Map<String, String> types = {
    'new_patient': 'New patient',
    'follow_up': 'Follow-up',
    'emergency': 'Emergency',
  };

  /// The lengths a clinic diary is cut into. Between 5 and 480 is what the DTO
  /// accepts; these four are what a desk actually books.
  static const List<int> durations = [15, 30, 45, 60];

  // ── Access ────────────────────────────────────────────────────────────────

  /// Whether this account may save what the form holds.
  ///
  /// A hint, not a permission: the server authorises every request on its own
  /// and the map in hand can be a minute older than the role it describes, so
  /// [submit] still handles the 403 that arrives anyway.
  bool get canSave {
    if (!Get.isRegistered<AccessService>()) return true;
    return AccessService.to.can(
      Modules.appointments,
      isEditing ? AccessVerb.update : AccessVerb.create,
    );
  }

  // ── The site's day ────────────────────────────────────────────────────────

  static SiteSettings get _site => Get.isRegistered<SettingsService>()
      ? SettingsService.to.settings
      : SiteSettings.empty;

  /// Every slot this site's diary has, generated from its own working hours.
  ///
  /// Not a hard-coded 08:00–17:00 grid: a clinic that opens at 07:00 could not
  /// book its first hour, and one running 20-minute appointments would be
  /// offered times its diary does not have.
  List<String> get slots => ClinicSchedule.slots(
        start: _site.workingHoursStart,
        end: _site.workingHoursEnd,
        minutes: _site.appointmentDuration,
      );

  /// When this site opens and closes, for the hint under the time field. Shown
  /// so a desk offered eighteen slots can see where they came from.
  String get openingTime => _site.workingHoursStart;
  String get closingTime => _site.workingHoursEnd;

  String formatDate(DateTime value) =>
      Formatters.date(value, pattern: _site.dateFormat);

  /// A slot as this site writes the time — `15:30`, or `3:30 PM` where the site
  /// charts in 12-hour.
  String formatSlot(String? value) =>
      Formatters.clockTime(value, use24Hour: _site.use24HourClock);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    _id = AppointmentRoutes.idFrom(arguments, Get.parameters);

    final args = arguments is Map ? arguments : const {};
    final passed = args['patient'];
    if (passed is PatientRef) patient.value = passed;

    final incoming = args['patientId'];
    if (incoming is String) _incomingPatientId = incoming;

    // The site's own appointment length, when it is one the control can show.
    // A site cut into 20-minute slots gets the nearest offered default rather
    // than a segmented control with five options in it.
    final configured = _site.appointmentDuration;
    if (durations.contains(configured)) duration.value = configured;
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          doctors.assignAll(await ClinicLookups.doctors());

          if (isEditing) {
            _adopt(await _appointments.read(_id));
          } else {
            await _resolveIncomingPatient();
            // A new booking opens on the first slot of the day rather than on
            // an empty field: it is the commonest answer, and an empty picker
            // above a save button reads as a form with nothing in it.
            time.value ??= slots.isEmpty ? null : slots.first;
          }

          // The snapshot the unsaved-changes guard measures against. Taken
          // after the record is showing, so a form opened and closed untouched
          // leaves without asking.
          markSaved();
        },
        fallback: "Couldn't open that booking.",
      );

  /// Names the patient a caller passed only an id for.
  ///
  /// Unguarded on purpose: a lookup that fails leaves an id-only reference,
  /// which is still enough to book with. Failing the whole form because a name
  /// could not be fetched would be a worse trade.
  Future<void> _resolveIncomingPatient() async {
    if (patient.value != null || _incomingPatientId.isEmpty) return;
    try {
      patient.value = await ClinicLookups.patients.read(_incomingPatientId);
    } catch (_) {
      patient.value = PatientRef(id: _incomingPatientId);
    }
  }

  void _adopt(AppointmentModel booking) {
    existing.value = booking;
    patient.value = booking.patient;
    doctor.value = doctors.firstWhereOrNull((d) => d.id == booking.doctorId) ??
        (booking.doctor.id.isEmpty
            ? null
            : DoctorModel(
                id: booking.doctor.id,
                fullName: booking.doctor.fullName,
                specialization: booking.doctor.specialization,
              ));
    date.value = booking.appointmentDate.toLocal();
    time.value = booking.appointmentTime.trim();
    duration.value = durations.contains(booking.durationMinutes)
        ? booking.durationMinutes
        : 30;
    type.value =
        types.containsKey(booking.appointmentType) ? booking.appointmentType : 'new_patient';
    complaintController.text = booking.chiefComplaint;
    notesController.text = booking.notes;
  }

  // ── Editing ───────────────────────────────────────────────────────────────

  /// Patients for the picker sheet.
  ///
  /// Searched rather than listed: a hospital has more patients than any picker
  /// can hold, and the one being booked is always one somebody can name.
  Future<List<PatientRef>> searchPatients(String query) =>
      ClinicLookups.patients.search(query);

  void choosePatient(PatientRef value) {
    patient.value = value;
    errorMessage.value = null;
  }

  void chooseDoctor(DoctorModel value) {
    doctor.value = value;
    errorMessage.value = null;
  }

  void chooseDate(DateTime? value) {
    if (value != null) date.value = value;
  }

  void chooseSlot(String value) {
    time.value = value;
    errorMessage.value = null;
  }

  void setDuration(int minutes) => duration.value = minutes;
  void setType(String value) => type.value = value;

  // ── Validation ────────────────────────────────────────────────────────────

  /// Five characters, because "pain" and "cough" are the entries a clinic
  /// desk types when it is in a hurry, and neither tells the clinician who
  /// opens the booking anything they did not already know.
  String? validateComplaint(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'What has brought them in?';
    if (text.length < 5) return 'A few more words — five characters at least';
    return null;
  }

  String? get patientError =>
      showErrors.value && (patient.value?.id.isEmpty ?? true)
          ? 'Choose the patient this booking is for'
          : null;

  String? get doctorError => showErrors.value && doctor.value == null
      ? 'Choose the clinician holding this slot'
      : null;

  String? get timeError =>
      showErrors.value && (time.value ?? '').trim().isEmpty
          ? 'Choose a time'
          : null;

  /// How many required answers are still missing, for the line above the save
  /// bar. A refused save that only marks the fields is a refusal nobody can
  /// see: the field it complains about is usually several screens up.
  int get missingCount {
    if (!showErrors.value) return 0;
    var count = 0;
    if (patientError != null) count++;
    if (doctorError != null) count++;
    if (timeError != null) count++;
    if (validateComplaint(complaintController.text) != null) count++;
    return count;
  }

  // ── The payload ───────────────────────────────────────────────────────────

  /// The draft this form would send.
  ///
  /// `priority` is absent and so is every other key the DTO does not declare —
  /// the backend runs `forbidNonWhitelisted`, and the web console strips
  /// `priority` for exactly this reason.
  AppointmentDraft get draft => AppointmentDraft(
        patientId: patient.value?.id,
        doctorId: doctor.value?.id,
        appointmentDate: date.value,
        appointmentTime: time.value,
        durationMinutes: duration.value,
        appointmentType: type.value,
        chiefComplaint: complaintController.text,
        notes: notesController.text,
      );

  @override
  Map<String, dynamic> unsavedPayload() =>
      isEditing ? draft.toUpdateJson() : draft.toCreateJson();

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (isSubmitting.value) return;
    showErrors.value = true;

    final chosen = patient.value;
    if (chosen == null || chosen.id.isEmpty) {
      errorMessage.value = 'Choose the patient this booking is for.';
      return;
    }
    if (doctor.value == null) {
      errorMessage.value = 'Choose the clinician holding this slot.';
      return;
    }
    if ((time.value ?? '').trim().isEmpty) {
      errorMessage.value = 'Choose a time.';
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final name = chosen.displayName;

    try {
      if (isEditing) {
        // The update DTO has no `patientId`: a booking cannot be moved to
        // another patient, and sending the key is a 400 rather than a no-op.
        await _appointments.update(_id, draft.toUpdateJson());
      } else {
        await _appointments.create(draft.toCreateJson());
      }
      // Snapshotted before leaving, so the back gesture that follows the pop
      // does not find a dirty form and ask about work that is already saved.
      markSaved();
      Get.back<void>();
      showBentoToast(
        isEditing
            ? "$name's appointment is updated."
            : '$name is booked for ${formatSlot(time.value)} on '
                '${formatDate(date.value)}.',
      );
    } on ApiForbiddenException catch (e) {
      // The access map is a hint and can be older than the role it describes,
      // so the button being there is never proof the write is allowed.
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = parseErrorMessage(
        e,
        isEditing
            ? "Couldn't save that booking."
            : "Couldn't book that appointment.",
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    complaintController.dispose();
    notesController.dispose();
    super.onClose();
  }

  static DateTime _today() {
    final now = AppClock.now();
    return DateTime(now.year, now.month, now.day);
  }
}
