/// Centralized API endpoint definitions for MediHive.
///
/// All path constants live here. Providers reference these —
/// never hardcode paths in business logic or controllers.
///
/// Base URL is configured in [AppDioClient].
abstract class Endpoints {
  Endpoints._();

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/logout';
  static const String refreshToken = '/api/auth/refresh';
  static const String me = '/api/auth/me';
  static const String meAccess = '/api/auth/me/access';
  static const String changePassword = '/api/auth/change-password';

  // ─── Users ─────────────────────────────────────────────────────────────────
  static const String users = '/api/users';
  static String userById(String id) => '/api/users/$id';

  // ─── Roles ─────────────────────────────────────────────────────────────────
  static const String roles = '/api/roles';
  static String roleById(String id) => '/api/roles/$id';

  // ─── Permissions ───────────────────────────────────────────────────────────
  static const String permissions = '/api/permissions';
  static String assignPermission(String roleId) =>
      '/api/roles/$roleId/permissions';

  // ─── Patients ──────────────────────────────────────────────────────────────
  static const String patients = '/api/patients';
  static String patientById(String id) => '/api/patients/$id';

  // ─── Appointments ──────────────────────────────────────────────────────────
  static const String appointments = '/api/appointments';
  static String appointmentById(String id) => '/api/appointments/$id';

  // ─── Consultations ─────────────────────────────────────────────────────────
  static const String consultations = '/api/consultations';
  static String consultationById(String id) => '/api/consultations/$id';

  // ─── Inpatient ─────────────────────────────────────────────────────────────
  static const String inpatient = '/api/inpatient';
  static String inpatientById(String id) => '/api/inpatient/$id';

  // ─── Laboratory ────────────────────────────────────────────────────────────
  static const String laboratory = '/api/laboratory';
  static String laboratoryById(String id) => '/api/laboratory/$id';

  // ─── Radiology ─────────────────────────────────────────────────────────────
  static const String radiology = '/api/radiology';
  static String radiologyById(String id) => '/api/radiology/$id';

  // ─── Pharmacy ──────────────────────────────────────────────────────────────
  static const String pharmacy = '/api/pharmacy';
  static String pharmacyById(String id) => '/api/pharmacy/$id';

  // ─── Pre-Triage ────────────────────────────────────────────────────────────
  static const String preTriage = '/api/pre-triage';
  static String preTriageById(String id) => '/api/pre-triage/$id';
  static String convertPreTriage(String id) => '/api/pre-triage/$id/convert';

  // ─── Queue ─────────────────────────────────────────────────────────────────
  static const String queue = '/api/queue';
  static String queueById(String id) => '/api/queue/$id';

  // ─── Billing ───────────────────────────────────────────────────────────────
  static const String billing = '/api/billing';
  static String billingById(String id) => '/api/billing/$id';

  // ─── Audit ─────────────────────────────────────────────────────────────────
  static const String audit = '/api/audit';

  // ─── Integrations ──────────────────────────────────────────────────────────
  static const String integrations = '/api/integrations';
  static String integrationById(String id) => '/api/integrations/$id';

  // ─── Dashboard ─────────────────────────────────────────────────────────────
  static const String dashboard = '/api/dashboard';

  // ─── Settings ──────────────────────────────────────────────────────────────
  static const String settings = '/api/settings';
}
