// lib/app/modules/appointments/models/appointment_model.dart

/// Represents the paginated appointments response from /api/appointments
class AppointmentsResponse {
  final List<AppointmentModel> data;
  final AppointmentMeta meta;

  const AppointmentsResponse({required this.data, required this.meta});

  factory AppointmentsResponse.fromJson(Map<String, dynamic> json) {
    final outer = json['data'] as Map<String, dynamic>? ?? json;
    final dataList = outer['data'] as List<dynamic>? ?? [];
    final metaMap = outer['meta'] as Map<String, dynamic>? ?? {};
    return AppointmentsResponse(
      data: dataList
          .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: AppointmentMeta.fromJson(metaMap),
    );
  }
}

class AppointmentMeta {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const AppointmentMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory AppointmentMeta.fromJson(Map<String, dynamic> json) =>
      AppointmentMeta(
        page: json['page'] as int? ?? 1,
        limit: json['limit'] as int? ?? 10,
        total: json['total'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 1,
        hasNextPage: json['hasNextPage'] as bool? ?? false,
        hasPreviousPage: json['hasPreviousPage'] as bool? ?? false,
      );
}

class AppointmentModel {
  final String id;
  final String organizationId;
  final String patientId;
  final String doctorId;
  final DateTime appointmentDate;
  final String appointmentTime; // "HH:mm"
  final int durationMinutes;
  final String appointmentType; // new_patient, emergency, follow_up, etc.
  final String? departmentId;
  final String status; // scheduled, confirmed, checked_in, in_progress, completed, cancelled, no_show
  final String? chiefComplaint;
  final String? notes;
  final bool reminderSent;
  final DateTime createdAt;
  final DateTime updatedAt;
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
    this.departmentId,
    required this.status,
    this.chiefComplaint,
    this.notes,
    required this.reminderSent,
    required this.createdAt,
    required this.updatedAt,
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
        durationMinutes: json['durationMinutes'] as int? ?? 30,
        appointmentType: json['appointmentType'] as String? ?? 'new_patient',
        departmentId: json['departmentId'] as String?,
        status: json['status'] as String? ?? 'scheduled',
        chiefComplaint: json['chiefComplaint'] as String?,
        notes: json['notes'] as String?,
        reminderSent: json['reminderSent'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        patient: AppointmentPatient.fromJson(
            json['patient'] as Map<String, dynamic>? ?? {}),
        doctor: AppointmentDoctor.fromJson(
            json['doctor'] as Map<String, dynamic>? ?? {}),
      );

  // ── Computed helpers ──────────────────────────────────────────────────────

  String get formattedType => switch (appointmentType) {
        'new_patient' => 'New Patient',
        'emergency' => 'Emergency',
        'follow_up' => 'Follow Up',
        'routine' => 'Routine',
        _ => appointmentType
            .split('_')
            .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' '),
      };

  String get formattedStatus => switch (status) {
        'scheduled' => 'Scheduled',
        'confirmed' => 'Confirmed',
        'checked_in' => 'Checked In',
        'in_progress' => 'In Progress',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        'no_show' => 'No Show',
        _ => '${status[0].toUpperCase()}${status.substring(1)}',
      };

  /// Formatted 12h time string, e.g. "10:00 AM"
  String get formattedTime {
    final parts = appointmentTime.split(':');
    if (parts.length < 2) return appointmentTime;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  bool get isToday {
    final now = DateTime.now();
    return appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;
  }

  bool get isActive =>
      status == 'scheduled' ||
      status == 'confirmed' ||
      status == 'checked_in' ||
      status == 'in_progress';

  bool get isCompleted =>
      status == 'completed' ||
      status == 'cancelled' ||
      status == 'no_show';
}

class AppointmentPatient {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String? phonePrimary;
  final String gender;
  final DateTime? dateOfBirth;

  const AppointmentPatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    this.phonePrimary,
    required this.gender,
    this.dateOfBirth,
  });

  factory AppointmentPatient.fromJson(Map<String, dynamic> json) =>
      AppointmentPatient(
        id: json['id'] as String? ?? '',
        mrn: json['mrn'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phonePrimary: json['phonePrimary'] as String?,
        gender: json['gender'] as String? ?? 'unknown',
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'] as String)
            : null,
      );

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();

  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    final fi = f.isNotEmpty ? f[0].toUpperCase() : '';
    final li = l.isNotEmpty ? l[0].toUpperCase() : '';
    return '$fi$li'.isEmpty ? '?' : '$fi$li';
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
        fullName: json['fullName'] as String? ?? 'Unknown Doctor',
        specialization: json['specialization'] as String?,
      );
}

/// Summary counts derived from the full appointments list
class AppointmentSummary {
  final int todayTotal;
  final int confirmed;
  final int checkedIn;
  final int inProgress;
  final int completed;
  final int cancelled;
  final int noShows;
  final int scheduled;

  const AppointmentSummary({
    this.todayTotal = 0,
    this.confirmed = 0,
    this.checkedIn = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShows = 0,
    this.scheduled = 0,
  });

  factory AppointmentSummary.fromList(List<AppointmentModel> all) {
    final today = all.where((a) => a.isToday).toList();
    return AppointmentSummary(
      todayTotal: today.length,
      confirmed: today.where((a) => a.status == 'confirmed').length,
      checkedIn: today.where((a) => a.status == 'checked_in').length,
      inProgress: today.where((a) => a.status == 'in_progress').length,
      completed: today.where((a) => a.status == 'completed').length,
      cancelled: today.where((a) => a.status == 'cancelled').length,
      noShows: today.where((a) => a.status == 'no_show').length,
      scheduled: today.where((a) => a.status == 'scheduled').length,
    );
  }
}
