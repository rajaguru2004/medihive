
import 'draft_json.dart';

/// A booking or a reschedule, in flight.
///
/// DTO: `hms_v2/src/modules/appointments/dto/create-appointment.dto.ts` and
/// `update-appointment.dto.ts`.
///
/// `patientId` is on the create DTO and **not** on the update one: an
/// appointment cannot be moved to another patient, and sending the key on a
/// PATCH is a 400 rather than a no-op.
class AppointmentDraft {
  const AppointmentDraft({
    this.patientId,
    this.doctorId,
    this.appointmentDate,
    this.appointmentTime,
    this.durationMinutes,
    this.appointmentType,
    this.chiefComplaint,
    this.notes,
    this.departmentId,
    this.status,
    this.cancellationReason,
    this.consultationNotes,
    this.reminderSent,
  });

  /// Create only.
  final String? patientId;
  final String? doctorId;

  /// The day, sent as `yyyy-MM-dd`. An instant would be read in the server's
  /// zone, and a clinic booked at 00:30 would land on the day before.
  final DateTime? appointmentDate;

  /// `09:30`. Text on the backend too, not a timestamp.
  final String? appointmentTime;

  /// Between 5 and 480; the DTO rejects anything outside that.
  final int? durationMinutes;

  /// `new_patient`, `follow_up`, `emergency`. A visit type, which is a category
  /// and not a clinical state — `emergency` here means "came through the ED".
  final String? appointmentType;
  final String? chiefComplaint;
  final String? notes;
  final String? departmentId;

  /// Update only. `scheduled`, `confirmed`, `checked_in`, `in_progress`,
  /// `completed`, `cancelled`, `no_show`, `rescheduled`.
  final String? status;

  /// Update only.
  final String? cancellationReason;

  /// Update only.
  final String? consultationNotes;

  /// Update only.
  final bool? reminderSent;

  AppointmentDraft copyWith({
    String? patientId,
    String? doctorId,
    DateTime? appointmentDate,
    String? appointmentTime,
    int? durationMinutes,
    String? appointmentType,
    String? chiefComplaint,
    String? notes,
    String? departmentId,
    String? status,
    String? cancellationReason,
    String? consultationNotes,
    bool? reminderSent,
  }) =>
      AppointmentDraft(
        patientId: patientId ?? this.patientId,
        doctorId: doctorId ?? this.doctorId,
        appointmentDate: appointmentDate ?? this.appointmentDate,
        appointmentTime: appointmentTime ?? this.appointmentTime,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        appointmentType: appointmentType ?? this.appointmentType,
        chiefComplaint: chiefComplaint ?? this.chiefComplaint,
        notes: notes ?? this.notes,
        departmentId: departmentId ?? this.departmentId,
        status: status ?? this.status,
        cancellationReason: cancellationReason ?? this.cancellationReason,
        consultationNotes: consultationNotes ?? this.consultationNotes,
        reminderSent: reminderSent ?? this.reminderSent,
      );

  /// The keys both routes accept, listed once so the two cannot drift.
  Map<String, dynamic> _shared() => {
        'doctorId': doctorId,
        'appointmentDate': isoDay(appointmentDate),
        'appointmentTime': appointmentTime,
        'durationMinutes': durationMinutes,
        'appointmentType': appointmentType,
        'chiefComplaint': chiefComplaint,
        'notes': notes,
        'departmentId': departmentId,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'patientId': patientId,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'status': status,
        'cancellationReason': cancellationReason,
        'consultationNotes': consultationNotes,
        'reminderSent': reminderSent,
      });
}
