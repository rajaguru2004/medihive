import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../../robots/home_robot.dart';
import '../../robots/inpatient_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerInpatientFlows();
}

/// The bed map: one ward as a floor plan.
void registerInpatientFlows() {
  group('the bed map', () {
    testWidgets('renders a ward and filters it by state', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final home = HomeRobot(harness);
      final wards = InpatientRobot(harness);

      await home.openTab(Routes.INPATIENT);
      await wards.assertOnBoard();

      await wards.openBedMap();
      await wards.assertOnBedMap();

      expect(wards.bedCount, 12, reason: 'Acute Medical has twelve beds');
      expect(
        wards.bedIdsInOrder().first,
        'b-1',
        reason: 'beds read in ward order, numerically — "10" after "9"',
      );

      // The four state counts are also the four filters: a number somebody
      // wants to act on should be the thing they tap.
      await wards.filterBedsBy(BedState.vacant);
      expect(wards.bedIdsInOrder(), ['b-3', 'b-6', 'b-10']);

      // The same chip again takes the filter off.
      await wards.filterBedsBy(BedState.vacant);
      expect(wards.bedCount, 12);
    });

    testWidgets('a vacant bed offers an admission and an occupied one does not',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final home = HomeRobot(harness);
      final wards = InpatientRobot(harness);

      await home.openTab(Routes.INPATIENT);
      await wards.openBedMap();
      await wards.assertOnBedMap();

      await wards.openBed('b-3');
      wards.seeBedAction('Admit a patient here');
      await wards.closeSheet();

      // The other half, and the one that matters clinically: a bed with
      // somebody in it must never be offered as somewhere to put somebody
      // else. Bed 3 also carries a *discharged* admission in the fixtures, so
      // this pair is the join being done correctly rather than by accident.
      await wards.openBed('b-1');
      wards.seeNoBedAction('Admit a patient here');
      wards.seeBedAction('Discharge');
      await wards.closeSheet();
    });
  });
}
