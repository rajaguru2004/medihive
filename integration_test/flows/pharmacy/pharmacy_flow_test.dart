import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/modules/pharmacy/controllers/pharmacy_controller.dart';

import '../../fakes/fake_api.dart';
import '../../fixtures/modules/pharmacy_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/no_access_robot.dart';
import '../../robots/pharmacy_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerPharmacyFlows();
}

/// The dispensing counter.
///
/// The shelf is the thing these flows are really about. Every assertion here
/// comes back to one of two facts: a dispense must never hand over more than
/// the shelf holds, and a shelf that is short must never be painted the colour
/// this app reserves for a patient in trouble.
void registerPharmacyFlows() {
  group('the pharmacy counter', () {
    testWidgets('a full dispense posts a sale and leaves the prescription to '
        'the server', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.pharmacist,
        overrides: _world,
      );
      final pharmacy = PharmacyRobot(harness);

      await pharmacy.openCounter();
      await pharmacy.assertOnCounter();

      await pharmacy.openPrescription(fullPrescriptionId);
      pharmacy.seeDispenseOffered();

      await pharmacy.startDispense();
      await pharmacy.assertOnDispense();

      // Both lines open at what was written, because the shelf covers both.
      expect(pharmacy.dispenseQuantity(shortDrugId), '$shortDrugRequested');

      await pharmacy.confirmDispense();

      final sale = harness.api.requireCall('POST', '/api/pharmacy/sales');
      final body = sale.jsonBody;
      expect(body['prescriptionId'], fullPrescriptionId);
      expect((body['items']! as List).length, 2);

      // `POST /pharmacy/sales` already moves a prescription it was given the
      // id of — in the same transaction that decrements the stock. A second
      // write here would be the app telling the server something it has just
      // been told.
      harness.api.requireNoCall('PATCH', '/api/pharmacy/prescriptions/:id');

      await pharmacy.letToastsExpire();
    });

    testWidgets('a dispense the shelf cannot cover marks the prescription '
        'partial', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.pharmacist,
        overrides: _world,
      );
      final pharmacy = PharmacyRobot(harness);

      await pharmacy.openCounter();
      await pharmacy.openPrescription(partialPrescriptionId);
      await pharmacy.startDispense();
      await pharmacy.assertOnDispense();

      // Ninety written, sixty on the shelf: the line opens at what will fit.
      expect(pharmacy.dispenseQuantity(cappedDrugId), '$cappedDrugStock');

      await pharmacy.confirmDispense();

      final sale = harness.api.requireCall('POST', '/api/pharmacy/sales');
      expect((sale.jsonBody['items']! as List).length, 2);

      // The sale set it to `fully_dispensed`, which is wrong here: the patient
      // is still owed thirty. This is the one case the app corrects.
      final patch =
          harness.api.requireCall('PATCH', '/api/pharmacy/prescriptions/:id');
      expect(patch.pathParams['id'], partialPrescriptionId);
      expect(patch.jsonBody['status'], 'partially_dispensed');

      await pharmacy.letToastsExpire();
    });

    testWidgets('a quantity cannot be raised past what is on the shelf',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.pharmacist,
        overrides: _world,
      );
      final pharmacy = PharmacyRobot(harness);

      await pharmacy.openCounter();
      await pharmacy.openPrescription(partialPrescriptionId);
      await pharmacy.startDispense();

      await pharmacy.setDispenseQuantity(cappedDrugId, '999');
      expect(
        pharmacy.dispenseQuantity(cappedDrugId),
        '$cappedDrugStock',
        reason: 'the counter must not offer to hand over stock it has not got',
      );

      // And down again, because a clamp that only ever raises is a clamp that
      // stops a pharmacist dispensing less than the maximum.
      await pharmacy.setDispenseQuantity(cappedDrugId, '10');
      expect(pharmacy.dispenseQuantity(cappedDrugId), '10');

      harness.api.requireNoCall('POST', '/api/pharmacy/sales');
    });

    testWidgets('a refusal for stock names the drug it is about',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.pharmacist,
        overrides: (api) {
          _world(api);
          stubInsufficientStock(api);
        },
      );
      final pharmacy = PharmacyRobot(harness);

      await pharmacy.openCounter();
      await pharmacy.openPrescription(fullPrescriptionId);
      await pharmacy.startDispense();

      // The shelf still says it can cover this when the screen opens. It is
      // somebody else's dispense, between that frame and the tap, that takes
      // the stock away — which is the whole point of the path.
      expect(pharmacy.dispenseQuantity(shortDrugId), '$shortDrugRequested');

      await pharmacy.confirmDispense();

      pharmacy.seeStockRefusal(naming: shortDrugName);

      // The screen re-read the shelf and lowered the line to what is actually
      // there, so the next tap can succeed without anybody retyping anything.
      expect(pharmacy.dispenseQuantity(shortDrugId), '$shortDrugRemaining');

      await pharmacy.letToastsExpire();
    });

    testWidgets('low and empty stock are amber, never red', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.pharmacist,
        overrides: _world,
      );
      final pharmacy = PharmacyRobot(harness);

      await pharmacy.openCounter();
      await pharmacy.showSegment(PharmacyCounter.inventory);

      // Below the line, exactly on it, and empty. All three are the pharmacy's
      // problem and none of them is a patient's.
      await pharmacy.seeAmberStock(lowStockDrugId);
      await pharmacy.seeAmberStock(atReorderDrugId);
      await pharmacy.seeAmberStock(outOfStockDrugId);
    });

    testWidgets('a pharmacist reaches the counter and a nurse does not',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.pharmacist,
        overrides: _world,
      );
      final pharmacy = PharmacyRobot(harness);

      await pharmacy.openCounter();
      await pharmacy.assertOnCounter();
      await pharmacy.openPrescription(fullPrescriptionId);
      pharmacy.seeDispenseOffered();
    });

    testWidgets('a nurse asking for the counter is refused, not broken',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
        overrides: _world,
      );
      final pharmacy = PharmacyRobot(harness);
      final locked = NoAccessRobot(harness);

      await pharmacy.requestCounter();

      await locked.assertVisible();
      locked.seeModuleName('Pharmacy');
      // Nothing here offers a retry: a permission is changed by a person, and
      // "try again" on a locked panel is what sends a nurse to IT for a role
      // she was never meant to have.
      locked.seeNoRetry();

      // The guard turned her back before the module asked the server anything.
      harness.api.requireNoCall('GET', '/api/pharmacy/drugs');
      harness.api.requireNoCall('GET', '/api/pharmacy/stats');
    });
  });
}

/// The pharmacy's own fixtures, on top of the shared world.
///
/// Installed from the flow rather than relied on from `World.install`, so these
/// flows run whether or not the world has adopted the module yet. Later
/// registrations win, so this is a no-op once it has.
void _world(FakeApi api) => installPharmacyFixtures(api);
