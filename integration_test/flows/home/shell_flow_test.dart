import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../../robots/appointments_robot.dart';
import '../../robots/dashboard_robot.dart';
import '../../robots/home_robot.dart';
import '../../robots/inpatient_robot.dart';
import '../../robots/queue_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerShellFlows();
}

/// The shell and its four tabs.
void registerShellFlows() {
  group('the shell', () {
    testWidgets('switches between four tabs and refetches none of them on the '
        'way back', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final home = HomeRobot(harness);
      final dashboard = DashboardRobot(harness);
      final queue = QueueRobot(harness);
      final clinic = AppointmentsRobot(harness);
      final wards = InpatientRobot(harness);

      await home.assertVisible();
      await dashboard.assertOnBoard();
      // First on the board, and only when there is something to say: a ward
      // board is picked up to answer "is anyone in trouble" before anything
      // else.
      dashboard.seeAttention();

      await home.openTab(Routes.QUEUE);
      await queue.assertOnBoard();
      // The tab that was showing has to stop showing. An `IndexedStack` keeps
      // every built child in the tree, so "the new one appeared" is only half
      // the assertion.
      await dashboard.assertNotVisible();

      await home.openTab(Routes.APPOINTMENTS);
      await clinic.assertOnBoard();
      await queue.assertNotVisible();

      await home.openTab(Routes.INPATIENT);
      await wards.assertOnBoard();
      await clinic.assertNotVisible();

      // Every tab is now built and has finished its first load. The second
      // pass must cost nothing: the tabs live in a `LazyIndexedStack` and
      // their controllers are permanent, so going back to one is a repaint.
      final settled = harness.api.calls.length;

      await home.openTab(Routes.HOME);
      await dashboard.assertOnBoard();

      await home.openTab(Routes.QUEUE);
      await queue.assertOnBoard();

      expect(
        harness.api.calls.length,
        settled,
        reason: 'switching tabs refetched. A shell that reloads a tab on every '
            'visit also loses its scroll position, and on a ward tablet that '
            'is a clinician finding their place again four times a minute',
      );
    });
  });
}
