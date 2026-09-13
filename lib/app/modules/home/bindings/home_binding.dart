import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/session_manager.dart';
import '../../../routes/app_pages.dart';
import '../../appointments/controllers/appointments_controller.dart';
import '../../appointments/views/appointments_view.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../inpatient/controllers/inpatient_controller.dart';
import '../../inpatient/views/inpatient_view.dart';
import '../../queue/controllers/queue_controller.dart';
import '../../queue/views/queue_view.dart';
import '../controllers/home_controller.dart';

/// Registers the shell and every tab that lives inside it.
///
/// The tab controllers are `permanent` because their views sit in an
/// `IndexedStack` that never disposes them — switching tabs must keep scroll
/// position and must not refetch. `permanent` is also why each one is
/// registered with [SessionManager.registerScoped]: `Get.offAllNamed` does not
/// dispose a permanent instance, so without that the next clinician to sign in
/// on a shared ward tablet inherits the previous one's patient list.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    final session = SessionManager.to;

    // ── Tab controllers ───────────────────────────────────────────────────
    Get.put<DashboardController>(DashboardController(), permanent: true);
    Get.put<QueueController>(QueueController(), permanent: true);
    Get.put<AppointmentsController>(AppointmentsController(), permanent: true);
    Get.put<InpatientController>(InpatientController(), permanent: true);

    session
      ..registerScoped<DashboardController>()
      ..registerScoped<QueueController>()
      ..registerScoped<AppointmentsController>()
      ..registerScoped<InpatientController>()
      ..registerScoped<HomeController>();

    Get.put<HomeController>(
      HomeController(destinations: shellDestinations()),
      permanent: true,
    );
  }

  /// The shell's tabs, in order.
  ///
  /// A table rather than a switch: the tab bar, the `IndexedStack`, the title
  /// and the keys all read from this one list, so a new tab cannot be added to
  /// three of those four and forgotten in the fourth.
  ///
  /// Four, not six. A bottom bar with six destinations gives each one a target
  /// narrower than a thumb, and the two that would have been cut — pre-triage
  /// and consultations — are reached from the dashboard and from the queue,
  /// which is where a clinician is already standing when they need them.
  static List<ShellDestination> shellDestinations() => [
        const ShellDestination(
          route: Routes.HOME,
          label: 'Today',
          title: 'Today',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          body: DashboardView.new,
        ),
        const ShellDestination(
          route: Routes.QUEUE,
          label: 'Queue',
          icon: Icons.groups_outlined,
          activeIcon: Icons.groups_rounded,
          body: QueueView.new,
        ),
        const ShellDestination(
          route: Routes.APPOINTMENTS,
          label: 'Clinic',
          title: 'Appointments',
          icon: Icons.event_outlined,
          activeIcon: Icons.event_rounded,
          body: AppointmentsView.new,
        ),
        const ShellDestination(
          route: Routes.INPATIENT,
          label: 'Wards',
          title: 'Inpatient',
          icon: Icons.local_hotel_outlined,
          activeIcon: Icons.local_hotel_rounded,
          body: InpatientView.new,
        ),
      ];
}
