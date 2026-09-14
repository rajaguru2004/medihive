import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/routes/app_pages.dart';

import 'robot.dart';

/// Where the route guard sends somebody who asked for a module they do not
/// hold.
///
/// Reached only by a deep link, a stale shortcut, or a role an administrator
/// changed under a running session — navigation itself never offers a
/// destination this account cannot open. So a flow that lands here is
/// asserting the *guard*, and the thing it must be able to tell apart is a
/// refusal from a crash: both are "not the screen I asked for", and only one
/// of them is correct.
final class NoAccessRobot extends Robot {
  NoAccessRobot(super.harness);

  @override
  String? get route => Routes.NO_ACCESS;

  @override
  Key get anchor => NoAccessKeys.screen;

  /// The refusal names the module it is about.
  ///
  /// Worth asserting rather than taking the screen's presence as enough: the
  /// guard passes the display name through as an argument, and a guard that
  /// forgets to falls back to "That screen" — which is still a working screen,
  /// still not an error, and tells the reader nothing about what to ask their
  /// administrator for.
  void seeModuleName(String name) => expect(
        find.descendant(
          of: find.byKey(NoAccessKeys.module),
          matching: find.textContaining(name),
        ),
        findsOneWidget,
        reason: 'the refusal should name "$name"; a guard that loses the name '
            'shows "That screen is not part of your role"',
      );

  /// Nothing here offers a retry.
  ///
  /// A permission is changed by a person, not by trying again — and a "try
  /// again" on a locked panel is what sends a nurse to IT for a role she was
  /// never meant to have. `ErrorRetryBanner` is the app's one retry affordance,
  /// so its absence is the whole assertion.
  void seeNoRetry() => seeNoErrorBanner();
}
