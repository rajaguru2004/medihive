class QueueItemPatient {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String? phonePrimary;
  final String gender;

  const QueueItemPatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    this.phonePrimary,
    required this.gender,
  });

  factory QueueItemPatient.fromJson(Map<String, dynamic> json) {
    return QueueItemPatient(
      id: json['id'] as String? ?? '',
      mrn: json['mrn'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      phonePrimary: json['phonePrimary'] as String?,
      gender: json['gender'] as String? ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

class QueueItem {
  final String id;
  final String organizationId;
  final String patientId;
  final String serviceArea;
  final String? serviceType;
  final String queueNumber;
  final String priority;
  final String? assignedRoom;
  final String status;
  final DateTime joinedQueueAt;
  final DateTime? calledAt;
  final int waitTime;
  final QueueItemPatient patient;

  const QueueItem({
    required this.id,
    required this.organizationId,
    required this.patientId,
    required this.serviceArea,
    this.serviceType,
    required this.queueNumber,
    required this.priority,
    this.assignedRoom,
    required this.status,
    required this.joinedQueueAt,
    this.calledAt,
    required this.waitTime,
    required this.patient,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      serviceArea: json['serviceArea'] as String? ?? '',
      serviceType: json['serviceType'] as String?,
      queueNumber: json['queueNumber'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      assignedRoom: json['assignedRoom'] as String?,
      status: json['status'] as String? ?? '',
      joinedQueueAt:
          DateTime.tryParse(json['joinedQueueAt'] as String? ?? '') ??
              DateTime.now(),
      calledAt: json['calledAt'] != null
          ? DateTime.tryParse(json['calledAt'] as String)
          : null,
      waitTime: (json['waitTime'] as num?)?.toInt() ?? 0,
      patient: QueueItemPatient.fromJson(
          (json['patient'] as Map<String, dynamic>?) ?? {}),
    );
  }

  /// Format queue number to show just the last 4 characters if it's long,
  /// or show full if it's short.
  String get displayQueueNumber {
    if (queueNumber.length > 4) {
      return queueNumber.substring(queueNumber.length - 4);
    }
    return queueNumber;
  }
}
