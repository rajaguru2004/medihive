/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — API surface
///
/// Every path the app calls, in one file. A path spelled inline at a call site
/// is a path nobody can grep for when the backend renames a route.
///
/// The backend mounts everything under `/api` and reads the bearer token from
/// the `Authorization` header. Two tiers:
///
///   * unauthenticated — `/auth/login`, `/auth/refresh`
///   * authenticated — everything else
///
/// Collection routes follow one shape (`/<entity>`, `/<entity>/<id>`), so
/// [Crud] builds them rather than listing four near-identical constants per
/// entity.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class Endpoints {
  /// The server this build talks to.
  ///
  /// Overridden per environment without touching code:
  ///
  /// ```sh
  /// flutter run --dart-define=MEDIHIVE_API=https://api.example.com/
  /// ```
  ///
  /// The default is the emulator's loopback to the host machine
  /// (`10.0.2.2` on Android), which is where the backend serves in dev.
  static const String baseUrl = String.fromEnvironment(
    'MEDIHIVE_API',
    defaultValue: 'http://10.0.2.2:8000/',
  );

  /// Where uploaded files live. The API returns storage-relative paths, which
  /// `fileUrl()` joins onto this. When object storage is configured the API
  /// returns absolute URLs instead, and `fileUrl()` passes those through
  /// untouched.
  static const String fileBaseUrl = String.fromEnvironment(
    'MEDIHIVE_FILES',
    defaultValue: 'http://10.0.2.2:8000/',
  );

  /// Whether this build is pointed somewhere only a developer can reach.
  ///
  /// The default above is the Android emulator's loopback to the host machine,
  /// which is right for `flutter run` and wrong for anything shipped: a
  /// release build with no `--dart-define` reaches a host that does not exist,
  /// over cleartext that both platforms refuse, and shows a network error on
  /// its first screen with nothing explaining why. `main()` checks this and
  /// says so out loud in debug.
  static bool get isLoopback =>
      baseUrl.contains('10.0.2.2') || baseUrl.contains('localhost');

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/logout';
  static const String refreshToken = '/api/auth/refresh';
  static const String me = '/api/auth/me';
  static const String meAccess = '/api/auth/me/access';
  static const String changePassword = '/api/auth/change-password';

  // ── Collections ───────────────────────────────────────────────────────────
  //
  // One [Crud] per resource. Anything that is not list/read/create/update/
  // delete gets a named constant below its group.

  static const users = Crud('/api/users');
  static const roles = Crud('/api/roles');
  static const permissions = Crud('/api/permissions');
  static const patients = Crud('/api/patients');
  static const appointments = Crud('/api/appointments');
  static const consultations = Crud('/api/consultations');
  static const inpatient = Crud('/api/inpatient');
  static const wards = Crud('/api/inpatient/wards');
  static const beds = Crud('/api/inpatient/beds');
  static const admissions = Crud('/api/inpatient/admissions');
  static const laboratory = Crud('/api/laboratory');
  static const radiology = Crud('/api/radiology');
  static const pharmacy = Crud('/api/pharmacy');
  static const preTriage = Crud('/api/pre-triage');
  static const queue = Crud('/api/queue');
  static const billing = Crud('/api/billing');
  static const integrations = Crud('/api/integrations');

  // ── Named actions ─────────────────────────────────────────────────────────

  /// Turns a screening into a live queue entry or appointment.
  static String convertPreTriage(String id) => '/api/pre-triage/$id/convert';

  /// Moves a queue entry to the next state (called, in progress, done).
  static String advanceQueue(String id) => '/api/queue/$id/advance';

  /// Discharges an admission. Not a `delete`: the record stays, its state
  /// moves, and the bed is released as a side effect the server owns.
  static String discharge(String id) =>
      '/api/inpatient/admissions/$id/discharge';

  /// Moves an admission to another bed.
  static String transferBed(String id) =>
      '/api/inpatient/admissions/$id/transfer';

  /// The beds belonging to one ward.
  static String bedsInWard(String wardId) =>
      '/api/inpatient/wards/$wardId/beds';

  static String assignPermission(String roleId) =>
      '/api/roles/$roleId/permissions';

  // ── Singletons ────────────────────────────────────────────────────────────
  static const String dashboard = '/api/dashboard';
  static const String settings = '/api/settings';
  static const String audit = '/api/audit';
  static const String upload = '/api/upload';
}

/// The five routes every collection has, built from one base path.
///
/// Exists so that adding a resource is one line rather than five near-identical
/// constants, and so that a rename is one edit rather than five.
class Crud {
  const Crud(this.base);

  /// The collection path, with no trailing slash.
  final String base;

  String get list => base;
  String get create => base;
  String byId(String id) => '$base/$id';
  String update(String id) => '$base/$id';
  String delete(String id) => '$base/$id';

  /// A sub-collection under one record — `/api/patients/<id>/visits`.
  String sub(String id, String name) => '$base/$id/$name';
}
