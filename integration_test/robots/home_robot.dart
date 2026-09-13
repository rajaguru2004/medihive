import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The shell: the top bar, the tab bar, and whichever tab is active.
///
/// Owns nothing a tab owns. What is *inside* a tab belongs to that tab's robot,
/// exactly as it belongs to that tab's controller.
final class HomeRobot extends Robot {
  HomeRobot(super.harness);

  @override
  String? get route => Routes.HOME;

  @override
  Key get anchor => HomeKeys.screen;

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
}
