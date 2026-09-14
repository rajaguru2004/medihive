import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/theme/theme.dart';

import '../fakes/fake_api.dart';
import '../support/app_harness.dart';
import '../support/pump.dart';
import '../support/watch_mode.dart';

/// One robot per routed screen: it knows how to act on that screen and how to
/// assert about it.
///
/// **A flow test never calls `find.*` directly.** If a flow needs a finder,
/// the finder belongs in a robot. That one rule is what keeps the suite
/// maintainable as the app grows — a UI change touches one robot, not forty
/// tests.
abstract base class Robot {
  Robot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;
  FakeApi get api => harness.api;

  /// The named route this screen is registered under. Null for a robot that
  /// spans screens.
  String? get route;

  /// The `<module>Keys.screen` anchor on this screen's outermost `Scaffold`.
  Key get anchor;

  /// "I am on this screen and it has finished rendering."
  ///
  /// Route plus anchor, not route alone: a view can return
  /// `SizedBox.shrink()` when its controller is gone, so the route can be
  /// correct while nothing at all is on screen.
  Future<void> assertVisible() async {
    await tester.pumpUntilFound(find.byKey(anchor));
    if (route != null) {
      expect(
        Get.currentRoute,
        route,
        reason: 'expected to be on $route; anchor $anchor was found though',
      );
    }
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: '$route is still showing a spinner after settling',
    );
    // Watch mode only: holds a freshly loaded screen long enough to read.
    await WatchMode.hold(tester);
  }

  Future<void> assertNotVisible() async {
    await tester.pumpUntilGone(find.byKey(anchor));
  }

  // ── Shared assertions ─────────────────────────────────────────────────────

  /// "The app said something, and it said this."
  ///
  /// One assertion for every transient message in the app: `showBentoToast` is
  /// the only thing that raises one, and [BentoToast] is what it puts on the
  /// overlay.
  void seeToast({String? containing}) {
    expect(find.byType(BentoToast), findsWidgets, reason: 'expected a toast');
    if (containing != null) {
      expect(
        find.descendant(
          of: find.byType(BentoToast),
          matching: find.textContaining(containing),
        ),
        findsWidgets,
        reason: 'expected a toast containing "$containing"',
      );
    }
  }

  /// The screen said nothing. Scoped to the toast, so a flow asserting silence
  /// is not fooled by the same words sitting in a banner on the page.
  void seeNoToast() => expect(find.byType(BentoToast), findsNothing);

  /// Takes down any toast and lets its timer go with it.
  ///
  /// Required before a flow that raised one ends. The toast owns a `Timer` for
  /// its own duration and `flutter_test` checks for pending timers at the end
  /// of the test *body* — earlier than `addTearDown`, so the harness cannot
  /// clean this up on the flow's behalf. A refused write is the usual way a
  /// flow raises one without meaning to.
  ///
  /// Cancels rather than waits: the durations vary (three seconds usually, six
  /// for a refusal worth reading), and a flow should not have to know which one
  /// it just provoked.
  Future<void> letToastsExpire() async {
    dismissBentoToasts();
    await tester.pump();
    await tester.pumpUntilGone(find.byType(BentoToast));
  }

  /// Presses the system back button, the way the edge gesture does.
  Future<void> pressSystemBack() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpUntilViewportStable();
    final page = tester.binding.defaultBinaryMessenger;
    await page.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('popRoute'),
      ),
      (_) {},
    );
    await settle();
  }

  /// Chooses an option in an open picker sheet, by the words on its row.
  ///
  /// Three things, and each one has cost a green run:
  ///
  ///   * **the keyboard comes down first.** A picker with a search box leaves
  ///     it up, and on a real device it covers the lower half of the screen —
  ///     the tap then lands on a key instead of the row, and the failure reads
  ///     as "the option was not there".
  ///   * **the row, not the label.** A `RenderParagraph` is a few points tall
  ///     and the row around it is a target; tapping text also risks hitting
  ///     the same words in the list *behind* the sheet.
  ///   * **after the sheet has stopped moving.** A tap delivered mid-animation
  ///     is absorbed, and nothing says so.
  Future<void> pickFromSheet(String label) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpUntilViewportStable();
    await tester.pumpUntilRouteSettled();

    // Exact text first, then a row that merely *contains* it. A picker labels
    // its options the way the screen wants to read them — a drug row says
    // "Amoxicillin 500mg capsule" — and a test that names the drug is naming
    // the row correctly even though the strings differ.
    final exact =
        find.ancestor(of: find.text(label), matching: find.byType(SheetRow));
    final containing = find.ancestor(
      of: find.textContaining(label),
      matching: find.byType(SheetRow),
    );
    Finder rows() => exact.evaluate().isNotEmpty ? exact : containing;

    // Narrow the sheet to what is being picked, the way a person does. The
    // sheet is capped at 62% of the screen, so anything past the fifth or
    // sixth option is never built — and an unbuilt row is indistinguishable
    // from an option the picker does not carry.
    if (rows().evaluate().isEmpty &&
        find.byKey(kPickerSearchKey).evaluate().isNotEmpty) {
      await tester.enterText(find.byKey(kPickerSearchKey), label);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpUntilViewportStable();
    }

    // Waited on unfiltered, tapped filtered. `.last` does not evaluate to
    // nothing while the sheet is still filling — it throws — so the wait has
    // to be on the finder that can answer "not yet".
    await tester.pumpUntil(
      () => rows().evaluate().isNotEmpty,
      reason: 'expected a sheet row reading "$label" to appear',
    );
    await tester.tap(rows().last);
    await settle();
  }

  /// "This open sheet is still usable with the keyboard up."
  ///
  /// Raises a soft keyboard, then asserts the row reading [label] is both
  /// hit-testable and drawn clear of it. The keyboard stays up afterwards, so
  /// whatever the flow does next does it under the conditions a person would.
  ///
  /// Two assertions rather than one, because the sheet this regression is
  /// about satisfied the easy half. Starved to forty points, `SheetShell` still
  /// *built* the first row or two — a sliver keeps its cache alive either side
  /// of a viewport, however short that viewport is — so `findsOneWidget` was
  /// happy while the reader saw a heading, a search field and then the
  /// keyboard. `hitTestable` is what notices there is nowhere to paint them;
  /// the rect is what notices the other failure mode, a sheet that lays its
  /// rows out perfectly well underneath the keyboard.
  Future<void> seeSheetRowAboveKeyboard(String label) async {
    await tester.raiseKeyboard();

    final row = find
        .ancestor(of: find.text(label), matching: find.byType(SheetRow))
        .last;
    expect(
      row.hitTestable(),
      findsOneWidget,
      reason: 'the sheet left no room to reach "$label" with the keyboard up',
    );

    final keyboardTop =
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
            tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    expect(
      tester.getRect(row).bottom,
      lessThanOrEqualTo(keyboardTop),
      reason: '"$label" is drawn underneath the keyboard',
    );
  }

  /// Sets a `DateField` through its quick-pick sheet.
  ///
  /// [choice] is the row's own label — `Today`, `In a week`, `In 30 days` or
  /// `Clear`. The calendar row is deliberately not reachable from here: a
  /// flow that needs one specific day should not be dragging a Material date
  /// picker around to get it.
  Future<void> pickDate(Key fieldKey, {String choice = 'Today'}) async {
    await tester.tapKeyWithoutKeyboard(fieldKey);
    await tester.pumpUntilRouteSettled();

    // The **row**, not the label: a sheet that is still sliding in has its
    // text on screen at an offset the tap would miss, and the row is what
    // carries the gesture anyway.
    final row = find
        .ancestor(of: find.text(choice), matching: find.byType(SheetRow))
        .last;
    await tester.pumpUntilFound(row);
    await tester.tap(row);
    await settle();
  }

  /// `ErrorRetryBanner` is the one shared error widget, so every
  /// `LoadStateMixin` screen gets its error path asserted the same way.
  void seeErrorBanner({String? containing}) {
    expect(find.byType(ErrorRetryBanner), findsOneWidget);
    if (containing != null) {
      expect(find.textContaining(containing), findsWidgets);
    }
  }

  void seeNoErrorBanner() =>
      expect(find.byType(ErrorRetryBanner), findsNothing);

  Future<void> tapRetry() async {
    await tester.tap(find.text('Try again'));
    await settle();
  }

  /// Asserts a piece of text is somewhere on this screen.
  ///
  /// Deliberately the only text-based assertion in the base class: everything
  /// structural goes through a key.
  void seeText(String text) =>
      expect(find.textContaining(text), findsWidgets, reason: 'expected "$text"');

  void seeNoText(String text) =>
      expect(find.textContaining(text), findsNothing);

  /// The navigator is still mounted and usable.
  ///
  /// Asserted after a teardown that could have raced: several concurrent 401s
  /// each calling `Get.offAllNamed` leave the navigator in a state no later
  /// route can recover from, and the symptom is a blank screen rather than an
  /// exception.
  void seeNavigatorIntact() => expect(
        find.byType(Navigator),
        findsWidgets,
        reason: 'the navigator did not survive the teardown',
      );

  /// Closes any open bottom sheet and lets its transition finish.
  ///
  /// Required before a flow that opened one ends. A `GetModalBottomSheetRoute`
  /// owns an `AnimationController` on the overlay's ticker provider, and
  /// `flutter_test` finalises the widget tree at the end of the test *body* —
  /// earlier than `addTearDown`, so the harness cannot clean this up on the
  /// flow's behalf. The failure it produces ("OverlayState was disposed with
  /// an active Ticker") names the overlay, not the sheet, so it is worth
  /// closing every sheet explicitly rather than debugging it twice.
  Future<void> closeSheet() async {
    if (Get.isBottomSheetOpen ?? false) Get.back();
    await tester.pumpUntilRouteSettled();
  }

  /// Pumps until the app stops talking to the server.
  Future<void> settle() => harness.settle();

  Future<void> back() async {
    Get.back();
    await tester.pumpUntilRouteSettled();
  }
}
