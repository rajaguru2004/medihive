// lib/app/modules/appointments/models/appointment_create_model.dart

/// Lightweight patient entry used in the "create appointment" dropdowns.
class PatientListItem {
  final String id;
  final String firstName;
  final String lastName;
  final String mrn;

  const PatientListItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.mrn,
  });

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();

  factory PatientListItem.fromJson(Map<String, dynamic> json) =>
      PatientListItem(
        id: json['id'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        mrn: json['mrn'] as String? ?? '',
      );
}

/// Lightweight doctor entry used in the "create appointment" dropdowns.
class DoctorListItem {
  final String id;
  final String fullName;
  final String? specialization;

  const DoctorListItem({
    required this.id,
    required this.fullName,
    this.specialization,
  });

  String get displayName =>
      specialization != null && specialization!.isNotEmpty
          ? '$fullName ($specialization)'
          : fullName;

  factory DoctorListItem.fromJson(Map<String, dynamic> json) => DoctorListItem(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? 'Unknown Doctor',
        specialization: json['specialization'] as String?,
      );
}

/// POST body for /api/appointments
class CreateAppointmentRequest {
  final String patientId;
  final String doctorId;
  final String appointmentDate; // yyyy-MM-dd
  final String appointmentTime; // HH:mm (24h)
  final int durationMinutes;
  final String appointmentType; // new_patient | follow_up | emergency
  final String chiefComplaint;
  final String notes;

  const CreateAppointmentRequest({
    required this.patientId,
    required this.doctorId,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.durationMinutes,
    required this.appointmentType,
    required this.chiefComplaint,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'doctorId': doctorId,
        'appointmentDate': appointmentDate,
        'appointmentTime': appointmentTime,
        'durationMinutes': durationMinutes,
        'appointmentType': appointmentType,
        'chiefComplaint': chiefComplaint,
        'notes': notes,
      };
}
