import 'dart:async';

import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/home_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../chart_palette.dart';
import '../shift_board.dart';
import '../shift_feed.dart';
import '../shift_sections.dart';

/// Today's board: what this account's shift looks like right now.
///
/// Two halves with different failure modes, which is why they do not share a
/// load state:
///
///   * **the census** — one call to the dashboard route, giving the eight
///     figures and the two charts;
///   * **the bands** — at most four, one call each, resolved from the access
///     map rather than from a role name.
///
/// A band is allowed to fail on its own. A laboratory outage must not blank a
/// nurse's bed counts, and a single `LoadStateMixin` across nine calls is
/// exactly what would make it.
class DashboardController extends GetxController with LoadStateMixin {
  static DashboardController get to => Get.find<DashboardController>();

  final _homeService = Get.find<HomeService>();

  final _dashboard = Rxn<DashboardData>();
  final _organization = Rxn<OrganizationData>();
  final _showAllPatients = false.obs;

  /// The bands this account gets, most urgent first. Recomputed when the
  /// access map changes — a role an administrator edits takes effect on the
  /// next refresh rather than on the next reinstall.
  final _sections = <ShiftSection>[].obs;

  /// One observable per band, so a band that reloads repaints itself and not
  /// the three beside it.
  final _bands = <String, Rx<ShiftBand>>{};

  /// When the figures on screen were last true.
  final _updatedAt = Rxn<DateTime>();

  /// True when a silent refresh failed and the board is still showing what it
  /// had. Distinct from [hasLoadError], which is a load that left nothing.
  final _stale = false.obs;

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

  /// The site's money convention. Read here rather than in the view so no
  /// widget has to know a currency symbol.
  MoneyFormat get money => SettingsService.to.settings.money;

  RxList<ShiftSection> get sections => _sections;

  Rx<DateTime?> get updatedAt => _updatedAt;
  RxBool get isStale => _stale;

  /// The band's state, created on first ask so a view can reach for one before
  /// the first fetch has come back.
  Rx<ShiftBand> bandOf(String id) =>
      _bands.putIfAbsent(id, () => ShiftBand.loading.obs);

  /// True when the fetch succeeded and there is genuinely nothing on the
  /// board. Distinct from an error, which keeps its own banner and a retry.
  bool get isEmpty =>
      !isLoading && !hasLoadError && !hasNoAccess && _dashboard.value == null;

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

  /// Bed occupancy, 0…1.
  ///
  /// Guarded on `<= 0` rather than on `== 0`: this backend stores an
  /// uncounted figure as zero, and a stats route that subtracts two counts
  /// taken a second apart has been seen to answer a negative one. Either way
  /// there is no ward to divide by.
  double get occupancy =>
      totalBeds <= 0 ? 0 : stats.occupiedBeds / totalBeds;

  /// Whether this account may be shown what the site took today.
  ///
  /// Gated on the module rather than on the role: a nurse has no billing grant
  /// and has no business reading the day's takings off a ward tablet.
  bool get canSeeRevenue =>
      Get.isRegistered<AccessService>() &&
      AccessService.to.canRead(Modules.billing);

  /// Whether the ward figures belong on this board.
  ///
  /// Two conditions, and the second is the one this misses without saying so:
  /// the account must be granted the module **and** the site must still run
  /// it. A site that switches the ward module off loses the ward tab straight
  /// away — `ShellLayout.resolve` sees to that — and a board still counting
  /// occupied beds underneath is a switch that only half worked.
  ///
  /// An absent key means on, exactly as the shell reads it: the backend's own
  /// default is `inpatient: false`, and treating a missing key as off would
  /// blank the census for every site that never opened the settings screen.
  bool get canSeeBeds {
    if (!Get.isRegistered<AccessService>()) return false;
    if (!AccessService.to.canRead(Modules.inpatient)) return false;
    if (!Get.isRegistered<SettingsService>()) return true;
    final flag = SettingsService.to.modulesEnabled[Modules.inpatient];
    return flag is! bool || flag;
  }

  List<ShiftSeries> get appointmentSeries =>
      ShiftCharts.appointments(appointmentStatuses);

  List<ShiftSeries> get queueSeries => ShiftCharts.queue(queueByService);

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
    _resolveSections();
    loadBoard();
    _watchForChanges();
    _watchAccess();
  }

  /// The census and every band, together.
  Future<void> loadBoard({bool silent = false}) => Future.wait([
        load(silent: silent),
        loadBands(silent: silent),
      ]);

  Future<void> load({bool silent = false}) async {
    await runGuarded(
      () async {
        // Both started before either is awaited: neither call needs the
        // other, and a cold start on hospital wifi pays for every round trip
        // it makes in series.
        //
        // The organisation is *not allowed to fail this screen*, and that is
        // the whole shape of what follows. It supplies one string - the site
        // name, which [siteName] already falls back to 'MediHive' for - and it
        // comes from `/settings/organization`, which is gated on
        // SETTINGS_READ. A doctor is refused it. Letting that refusal reach
        // `runGuarded` set the no-access state for the whole board, so every
        // doctor's census rendered as "not available to your role" while
        // `/api/dashboard` had answered 200 with their real figures.
        //
        // Two bugs came out of that one line, and both are fixed by giving
        // the organisation its own error handler at the moment it is started:
        //
        //  * awaiting the two in sequence left the refusal unobserved while
        //    the census was still in flight, and Dart reports a rejection
        //    with no listener as an unhandled exception - which is what a
        //    doctor's launch logged, every time;
        //  * `Future.wait` would have observed it, but completes with the
        //    error that arrived *first* and discards the rest, so a fast 403
        //    beside a slow 500 hid a genuine census failure behind the same
        //    lock, with no banner and no retry.
        //
        // Now the census owns the load state on its own, and a refused
        // organisation costs the screen its title and nothing else.
        final dashboard = _homeService.fetchDashboard();
        final organization = _homeService.fetchOrganization().then<
            OrganizationData?>(
          (value) => value,
          onError: (Object error) {
            AppLog.info(
              'DashboardController',
              'site name unavailable, using the fallback: $error',
            );
            return null;
          },
        );

        _dashboard.value = await dashboard;
        final site = await organization;
        if (site != null) _organization.value = site;

        _renderedTick = _currentTick;
      },
      fallback: "Couldn't load today's board.",
      silent: silent,
    );

    if (hasLoadError) {
      // A silent refresh that failed over numbers still on screen is not an
      // error banner. Those figures were true four minutes ago; replacing them
      // with a red retry says they are wrong, and blanking them says the
      // department is empty. It says so in a notice and keeps the numbers.
      if (silent && _dashboard.value != null) {
        _stale.value = true;
        clearLoadError();
      }
      return;
    }
    if (hasNoAccess) return;

    _stale.value = false;
    _updatedAt.value = AppClock.now();
  }

  /// Pull-to-refresh. Silent, so the board the clinician is reading stays on
  /// screen instead of collapsing to a skeleton under their thumb.
  ///
  /// Named `reload` rather than `refresh`: `GetxController.refresh()` already
  /// exists and returns void, and a same-named override that returns a Future
  /// is one an `onRefresh:` callback silently accepts and never awaits.
  Future<void> reload() => loadBoard(silent: true);

  void toggleShowAllPatients() => _showAllPatients.toggle();

  // ── The bands ─────────────────────────────────────────────────────────────

  /// Every visible band, in parallel and independently.
  ///
  /// `Future.wait` never rejects here because each band catches its own
  /// failure — which is the point. One band throwing out of this would take
  /// the other three down with it.
  Future<void> loadBands({bool silent = false}) => Future.wait([
        for (final section in _sections) loadBand(section, silent: silent),
      ]);

  Future<void> loadBand(ShiftSection section, {bool silent = false}) async {
    final band = bandOf(section.id);
    // A silent reload keeps the rows on screen. A first load has none to keep.
    if (!silent && !band.value.hasRows) band.value = ShiftBand.loading;

    try {
      final data = await _feed.fetch(section.id);
      band.value = ShiftBand.ready(
        rows: data.rows,
        total: data.total,
        capped: data.capped,
      );
    } on ApiForbiddenException catch (e) {
      // Not an error: the server answered a question correctly. Nothing is
      // broken, a retry cannot help, and a red banner over it sends a
      // clinician to IT for a grant they were never meant to have.
      band.value = ShiftBand.locked;
      AppLog.info('DashboardController', '${section.id} refused: ${e.message}');
    } catch (e, stack) {
      band.value = band.value.asFailed(
        parseErrorMessage(e, "That didn't load."),
      );
      AppLog.error('DashboardController', '${section.id} band failed', e, stack);
    }
  }

  /// What the band's own `ErrorRetryBanner` calls.
  Future<void> retryBand(String id) async {
    final section = _sections.firstWhereOrNull((s) => s.id == id);
    if (section == null) return;
    await loadBand(section);
  }

  ShiftFeed get _feed => ShiftFeed(money: money);

  void _resolveSections() {
    final access =
        Get.isRegistered<AccessService>() ? AccessService.to.map : AccessMap.empty;
    _sections.value = ShiftBoard.bandsFor(access);
  }

  /// Re-resolves the board when the access map changes, and fills in whatever
  /// is new.
  ///
  /// A map can arrive after the first frame — a cold start paints from
  /// storage and `/auth/me` lands a moment later — and a board resolved once
  /// at `onReady` would show that first frame's bands for the rest of the
  /// session.
  void _watchAccess() {
    if (!Get.isRegistered<AccessService>()) return;
    ever<AccessMap>(AccessService.to.rx, (_) {
      final before = _sections.map((s) => s.id).toSet();
      _resolveSections();
      for (final section in _sections) {
        if (!before.contains(section.id)) unawaited(loadBand(section));
      }
    });
  }

  // ── Staying fresh ─────────────────────────────────────────────────────────

  /// Reloads if something changed while this tab was in the background.
  void refreshIfStale() {
    if (_currentTick != _renderedTick && !isLoading) loadBoard(silent: true);
  }

  int get _currentTick =>
      Get.isRegistered<DataBus>() ? DataBus.to.tick(DataBus.summary).value : 0;

  void _watchForChanges() {
    if (!Get.isRegistered<DataBus>()) return;
    // `ever` rather than a manual listener so the subscription is disposed
    // with the controller — a dangling worker on a permanent controller is a
    // reload firing against a screen nobody is looking at.
    ever<int>(DataBus.to.tick(DataBus.summary), (_) {
      if (!isLoading) loadBoard(silent: true);
    });
  }
}
