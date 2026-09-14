import 'package:get/get.dart';

import '../../../data/models/dashboard_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/home_service.dart';
import '../../../data/utils/load_state.dart';

/// Today's board: what the department looks like right now.
///
/// Split out of the old 1,981-line `HomeView`, which owned the shell, the
/// dashboard, and three other tabs at once. The shell keeps the tab index and
/// the signed-in user; everything the dashboard shows belongs here.
class DashboardController extends GetxController with LoadStateMixin {
  static DashboardController get to => Get.find<DashboardController>();

  final _homeService = Get.find<HomeService>();

  final _dashboard = Rxn<DashboardData>();
  final _organization = Rxn<OrganizationData>();
  final _showAllPatients = false.obs;

  /// The DataBus tick this screen last rendered.
  ///
  /// The shell keeps every tab alive, so this one goes stale the moment
  /// somebody admits a patient from another tab. Rather than refetching on
  /// every tab switch — a request each time a clinician glances at the board —
  /// it reloads only when it is looked at *and* something has changed since.
  int _renderedTick = 0;

  DashboardData? get dashboard => _dashboard.value;
  OrganizationData? get organization => _organization.value;
  bool get showAllPatients => _showAllPatients.value;

  /// True when the fetch succeeded and there is genuinely nothing on the
  /// board. Distinct from an error, which keeps its own banner and a retry.
  bool get isEmpty =>
      !isLoading && !hasLoadError && _dashboard.value == null;

  DashboardStats get stats =>
      _dashboard.value?.stats ??
      const DashboardStats(
        totalPatients: 0,
        todayAppointments: 0,
        pendingLabOrders: 0,
        pendingPrescriptions: 0,
        todayRevenue: 0,
        occupiedBeds: 0,
        availableBeds: 0,
        queueWaiting: 0,
        criticalAlerts: 0,
      );

  int get totalBeds => stats.occupiedBeds + stats.availableBeds;

  /// Bed occupancy, 0…1. Zero beds reads as zero rather than dividing by it.
  double get occupancy =>
      totalBeds == 0 ? 0 : stats.occupiedBeds / totalBeds;

  List<RecentPatient> get recentPatients {
    final patients = _dashboard.value?.recentPatients ?? const [];
    return _showAllPatients.value ? patients : patients.take(5).toList();
  }

  /// Whether there are more patients than the collapsed list shows.
  bool get hasMorePatients =>
      (_dashboard.value?.recentPatients.length ?? 0) > 5;

  List<UpcomingAppointment> get upcomingAppointments =>
      _dashboard.value?.upcomingAppointments ?? const [];

  AppointmentStatuses get appointmentStatuses =>
      _dashboard.value?.appointmentStatuses ?? const AppointmentStatuses();

  List<QueueServiceCount> get queueByService =>
      _dashboard.value?.queueByService ?? const [];

  String get siteName => _organization.value?.name ?? 'MediHive';

  @override
  void onReady() {
    super.onReady();
    // onReady, not onInit: the first widget to touch `controller` constructs
    // it, and writing an observable during that build marks the building Obx
    // dirty.
    load();
    _watchForChanges();
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          // Both started before either is awaited: neither call needs the
          // other, and a cold start on hospital wifi pays for every round trip
          // it makes in series. Not `Future.wait`, which would erase the two
          // different result types into `Object`.
          final dashboard = _homeService.fetchDashboard();
          final organization = _homeService.fetchOrganization();

          _dashboard.value = await dashboard;
          _organization.value = await organization;

          _renderedTick = _currentTick;
        },
        fallback: "Couldn't load today's board.",
        silent: silent,
      );

  /// Pull-to-refresh. Silent, so the board the clinician is reading stays on
  /// screen instead of collapsing to a skeleton under their thumb.
  ///
  /// Named `reload` rather than `refresh`: `GetxController.refresh()` already
  /// exists and returns void, and a same-named override that returns a Future
  /// is one an `onRefresh:` callback silently accepts and never awaits.
  Future<void> reload() => load(silent: true);

  void toggleShowAllPatients() => _showAllPatients.toggle();

  /// Reloads if something changed while this tab was in the background.
  void refreshIfStale() {
    if (_currentTick != _renderedTick && !isLoading) load(silent: true);
  }

  int get _currentTick =>
      Get.isRegistered<DataBus>() ? DataBus.to.tick(DataBus.summary).value : 0;

  void _watchForChanges() {
    if (!Get.isRegistered<DataBus>()) return;
    // `ever` rather than a manual listener so the subscription is disposed
    // with the controller — a dangling worker on a permanent controller is a
    // reload firing against a screen nobody is looking at.
    ever<int>(DataBus.to.tick(DataBus.summary), (_) {
      if (!isLoading) load(silent: true);
    });
  }
}
