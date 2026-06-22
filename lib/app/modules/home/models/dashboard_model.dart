// lib/app/modules/home/models/dashboard_model.dart

class DashboardStats {
  final int totalPatients;
  final int todayAppointments;
  final int pendingLabOrders;
  final int pendingPrescriptions;
  final double todayRevenue;
  final int occupiedBeds;
  final int availableBeds;
  final int queueWaiting;
  final int criticalAlerts;

  const DashboardStats({
    required this.totalPatients,
    required this.todayAppointments,
    required this.pendingLabOrders,
    required this.pendingPrescriptions,
    required this.todayRevenue,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.queueWaiting,
    required this.criticalAlerts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalPatients: (json['totalPatients'] as num?)?.toInt() ?? 0,
        todayAppointments: (json['todayAppointments'] as num?)?.toInt() ?? 0,
        pendingLabOrders: (json['pendingLabOrders'] as num?)?.toInt() ?? 0,
        pendingPrescriptions:
            (json['pendingPrescriptions'] as num?)?.toInt() ?? 0,
        todayRevenue: (json['todayRevenue'] as num?)?.toDouble() ?? 0.0,
        occupiedBeds: (json['occupiedBeds'] as num?)?.toInt() ?? 0,
        availableBeds: (json['availableBeds'] as num?)?.toInt() ?? 0,
        queueWaiting: (json['queueWaiting'] as num?)?.toInt() ?? 0,
        criticalAlerts: (json['criticalAlerts'] as num?)?.toInt() ?? 0,
      );

  DashboardStats copyWith({
    int? totalPatients,
    int? todayAppointments,
    int? pendingLabOrders,
    int? pendingPrescriptions,
    double? todayRevenue,
    int? occupiedBeds,
    int? availableBeds,
    int? queueWaiting,
    int? criticalAlerts,
  }) =>
      DashboardStats(
        totalPatients: totalPatients ?? this.totalPatients,
        todayAppointments: todayAppointments ?? this.todayAppointments,
        pendingLabOrders: pendingLabOrders ?? this.pendingLabOrders,
        pendingPrescriptions: pendingPrescriptions ?? this.pendingPrescriptions,
        todayRevenue: todayRevenue ?? this.todayRevenue,
        occupiedBeds: occupiedBeds ?? this.occupiedBeds,
        availableBeds: availableBeds ?? this.availableBeds,
        queueWaiting: queueWaiting ?? this.queueWaiting,
        criticalAlerts: criticalAlerts ?? this.criticalAlerts,
      );
}

class RecentPatient {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final DateTime createdAt;

  const RecentPatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.createdAt,
  });

  factory RecentPatient.fromJson(Map<String, dynamic> json) => RecentPatient(
        id: json['id'] as String? ?? '',
        mrn: json['mrn'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? '') ??
            DateTime.now(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }
}

class UpcomingAppointment {
  final String id;
  final String patientName;
  final String doctorName;
  final DateTime appointmentTime;
  final String status;

  const UpcomingAppointment({
    required this.id,
    required this.patientName,
    required this.doctorName,
    required this.appointmentTime,
    required this.status,
  });

  factory UpcomingAppointment.fromJson(Map<String, dynamic> json) =>
      UpcomingAppointment(
        id: json['id'] as String? ?? '',
        patientName: json['patientName'] as String? ?? '',
        doctorName: json['doctorName'] as String? ?? '',
        appointmentTime:
            DateTime.tryParse(json['appointmentTime'] as String? ?? '') ??
                DateTime.now(),
        status: json['status'] as String? ?? '',
      );
}

class AppointmentStatuses {
  final int completed;
  final int confirmed;
  final int scheduled;
  final int cancelled;

  const AppointmentStatuses({
    this.completed = 0,
    this.confirmed = 0,
    this.scheduled = 0,
    this.cancelled = 0,
  });

  int get total => completed + confirmed + scheduled + cancelled;

  factory AppointmentStatuses.fromJson(Map<String, dynamic> json) =>
      AppointmentStatuses(
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
        scheduled: (json['scheduled'] as num?)?.toInt() ?? 0,
        cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      );
}

class QueueService {
  final String name;
  final int count;

  const QueueService({required this.name, required this.count});
}

class DashboardData {
  final DashboardStats stats;
  final AppointmentStatuses appointmentStatuses;
  final List<QueueService> queueByService;
  final List<RecentPatient> recentPatients;
  final List<UpcomingAppointment> upcomingAppointments;

  const DashboardData({
    required this.stats,
    required this.appointmentStatuses,
    required this.queueByService,
    required this.recentPatients,
    required this.upcomingAppointments,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};

    final statsJson = data['stats'] as Map<String, dynamic>? ?? {};
    final apptJson =
        data['appointmentStatuses'] as Map<String, dynamic>? ?? {};
    final queueJson = data['queueByService'] as Map<String, dynamic>? ?? {};
    final patientsJson = data['recentPatients'] as List<dynamic>? ?? [];
    final appointmentsJson =
        data['upcomingAppointments'] as List<dynamic>? ?? [];

    final queueServices = queueJson.entries
        .map((e) => QueueService(
              name: e.key,
              count: (e.value as num?)?.toInt() ?? 0,
            ))
        .toList();

    return DashboardData(
      stats: DashboardStats.fromJson(statsJson),
      appointmentStatuses: AppointmentStatuses.fromJson(apptJson),
      queueByService: queueServices,
      recentPatients:
          patientsJson.map((e) => RecentPatient.fromJson(e as Map<String, dynamic>)).toList(),
      upcomingAppointments: appointmentsJson
          .map((e) => UpcomingAppointment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrganizationData {
  final String id;
  final String name;
  final String? logoUrl;
  final String? logoTextUrl;
  final String primaryColor;
  final String secondaryColor;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String country;

  const OrganizationData({
    required this.id,
    required this.name,
    this.logoUrl,
    this.logoTextUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.country,
  });

  factory OrganizationData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return OrganizationData(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'MediHive',
      logoUrl: data['logoUrl'] as String?,
      logoTextUrl: data['logoTextUrl'] as String?,
      primaryColor: data['primaryColor'] as String? ?? '#0A84FF',
      secondaryColor: data['secondaryColor'] as String? ?? '#30D158',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      city: data['city'] as String? ?? '',
      country: data['country'] as String? ?? '',
    );
  }
}
