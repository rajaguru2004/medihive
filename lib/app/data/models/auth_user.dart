import '../utils/jwt_claims.dart';
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
    this.roles = const {},
    this.avatar = '',
    this.department = '',
    this.organizationId = '',
    this.permissions = const {},
  });

  final String id;
  final String name;
  final String email;

  /// The role's display name — "Consultant", "Charge nurse". Shown; never
  /// used to decide what somebody may do.
  final String role;

  final String roleId;

  /// Every role this account holds, by name. Plural because an account can
  /// hold several, and because `SUPER_ADMIN` is a role rather than a
  /// permission — the one role the access map reads.
  final Set<String> roles;

  final String avatar;
  final String department;

  /// Which hospital this account belongs to.
  ///
  /// Carried because the server scopes every row by it and a few routes still
  /// want it named. Read from the token: `/auth/me` puts it on the
  /// organisation rather than on the user.
  final String organizationId;

  /// What this user may actually do, as `<MODULE>_<VERB>` strings.
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

  /// Holds the role that bypasses the access map.
  bool get isSuperAdmin => roles.contains('SUPER_ADMIN');

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    // The role arrives either as an id string or as the populated document,
    // depending on whether the route called `.populate()`.
    final roleRaw = json['role'];
    final roleMap = roleRaw is Map ? roleRaw.cast<String, dynamic>() : null;

    // Same for the department: `/auth/me` sends `{id, name}` and the cached
    // copy this class writes sends the name alone. Reading the map with
    // `asString` printed `{id: d-2, name: Emergency}` into the shell's header.
    final departmentRaw = json['department'];
    final departmentMap =
        departmentRaw is Map ? departmentRaw.cast<String, dynamic>() : null;

    return AuthUser(
      id: asString(json['_id'] ?? json['id']),
      name: asString(
        json['name'] ??
            json['fullName'] ??
            [json['firstName'], json['lastName']]
                .where((p) => asString(p).isNotEmpty)
                .join(' '),
      ),
      email: asString(json['email']),
      role: asString(roleMap?['name'] ?? json['roleName'] ?? roleRaw),
      roleId: asString(roleMap?['_id'] ?? roleMap?['id'] ?? roleRaw),
      roles: _stringSet(json['roles']),
      avatar: asString(json['avatar'] ?? json['photo']),
      department: asString(
        json['departmentName'] ?? departmentMap?['name'] ?? departmentRaw,
      ),
      organizationId: asString(json['organizationId']),
      permissions: {
        for (final p in (json['permissions'] as List? ?? const []))
          asString(p is Map ? (p['code'] ?? p['name']) : p),
      }..removeWhere((p) => p.isEmpty),
    );
  }

  /// Builds from the `/auth/me` payload, which nests the user under `user` and
  /// carries the organisation beside it.
  ///
  /// Tolerates the bare user object too, because that is what the route used to
  /// answer with and what the e2e fixtures still send.
  factory AuthUser.fromMePayload(Map<String, dynamic> payload) {
    final user = payload['user'] is Map
        ? (payload['user'] as Map).cast<String, dynamic>()
        : payload;
    final organization = payload['organization'] is Map
        ? (payload['organization'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final base = AuthUser.fromJson(user);
    final organizationId = asString(organization['id']);
    return organizationId.isEmpty
        ? base
        : base.copyWith(organizationId: organizationId);
  }

  /// Builds from the access token alone.
  ///
  /// `POST /auth/login` answers with a token and no user, so this is what the
  /// shell paints from between signing in and `/auth/me` landing. The name is a
  /// placeholder derived from the email — the token carries no display name —
  /// and is replaced the moment the real payload arrives.
  factory AuthUser.fromClaims(JwtClaims claims, {String? fallbackEmail}) {
    final email = claims.email.isNotEmpty ? claims.email : (fallbackEmail ?? '');
    return AuthUser(
      id: claims.sub,
      name: email.contains('@') ? email.split('@').first : email,
      email: email,
      role: claims.roles.isEmpty ? '' : claims.roles.first,
      roles: claims.roles,
      organizationId: claims.organizationId,
      permissions: claims.permissions,
    );
  }

  AuthUser copyWith({
    String? name,
    String? role,
    String? avatar,
    String? department,
    String? organizationId,
    Set<String>? roles,
    Set<String>? permissions,
  }) =>
      AuthUser(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role ?? this.role,
        roleId: roleId,
        roles: roles ?? this.roles,
        avatar: avatar ?? this.avatar,
        department: department ?? this.department,
        organizationId: organizationId ?? this.organizationId,
        permissions: permissions ?? this.permissions,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'roleName': role,
        'role': roleId,
        'roles': roles.toList(),
        'avatar': avatar,
        'department': department,
        'organizationId': organizationId,
        'permissions': permissions.toList(),
      };

  static Set<String> _stringSet(dynamic value) {
    if (value is! List) return const {};
    return {
      for (final entry in value)
        asString(entry is Map ? (entry['name'] ?? entry['code']) : entry),
    }..removeWhere((entry) => entry.isEmpty);
  }
}
