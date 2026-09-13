import 'bed_model.dart';

class WardModel {
  final String id;
  final String organizationId;
  final String? departmentId;
  final String name;
  final String code;
  final String type;
  final int capacity;
  final bool isActive;
  final List<BedModel> beds;
  final int occupiedBeds;
  final int availableBeds;
  final double occupancyRate;

  WardModel({
    required this.id,
    required this.organizationId,
    this.departmentId,
    required this.name,
    required this.code,
    required this.type,
    required this.capacity,
    required this.isActive,
    required this.beds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.occupancyRate,
  });

  factory WardModel.fromJson(Map<String, dynamic> json) {
    final bedsList = json['beds'] as List? ?? [];
    final List<BedModel> parsedBeds = [];
    for (var bedJson in bedsList) {
      if (bedJson is Map<String, dynamic>) {
        parsedBeds.add(BedModel.fromJson(bedJson));
      }
    }

    return WardModel(
      id: json['id'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
      departmentId: json['departmentId'] as String?,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      type: json['type'] as String? ?? '',
      capacity: json['capacity'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      beds: parsedBeds,
      occupiedBeds: json['occupiedBeds'] as int? ?? 0,
      availableBeds: json['availableBeds'] as int? ?? 0,
      occupancyRate: (json['occupancyRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
