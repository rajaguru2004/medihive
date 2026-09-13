import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';

import 'robot.dart';
import 'shell_tab.dart';

/// The clinic list — the shell's third tab.
final class AppointmentsRobot extends Robot with ShellTab {
  AppointmentsRobot(super.harness);

  @override
  Key get anchor => AppointmentsKeys.screen;

  /// "Clinic" on the tab, "Appointments" in the bar: the destination table
  /// gives this one a `title` of its own, because the tab label has to fit a
  /// quarter of a phone and the heading does not.
  @override
  String get shellTitle => 'Appointments';

  Future<void> assertOnBoard() async {
    await assertVisible();
    seeNoErrorBanner();
  }
}
