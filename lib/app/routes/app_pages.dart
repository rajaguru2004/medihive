import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../modules/add_to_queue/bindings/add_to_queue_binding.dart';
import '../modules/add_to_queue/views/add_to_queue_view.dart';
import '../modules/admit_patient/bindings/admit_patient_binding.dart';
import '../modules/admit_patient/views/admit_patient_view.dart';
import '../modules/appointments/bindings/appointments_binding.dart';
import '../modules/appointments/views/appointments_view.dart';
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
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/new_screening_step1/bindings/new_screening_step1_binding.dart';
import '../modules/new_screening_step1/views/new_screening_step1_view.dart';
import '../modules/new_screening_step2/bindings/new_screening_step2_binding.dart';
import '../modules/new_screening_step2/views/new_screening_step2_view.dart';
import '../modules/placeholders/views/placeholder_view.dart';
import '../modules/pre_triage/bindings/pre_triage_binding.dart';
import '../modules/pre_triage/views/pre_triage_view.dart';
import '../modules/pre_triage_details/bindings/pre_triage_details_binding.dart';
import '../modules/pre_triage_details/views/pre_triage_details_view.dart';
import '../modules/queue/bindings/queue_binding.dart';
import '../modules/queue/views/queue_view.dart';
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

    // ── Shell ─────────────────────────────────────────────────────────────
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
      middlewares: _auth,
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
      middlewares: _auth,
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
      middlewares: _auth,
      transition: _push,
    ),

    // ── Pre-triage ────────────────────────────────────────────────────────
    GetPage(
      name: _Paths.PRE_TRIAGE,
      page: () => const PreTriageView(),
      binding: PreTriageBinding(),
      middlewares: _auth,
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
      middlewares: _auth,
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

    // ── Routed, not yet built ─────────────────────────────────────────────
    //
    // Reachable rather than absent: a nav entry or a deep link that lands on
    // one of these gets a screen that says what the module is for and where
    // the work happens today. The alternative is an unknown-route page, which
    // reads as a broken app rather than as an unfinished one.
    GetPage(
      name: _Paths.PATIENTS,
      page: () => const PlaceholderView(
        module: 'patients',
        title: 'Patients',
        icon: Icons.people_outline_rounded,
        message: 'The patient register is managed in the admin console. '
            'Patients registered there are searchable from every picker in '
            'this app.',
      ),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.PHARMACY,
      page: () => const PlaceholderView(
        module: 'pharmacy',
        title: 'Pharmacy',
        icon: Icons.medication_outlined,
        message: 'Dispensing is not switched on for this site yet. Pending '
            'prescription counts still appear on today\'s board.',
      ),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.LABORATORY,
      page: () => const PlaceholderView(
        module: 'laboratory',
        title: 'Laboratory',
        icon: Icons.science_outlined,
        message: 'Lab ordering and results are not switched on for this site '
            "yet. Pending order counts still appear on today's board.",
      ),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.RADIOLOGY,
      page: () => const PlaceholderView(
        module: 'radiology',
        title: 'Radiology',
        icon: Icons.monitor_heart_outlined,
        message: 'Imaging requests are not switched on for this site yet.',
      ),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.BILLING,
      page: () => const PlaceholderView(
        module: 'billing',
        title: 'Billing',
        icon: Icons.receipt_long_outlined,
        message: 'Charges and payments are handled in the admin console for '
            'this site.',
      ),
      middlewares: _auth,
      transition: _push,
    ),
    GetPage(
      name: _Paths.USERS_STAFF,
      page: () => const PlaceholderView(
        module: 'staff',
        title: 'Staff',
        icon: Icons.badge_outlined,
        message: 'Staff accounts, roles and permissions are managed in the '
            'admin console.',
      ),
      middlewares: _auth,
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
      middlewares: _auth,
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
