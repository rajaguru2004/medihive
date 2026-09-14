import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/theme/theme.dart';

import 'watch_mode.dart';

/// Frame-pumping helpers. **`pumpAndSettle` is banned in this suite.**
///
/// Any widget that schedules a frame forever — a `..repeat()` shimmer, a
/// one-second ticker — makes `pumpAndSettle` never return. It then fails only
/// when the test times out twelve minutes later, with no message naming what
/// it was waiting for.
///
/// `ShimmerBox` honours Reduce Motion (which the harness turns on), which
/// removes today's only such hazard. The ban stays anyway: it means the *next*
/// infinite animation somebody adds degrades into a ten-second failure that
/// says what it was waiting for, instead of a hang.
extension HarnessPump on WidgetTester {
  static const _tick = Duration(milliseconds: 32);
  static const _defaultTimeout = Duration(seconds: 10);

  /// Pumps frames until [condition] holds.
  ///
  /// Iteration-counted rather than wall-clocked, so it behaves identically
  /// under `flutter test`'s fake clock and `integration_test`'s real one.
  Future<void> pumpUntil(
    bool Function() condition, {
    Duration timeout = _defaultTimeout,
    String? reason,
  }) async {
    final maxFrames = timeout.inMilliseconds ~/ _tick.inMilliseconds;
    for (var frame = 0; frame < maxFrames; frame++) {
      if (condition()) {
        await pump();
        return;
      }
      await pump(_tick);
    }
    if (condition()) return;
    fail('pumpUntil gave up after $timeout'
        '${reason == null ? '' : ': $reason'}\n'
        'Current route: ${Get.currentRoute}');
  }

  /// Whether [finder] matches anything **right now**, without throwing.
  ///
  /// A `.first` or `.last` finder does not answer "nothing yet" — it throws
  /// `Bad state: No element` out of `evaluate()`. Polling one directly turns
  /// every frame before the widget arrives into a test error with a stack
  /// trace from inside `Iterable.last`, which is the opposite of what the
  /// caller asked for. The throw *is* the empty answer.
  static bool _present(Finder finder) {
    try {
      return finder.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  // `describeMatch` rather than the finder itself in both reasons below.
  // Interpolating a `Finder` calls `toString`, which renders the *matches* —
  // and on a `.first`/`.last` finder with none, that throws too. Which is
  // exactly the case these two report on, so the timeout message was replaced
  // by a stack trace from inside the failure message.
  Future<void> pumpUntilFound(Finder finder, {Duration? timeout}) => pumpUntil(
        () => _present(finder),
        timeout: timeout ?? _defaultTimeout,
        reason: 'expected ${finder.describeMatch(Plurality.one)} to appear',
      );

  Future<void> pumpUntilGone(Finder finder, {Duration? timeout}) => pumpUntil(
        () => !_present(finder),
        timeout: timeout ?? _defaultTimeout,
        reason: 'expected ${finder.describeMatch(Plurality.one)} to disappear',
      );

  /// Waits for navigation to land and the destination to finish its first
  /// load.
  ///
  /// "Settled" means four things at once: the expected route is current, no
  /// route transition is still running, no spinner is on screen, and no
  /// shimmer skeleton is left.
  ///
  /// The transition check is not cosmetic. A `GetPageRoute` wraps the incoming
  /// page in an `AbsorbPointer` while it animates, so a tap during those
  /// 280 ms is swallowed with "derived an Offset that would not hit test".
  /// Under `flutter test` the fake clock skips the animation and the race is
  /// invisible; on a device it is real, which is why this is checked rather
  /// than assumed.
  Future<void> pumpUntilRouteSettled({
    String? expectRoute,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      pumpUntil(
        () {
          if (expectRoute != null && Get.currentRoute != expectRoute) {
            return false;
          }
          if (binding.transientCallbackCount > 0) return false;
          return find.byType(CircularProgressIndicator).evaluate().isEmpty &&
              find.byType(ShimmerBox).evaluate().isEmpty;
        },
        timeout: timeout,
        reason: expectRoute == null
            ? 'the app never reached a settled frame'
            : 'never settled on $expectRoute',
      );

  /// Advances a known periodic ticker deterministically, one second per frame.
  Future<void> pumpSeconds(int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await pump(const Duration(seconds: 1));
    }
  }

  /// Puts a soft keyboard of [height] logical points under the app.
  ///
  /// `flutter test` has no keyboard and reports a zero bottom inset forever,
  /// so every layout that has to give way when the viewport shrinks — a sheet,
  /// a form's pinned save button, a picker's result list — is laid out in the
  /// headless tier at a size no phone ever gives it. A whole class of "it
  /// works in the tests and not on the device" lives in that gap, and the only
  /// way to close it is to put the inset there by hand.
  ///
  /// 340 is a Pixel-class keyboard on an 891-point-tall screen: a little over
  /// a third of the window, which is what the layouts have to survive.
  /// `viewInsets` is in *physical* pixels, hence the ratio.
  ///
  /// Restored at the end of the test, so a flow that raises one does not have
  /// to remember to put it away.
  Future<void> raiseKeyboard({double height = 340}) async {
    addTearDown(view.resetViewInsets);
    view.viewInsets = FakeViewPadding(bottom: height * view.devicePixelRatio);
    await pumpUntilViewportStable();
  }

  Future<void> lowerKeyboard() async {
    view.resetViewInsets();
    await pumpUntilViewportStable();
  }

  /// Waits for the soft keyboard to finish opening or closing.
  ///
  /// The keyboard inset is driven by the platform, not by a Flutter ticker, so
  /// `transientCallbackCount` is already zero while the viewport is still
  /// shrinking. Tapping during that window computes an offset that is stale by
  /// the time the pointer lands. It bites exactly once per run — on the first
  /// field a flow types into.
  ///
  /// Under `flutter test` the inset is always zero and this returns after
  /// three frames.
  Future<void> pumpUntilViewportStable({int stableFrames = 3}) async {
    var last = view.viewInsets.bottom;
    var stable = 0;
    for (var frame = 0; frame < 60; frame++) {
      await pump(const Duration(milliseconds: 32));
      final now = view.viewInsets.bottom;
      if (now == last) {
        if (++stable >= stableFrames) return;
      } else {
        last = now;
        stable = 0;
      }
    }
  }

  /// Taps a keyed widget once the tree is holding still.
  ///
  /// Waiting out any in-flight transition first is what keeps this working on
  /// a device, where animations take real time and a tap landing mid-transition
  /// is absorbed rather than delivered.
  ///
  /// Only one frame is pumped afterwards, deliberately: an assertion about a
  /// transient state — a submit button's spinner, say — must still be able to
  /// observe it. Waiting for the result is the caller's job.
  Future<void> tapKey(Key key) async {
    await pumpUntilViewportStable();
    await pumpUntil(
      () => binding.transientCallbackCount == 0,
      reason: 'the tree was still animating when tapKey($key) was called',
    );
    // Scroll the target into view first. On a device the soft keyboard shrinks
    // the viewport as soon as a field takes focus, which pushes a scrolling
    // form's submit button out of the visible area — the tap then lands on
    // whatever the inset left behind and fails with "derived an Offset that
    // would not hit test". Under `flutter test` there is no keyboard and no
    // viewport change, so that half only shows up on device; the other half —
    // a sliver below the fold that was never built — shows up everywhere.
    await scrollToKey(key);

    final finder = find.byKey(key);
    expect(finder, findsOneWidget, reason: 'tapKey($key)');

    await tap(finder);
    await pump(const Duration(milliseconds: 16));
    // Watch mode only: holds the result on screen long enough to read. A no-op
    // otherwise, so the gate pays nothing for it.
    await WatchMode.hold(this);
  }

  Future<void> enterTextByKey(Key key, String text) async {
    await scrollToKey(key);
    final finder = find.byKey(key);
    expect(finder, findsOneWidget, reason: 'enterTextByKey($key)');
    await enterText(finder, text);
    await pump(const Duration(milliseconds: 16));
    await WatchMode.hold(this);
  }

  /// Taps a keyed widget with the soft keyboard out of the way first.
  ///
  /// For anything that opens a sheet or a dialog from a form. On a real device
  /// the keyboard is still up from the field typed into a moment ago, it
  /// covers the lower half of the screen, and the tap lands on the keyboard
  /// instead — which shows up only on device, and only as "another widget is
  /// obscuring it".
  Future<void> tapKeyWithoutKeyboard(Key key) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpUntilViewportStable();
    await tapKey(key);
  }

  /// Brings a keyed widget into the tree and into view.
  ///
  /// Two different problems, and a long form has both. A sliver below the fold
  /// is **not built at all**, so `find.byKey` returns nothing and no amount of
  /// `ensureVisible` helps — the scroll view has to be dragged until the item
  /// is created. A widget that *is* built can still be off screen, where a tap
  /// lands on whatever is in front of it.
  ///
  /// Quietly does nothing when there is no scroll view: a sheet that fits, a
  /// dialog, a screen that does not scroll.
  Future<void> scrollToKey(Key key, {int maxDrags = 60}) =>
      scrollToFinder(find.byKey(key), maxDrags: maxDrags);

  /// The same, for a widget a test can only name by what it says.
  ///
  /// Most targets have a key and should use [scrollToKey]. A few are addressed
  /// by their label because the label is what the assertion is about — a
  /// destination in the More hub is "Billing" to the person looking at it, and
  /// keyed by route to the code that built it.
  Future<void> scrollToFinder(Finder finder, {int maxDrags = 60}) async {
    if (finder.evaluate().isEmpty) {
      final Finder? view = _topScrollView();
      if (view == null) return;

      // Which way to look. Dragging down never reaches something *above* the
      // current offset, and after a failed save the form is sitting at the
      // button while the field being complained about is several screens up —
      // so a downward-only search reports "not there" for something that is
      // merely behind you.
      final steps = _scrollOffsetOf(view) > 1
          ? const [Offset(0.0, 240.0), Offset(0.0, -240.0)]
          : const [Offset(0.0, -240.0)];

      for (final step in steps) {
        for (var i = 0; i < maxDrags; i++) {
          if (finder.evaluate().isNotEmpty) break;
          final before = _scrollOffsetOf(view);
          await _dragScrollView(view, step);
          // Nothing moved: this is the end of the list, or the drag landed on
          // something that swallowed it. Either way another sixty of the same
          // will not help.
          if ((_scrollOffsetOf(view) - before).abs() < 0.5) break;
        }
        if (finder.evaluate().isNotEmpty) break;
      }
    }

    if (finder.evaluate().isEmpty) return;
    try {
      await ensureVisible(finder);
      await pump(const Duration(milliseconds: 16));
    } on StateError {
      // Not inside a Scrollable — already as visible as it will get.
    }
  }

  /// Brings a keyed widget into view inside a **horizontal** strip.
  ///
  /// [scrollToKey] drags the page, which does nothing for a row of chips that
  /// scrolls sideways — and a chip past the right edge is not built at all, so
  /// the failure reads as "that tab does not exist". The patient hub's seventh
  /// tab is off screen on every phone.
  Future<void> scrollToKeyInStrip(
    Finder strip,
    Key key, {
    int maxDrags = 20,
  }) async {
    final target = find.byKey(key);
    if (strip.evaluate().isEmpty) return;

    // Left first, then right. A strip already dragged to its end has the early
    // chips unbuilt behind it, so a forward-only search reports the first tab
    // as missing the moment a test has visited the last one.
    for (final step in const [Offset(-180, 0), Offset(180, 0)]) {
      for (var i = 0; i < maxDrags && target.evaluate().isEmpty; i++) {
        await drag(strip.first, step);
        await pump(const Duration(milliseconds: 16));
      }
      if (target.evaluate().isNotEmpty) break;
    }
    if (target.evaluate().isEmpty) return;
    try {
      await ensureVisible(target);
      await pump(const Duration(milliseconds: 16));
    } on StateError {
      // Not inside a Scrollable — already as visible as it will get.
    }
  }

  /// The scroll view a drag should act on.
  ///
  /// Two traps, and both produce a drag that scrolls nothing. `find.byType
  /// (Scrollable)` is useless because every `TextField` brings one of its own.
  /// And taking the last scroll view in tree order picks a **nested** one — a
  /// multi-line field inside the page's own list — which scrolls its own two
  /// lines while the page stays exactly where it was.
  ///
  /// So: match the scroll views the app builds, discard any that sit inside
  /// another match, and take the last of what is left. That is the outermost
  /// scroll view of the topmost route — the sheet's when a sheet is open, the
  /// page's otherwise.
  Finder? _topScrollView() {
    final matches = find
        .byWidgetPredicate(
          (widget) =>
              widget is CustomScrollView ||
              widget is SingleChildScrollView ||
              widget is ListView ||
              widget is GridView,
          description: 'app scroll view',
        )
        .evaluate()
        .toList();
    if (matches.isEmpty) return null;

    final outermost = [
      for (final element in matches)
        if (!_hasAncestorIn(element, matches)) element,
    ];
    final target = outermost.isEmpty ? matches.last : outermost.last;

    return find.byElementPredicate(
      (element) => identical(element, target),
      description: 'the topmost app scroll view',
    );
  }

  /// Drags a scroll view by [step], from a point that is certainly not a
  /// field.
  ///
  /// Not from the centre, which is where `dragUntilVisible` starts: on a form
  /// the centre of the scroll view lands on whatever input happens to be in
  /// the middle, and a multi-line `TextField` wins the vertical drag and
  /// scrolls its own three lines while the page stays exactly where it was.
  /// The left gutter belongs to nothing but the scroll view.
  Future<void> _dragScrollView(Finder view, Offset step) async {
    final rect = getRect(view);
    await dragFrom(Offset(rect.left + 6, rect.center.dy), step);
    await pump(const Duration(milliseconds: 16));
  }

  /// How far the scroll view named by [view] has been scrolled, or zero when
  /// it has no position yet.
  double _scrollOffsetOf(Finder view) {
    final elements = view.evaluate();
    if (elements.isEmpty) return 0;
    ScrollableState? state;
    void visit(Element child) {
      if (state != null) return;
      if (child is StatefulElement && child.state is ScrollableState) {
        state = child.state as ScrollableState;
        return;
      }
      child.visitChildElements(visit);
    }

    elements.first.visitChildElements(visit);
    final position = state?.position;
    return position != null && position.hasPixels ? position.pixels : 0;
  }

  static bool _hasAncestorIn(Element element, List<Element> candidates) {
    var found = false;
    element.visitAncestorElements((ancestor) {
      if (candidates.any((c) => identical(c, ancestor))) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }
}
