import '../utils/formatters.dart';
import 'json.dart';
import 'patient_ref.dart';

class AppointmentDoctor {
  final String id;
  final String fullName;
  final String? specialization;

  const AppointmentDoctor({
    required this.id,
    required this.fullName,
    this.specialization,
  });

  factory AppointmentDoctor.fromJson(Map<String, dynamic> json) =>
      AppointmentDoctor(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        specialization: json['specialization'] as String?,
      );
}

class AppointmentModel {
  final String id;
  final String organizationId;
  final String patientId;
  final String doctorId;
  final DateTime appointmentDate;
  final String appointmentTime; // "14:30"
  final int durationMinutes;
  final String appointmentType; // "emergency", "new_patient", "follow_up"
  final String
      status; // "scheduled", "confirmed", "checked_in", "in_progress", "completed", "cancelled", "no_show"
  final String chiefComplaint;
  final String notes;
  final DateTime? checkedInAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final bool reminderSent;
  final PatientRef patient;
  final AppointmentDoctor doctor;

  const AppointmentModel({
    required this.id,
    required this.organizationId,
    required this.patientId,
    required this.doctorId,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.durationMinutes,
    required this.appointmentType,
    required this.status,
    required this.chiefComplaint,
    required this.notes,
    this.checkedInAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    required this.reminderSent,
    required this.patient,
    required this.doctor,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) =>
      AppointmentModel(
        id: json['id'] as String? ?? '',
        organizationId: json['organizationId'] as String? ?? '',
        patientId: json['patientId'] as String? ?? '',
        doctorId: json['doctorId'] as String? ?? '',
        appointmentDate: json['appointmentDate'] != null
            ? DateTime.tryParse(json['appointmentDate'] as String) ??
                DateTime.now()
            : DateTime.now(),
        appointmentTime: json['appointmentTime'] as String? ?? '00:00',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 15,
        appointmentType: json['appointmentType'] as String? ?? 'new_patient',
        status: json['status'] as String? ?? 'scheduled',
        chiefComplaint: json['chiefComplaint'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        checkedInAt: json['checkedInAt'] != null
            ? DateTime.tryParse(json['checkedInAt'] as String)
            : null,
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
        cancelledAt: json['cancelledAt'] != null
            ? DateTime.tryParse(json['cancelledAt'] as String)
            : null,
        reminderSent: json['reminderSent'] as bool? ?? false,
        patient: PatientRef.of(json['patient']),
        doctor: AppointmentDoctor.fromJson(asMap(json['doctor'])),
      );

  AppointmentModel copyWith({
    String? status,
    bool? reminderSent,
    DateTime? checkedInAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) =>
      AppointmentModel(
        id: id,
        organizationId: organizationId,
        patientId: patientId,
        doctorId: doctorId,
        appointmentDate: appointmentDate,
        appointmentTime: appointmentTime,
        durationMinutes: durationMinutes,
        appointmentType: appointmentType,
        status: status ?? this.status,
        chiefComplaint: chiefComplaint,
        notes: notes,
        checkedInAt: checkedInAt ?? this.checkedInAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        reminderSent: reminderSent ?? this.reminderSent,
        patient: patient,
        doctor: doctor,
      );

  /// `15:30`, or `3:30 PM` where the site charts in 12-hour.
  String formattedTime({bool use24Hour = true}) =>
      Formatters.clockTime(appointmentTime, use24Hour: use24Hour);

  /// `Mon, 22 Jun`.
  String get formattedDate => Formatters.dayAndMonth(appointmentDate);

  String get formattedType {
    switch (appointmentType.toLowerCase()) {
      case 'emergency':
        return 'Emergency';
      case 'new_patient':
        return 'New Patient';
      case 'follow_up':
        return 'Follow-up';
      default:
        return appointmentType.replaceAll('_', ' ');
    }
  }
}
