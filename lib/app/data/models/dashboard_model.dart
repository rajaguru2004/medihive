import '../utils/formatters.dart';
import 'json.dart';
import 'patient_ref.dart';

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

/// A patient registered in the last few days, for the board's tail.
class RecentPatient {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String gender;

  /// Null when the route sent none, never today.
  ///
  /// These both defaulted to `DateTime.now()`, which made a patient with no
  /// recorded date of birth a newborn on the board and one with no `createdAt`
  /// "registered today". An absent field has to read as absent.
  final DateTime? dateOfBirth;
  final DateTime? createdAt;

  const RecentPatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.dateOfBirth,
    this.createdAt,
  });

  factory RecentPatient.fromJson(Map<String, dynamic> json) => RecentPatient(
        id: asString(json['id']),
        mrn: asString(json['mrn']),
        firstName: asString(json['firstName']),
        lastName: asString(json['lastName']),
        gender: asString(json['gender']),
        dateOfBirth: asDate(json['dateOfBirth']),
        createdAt: asDate(json['createdAt']),
      );

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return f.isEmpty && l.isEmpty ? '?' : '$f$l';
  }

  /// `42y`, `7mo`, `—`. Through `Formatters`, which reads `AppClock` — age
  /// computed inline against `DateTime.now()` is age a golden cannot capture.
  String get age => Formatters.age(dateOfBirth);
}

class UpcomingAppointment {
  final String id;

  /// Null when the route sent none. An appointment dated "now" because its
  /// date failed to parse sorts into today's clinic and is kept by every
  /// "today" filter on the board.
  final DateTime? appointmentDate;

  /// The clock time as the API stores it — `"11:00"`, `"15:30"`.
  final String appointmentTime;
  final String status;
  final PatientRef patient;

  const UpcomingAppointment({
    required this.id,
    this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    required this.patient,
  });

  factory UpcomingAppointment.fromJson(Map<String, dynamic> json) =>
      UpcomingAppointment(
        id: asString(json['id']),
        appointmentDate: asDate(json['appointmentDate']),
        appointmentTime: asString(json['appointmentTime']),
        status: asString(json['status']),
        patient: PatientRef.of(json['patient']),
      );

  /// `15:30`, or `3:30 PM` where the site charts in 12-hour.
  String formattedTime({bool use24Hour = true}) =>
      Formatters.clockTime(appointmentTime, use24Hour: use24Hour);

  /// `Mon, 22 Jun`.
  String get formattedDate => Formatters.dayAndMonth(appointmentDate);
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

/// How many people are waiting in one service area.
///
/// `QueueServiceCount`, not `QueueService`: that name already belongs to the
/// `GetxService` in `data/services/queue_service.dart`, and a file importing
/// both got whichever it imported second — or, in the dashboard's case, a
/// `Get.find<QueueService>()` that would not compile beside its own model.
class QueueServiceCount {
  final String name;
  final int count;

  const QueueServiceCount({required this.name, required this.count});
}

class DashboardData {
  final DashboardStats stats;
  final AppointmentStatuses appointmentStatuses;
  final List<QueueServiceCount> queueByService;
  final List<RecentPatient> recentPatients;
  final List<UpcomingAppointment> upcomingAppointments;

  const DashboardData({
    required this.stats,
    required this.appointmentStatuses,
    required this.queueByService,
    required this.recentPatients,
    required this.upcomingAppointments,
  });

  /// Takes the **payload**, not the envelope around it.
  ///
  /// This read `json['data']` itself, so it only worked when handed the whole
  /// response body — unlike every other model in this app, and impossible to
  /// use with `ApiEnvelope`. Unwrapping happens once, in `HomeService`.
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final statsJson = asMap(json['stats']);
    final apptJson = asMap(json['appointmentStatuses']);
    final queueJson = asMap(json['queueByService']);
    final patientsJson = asMapList(json['recentPatients']);
    final appointmentsJson = asMapList(json['upcomingAppointments']);

    final queueServices = queueJson.entries
        .map((e) => QueueServiceCount(
              name: e.key,
              count: (e.value as num?)?.toInt() ?? 0,
            ))
        .toList();

    return DashboardData(
      stats: DashboardStats.fromJson(statsJson),
      appointmentStatuses: AppointmentStatuses.fromJson(apptJson),
      queueByService: queueServices,
      recentPatients: patientsJson.map(RecentPatient.fromJson).toList(),
      upcomingAppointments:
          appointmentsJson.map(UpcomingAppointment.fromJson).toList(),
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

  /// Takes the **payload**, not the envelope around it — see
  /// [DashboardData.fromJson].
  factory OrganizationData.fromJson(Map<String, dynamic> json) =>
      OrganizationData(
        id: asString(json['id']),
        name: asString(json['name'], fallback: 'MediHive'),
        logoUrl: asStringOrNull(json['logoUrl']),
        logoTextUrl: asStringOrNull(json['logoTextUrl']),
        primaryColor: asString(json['primaryColor'], fallback: '#0A84FF'),
        secondaryColor: asString(json['secondaryColor'], fallback: '#30D158'),
        email: asString(json['email']),
        phone: asString(json['phone']),
        address: asString(json['address']),
        city: asString(json['city']),
        country: asString(json['country']),
      );
}
