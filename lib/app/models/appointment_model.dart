class AppointmentPatient {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String? phonePrimary;
  final String? gender;
  final DateTime? dateOfBirth;

  const AppointmentPatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    this.phonePrimary,
    this.gender,
    this.dateOfBirth,
  });

  factory AppointmentPatient.fromJson(Map<String, dynamic> json) =>
      AppointmentPatient(
        id: json['id'] as String? ?? '',
        mrn: json['mrn'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phonePrimary: json['phonePrimary'] as String?,
        gender: json['gender'] as String?,
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'] as String)
            : null,
      );

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f =
        firstName.trim().isNotEmpty ? firstName.trim()[0].toUpperCase() : '';
    final l =
        lastName.trim().isNotEmpty ? lastName.trim()[0].toUpperCase() : '';
    return f.isNotEmpty || l.isNotEmpty ? '$f$l' : '?';
  }

  int get age {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
}

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
  final AppointmentPatient patient;
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
        patient: AppointmentPatient.fromJson(
            (json['patient'] as Map<String, dynamic>?) ?? {}),
        doctor: AppointmentDoctor.fromJson(
            (json['doctor'] as Map<String, dynamic>?) ?? {}),
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

  String get formattedTime {
    final parts = appointmentTime.split(':');
    if (parts.length < 2) return appointmentTime;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1].padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayH:$m $period';
  }

  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final d = appointmentDate;
    final dayName = days[d.weekday % 7];
    return '$dayName, ${d.day} ${months[d.month - 1]}';
  }

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
