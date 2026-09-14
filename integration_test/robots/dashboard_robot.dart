import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/data/network/endpoints.dart';
import 'package:medihive/app/data/services/data_bus.dart';
import 'package:medihive/app/modules/appointments/appointment_routes.dart';
import 'package:medihive/app/modules/dashboard/shift_board.dart';
import 'package:medihive/app/modules/patients/patient_routes.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../support/pump.dart';
import 'robot.dart';
import 'shell_tab.dart';

/// Today's board — the shell's first tab.
///
/// Two halves, and they fail separately: the census (the eight figures and the
/// two charts) and the shift bands, of which an account gets at most four. A
/// robot that could only say "the board is up" would call a board with three
/// dead bands a pass.
final class DashboardRobot extends Robot with ShellTab {
  DashboardRobot(super.harness);

  @override
  Key get anchor => HomeKeys.dashboard;

  @override
  String get shellTitle => 'Today';

  /// The board is up, it loaded, and it is showing a department rather than an
  /// error.
  Future<void> assertOnBoard() async {
    await assertVisible();
    seeNoErrorBanner();
    // The figures, not the census card. The hero card is beds and money, and
    // an account with neither — a lab technician holds no ward grant and no
    // billing grant — correctly gets a board without one. Waiting for it made
    // the absence of a card nobody should see look like a board that never
    // loaded.
    await tester.pumpUntilFound(find.byKey(ShiftKeys.figures));
  }

  /// The attention card, which is drawn only when there is something to say.
  void seeAttention() => expect(
        _onBoard(HomeKeys.attention),
        findsOneWidget,
        reason: 'a critical alert should raise the attention card',
      );

  /// Present on the board, whether or not it is currently on screen.
  ///
  /// `Viewport` reports a sliver it has scrolled past as **offstage**, and
  /// every finder skips offstage widgets by default — so a board this long
  /// would answer "there is no ward band" for a nurse who simply has not
  /// scrolled to it yet. Being *reachable* is a separate question, and
  /// `tapKey` scrolls before it taps, so every method here that acts on
  /// something still proves it can be got to.
  static Finder _onBoard(Key key) => find.byKey(key, skipOffstage: false);

  // ── Figures and charts ────────────────────────────────────────────────────

  /// One of the eight tiles, by the word on it.
  ///
  /// Scoped to the grid: `Figure` is a data class rather than a widget and
  /// carries no key, and "Waiting" is also a band title and a chart legend.
  void seeFigure(String label) => expect(
        find.descendant(
          of: _onBoard(ShiftKeys.figures),
          matching: find.text(label, skipOffstage: false),
        ),
        findsOneWidget,
        reason: 'expected a "$label" figure on the census card',
      );

  /// Today's takings. Gated on the billing module, so most clinical accounts
  /// must not see it at all.
  void seeRevenue() => expect(_onBoard(ShiftKeys.revenue), findsOneWidget);

  void seeNoRevenue() => expect(
        _onBoard(ShiftKeys.revenue),
        findsNothing,
        reason: 'an account with no billing grant was shown the day\'s '
            'takings',
      );

  void seeCharts() {
    expect(_onBoard(ShiftKeys.appointmentChart), findsOneWidget);
    expect(_onBoard(ShiftKeys.queueChart), findsOneWidget);
  }

  // ── Freshness ─────────────────────────────────────────────────────────────

  /// "Updated 14:20". Present once the board has good figures on it.
  void seeUpdatedAt() => expect(
        _onBoard(ShiftKeys.updatedAt),
        findsOneWidget,
        reason: 'a board that refreshes silently has to say when it last '
            'landed',
      );

  void seeStaleNotice() => expect(
        _onBoard(ShiftKeys.stale),
        findsOneWidget,
        reason: 'a silent refresh that failed should say so over the figures '
            'it kept',
      );

  void seeNoStaleNotice() => expect(_onBoard(ShiftKeys.stale), findsNothing);

  /// Somebody wrote something on another tab.
  ///
  /// The production trigger for a **silent** refresh: the shell keeps every tab
  /// alive, so the board reloads when the `DataBus` says the census moved
  /// rather than on every glance. Driven through the bus rather than by
  /// flinging the `RefreshIndicator`, because what is under test is what the
  /// board does when that refresh fails — not the gesture that started it.
  Future<void> announceChangeElsewhere() async {
    final before = api.callCount('GET', Endpoints.dashboard);
    DataBus.to.changedRecord('queue');

    // A silent refresh raises no spinner and no skeleton, so `settle` has
    // nothing to wait on and returns on the next frame — before the request
    // has even left. Waited on the request instead, then pumped for the
    // answer: the fake replies on a microtask and the board repaints on the
    // frame after that.
    await tester.pumpUntil(
      () => api.callCount('GET', Endpoints.dashboard) > before,
      reason: 'a write on another tab should have started a silent refresh',
    );
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
    }
  }

  // ── Bands ─────────────────────────────────────────────────────────────────

  /// The band ids on screen, in the order the board drew them.
  ///
  /// Read off the catalogue rather than by taking keys apart, so the ids stay
  /// production API and a rename is a compile error rather than a silent
  /// mismatch.
  List<String> bandIds() => [
        for (final id in ShiftBandId.all)
          if (_onBoard(ShiftKeys.band(id)).evaluate().isNotEmpty) id,
      ];

  Future<void> seeBand(String id) =>
      tester.pumpUntilFound(_onBoard(ShiftKeys.band(id)));

  void seeNoBand(String id) => expect(
        _onBoard(ShiftKeys.band(id)),
        findsNothing,
        reason: 'this account should not be offered the "$id" band',
      );

  /// A band that loaded and has work on it.
  ///
  /// Asserted through the absence of the other four states rather than by
  /// counting rows: a skeleton, a refusal, an empty card and an error banner
  /// are each a band that is *there* and showing nothing, and only one of them
  /// is a band doing its job.
  void seeBandLoaded(String id) {
    expect(_onBoard(ShiftKeys.band(id)), findsOneWidget, reason: id);
    expect(_onBoard(ShiftKeys.bandEmpty(id)), findsNothing, reason: id);
    expect(_onBoard(ShiftKeys.bandError(id)), findsNothing, reason: id);
    expect(_onBoard(ShiftKeys.bandLocked(id)), findsNothing, reason: id);
  }

  void seeBandEmpty(String id) =>
      expect(_onBoard(ShiftKeys.bandEmpty(id)), findsOneWidget, reason: id);

  void seeBandError(String id) =>
      expect(_onBoard(ShiftKeys.bandError(id)), findsOneWidget, reason: id);

  void seeBandRow(String band, String row) => expect(
        _onBoard(ShiftKeys.bandRow(band, row)),
        findsOneWidget,
        reason: 'expected row "$row" on the "$band" band',
      );

  /// Retries one failed band. Scoped to that band's own banner, because the
  /// whole point is that the others are still fine.
  Future<void> retryBand(String id) async {
    await tester.scrollToKey(ShiftKeys.bandError(id));
    await tester.tap(
      find.descendant(
        of: find.byKey(ShiftKeys.bandError(id)),
        matching: find.text('Try again'),
      ),
    );
    await settle();
  }

  // ── Quick actions ─────────────────────────────────────────────────────────

  /// The shortcuts this account is actually being offered.
  List<String> offeredQuickActions() => [
        for (final action in ShiftBoard.quickActions)
          if (_onBoard(ShiftKeys.quickAction(action.id)).evaluate().isNotEmpty)
            action.id,
      ];

  void seeNoQuickActions() => expect(
        _onBoard(ShiftKeys.quickActions),
        findsNothing,
        reason: 'an account that can create nothing should be offered no '
            'shortcuts at all',
      );

  /// Presses a shortcut and asserts it opened the screen it promises.
  ///
  /// The refusal screen is the failure this exists to catch: a tile gated on
  /// the wrong module still navigates, still leaves a working screen on
  /// display, and is only wrong because it is the *refusal*.
  Future<void> openQuickAction(String id) async {
    final action =
        ShiftBoard.quickActions.firstWhere((candidate) => candidate.id == id);

    await tester.tapKey(ShiftKeys.quickAction(id));
    await tester.pumpUntilRouteSettled();

    expect(
      Get.currentRoute,
      isNot(Routes.NO_ACCESS),
      reason: 'the "$id" shortcut opened the refusal screen. A shortcut that '
          'refuses teaches a clinician the app\'s shortcuts cannot be trusted',
    );
    expect(
      Get.currentRoute,
      action.route,
      reason: 'the "$id" shortcut promises ${action.route}',
    );
  }

  // ── The tail ──────────────────────────────────────────────────────────────

  /// Opens one recently registered patient's record.
  ///
  /// `/patients/record` with the id in `Get.arguments` — a `:id` registered at
  /// that position would match `search` and `edit` too, and the hub would open
  /// on a record whose id is the word "search".
  Future<void> openPatient(String id) async {
    await tester.tapKey(ShiftKeys.patient(id));
    await tester.pumpUntilRouteSettled();
    expect(Get.currentRoute, PatientRoutes.hub);
  }

  /// Opens one of today's remaining bookings.
  ///
  /// Asserts the **route**, not the screen behind it. Where that booking goes
  /// is the board's business; what the detail screen makes of it belongs to
  /// the clinic's own flow, and a board test that asserted on it would fail
  /// for reasons that have nothing to do with the board.
  Future<void> openAppointment(String id) async {
    await tester.tapKey(ShiftKeys.appointment(id));
    await tester.pumpUntilRouteSettled();
    expect(
      Get.currentRoute,
      AppointmentRoutes.detailFor(id),
      reason: 'a booking on the board should open that booking',
    );
  }

  void seeUpcoming() => expect(_onBoard(ShiftKeys.upcoming), findsOneWidget);

  void seeRecentPatients() =>
      expect(_onBoard(ShiftKeys.recentPatients), findsOneWidget);
}
