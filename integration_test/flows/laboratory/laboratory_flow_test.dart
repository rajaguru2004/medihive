import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/theme/theme.dart';

import '../../fixtures/modules/laboratory_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/laboratory_robot.dart';
import '../../robots/no_access_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerLaboratoryFlows();
}

/// The laboratory: the worklist, and the chain an order travels down it.
void registerLaboratoryFlows() {
  group('the laboratory', () {
    testWidgets('an order is raised, collected, resulted and verified',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.labTechnician,
        overrides: installLaboratoryFixtures,
      );
      final lab = LaboratoryRobot(harness);

      await lab.open();
      await lab.assertOnWorklist();

      // ── Raise one ────────────────────────────────────────────────────────
      await lab.startNewOrder();
      await lab.assertOnOrderForm();
      await lab.choosePatient('Tom Whitfield');
      await lab.addTests([LabFixtureIds.catalogueTest]);
      await lab.setOrderPriority('stat');
      await lab.typeIndication('Query hyperkalaemia');
      await lab.submitOrder();
      await lab.assertOnWorklist();

      final raised = harness.api.requireCall('POST', '/api/laboratory/orders');
      expect(raised.jsonBody['patientId'], 'p-2');
      expect(raised.jsonBody['priority'], 'stat');

      final ordered = (raised.jsonBody['tests'] as List).single as Map;
      expect(ordered['testId'], LabFixtureIds.catalogueTest);
      // A test follows the order's priority until somebody says otherwise: a
      // STAT order whose tests all read "routine" is one the bench works in
      // the wrong sequence.
      expect(ordered['urgency'], 'stat');

      // The worklist heard about the write and caught up with it.
      lab.seeRow(LabFixtureIds.firstCreatedOrder);
      lab.seeToast(containing: 'raised');
      await lab.letToastsExpire();

      // ── Collect the sample ───────────────────────────────────────────────
      await lab.openOrder(LabFixtureIds.pendingOrder);
      await lab.assertOnOrder();
      lab.seeOrderStatus('Pending');
      lab.seeCollectAction();

      await lab.collectSample(accession: 'ACC-TYPED-BY-HAND');
      lab.seeOrderStatus('Sample collected');

      final collected = harness.api.requireCall(
        'PATCH',
        '/api/laboratory/orders/:id',
        where: (request) => request.jsonBody['status'] == 'sample_collected',
      );
      expect(collected.jsonBody['sampleCollectedAt'], isNotNull);
      expect(collected.jsonBody['sampleCollectedById'], WorldRole.labTechnician.id);

      // The accession the screen reports back is the one the **server**
      // assigned, not the one that was typed. This backend mints its own on
      // this transition and discards the client's, and a screen that showed
      // the typed value would send somebody to a tube rack with a number that
      // exists nowhere but their phone.
      lab.seeToast(containing: LabFixtureIds.mintedAccession);
      await lab.letToastsExpire();
      lab.seeNoCollectAction();

      // ── Enter a result ───────────────────────────────────────────────────
      await lab.enterResultFor(LabFixtureIds.pendingOrderTest);
      await lab.assertOnResultForm();
      lab.seeFlagWords();
      lab.seeReferenceRange('4.0');

      await lab.typeResultValue('5.4');
      await lab.flagAs('N');
      await lab.saveResult();

      await lab.assertOnOrder();
      final entered = harness.api.requireCall('POST', '/api/laboratory/results');
      expect(entered.jsonBody['orderId'], LabFixtureIds.pendingOrder);
      expect(entered.jsonBody['testId'], LabFixtureIds.pendingOrderTest);
      expect(entered.jsonBody['resultValue'], '5.4');
      expect(entered.jsonBody['flag'], 'N');
      expect(entered.jsonBody['isCritical'], isFalse);

      lab.seeOrderStatus('In progress');
      lab.seeResult(LabFixtureIds.firstCreatedResult, '5.4');
      lab.seeNoCriticalBanner();
      await lab.letToastsExpire();

      // ── Verify it ────────────────────────────────────────────────────────
      await lab.verifyResult(LabFixtureIds.firstCreatedResult);

      final verified = harness.api.requireCall(
        'PATCH',
        '/api/laboratory/results/:id',
      );
      expect(verified.jsonBody['verifiedAt'], isNotNull);

      // Every result on this order is signed off, so the server closed it —
      // the screen reads the answer back rather than assuming it.
      lab.seeOrderStatus('Completed');
      lab.seeNoVerifyAction(LabFixtureIds.firstCreatedResult);
      await lab.letToastsExpire();
    });

    testWidgets('a critical result carries the word and raises a banner',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.labTechnician,
        overrides: installLaboratoryFixtures,
      );
      final lab = LaboratoryRobot(harness);

      await lab.open();
      await lab.assertOnWorklist();

      // Red, and only because there is something to be red about.
      expect(lab.figure('Critical').value, '1');
      expect(lab.figure('Critical').color, AppColors.acuityCritical);

      // The worklist row says so in words before anybody opens anything.
      lab.seeOnRow(LabFixtureIds.criticalOrder, 'Critical');

      await lab.openOrder(LabFixtureIds.criticalOrder);
      await lab.assertOnOrder();

      lab.seeCriticalBanner();
      lab.seeCriticalWordOnResult(LabFixtureIds.criticalResult);
      lab.seeResult(LabFixtureIds.criticalResult, '7.2');
    });

    testWidgets('a critical count of zero is not painted red', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.labTechnician,
        overrides: (api) {
          installLaboratoryFixtures(api);
          // Later registrations win. A quiet laboratory: nothing critical is
          // waiting on anybody.
          api.json('GET', '/api/laboratory/stats', const {
            'pending': 2,
            'sampleCollected': 2,
            'inProgress': 2,
            'completedToday': 2,
            'criticalResults': 0,
            'totalTests': 15,
          });
        },
      );
      final lab = LaboratoryRobot(harness);

      await lab.open();
      await lab.assertOnWorklist();

      expect(lab.figure('Critical').value, '0');
      expect(
        lab.figure('Critical').color,
        isNull,
        reason: 'a zero in the app’s one alarm colour is a false alarm, '
            'and a board that cries wolf in the corner it reserves for wolves '
            'stops being read',
      );
    });

    testWidgets('STAT sorts to the top of the worklist', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.labTechnician,
        overrides: installLaboratoryFixtures,
      );
      final lab = LaboratoryRobot(harness);

      await lab.open();
      await lab.assertOnWorklist();

      final rows = lab.rowIdsInOrder();
      expect(
        rows.first,
        LabFixtureIds.statOrder,
        reason: 'the route orders by request time alone, and the STAT order is '
            'deliberately the fifth-newest — a worklist that did not sort '
            'would run a routine cholesterol ahead of it',
      );
      // Then the two urgent ones, still in the order the server sent them.
      expect(rows.take(3).toList(), [LabFixtureIds.statOrder, 'o-3', 'o-5']);

      // Colour and rank and word: STAT is amber and says so. Red is reserved
      // for a patient in trouble.
      lab.seeOnRow(LabFixtureIds.statOrder, 'STAT');
    });

    testWidgets('a lab technician may raise an order', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.labTechnician,
        overrides: installLaboratoryFixtures,
      );
      final lab = LaboratoryRobot(harness);

      await lab.open();
      await lab.assertOnWorklist();
      lab.seeNewOrderAction();

      await lab.startNewOrder();
      await lab.assertOnOrderForm();
    });

    testWidgets('a nurse is refused the laboratory', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
        overrides: installLaboratoryFixtures,
      );
      final lab = LaboratoryRobot(harness);
      final refused = NoAccessRobot(harness);

      // The nurse holds no LABORATORY grant at all, so the route guard answers
      // before the screen does.
      await lab.open();
      await refused.assertVisible();
      refused.seeModuleName('Laboratory');
      // Nothing here offers a retry: a permission is changed by a person.
      refused.seeNoRetry();
    });

    testWidgets('the worklist survives a 403 from the server', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.labTechnician,
        overrides: (api) {
          installLaboratoryFixtures(api);
          // The access map is a hint and can be a minute older than the role
          // it describes, so the screen has to survive the refusal arriving
          // anyway.
          api.forbid('GET', '/api/laboratory/orders');
        },
      );
      final lab = LaboratoryRobot(harness);

      await lab.open();
      await lab.assertVisible();
      lab.seeLockedList();
    });

    testWidgets('the catalogue prices every test in the site’s own money',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.labTechnician,
        overrides: installLaboratoryFixtures,
      );
      final lab = LaboratoryRobot(harness);

      await lab.open();
      await lab.assertOnWorklist();

      await lab.openCatalogue();
      await lab.assertOnCatalogue();
      lab.seeCatalogueRow(LabFixtureIds.catalogueTest);

      await lab.searchCatalogue('Potassium');
      lab.seeCatalogueRow(LabFixtureIds.catalogueTest);
      expect(
        lab.catalogueRowCount,
        1,
        reason: 'the catalogue route has no `search` parameter, so the filter '
            'is applied to the rows already in hand',
      );
    });
  });
}
