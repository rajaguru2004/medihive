import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The shell: the top bar, the navigation, and whichever tab is active.
///
/// Owns nothing a tab owns. What is *inside* a tab belongs to that tab's robot,
/// exactly as it belongs to that tab's controller.
final class HomeRobot extends Robot {
  HomeRobot(super.harness);

  @override
  String? get route => Routes.HOME;

  @override
  Key get anchor => HomeKeys.screen;

  /// The side rail the shell grows into at tablet width.
  ///
  /// TODO(shell): replace with `HomeKeys.rail` once the expanded layout lands
  /// — the key belongs in `lib/app/core/keys/home_keys.dart` beside `tabBar`,
  /// and this robot must not be the thing that defines it. Spelled in the key
  /// file's own convention so the move is a rename and nothing else.
  static const Key _rail = ValueKey('home_rail');

  /// Switches tab the way a thumb does.
  ///
  /// Tapping rather than driving `HomeController.selectRoute` — which is what
  /// the screenshot suite does, to avoid photographing a transition — because a
  /// tab that is wired to nothing is exactly the regression a shell flow is
  /// for.
  Future<void> openTab(String route) async {
    await tester.tapKey(HomeKeys.tab(route));
    await settle();
  }

  /// Opens the More hub.
  ///
  /// The shell's last slot, and the only route to anything that did not fit on
  /// the bar — so an account whose modules outnumber the slots reaches half of
  /// them through here.
  Future<void> openMore() async {
    await tester.tapKey(HomeKeys.tab(Routes.MORE));
    await settle();
  }

  /// The shell bar shows the **active tab's** title, and the tab body must not
  /// repeat it (RULES §6.3) — so this is the one place a flow can read which
  /// tab is up without reaching into a controller.
  void seeTitle(String title) {
    expect(
      tester.widget<Text>(find.byKey(HomeKeys.title)).data,
      title,
      reason: 'the shell bar should be titled "$title"',
    );
  }

  /// The site under the screen name. A clinician covering two sites on one
  /// device needs to know which one this tablet is pointed at.
  void seeSite(String name) => seeText(name);

  // ── Destinations ──────────────────────────────────────────────────────────
  //
  // By the word on the tab, not by its route. A role flow's claim is "a nurse
  // has no Billing tab", which is what a nurse would say looking at it; the
  // route is how the code happens to key it. Both assertions are scoped to the
  // navigation surface, because every tab that has ever been opened stays in
  // the `IndexedStack` — so an unscoped `find.text('Queue')` is answered by a
  // section header on a screen nobody can see.

  /// This account has a destination reading [label].
  void seeTab(String label) => expect(
        _navigationLabel(label),
        findsOneWidget,
        reason: 'expected a "$label" destination on the shell navigation',
      );

  /// This account has no destination reading [label].
  ///
  /// The half of role navigation that actually matters. Showing a pharmacist a
  /// Billing tab that answers 403 when tapped is worse than not showing it: it
  /// reads as the app being broken rather than as the account being scoped.
  void seeNoTab(String label) => expect(
        _navigationLabel(label),
        findsNothing,
        reason: 'the shell offered a "$label" destination to an account that '
            'cannot use it',
      );

  /// True when the shell has laid its navigation out as a side rail rather
  /// than as a bottom bar.
  ///
  /// **Branch on this, never on the device class.** The class is what the run
  /// *asked for*; this is what the shell did with it. A flow that says "on a
  /// tablet" stops testing the breakpoint the moment somebody moves it, and
  /// starts asserting a device name instead — see the comment on
  /// `DeviceClass`.
  ///
  /// Geometry rather than a widget type, so it stays true through whatever the
  /// rail is eventually built out of: a bar spans the shell and is a strip, a
  /// rail is a column beside the body.
  bool get isExpandedLayout {
    final shell = tester.getRect(find.byKey(HomeKeys.screen));
    final navigation = tester.getRect(_navigation);
    return navigation.height > navigation.width &&
        navigation.width < shell.width / 2;
  }

  /// Whichever surface the shell is currently navigating from.
  Finder get _navigation {
    final rail = find.byKey(_rail);
    return rail.evaluate().isEmpty ? find.byKey(HomeKeys.tabBar) : rail;
  }

  Finder _navigationLabel(String label) => find.descendant(
        of: _navigation,
        matching: find.text(label),
      );
}
