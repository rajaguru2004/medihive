import 'json.dart';

/// A clinical or administrative unit — Cardiology, Laboratory, Records.
///
/// Wards hang off one and so do staff, so a department that fails to parse
/// takes a ward board's grouping with it.
class Department {
  const Department({
    this.id = '',
    this.organizationId = '',
    this.name = '',
    this.code,
    this.description,
    this.headId,
    this.isActive = true,
    this.staffCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;

  final String name;

  /// `CARD`. What a rota or a room sign says where the full name will not fit.
  final String? code;

  final String? description;

  /// The user who heads it, where a site records one.
  final String? headId;

  final bool isActive;

  /// From the `_count` block on the routes that send one; null means the route
  /// did not count rather than that the department is empty.
  final int? staffCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const Department empty = Department();

  bool get isEmpty => id.isEmpty && name.isEmpty;

  /// The code where a site keeps one, the name otherwise — never a blank cell.
  String get displayCode => (code ?? '').isNotEmpty ? code! : name;

  factory Department.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['_count']);
    return Department(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      name: asString(json['name']),
      code: asStringOrNull(json['code']),
      description: asStringOrNull(json['description']),
      headId: asStringOrNull(json['headId']),
      isActive: asBool(json['isActive'], fallback: true),
      staffCount: counts['users'] == null ? null : asInt(counts['users']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
    );
  }

  factory Department.of(dynamic value) =>
      value is Map ? Department.fromJson(value.cast<String, dynamic>()) : empty;
}
