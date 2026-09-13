import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';

import '../support/pump.dart';
import 'robot.dart';
import 'shell_tab.dart';

/// Today's board — the shell's first tab.
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
    await tester.pumpUntilFound(find.byKey(HomeKeys.census));
  }

  /// The attention card, which is drawn only when there is something to say.
  void seeAttention() => expect(
        find.byKey(HomeKeys.attention),
        findsOneWidget,
        reason: 'a critical alert should raise the attention card',
      );
}
