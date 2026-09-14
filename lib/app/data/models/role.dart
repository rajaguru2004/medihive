import 'json.dart';

/// One permission as a role holds it, with the four verbs spelled out.
///
/// The backend models a grant as a row joining a role to a permission plus
/// four booleans, so "has patients" is never a yes/no: a receptionist reads
/// and creates patients and must not delete one.
class PermissionGrant {
  const PermissionGrant({
    this.id = '',
    this.permissionId = '',
    this.name = '',
    this.code,
    this.category,
    this.description,
    this.canCreate = false,
    this.canRead = false,
    this.canUpdate = false,
    this.canDelete = false,
  });

  /// The join row's own id. Not the permission's — a role editor patches this
  /// grant, and sending the permission id in its place rewrites the wrong row.
  final String id;

  final String permissionId;

  /// The NestJS identifier — `USER_CREATE`.
  final String name;

  /// The console's key — `patients:create`. Null on permissions that predate
  /// it.
  final String? code;

  /// `patients`, `billing` — how a role editor groups its rows.
  final String? category;

  final String? description;

  final bool canCreate;
  final bool canRead;
  final bool canUpdate;
  final bool canDelete;

  bool get isEmpty => permissionId.isEmpty && name.isEmpty;

  /// Whether this grant gives anything at all. A row with four falses is a
  /// permission explicitly withheld, which a role editor must still show.
  bool get isGranted => canCreate || canRead || canUpdate || canDelete;

  /// The module this grant belongs to — the category where there is one, else
  /// the half of the code or name before the separator.
  String get module {
    final group = category ?? '';
    if (group.isNotEmpty) return group;
    final key = code ?? name;
    final separator = key.contains(':') ? ':' : '_';
    final head = key.split(separator).first;
    return head.toLowerCase();
  }

  factory PermissionGrant.fromJson(Map<String, dynamic> json) {
    // The join row nests the permission; a flattened row carries the same
    // fields at the top level. Both shapes reach this app.
    final permission = asMap(json['permission']);
    Object? pick(String key) => permission[key] ?? json[key];

    return PermissionGrant(
      id: asString(json['id'] ?? json['_id']),
      permissionId:
          asString(json['permissionId'], fallback: asString(permission['id'])),
      name: asString(pick('name')),
      code: asStringOrNull(pick('code')),
      category: asStringOrNull(pick('category')),
      description: asStringOrNull(pick('description')),
      canCreate: asBool(json['canCreate']),
      canRead: asBool(json['canRead']),
      canUpdate: asBool(json['canUpdate']),
      canDelete: asBool(json['canDelete']),
    );
  }

  /// The shape `PUT /roles/:id/permissions` accepts — the four verbs and the
  /// permission, and nothing else the DTO would reject.
  Map<String, dynamic> toAssignmentJson() => {
        'permissionId': permissionId,
        'canRead': canRead,
        'canUpdate': canUpdate,
        'canCreate': canCreate,
        'canDelete': canDelete,
      };
}

/// A named bundle of permissions.
class Role {
  const Role({
    this.id = '',
    this.name = '',
    this.description,
    this.isSystem = false,
    this.organizationId,
    this.permissions = const [],
    this.userCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Stored upper-cased by the backend, which upper-cases whatever it is sent.
  final String name;

  final String? description;

  /// A role the product ships. The backend refuses every edit to one, so a
  /// role editor must disable rather than let the save 403.
  final bool isSystem;

  /// Null on a role shared across every site.
  final String? organizationId;

  final List<PermissionGrant> permissions;

  /// From the `_count` block where a route sends one.
  final int? userCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const Role empty = Role();

  bool get isEmpty => id.isEmpty && name.isEmpty;

  bool get isEditable => !isSystem;

  /// `Ward Nurse` from `WARD_NURSE` — the stored token made readable.
  String get displayName => name
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');

  /// Grants that give something, grouped by module — what a role editor draws.
  Map<String, List<PermissionGrant>> get grantsByModule {
    final out = <String, List<PermissionGrant>>{};
    for (final grant in permissions) {
      out.putIfAbsent(grant.module, () => <PermissionGrant>[]).add(grant);
    }
    return out;
  }

  factory Role.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['_count']);
    return Role(
      id: asString(json['id'] ?? json['_id']),
      name: asString(json['name']),
      description: asStringOrNull(json['description']),
      isSystem: asBool(json['isSystem']),
      organizationId: asStringOrNull(json['organizationId']),
      permissions: asModelList(
        json['rolePermissions'] ?? json['permissions'],
        PermissionGrant.fromJson,
      ),
      userCount:
          counts['userRoles'] == null ? null : asInt(counts['userRoles']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
    );
  }

  factory Role.of(dynamic value) =>
      value is Map ? Role.fromJson(value.cast<String, dynamic>()) : empty;
}
