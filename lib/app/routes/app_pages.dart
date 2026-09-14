import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/access_map.dart';
import '../modules/add_to_queue/bindings/add_to_queue_binding.dart';
import '../modules/add_to_queue/views/add_to_queue_view.dart';
import '../modules/admit_patient/bindings/admit_patient_binding.dart';
import '../modules/admit_patient/views/admit_patient_view.dart';
import '../modules/appointments/bindings/appointments_binding.dart';
import '../modules/appointments/views/appointments_view.dart';
import '../modules/billing/billing_routes.dart';
import '../modules/consultations/bindings/consultations_binding.dart';
import '../modules/consultations/views/consultations_view.dart';
import '../modules/dashboard/bindings/dashboard_binding.dart';
import '../modules/dashboard/views/dashboard_view.dart';
import '../modules/discharge_patient/bindings/discharge_patient_binding.dart';
import '../modules/discharge_patient/views/discharge_patient_view.dart';
import '../modules/edit_screening/bindings/edit_screening_binding.dart';
import '../modules/edit_screening/views/edit_screening_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/inpatient/bindings/inpatient_binding.dart';
import '../modules/inpatient/views/inpatient_view.dart';
import '../modules/inpatient_add_bed/bindings/inpatient_add_bed_binding.dart';
import '../modules/inpatient_add_bed/views/inpatient_add_bed_view.dart';
import '../modules/inpatient_add_ward/bindings/inpatient_add_ward_binding.dart';
import '../modules/inpatient_add_ward/views/inpatient_add_ward_view.dart';
import '../modules/inpatient_admissions/bindings/inpatient_admissions_binding.dart';
import '../modules/inpatient_admissions/views/inpatient_admissions_view.dart';
import '../modules/inpatient_beds_grid/bindings/inpatient_beds_grid_binding.dart';
import '../modules/inpatient_beds_grid/views/inpatient_beds_grid_view.dart';
import '../modules/inpatient_overview/bindings/inpatient_overview_binding.dart';
import '../modules/inpatient_overview/views/inpatient_overview_view.dart';
import '../modules/inpatient_wards/bindings/inpatient_wards_binding.dart';
import '../modules/inpatient_wards/views/inpatient_wards_view.dart';
import '../modules/laboratory/laboratory_routes.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/more/views/more_view.dart';
import '../modules/new_screening_step1/bindings/new_screening_step1_binding.dart';
import '../modules/new_screening_step1/views/new_screening_step1_view.dart';
import '../modules/new_screening_step2/bindings/new_screening_step2_binding.dart';
import '../modules/new_screening_step2/views/new_screening_step2_view.dart';
import '../modules/no_access/views/no_access_view.dart';
import '../modules/patient_form/bindings/patient_form_binding.dart';
import '../modules/patient_form/views/patient_form_view.dart';
import '../modules/patient_hub/bindings/patient_hub_binding.dart';
import '../modules/patient_hub/views/patient_hub_view.dart';
import '../modules/patient_search/bindings/patient_search_binding.dart';
import '../modules/patient_search/views/patient_search_view.dart';
import '../modules/patients/bindings/patients_binding.dart';
import '../modules/patients/patient_routes.dart';
import '../modules/patients/views/patients_view.dart';
import '../modules/pharmacy/pharmacy_routes.dart';
import '../modules/placeholders/views/placeholder_view.dart';
import '../modules/pre_triage/bindings/pre_triage_binding.dart';
import '../modules/pre_triage/views/pre_triage_view.dart';
import '../modules/pre_triage_details/bindings/pre_triage_details_binding.dart';
import '../modules/pre_triage_details/views/pre_triage_details_view.dart';
import '../modules/queue/bindings/queue_binding.dart';
import '../modules/queue/views/queue_view.dart';
import '../modules/radiology/radiology_routes.dart';
import '../modules/roles/bindings/roles_binding.dart';
import '../modules/roles/views/roles_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/settings/views/appearance_settings_view.dart';
import '../modules/settings/views/clinical_settings_view.dart';
import '../modules/settings/views/settings_hub_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import 'middlewares/auth_middleware.dart';

part 'app_routes.dart';

/// The route table.
///
/// Every tab in the shell is **also** a standalone page here, so a deep link
/// or a push from a sub-screen can open it directly. Inside the shell its
/// controller is already registered `permanent`, so the binding's `lazyPut`
/// finds the live instance rather than building a second one.
///
/// Those three pass `embedded: false`. A tab body drawn inside the shell has
/// no scaffold and no bottom clearance of its own — the shell provides both —
/// so a pushed copy that forgets the flag is a screen with no app bar, no
/// back button, and its last row under the system navigation bar.
class AppPages {
  AppPages._();

  /// Where a cold start goes before the session has been checked.
  // ignore: constant_identifier_names — matches the Routes convention above.
  static const INITIAL = Routes.SPLASH;

  /// The transition every pushed screen uses.
  ///
  /// One transition, named once. A table where a third of the entries specify
  /// `Transition.cupertino` and the rest inherit whatever the default is that
  /// year is a table where screens animate differently for no reason anybody
  /// chose.
  static const _push = Transition.cupertino;

  static final _auth = [AuthMiddleware()];

  /// A route that also needs a module.
  ///
  /// Navigation never offers a destination this account cannot open — the
  /// shell resolves itself from the access map — so this only catches the ways
  /// in that bypass navigation: a deep link, a stale shortcut, or a push from
  /// before an administrator changed what the account may do.
  static List<GetMiddleware> _gate(String module, String name) =>
      [AuthMiddleware(module: module, moduleName: name)];

  static final routes = <GetPage<dynamic>>[
    // ── Entry ─────────────────────────────────────────────────────────────
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
      middlewares: [GuestMiddleware()],
    ),

    // ── Settings ──────────────────────────────────────────────────────────
    GetPage(
      name: _Paths.SETTINGS,
      page: () => const SettingsHubView(),
      binding: SettingsHubBinding(),
      middlewares: _gate(Modules.settings, 'Settings'),
      transition: _push,
    ),
    GetPage(
      name: _Paths.SETTINGS_APPEARANCE,
      page: () => const AppearanceSettingsView(),
      binding: AppearanceSettingsBinding(),
      // Changing the site's theme is a write, so the guard asks for one. A
      // read-only settings account can open the hub and see what is set; it
      // cannot open the screens that change it.
      middlewares: [
        AuthMiddleware(
          module: Modules.settings,
          moduleName: 'Appearance settings',
          verb: AccessVerb.update,
        ),
      ],
      transition: _push,
    ),
    GetPage(
      name: _Paths.SETTINGS_CLINICAL,
      page: () => const ClinicalSettingsView(),
      binding: ClinicalSettingsBinding(),
      middlewares: [
        AuthMiddleware(
          module: Modules.settings,
          moduleName: 'Clinical settings',
          verb: AccessVerb.update,
        ),
      ],
      transition: _push,
    ),

    GetPage(
      name: _Paths.SETTINGS_ROLES,
      page: () => const RolesView(),
      binding: RolesBinding(),
      middlewares: _gate(Modules.roles, 'Roles and access'),
      transition: _push,
    ),

    // ── Shell ─────────────────────────────────────────────────────────────
    GetPage(
      name: _Paths.MORE,
      page: () => const MoreView(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.NO_ACCESS,
      page: () => const NoAccessView(),
      // Auth only. Gating the refusal screen behind a permission would be a
      // loop: the guard sends somebody here precisely because they lack one.
      middlewares: _auth,
      transition: _push,
    ),

    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
      middlewares: _auth,
    ),
    GetPage(
      name: _Paths.DASHBOARD,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
      middlewares: _auth,
      transition: _push,
    ),

    // ── Queue ─────────────────────────────────────────────────────────────
    GetPage(
      name: _Paths.QUEUE,
      page: () => const QueueView(embedded: false),
      binding: QueueBinding(),
      middlewares: _gate(Modules.queue, 'The queue'),
      transition: _push,
    ),
    GetPage(
      name: _Paths.ADD_TO_QUEUE,
      page: () => const AddToQueueView(),
      binding: AddToQueueBinding(),
      middlewares: _auth,
      transition: _push,
    ),

    // ── Clinic ────────────────────────────────────────────────────────────
    GetPage(
      name: _Paths.APPOINTMENTS,
      page: () => const AppointmentsView(embedded: false),
      binding: AppointmentsBinding(),
      middlewares: _gate(Modules.appointments, 'The clinic list'),
      transition: _push,
    ),
    GetPage(
      name: _Paths.APPOINTMENT_CREATE,
      page: () => const PlaceholderView(
        module: 'appointment-create',
        title: 'Book appointment',
        icon: Icons.event_available_outlined,
        message: 'Booking from the app is not switched on for this site yet. '
            'Appointments booked in the admin console appear on the clinic '
            'board straight away.',
      ),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.CONSULTATIONS,
      page: () => const ConsultationsView(),
      binding: ConsultationsBinding(),
      middlewares: _gate(Modules.consultations, 'Consultations'),
      transition: _push,
    ),

    // ── Pre-triage ────────────────────────────────────────────────────────
    GetPage(
      name: _Paths.PRE_TRIAGE,
      page: () => const PreTriageView(),
      binding: PreTriageBinding(),
      middlewares: _gate(Modules.preTriage, 'Pre-triage'),
      transition: _push,
    ),
    GetPage(
      name: _Paths.PRE_TRIAGE_DETAILS,
      page: () => const PreTriageDetailsView(),
      binding: PreTriageDetailsBinding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.NEW_SCREENING_STEP1,
      page: () => const NewScreeningStep1View(),
      binding: NewScreeningStep1Binding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.NEW_SCREENING_STEP2,
      page: () => const NewScreeningStep2View(),
      binding: NewScreeningStep2Binding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.EDIT_SCREENING,
      page: () => const EditScreeningView(),
      binding: EditScreeningBinding(),
      middlewares: _auth,
      transition: _push,
    ),

    // ── Inpatient ─────────────────────────────────────────────────────────
    GetPage(
      name: _Paths.INPATIENT,
      page: () => const InpatientView(embedded: false),
      binding: InpatientBinding(),
      middlewares: _gate(Modules.inpatient, 'The ward board'),
      transition: _push,
    ),
    GetPage(
      name: _Paths.INPATIENT_OVERVIEW,
      page: () => const InpatientOverviewView(),
      binding: InpatientOverviewBinding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.INPATIENT_WARDS,
      page: () => const InpatientWardsView(),
      binding: InpatientWardsBinding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.INPATIENT_BEDS_GRID,
      page: () => const InpatientBedsGridView(),
      binding: InpatientBedsGridBinding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADMISSIONS,
      page: () => const InpatientAdmissionsView(),
      binding: InpatientAdmissionsBinding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADD_WARD,
      page: () => const InpatientAddWardView(),
      binding: InpatientAddWardBinding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADD_BED,
      page: () => const InpatientAddBedView(),
      binding: InpatientAddBedBinding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADMIT,
      page: () => const AdmitPatientView(),
      binding: AdmitPatientBinding(),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.DISCHARGE_PATIENT,
      page: () => const DischargePatientView(),
      binding: DischargePatientBinding(),
      middlewares: _auth,
      transition: _push,
    ),

    // ── Records ───────────────────────────────────────────────────────────
    //
    // `/patients/record` rather than `/patients/:id`: a parameter registered at
    // that position also matches `search` and `edit`, so the hub would swallow
    // both siblings and open on a record whose id is the word "search". The id
    // travels in `Get.arguments` instead — `PatientRoutes.idFrom` reads either
    // the map a push sends or the bare string half the call sites use.
    GetPage(
      name: PatientRoutes.registry,
      page: () => const PatientsView(embedded: false),
      binding: PatientsBinding(),
      middlewares: _gate(Modules.patients, 'The patient register'),
      transition: _push,
    ),
    GetPage(
      name: PatientRoutes.search,
      page: () => const PatientSearchView(),
      binding: PatientSearchBinding(),
      middlewares: _gate(Modules.patients, 'Patient search'),
      transition: _push,
    ),
    GetPage(
      name: PatientRoutes.form,
      page: () => const PatientFormView(),
      binding: PatientFormBinding(),
      middlewares: _gate(Modules.patients, 'The patient register'),
      transition: _push,
    ),
    GetPage(
      name: PatientRoutes.hub,
      page: () => const PatientHubView(),
      binding: PatientHubBinding(),
      middlewares: _gate(Modules.patients, 'The patient record'),
      transition: _push,
    ),

    // ── Modules that carry their own tables ───────────────────────────────
    //
    // Each list is spliced whole. Registration order inside one of them is
    // load-bearing — GetX answers with the first pattern that matches, so a
    // literal path listed after its `:id` sibling opens as a record whose id
    // is the word "new" — and each module's own file is where that order is
    // documented. Sorting them here would undo it silently.
    ...LabPages.routes,
    ...RadiologyPages.pages,
    ...PharmacyPages.pages,
    ...BillingPages.pages,

    // ── Routed, not yet built ─────────────────────────────────────────────
    //
    // Reachable rather than absent: a nav entry or a deep link that lands on
    // one of these gets a screen that says what the module is for and where
    // the work happens today. The alternative is an unknown-route page, which
    // reads as a broken app rather than as an unfinished one.
    GetPage(
      name: _Paths.USERS_STAFF,
      page: () => const PlaceholderView(
        module: 'staff',
        title: 'Staff',
        icon: Icons.badge_outlined,
        message: 'Staff accounts, roles and permissions are managed in the '
            'admin console.',
      ),
      middlewares: _gate(Modules.users, 'Users and staff'),
      transition: _push,
    ),
    GetPage(
      name: _Paths.INTEGRATIONS,
      page: () => const PlaceholderView(
        module: 'integrations',
        title: 'Integrations',
        icon: Icons.hub_outlined,
        message: 'Device and third-party integrations are configured in the '
            'admin console.',
      ),
      middlewares: _gate(Modules.integrations, 'Integrations'),
      transition: _push,
    ),
  ];

  /// Where an unrecognised route lands.
  ///
  /// A deep link from an old build, or a typo in a pushed route name. Saying
  /// so and offering the way back beats GetX's default, which is a bare red
  /// "Route not found" on a black ground.
  static final GetPage<dynamic> unknown = GetPage(
    name: '/not-found',
    page: () => PlaceholderView(
      module: 'not-found',
      title: 'Screen not found',
      icon: Icons.help_outline_rounded,
      message: "This link points at a screen that doesn't exist in this "
          'version of MediHive.',
      actionLabel: 'Go to today',
      onAction: () => Get.offAllNamed<void>(Routes.HOME),
    ),
  );
}
