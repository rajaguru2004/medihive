// lib/app/modules/queue/models/queue_model.dart

/// Represents the paginated queue response from /api/queue
class QueueResponse {
  final List<QueueModel> data;
  final QueueMeta meta;

  const QueueResponse({required this.data, required this.meta});

  factory QueueResponse.fromJson(Map<String, dynamic> json) {
    final outer = json['data'] as Map<String, dynamic>? ?? json;
    final dataList = outer['data'] as List<dynamic>? ?? [];
    final metaMap = outer['meta'] as Map<String, dynamic>? ?? {};
    return QueueResponse(
      data: dataList
          .map((e) => QueueModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: QueueMeta.fromJson(metaMap),
    );
  }
}

class QueueMeta {
  final int total;
  final int lastPage;
  final int currentPage;
  final int perPage;

  const QueueMeta({
    required this.total,
    required this.lastPage,
    required this.currentPage,
    required this.perPage,
  });

  factory QueueMeta.fromJson(Map<String, dynamic> json) => QueueMeta(
        total: json['total'] as int? ?? 0,
        lastPage: json['lastPage'] as int? ?? 1,
        currentPage: json['currentPage'] as int? ?? 1,
        perPage: json['perPage'] as int? ?? 100,
      );
}

class QueueModel {
  final String id;
  final String organizationId;
  final String patientId;
  final String serviceArea;
  final String? serviceType;
  final String queueNumber;
  final String priority;
  final String? assignedToId;
  final String? assignedRoom;
  final String status;
  final DateTime joinedQueueAt;
  final DateTime? calledAt;
  final DateTime? serviceStartedAt;
  final DateTime? serviceCompletedAt;
  final int? estimatedWaitMinutes;
  final String? displayMessage;
  final int waitTime;
  final QueuePatient patient;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QueueModel({
    required this.id,
    required this.organizationId,
    required this.patientId,
    required this.serviceArea,
    this.serviceType,
    required this.queueNumber,
    required this.priority,
    this.assignedToId,
    this.assignedRoom,
    required this.status,
    required this.joinedQueueAt,
    this.calledAt,
    this.serviceStartedAt,
    this.serviceCompletedAt,
    this.estimatedWaitMinutes,
    this.displayMessage,
    required this.waitTime,
    required this.patient,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QueueModel.fromJson(Map<String, dynamic> json) => QueueModel(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        patientId: json['patientId'] as String,
        serviceArea: json['serviceArea'] as String? ?? '',
        serviceType: json['serviceType'] as String?,
        queueNumber: json['queueNumber'] as String? ?? '',
        priority: json['priority'] as String? ?? 'routine',
        assignedToId: json['assignedToId'] as String?,
        assignedRoom: json['assignedRoom'] as String?,
        status: json['status'] as String? ?? 'waiting',
        joinedQueueAt: DateTime.parse(json['joinedQueueAt'] as String),
        calledAt: json['calledAt'] != null
            ? DateTime.parse(json['calledAt'] as String)
            : null,
        serviceStartedAt: json['serviceStartedAt'] != null
            ? DateTime.parse(json['serviceStartedAt'] as String)
            : null,
        serviceCompletedAt: json['serviceCompletedAt'] != null
            ? DateTime.parse(json['serviceCompletedAt'] as String)
            : null,
        estimatedWaitMinutes: json['estimatedWaitMinutes'] as int?,
        displayMessage: json['displayMessage'] as String?,
        waitTime: json['waitTime'] as int? ?? 0,
        patient: QueuePatient.fromJson(
            json['patient'] as Map<String, dynamic>? ?? {}),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  /// Short queue number (last 4 digits)
  String get shortQueueNumber {
    if (queueNumber.length >= 4) {
      return queueNumber.substring(queueNumber.length - 4);
    }
    return queueNumber;
  }

  /// Formatted wait time
  String get formattedWaitTime {
    if (waitTime < 60) return '${waitTime}m';
    final hours = waitTime ~/ 60;
    final mins = waitTime % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class QueuePatient {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String? phonePrimary;
  final String gender;

  const QueuePatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    this.phonePrimary,
    required this.gender,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory QueuePatient.fromJson(Map<String, dynamic> json) => QueuePatient(
        id: json['id'] as String? ?? '',
        mrn: json['mrn'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phonePrimary: json['phonePrimary'] as String?,
        gender: json['gender'] as String? ?? '',
      );
}

/// Summary derived from the queue list
class QueueSummary {
  final int waiting;
  final int called;
  final int inService;
  final int completed;

  const QueueSummary({
    required this.waiting,
    required this.called,
    required this.inService,
    required this.completed,
  });

  factory QueueSummary.fromList(List<QueueModel> items) {
    return QueueSummary(
      waiting: items.where((q) => q.status == 'waiting').length,
      called: items.where((q) => q.status == 'called').length,
      inService: items.where((q) => q.status == 'in_service').length,
      completed: items.where((q) => q.status == 'completed').length,
    );
  }
}

/// Patient model for the Add to Queue dropdown
class PatientOption {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String? phonePrimary;

  const PatientOption({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    this.phonePrimary,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get displayText => '$fullName • $mrn';

  factory PatientOption.fromJson(Map<String, dynamic> json) => PatientOption(
        id: json['id'] as String,
        mrn: json['mrn'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phonePrimary: json['phonePrimary'] as String?,
      );
}
