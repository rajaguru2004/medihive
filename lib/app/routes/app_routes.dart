// Route names are SCREAMING_CASE by convention here and in `get_cli`'s
// generator, which is what most GetX codebases read like. Renaming them to
// lowerCamelCase would make this file disagree with every GetX example anyone
// on the team will look up.
// ignore_for_file: constant_identifier_names

part of 'app_pages.dart';

/// Every route name in the app.
///
/// A route spelled inline at a call site is a route nobody can grep for when a
/// screen is renamed, and a typo in one is a silent navigation failure rather
/// than a compile error.
abstract class Routes {
  Routes._();

  static const SPLASH = _Paths.SPLASH;
  static const LOGIN = _Paths.LOGIN;
  static const HOME = _Paths.HOME;
  static const DASHBOARD = _Paths.DASHBOARD;

  // ── Queue ─────────────────────────────────────────────────────────────────
  static const QUEUE = _Paths.QUEUE;
  static const ADD_TO_QUEUE = _Paths.ADD_TO_QUEUE;

  // ── Clinic ────────────────────────────────────────────────────────────────
  static const APPOINTMENTS = _Paths.APPOINTMENTS;
  static const APPOINTMENT_CREATE = _Paths.APPOINTMENT_CREATE;
  static const CONSULTATIONS = _Paths.CONSULTATIONS;

  // ── Pre-triage ────────────────────────────────────────────────────────────
  static const PRE_TRIAGE = _Paths.PRE_TRIAGE;
  static const PRE_TRIAGE_DETAILS = _Paths.PRE_TRIAGE_DETAILS;
  static const NEW_SCREENING_STEP1 = _Paths.NEW_SCREENING_STEP1;
  static const NEW_SCREENING_STEP2 = _Paths.NEW_SCREENING_STEP2;
  static const EDIT_SCREENING = _Paths.EDIT_SCREENING;

  // ── Inpatient ─────────────────────────────────────────────────────────────
  static const INPATIENT = _Paths.INPATIENT;
  static const INPATIENT_OVERVIEW = _Paths.INPATIENT_OVERVIEW;
  static const INPATIENT_WARDS = _Paths.INPATIENT_WARDS;
  static const INPATIENT_BEDS_GRID = _Paths.INPATIENT_BEDS_GRID;
  static const INPATIENT_ADMISSIONS = _Paths.INPATIENT_ADMISSIONS;
  static const INPATIENT_ADD_WARD = _Paths.INPATIENT_ADD_WARD;
  static const INPATIENT_ADD_BED = _Paths.INPATIENT_ADD_BED;
  static const INPATIENT_ADMIT = _Paths.INPATIENT_ADMIT;
  static const DISCHARGE_PATIENT = _Paths.DISCHARGE_PATIENT;

  // ── Routed, not yet built ─────────────────────────────────────────────────
  static const PATIENTS = _Paths.PATIENTS;
  static const PHARMACY = _Paths.PHARMACY;
  static const LABORATORY = _Paths.LABORATORY;
  static const RADIOLOGY = _Paths.RADIOLOGY;
  static const BILLING = _Paths.BILLING;
  static const USERS_STAFF = _Paths.USERS_STAFF;
  static const INTEGRATIONS = _Paths.INTEGRATIONS;
}

abstract class _Paths {
  _Paths._();

  static const SPLASH = '/splash';
  static const LOGIN = '/login';
  static const HOME = '/home';
  static const DASHBOARD = '/dashboard';

  static const QUEUE = '/queue';
  static const ADD_TO_QUEUE = '/queue/add';

  static const APPOINTMENTS = '/appointments';
  static const APPOINTMENT_CREATE = '/appointments/create';
  static const CONSULTATIONS = '/consultations';

  static const PRE_TRIAGE = '/pre-triage';
  static const PRE_TRIAGE_DETAILS = '/pre-triage/details';
  static const NEW_SCREENING_STEP1 = '/pre-triage/new-step1';
  static const NEW_SCREENING_STEP2 = '/pre-triage/new-step2';
  static const EDIT_SCREENING = '/pre-triage/edit';

  static const INPATIENT = '/inpatient';
  static const INPATIENT_OVERVIEW = '/inpatient/overview';
  static const INPATIENT_WARDS = '/inpatient/wards';
  static const INPATIENT_BEDS_GRID = '/inpatient/beds';
  static const INPATIENT_ADMISSIONS = '/inpatient/admissions';
  static const INPATIENT_ADD_WARD = '/inpatient/wards/add';
  static const INPATIENT_ADD_BED = '/inpatient/beds/add';
  static const INPATIENT_ADMIT = '/inpatient/admit';
  static const DISCHARGE_PATIENT = '/inpatient/discharge';

  static const PATIENTS = '/patients';
  static const PHARMACY = '/pharmacy';
  static const LABORATORY = '/laboratory';
  static const RADIOLOGY = '/radiology';
  static const BILLING = '/billing';
  static const USERS_STAFF = '/staff';
  static const INTEGRATIONS = '/integrations';
}
