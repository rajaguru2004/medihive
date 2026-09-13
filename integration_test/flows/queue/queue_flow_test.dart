import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../../robots/home_robot.dart';
import '../../robots/queue_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerQueueFlows();
}

/// The queue board — the one screen in this app where the ordering *is* the
/// product.
///
/// The expected order below is not arbitrary. In the fixtures P1 has waited 42
/// minutes, P5 eight, and a P4 who arrived 35 minutes ago sits ahead of a P4
/// who arrived 24 minutes ago. Any of those pairs coming out the other way
/// round is the board falling back to arrival order, which is the sort this
/// screen exists to replace.
void registerQueueFlows() {
  group('the queue board', () {
    const byAcuityThenArrival = ['q-1', 'q-5', 'q-2', 'q-3', 'q-6', 'q-4'];

    testWidgets('is ordered by acuity, then by arrival', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final home = HomeRobot(harness);
      final queue = QueueRobot(harness);

      await home.openTab(Routes.QUEUE);
      await queue.assertOnBoard();

      queue.seeRowOrder(byAcuityThenArrival);
      expect(
        queue.acuityOf(queue.rowIdsInOrder().first),
        'P1',
        reason: 'the top of the board must be the most urgent patient, not '
            'the longest wait',
      );

      // The top row is somebody still waiting, so their sheet offers the call.
      await queue.openActionsFor('q-1');
      queue.seeSheetAction('Call');
      await queue.closeSheet();
    });

    testWidgets('call next calls whoever the board put first', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final home = HomeRobot(harness);
      final queue = QueueRobot(harness);

      await home.openTab(Routes.QUEUE);
      await queue.assertOnBoard();

      await queue.callNext();

      final patch = harness.api.requireCall('PATCH', '/api/queue/:id');
      expect(
        patch.pathParams['id'],
        'q-1',
        reason: 'call next disagreed with the order on screen, which is the '
            'worst outcome here — the person pressing it is watching the list',
      );
      expect(patch.jsonBody['status'], 'called');

      await queue.letToastsExpire();
    });

    testWidgets('a filter narrows the board and clearing restores it',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final home = HomeRobot(harness);
      final queue = QueueRobot(harness);

      await home.openTab(Routes.QUEUE);
      await queue.assertOnBoard();
      expect(queue.rowIdsInOrder(), byAcuityThenArrival);

      await queue.filterBy('P1');
      queue.seeRowOrder(['q-1']);

      await queue.clearFilter();
      // Restored, and still in the order it was in. A filter that quietly
      // resorts the board on the way out is the same defect as one that never
      // sorted it.
      queue.seeRowOrder(byAcuityThenArrival);
    });
  });
}
