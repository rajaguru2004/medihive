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
    this.headName,
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

  /// Who heads it, where the route resolved the name as well as the id.
  ///
  /// `GET /settings/departments` looks it up; the collection routes send only
  /// [headId]. Null therefore means "not told", never "nobody" — a screen that
  /// printed "No head" from a route that simply did not join would be stating
  /// something about the department that nobody said.
  final String? headName;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const Department empty = Department();

  bool get isEmpty => id.isEmpty && name.isEmpty;

  /// The code where a site keeps one, the name otherwise — never a blank cell.
  String get displayCode => (code ?? '').isNotEmpty ? code! : name;

  factory Department.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['_count']);
    // `_count.users` on the collection routes, `userCount` on
    // `GET /settings/departments`, which shapes its own row rather than sending
    // Prisma's. Reading only the first left the settings screen with no idea
    // how many people a department it was about to delete holds.
    final staff = counts['users'] ?? json['userCount'];
    return Department(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      name: asString(json['name']),
      code: asStringOrNull(json['code']),
      description: asStringOrNull(json['description']),
      headId: asStringOrNull(json['headId']),
      headName: asStringOrNull(json['headName']),
      isActive: asBool(json['isActive'], fallback: true),
      staffCount: staff == null ? null : asInt(staff),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
    );
  }

  factory Department.of(dynamic value) =>
      value is Map ? Department.fromJson(value.cast<String, dynamic>()) : empty;
}
