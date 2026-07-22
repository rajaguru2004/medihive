class SimpleWardModel {
  final String id;
  final String organizationId;
  final String? departmentId;
  final String name;
  final String code;
  final String type;
  final int capacity;
  final bool isActive;

  SimpleWardModel({
    required this.id,
    required this.organizationId,
    this.departmentId,
    required this.name,
    required this.code,
    required this.type,
    required this.capacity,
    required this.isActive,
  });

  factory SimpleWardModel.fromJson(Map<String, dynamic> json) =>
      SimpleWardModel(
        id: json['id'] as String? ?? '',
        organizationId: json['organizationId'] as String? ?? '',
        departmentId: json['departmentId'] as String?,
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        type: json['type'] as String? ?? '',
        capacity: json['capacity'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? false,
      );
}

class BedModel {
  final String id;
  final String organizationId;
  final String wardId;
  final String bedNumber;
  final String type;
  final String status; // 'occupied', 'available', 'maintenance'
  final String? currentPatientId;
  final SimpleWardModel? ward;

  BedModel({
    required this.id,
    required this.organizationId,
    required this.wardId,
    required this.bedNumber,
    required this.type,
    required this.status,
    this.currentPatientId,
    this.ward,
  });

  factory BedModel.fromJson(Map<String, dynamic> json) => BedModel(
        id: json['id'] as String? ?? '',
        organizationId: json['organizationId'] as String? ?? '',
        wardId: json['wardId'] as String? ?? '',
        bedNumber: json['bedNumber'] as String? ?? '',
        type: json['type'] as String? ?? '',
        status: json['status'] as String? ?? 'available',
        currentPatientId: json['currentPatientId'] as String?,
        ward: json['ward'] != null
            ? SimpleWardModel.fromJson(json['ward'] as Map<String, dynamic>)
            : null,
      );
}
