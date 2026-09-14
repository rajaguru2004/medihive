import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/session_manager.dart';
import '../../../routes/app_pages.dart';
import '../../appointments/controllers/appointments_controller.dart';
import '../../appointments/views/appointments_view.dart';
import '../../billing/controllers/billing_controller.dart';
import '../../billing/views/billing_view.dart';
import '../../consultations/controllers/consultations_controller.dart';
import '../../consultations/views/consultations_view.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../inpatient/controllers/inpatient_controller.dart';
import '../../inpatient/views/inpatient_view.dart';
import '../../integrations/controllers/integrations_controller.dart';
import '../../integrations/views/integrations_view.dart';
import '../../laboratory/controllers/laboratory_controller.dart';
import '../../laboratory/views/laboratory_view.dart';
import '../../patients/controllers/patients_controller.dart';
import '../../patients/views/patients_view.dart';
import '../../pharmacy/controllers/pharmacy_controller.dart';
import '../../pharmacy/views/pharmacy_view.dart';
import '../../pre_triage/controllers/pre_triage_controller.dart';
import '../../pre_triage/views/pre_triage_view.dart';
import '../../queue/controllers/queue_controller.dart';
import '../../queue/views/queue_view.dart';
import '../../radiology/controllers/radiology_controller.dart';
import '../../radiology/views/radiology_view.dart';
import '../../settings/controllers/settings_hub_controller.dart';
import '../../settings/views/settings_hub_view.dart';
import '../../users/controllers/users_controller.dart';
import '../../users/views/users_view.dart';
import '../controllers/home_controller.dart';

/// Registers the shell and the tabs this account actually gets.
///
/// Only the resolved tabs' controllers are constructed. That is the point of
/// registering here rather than eagerly: a controller fetches in `onReady`, so
/// building a `BillingController` for a nurse would fire a request that comes
/// back 403 for a screen she was never shown.
///
/// Every tab controller is `permanent` because its view sits in an
/// `IndexedStack` that never disposes it — switching tabs must keep scroll
/// position and must not refetch. `permanent` is also why each is registered
/// with [SessionManager.registerScoped]: `Get.offAllNamed` does not dispose a
/// permanent instance, so without that the next clinician to sign in on a
/// shared ward tablet inherits the previous one's patient list.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    final session = SessionManager.to;

    final destinations = allDestinations();
    final layout = ShellLayout.resolve(
      access: AccessService.to.map,
      destinations: destinations,
    );

    for (final destination in layout.tabs) {
      destination.register?.call();
    }

    session.registerScoped<HomeController>();
    Get.put<HomeController>(
      HomeController(allDestinations: destinations),
      permanent: true,
    );
  }

  /// The settings hub's rows.
  ///
  /// Built here as well as in `SettingsHubBinding` because the hub is both a
  /// pushed route and — for an administrator, who gets it on the bar — a tab
  /// the shell builds directly, where no route binding runs.
  static List<SettingsEntry> _settingsEntries() =>
      SettingsHubController.allEntries(
        Routes.SETTINGS,
        profile: Routes.SETTINGS_PROFILE,
        locale: Routes.SETTINGS_LOCALE,
        appearance: Routes.SETTINGS_APPEARANCE,
        clinical: Routes.SETTINGS_CLINICAL,
        modules: Routes.SETTINGS_MODULES,
        departments: Routes.SETTINGS_DEPARTMENTS,
        staff: Routes.USERS_STAFF,
        roles: Routes.SETTINGS_ROLES,
        integrations: Routes.INTEGRATIONS,
      );

  /// Every destination the app has, in the order the More hub reads them.
  ///
  /// A table rather than a switch: the bar, the `IndexedStack`, the title, the
  /// More hub and the keys all read from this one list, so a new module cannot
  /// be added to four of those five and forgotten in the fifth.
  ///
  /// `rank` is what competes for a bar slot and is deliberately hand-assigned
  /// rather than derived from this order — the order here is the reading order
  /// of the hub, grouped by category, while the bar wants the busiest screens
  /// first.
  static List<ShellDestination> allDestinations() => [
        ShellDestination(
          route: Routes.HOME,
          label: 'Today',
          title: 'Today',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          group: ShellGroup.overview,
          rank: 0,
          body: DashboardView.new,
          register: () {
            Get.put<DashboardController>(DashboardController(),
                permanent: true);
            SessionManager.to.registerScoped<DashboardController>();
          },
        ),

        // ── Clinical ──────────────────────────────────────────────────────
        ShellDestination(
          route: Routes.QUEUE,
          label: 'Queue',
          icon: Icons.groups_outlined,
          activeIcon: Icons.groups_rounded,
          group: ShellGroup.clinical,
          module: Modules.queue,
          rank: 1,
          body: QueueView.new,
          register: () {
            Get.put<QueueController>(QueueController(), permanent: true);
            SessionManager.to.registerScoped<QueueController>();
          },
        ),
        ShellDestination(
          route: Routes.APPOINTMENTS,
          label: 'Clinic',
          title: 'Appointments',
          icon: Icons.event_outlined,
          activeIcon: Icons.event_rounded,
          group: ShellGroup.clinical,
          module: Modules.appointments,
          rank: 2,
          body: AppointmentsView.new,
          register: () {
            Get.put<AppointmentsController>(AppointmentsController(),
                permanent: true);
            SessionManager.to.registerScoped<AppointmentsController>();
          },
        ),
        ShellDestination(
          route: Routes.INPATIENT,
          label: 'Wards',
          title: 'Inpatient',
          icon: Icons.local_hotel_outlined,
          activeIcon: Icons.local_hotel_rounded,
          group: ShellGroup.clinical,
          module: Modules.inpatient,
          rank: 3,
          body: InpatientView.new,
          register: () {
            Get.put<InpatientController>(InpatientController(),
                permanent: true);
            SessionManager.to.registerScoped<InpatientController>();
          },
        ),
        ShellDestination(
          route: Routes.PRE_TRIAGE,
          label: 'Triage',
          title: 'Pre-triage',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          group: ShellGroup.clinical,
          module: Modules.preTriage,
          rank: 4,
          body: PreTriageView.new,
          register: () {
            Get.put<PreTriageController>(PreTriageController(),
                permanent: true);
            SessionManager.to.registerScoped<PreTriageController>();
          },
        ),
        ShellDestination(
          route: Routes.CONSULTATIONS,
          label: 'Consults',
          title: 'Consultations',
          icon: Icons.description_outlined,
          activeIcon: Icons.description_rounded,
          group: ShellGroup.clinical,
          module: Modules.consultations,
          rank: 10,
          body: ConsultationsView.new,
          register: () {
            Get.put<ConsultationsController>(ConsultationsController(),
                permanent: true);
            SessionManager.to.registerScoped<ConsultationsController>();
          },
        ),

        // ── Diagnostics ───────────────────────────────────────────────────
        ShellDestination(
          route: Routes.LABORATORY,
          label: 'Lab',
          title: 'Laboratory',
          icon: Icons.science_outlined,
          activeIcon: Icons.science_rounded,
          group: ShellGroup.diagnostics,
          module: Modules.laboratory,
          rank: 5,
          body: LaboratoryView.new,
          register: () {
            Get.put<LaboratoryController>(LaboratoryController(),
                permanent: true);
            SessionManager.to.registerScoped<LaboratoryController>();
          },
        ),
        ShellDestination(
          route: Routes.RADIOLOGY,
          label: 'Imaging',
          title: 'Radiology',
          icon: Icons.monitor_heart_outlined,
          activeIcon: Icons.monitor_heart_rounded,
          group: ShellGroup.diagnostics,
          module: Modules.radiology,
          rank: 6,
          body: RadiologyView.new,
          register: () {
            // Before the controller: it reads a repository in its own
            // initialiser list, so a tab built before `RadiologyBinding` ever
            // runs would look one up that nothing had registered.
            RadiologyRepositories.register();
            Get.put<RadiologyController>(RadiologyController(),
                permanent: true);
            SessionManager.to.registerScoped<RadiologyController>();
          },
        ),

        // ── Records ───────────────────────────────────────────────────────
        ShellDestination(
          route: Routes.PATIENTS,
          label: 'Patients',
          title: 'Patients',
          icon: Icons.badge_outlined,
          activeIcon: Icons.badge_rounded,
          group: ShellGroup.records,
          module: Modules.patients,
          rank: 9,
          body: PatientsView.new,
          register: () {
            Get.put<PatientsController>(PatientsController(), permanent: true);
            SessionManager.to.registerScoped<PatientsController>();
          },
        ),

        // ── Operations ────────────────────────────────────────────────────
        ShellDestination(
          route: Routes.PHARMACY,
          label: 'Pharmacy',
          title: 'Pharmacy',
          icon: Icons.medication_outlined,
          activeIcon: Icons.medication_rounded,
          group: ShellGroup.operations,
          module: Modules.pharmacy,
          rank: 7,
          body: PharmacyView.new,
          register: () {
            Get.put<PharmacyController>(PharmacyController(), permanent: true);
            SessionManager.to.registerScoped<PharmacyController>();
          },
        ),
        ShellDestination(
          route: Routes.BILLING,
          label: 'Billing',
          title: 'Billing',
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          group: ShellGroup.operations,
          module: Modules.billing,
          rank: 8,
          body: BillingView.new,
          register: () {
            Get.put<BillingController>(BillingController(), permanent: true);
            SessionManager.to.registerScoped<BillingController>();
          },
        ),

        // ── Administration ────────────────────────────────────────────────
        ShellDestination(
          route: Routes.USERS_STAFF,
          label: 'Staff',
          title: 'Users & staff',
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          group: ShellGroup.administration,
          module: Modules.users,
          rank: 11,
          body: UsersView.new,
          register: () {
            Get.put<UsersController>(UsersController(), permanent: true);
            SessionManager.to.registerScoped<UsersController>();
          },
        ),
        ShellDestination(
          route: Routes.SETTINGS,
          label: 'Settings',
          title: 'Settings',
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          group: ShellGroup.administration,
          module: Modules.settings,
          rank: 12,
          body: SettingsHubView.new,
          register: () {
            Get.put<SettingsHubController>(
              SettingsHubController()..entries = _settingsEntries(),
              permanent: true,
            );
            SessionManager.to.registerScoped<SettingsHubController>();
          },
        ),
        ShellDestination(
          route: Routes.INTEGRATIONS,
          label: 'Devices',
          title: 'Integrations',
          icon: Icons.cable_outlined,
          activeIcon: Icons.cable_rounded,
          group: ShellGroup.administration,
          module: Modules.integrations,
          rank: 13,
          body: IntegrationsView.new,
          register: () {
            Get.put<IntegrationsController>(IntegrationsController(),
                permanent: true);
            SessionManager.to.registerScoped<IntegrationsController>();
          },
        ),
      ];
}
