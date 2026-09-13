import 'json.dart';

/// The signed-in user, as the app needs them.
///
/// Cached in encrypted storage beside the token so a cold start can paint the
/// shell — name, role, avatar — before `GET /auth/me` answers. Every field is
/// read defensively: a backend that adds a claim must not break a build that
/// predates it.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = '',
    this.roleId = '',
    this.avatar = '',
    this.department = '',
    this.permissions = const {},
  });

  final String id;
  final String name;
  final String email;

  /// The role's display name — "Consultant", "Charge nurse". Shown; never
  /// used to decide what somebody may do.
  final String role;

  final String roleId;
  final String avatar;
  final String department;

  /// What this user may actually do, as `<resource>.<action>` strings.
  ///
  /// Authorisation is the server's job and this is a *hint*: it exists so the
  /// app can avoid offering a button that would come back 403, not so it can
  /// enforce anything. A screen that gates on this must still handle the 403.
  final Set<String> permissions;

  static const AuthUser empty = AuthUser(id: '', name: '', email: '');

  bool get isEmpty => id.isEmpty;

  /// The initials for an avatar fallback. Two letters at most: three is a
  /// monogram, and a monogram in a 34 dp circle is a smudge.
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  bool can(String permission) => permissions.contains(permission);

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    // The role arrives either as an id string or as the populated document,
    // depending on whether the route called `.populate()`.
    final roleRaw = json['role'];
    final roleMap = roleRaw is Map ? roleRaw.cast<String, dynamic>() : null;

    return AuthUser(
      id: asString(json['_id'] ?? json['id']),
      name: asString(
        json['name'] ??
            [json['firstName'], json['lastName']]
                .where((p) => asString(p).isNotEmpty)
                .join(' '),
      ),
      email: asString(json['email']),
      role: asString(roleMap?['name'] ?? json['roleName'] ?? roleRaw),
      roleId: asString(roleMap?['_id'] ?? roleMap?['id'] ?? roleRaw),
      avatar: asString(json['avatar'] ?? json['photo']),
      department: asString(json['department'] ?? json['departmentName']),
      permissions: {
        for (final p in (json['permissions'] as List? ?? const []))
          asString(p is Map ? (p['code'] ?? p['name']) : p),
      }..removeWhere((p) => p.isEmpty),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'roleName': role,
        'role': roleId,
        'avatar': avatar,
        'department': department,
        'permissions': permissions.toList(),
      };
}
