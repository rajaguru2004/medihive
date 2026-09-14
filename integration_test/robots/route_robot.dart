import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot.dart';

/// Assertions that hold on **every** screen, whatever it is.
///
/// The per-module robots know what their screen says; this one knows only what
/// any screen must be. It exists because the two worst failures a route can
/// have are invisible to a module flow: a screen nobody wrote a flow for, and
/// a screen that renders but renders wrongly for a structural reason.
final class RouteRobot extends Robot {
  RouteRobot(super.harness);

  // This robot spans every screen, so it has neither of its own. The base
  // class asks for them so that `assertVisible` can check both; nothing here
  // calls it.
  @override
  String? get route => null;

  @override
  Key get anchor => throw UnsupportedError(
        'RouteRobot is about every screen, so it has no anchor of its own',
      );

  /// "This screen sits on a material."
  ///
  /// A pushed route that forgets its `Scaffold` — the usual cause is an
  /// `embedded` flag left at its default, which is what a shell tab wants and
  /// what a pushed copy must not have — still renders. Flutter draws every
  /// `Text` under it in the error style instead: the right size, the right
  /// colour, and a **yellow double underline through every word on the
  /// screen**. Nothing throws, no test notices, and the screenshot is the only
  /// place it shows up.
  void assertOnMaterial(String route) {
    expect(
      find.byType(Material),
      findsWidgets,
      reason: '$route renders with no Material above it, so every label on it '
          'is drawn with a yellow underline. The usual cause is a pushed '
          'route building its view without `embedded: false`.',
    );
  }
}
