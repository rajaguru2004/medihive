import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';

import '../support/pump.dart';
import '../support/watch_mode.dart';
import 'robot.dart';

/// A screen that lives inside the shell's `IndexedStack` rather than on the
/// navigator.
///
/// Two things the base [Robot] cannot know, and both make a naïve "am I here"
/// assertion pass on the wrong tab:
///
///   * **the route is no evidence.** `Get.currentRoute` is `/home` whichever of
///     the four is showing, so a robot that checks it would accept any of them.
///   * **a tab that has been opened once never leaves the tree.** An
///     `IndexedStack` lays every child it has built out and paints one, so
///     `find.byKey` keeps finding three screens nobody can see. Only
///     hit-testing separates them: `RenderIndexedStack` hit-tests the active
///     child alone.
///
/// The shell bar's title is checked alongside, because it is the contract
/// (RULES §6.3: the bar says the active tab's name) and because it fails with a
/// sentence rather than with an empty finder.
base mixin ShellTab on Robot {
  /// What the shell bar says while this tab is active.
  String get shellTitle;

  @override
  String? get route => null;

  @override
  Future<void> assertVisible() async {
    await tester.pumpUntilFound(find.byKey(anchor).hitTestable());
    expect(
      tester.widget<Text>(find.byKey(HomeKeys.title)).data,
      shellTitle,
      reason: '$anchor is the tab on screen, but the shell bar does not say '
          '"$shellTitle"',
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: '$shellTitle is still showing a spinner after settling',
    );
    await WatchMode.hold(tester);
  }

  @override
  Future<void> assertNotVisible() async {
    await tester.pumpUntilGone(find.byKey(anchor).hitTestable());
  }
}
