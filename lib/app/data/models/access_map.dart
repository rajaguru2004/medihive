/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what this account may do, per module
///
/// `GET /api/auth/me` answers with an access map:
///
/// ```json
/// { "modules": { "patients": { "canCreate": true, "canRead": true, … } } }
/// ```
///
/// keyed by the module names the server's permission rows are categorised
/// under. This is the app's copy of it, and like `AuthUser.permissions` it is a
/// **hint**: the server authorises every request on its own, and a screen that
/// gates a button on this must still handle the 403 that arrives anyway — see
/// `ApiForbiddenException`.
///
/// What it is for is the other direction. A clinician who cannot dispense
/// should not be shown a Pharmacy tab that answers 403 when tapped; a nurse who
/// cannot delete should not be offered a swipe action that fails. Hiding what
/// cannot be done is the difference between an app that fits a role and one
/// that argues with it.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// The four things a module's rows can be asked to do.
enum AccessVerb { create, read, update, delete }

/// The module keys the server categorises permissions under.
///
/// Spelled exactly as the server spells them — **including the hyphen in
/// `pre-triage`**, which is the one that does not follow the pattern and the
/// one a typo hides in: `preTriage` finds nothing and reads as "no access".
abstract final class Modules {
  static const String patients = 'patients';
  static const String appointments = 'appointments';
  static const String consultations = 'consultations';
  static const String preTriage = 'pre-triage';
  static const String queue = 'queue';
  static const String inpatient = 'inpatient';
  static const String laboratory = 'laboratory';
  static const String radiology = 'radiology';
  static const String pharmacy = 'pharmacy';
  static const String billing = 'billing';
  static const String integrations = 'integrations';
  static const String users = 'users';
  static const String roles = 'roles';
  static const String permissions = 'permissions';
  static const String settings = 'settings';
  static const String dashboard = 'dashboard';
  static const String audit = 'audit';

  /// Named because the permission vocabulary maps onto it
  /// (`DEATH_CERTIFICATE_READ`), but deliberately **not** in [all]: the server
  /// seeds no permission rows in this category, so it never appears in an
  /// access map and listing it would show a tab nobody can reach.
  static const String deathCertificates = 'death-certificates';

  /// Every module the server's access map can carry.
  static const List<String> all = [
    patients,
    appointments,
    consultations,
    preTriage,
    queue,
    inpatient,
    laboratory,
    radiology,
    pharmacy,
    billing,
    integrations,
    users,
    roles,
    permissions,
    settings,
    dashboard,
    audit,
  ];
}

/// What one account may do to one module.
class ModuleAccess {
  const ModuleAccess({
    this.canCreate = false,
    this.canRead = false,
    this.canUpdate = false,
    this.canDelete = false,
  });

  final bool canCreate;
  final bool canRead;
  final bool canUpdate;
  final bool canDelete;

  /// The safe answer for a module the map says nothing about.
  ///
  /// Closed rather than open: a module the server did not mention is one this
  /// account was not granted, and defaulting to "yes" would offer a nurse a
  /// Users tab that 403s on every row.
  static const ModuleAccess none = ModuleAccess();

  static const ModuleAccess full = ModuleAccess(
    canCreate: true,
    canRead: true,
    canUpdate: true,
    canDelete: true,
  );

  bool allows(AccessVerb verb) => switch (verb) {
        AccessVerb.create => canCreate,
        AccessVerb.read => canRead,
        AccessVerb.update => canUpdate,
        AccessVerb.delete => canDelete,
      };

  /// True when this account can change something here — the test a form or a
  /// floating action button asks.
  bool get canWrite => canCreate || canUpdate || canDelete;

  bool get isEmpty => !canRead && !canWrite;

  /// The union of two grants. A user holding two roles gets what either allows,
  /// which is how the server resolves them too.
  ModuleAccess merge(ModuleAccess other) => ModuleAccess(
        canCreate: canCreate || other.canCreate,
        canRead: canRead || other.canRead,
        canUpdate: canUpdate || other.canUpdate,
        canDelete: canDelete || other.canDelete,
      );

  ModuleAccess withVerb(AccessVerb verb) => ModuleAccess(
        canCreate: canCreate || verb == AccessVerb.create,
        canRead: canRead || verb == AccessVerb.read,
        canUpdate: canUpdate || verb == AccessVerb.update,
        canDelete: canDelete || verb == AccessVerb.delete,
      );

  factory ModuleAccess.fromJson(Map<String, dynamic> json) => ModuleAccess(
        canCreate: json['canCreate'] == true,
        canRead: json['canRead'] == true,
        canUpdate: json['canUpdate'] == true,
        canDelete: json['canDelete'] == true,
      );

  Map<String, dynamic> toJson() => {
        'canCreate': canCreate,
        'canRead': canRead,
        'canUpdate': canUpdate,
        'canDelete': canDelete,
      };

  @override
  String toString() =>
      'ModuleAccess(${canCreate ? 'C' : '-'}${canRead ? 'R' : '-'}'
      '${canUpdate ? 'U' : '-'}${canDelete ? 'D' : '-'})';
}

/// Every module this account can touch, and what it may do there.
class AccessMap {
  const AccessMap({this.modules = const {}, this.isSuperAdmin = false});

  final Map<String, ModuleAccess> modules;

  /// A super admin holds every module whether or not the map names it, which
  /// is how the server resolves the role. Kept as a flag rather than expanded
  /// into seventeen entries so a map read back from storage still says *why*
  /// it allows everything.
  final bool isSuperAdmin;

  /// No access at all — what a cold start runs on before the first fetch, and
  /// what a failed one falls back to.
  static const AccessMap empty = AccessMap();

  ModuleAccess of(String module) =>
      isSuperAdmin ? ModuleAccess.full : (modules[module] ?? ModuleAccess.none);

  bool can(String module, AccessVerb verb) => of(module).allows(verb);

  /// True when this account can read *something*.
  ///
  /// The question sign-in asks: an authenticated user whose every module is
  /// closed has no screen in this app that works, and dropping them on a shell
  /// of empty tabs is worse than telling them so — see
  /// `SessionEndReason.noAccess`.
  bool get isUsable =>
      isSuperAdmin || modules.values.any((access) => access.canRead);

  bool get isEmpty => !isSuperAdmin && modules.isEmpty;

  /// Reads either the `/auth/me` shape (`{modules: {…}}`) or the bare map that
  /// `/auth/me/access` and this class's own [toJson] produce.
  factory AccessMap.fromJson(Map<String, dynamic> json) {
    final raw = json['modules'] is Map ? json['modules'] as Map : json;
    return AccessMap(
      modules: {
        for (final entry in raw.entries)
          if (entry.value is Map)
            entry.key.toString(): ModuleAccess.fromJson(
              (entry.value as Map).cast<String, dynamic>(),
            ),
      },
      isSuperAdmin: json['isSuperAdmin'] == true,
    );
  }

  /// Rebuilds the map from the permission strings in a JWT.
  ///
  /// The last resort, for when `/auth/me` and `/auth/me/access` are both
  /// unreachable but the token in hand still lists what it was granted. The
  /// server derives its map from the same rows, so this lands in the same place
  /// — it is second choice because a token minted before a role changed is
  /// stale, and `/auth/me` never is.
  factory AccessMap.fromPermissions(Iterable<String> permissions) {
    final modules = <String, ModuleAccess>{};
    var superAdmin = false;

    for (final raw in permissions) {
      final code = raw.trim().toUpperCase();
      if (code.isEmpty) continue;
      if (code == 'SUPER_ADMIN' || code == '*') {
        superAdmin = true;
        continue;
      }

      final cut = code.lastIndexOf('_');
      if (cut <= 0) continue;

      final verb = _verbs[code.substring(cut + 1)];
      final module = _modulesByPrefix[code.substring(0, cut)];
      if (verb == null || module == null) continue;

      modules[module] = (modules[module] ?? ModuleAccess.none).withVerb(verb);
    }

    return AccessMap(modules: modules, isSuperAdmin: superAdmin);
  }

  Map<String, dynamic> toJson() => {
        'modules': {
          for (final entry in modules.entries) entry.key: entry.value.toJson(),
        },
        'isSuperAdmin': isSuperAdmin,
      };

  /// `PATIENT_READ` → `patients`. The permission vocabulary is singular and
  /// upper-case; the module keys are the server's own category strings, which
  /// are plural, lower-case, and hyphenated where the module name is.
  static const Map<String, String> _modulesByPrefix = {
    'PATIENT': Modules.patients,
    'APPOINTMENT': Modules.appointments,
    'CONSULTATION': Modules.consultations,
    'PRE_TRIAGE': Modules.preTriage,
    'QUEUE': Modules.queue,
    'INPATIENT': Modules.inpatient,
    'LABORATORY': Modules.laboratory,
    'RADIOLOGY': Modules.radiology,
    'PHARMACY': Modules.pharmacy,
    'BILLING': Modules.billing,
    'INTEGRATION': Modules.integrations,
    'USER': Modules.users,
    'ROLE': Modules.roles,
    'PERMISSION': Modules.permissions,
    'SETTINGS': Modules.settings,
    'DASHBOARD': Modules.dashboard,
    'AUDIT': Modules.audit,
    'DEATH_CERTIFICATE': Modules.deathCertificates,
  };

  static const Map<String, AccessVerb> _verbs = {
    'CREATE': AccessVerb.create,
    'READ': AccessVerb.read,
    'UPDATE': AccessVerb.update,
    'DELETE': AccessVerb.delete,
    // `PERMISSION_ASSIGN` is the one verb outside the four. Granting a role a
    // permission is a change to that role, so it lands on update.
    'ASSIGN': AccessVerb.update,
  };

  @override
  String toString() => isSuperAdmin
      ? 'AccessMap(super admin)'
      : 'AccessMap(${modules.length} modules)';
}
