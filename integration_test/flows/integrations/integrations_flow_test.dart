import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/data/repositories/integrations_repository.dart';
import 'package:medihive/app/theme/theme.dart';

import '../../fakes/fake_api.dart';
import '../../fixtures/modules/integrations_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/integrations_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerIntegrationsFlows();
}

/// The instrument link, end to end.
///
/// Six tests, and each is a rule that costs somebody something when it breaks:
/// a disconnected analyser painted in the colour a ward scans for; a result
/// that reached nobody and does not say so; an import posted under a field name
/// the route ignores, which files an empty file and reports success; a retry
/// that makes somebody find the file again; a device whose kind is sent on an
/// edit, losing the rename with it in a 400; and an account being shown a board
/// it has no business reading.
void registerIntegrationsFlows() {
  group('integrations', () {
    testWidgets('the board says every link state in a word as well as a tint',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.superAdmin,
        overrides: installIntegrationsFixtures,
      );
      final devices = IntegrationsRobot(harness);

      await devices.openHub();
      await devices.assertOnHub();

      // Neither list route declares `page` or `limit`, and the API runs
      // `forbidNonWhitelisted` — so an unfiltered load asks for the collection
      // and nothing else. The fixture refuses anything more, and this says out
      // loud what it is refusing.
      final firstLoad =
          harness.api.callsTo('GET', '/api/integrations/machines').first;
      expect(
        firstLoad.query,
        isEmpty,
        reason: 'a paged request to this route is a 400 for the whole call',
      );

      devices.seeDevice('mi-1');
      devices.seeDevice('mi-2');
      devices.seeDevice('mi-3');
      devices.seeDevice('mi-4');

      // The word, which survives a black-and-white printout and a reader who
      // cannot resolve a tint.
      expect(devices.deviceStateWord('mi-1'), 'Connected');
      expect(devices.deviceStateWord('mi-2'), 'Not connected');
      expect(devices.deviceStateWord('mi-3'), 'Reporting a fault');
      // Switched off on purpose, whatever its last handshake said. "Not
      // connected" about a machine somebody took out of service is an alarm
      // about a decision.
      expect(devices.deviceStateWord('mi-4'), 'Switched off');

      // And the tint. Amber for an analyser that has stopped talking — never
      // red, which in this app means a deteriorating patient.
      expect(devices.deviceStateColour('mi-2'), AppColors.warning);
      expect(devices.deviceStateColour('mi-1'), AppColors.acuityStable);
      devices.seeNoRedOnTheBoard();

      // Anything wrong first. The route sorts by registration date, which
      // buries the machine that stopped talking this morning.
      devices.seeDeviceAbove('mi-3', 'mi-2');
      devices.seeDeviceAbove('mi-2', 'mi-1');

      await devices.filterDevices(MachineLink.disconnected);
      final filtered = harness.api.callsTo('GET', '/api/integrations/machines');
      expect(filtered.last.query['status'], MachineLink.disconnected);
      // Both of the site's silent analysers, and neither of the three that are
      // in some other state.
      expect(devices.deviceCount, 2);
      devices.seeDevice('mi-2');
      devices.seeDevice('mi-5');
      devices.seeNoDevice('mi-1');
      devices.seeNoDevice('mi-3');
    });

    testWidgets('an unmatched result says so, and a matched one names who for',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.superAdmin,
        overrides: installIntegrationsFixtures,
      );
      final devices = IntegrationsRobot(harness);

      await devices.openHub();
      await devices.showQueue();

      devices.seeQueueRow('rq-1');
      devices.seeQueueRow('rq-2');

      // What came in, in the analyser's own words.
      expect(devices.queueRowTitle('rq-1'), contains('White cell count'));

      // Who it is for. The queue matches a **patient**, not an order — the
      // analyser identifies a sample by whatever the bench typed onto the tube.
      expect(devices.queueRowSubtitle('rq-1'), contains('Tom Whitfield'));

      // And the one nobody could be found for says so in a word. A blank here
      // reads as a rendering fault rather than as an unmatched sample, and a
      // result silently dropped is a test the ward believes was run.
      expect(devices.queueRowSubtitle('rq-2'), contains('Unmatched'));

      await devices.filterQueue(ResultsQueueStatus.failed);
      expect(
        harness.api
            .callsTo('GET', '/api/integrations/results-queue')
            .last
            .query['status'],
        ResultsQueueStatus.failed,
      );
      expect(devices.queueRowCount, 1);
      devices.seeQueueRow('rq-2');
    });

    testWidgets('an import is posted as multipart under the field name "file"',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.superAdmin,
        overrides: installIntegrationsFixtures,
      );
      final devices = IntegrationsRobot(harness);

      await devices.openHub();
      await devices.showQueue();
      final before = devices.queueRowCount;

      await devices.showUpload();
      await devices.chooseFile();
      devices.seeChosenFile(named: 'analyser-results.csv');

      // Attributed to the machine it came off, so the queue still says where
      // every row arrived from.
      await devices.chooseSendingDevice('Mindray BC-5150');
      await devices.sendFile();

      final sent =
          harness.api.requireCall('POST', '/api/integrations/results/upload');
      expect(
        sent.formFiles.keys,
        contains('file'),
        reason: "the route's FileInterceptor reads 'file' and nothing else; a "
            'part sent under any other name arrives as no file at all and the '
            'handler files an empty import',
      );
      expect(sent.formFiles['file'], 'analyser-results.csv');
      expect(sent.formFields['machineIntegrationId'], 'mi-5');

      devices.seeUploadSummary();
      // The server has it, so the picker goes back to offering a fresh one.
      devices.seeNoChosenFile();

      // And it really landed. A fixture that answered a summary without
      // appending the rows would pass a screen that sent nothing at all.
      await devices.showQueue();
      expect(devices.queueRowCount, before + 2);

      await devices.letToastsExpire();
    });

    testWidgets('a refused import keeps the file, so the retry is one tap',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.superAdmin,
        overrides: (FakeApi api) {
          installIntegrationsFixtures(api);
          // Once. The second attempt reaches the real fixture, which is the
          // whole point: a retry that starts by asking for the file again is a
          // retry nobody makes on a ward.
          api.failOnce(
            'POST',
            '/api/integrations/results/upload',
            message: 'The import service is not answering.',
          );
        },
      );
      final devices = IntegrationsRobot(harness);

      await devices.openHub();
      await devices.showUpload();
      await devices.chooseFile();
      await devices.sendFile();

      devices.seeUploadError(containing: 'not answering');
      devices.seeChosenFile(named: 'analyser-results.csv');

      await devices.sendFile();

      devices.seeNoUploadError();
      devices.seeUploadSummary();
      devices.seeNoChosenFile();
      expect(
        harness.api.callCount('POST', '/api/integrations/results/upload'),
        2,
      );

      await devices.letToastsExpire();
    });

    testWidgets('a device is registered, and removed with a confirm that says '
        'what stops working', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.superAdmin,
        overrides: installIntegrationsFixtures,
      );
      final devices = IntegrationsRobot(harness);

      await devices.openHub();
      devices.seeAddDeviceAction();
      await devices.tapAddDevice();
      await devices.assertOnMachineForm();

      // A device that does not exist yet is offered both enums; only one that
      // already exists is told it cannot change them.
      devices.seeNoFixedLinkFacts();

      // Saving with nothing filled in must not go anywhere: `machineName`,
      // `machineType` and `connectionType` are all required by the create DTO,
      // and a null in any of them is a 400 for the whole request.
      await devices.saveDevice();
      harness.api.requireNoCall('POST', '/api/integrations/machines');
      devices.seeFieldErrorSummary();

      await devices.enterDeviceName('Mindray BC-6200');
      await devices.chooseKind('Lab analyser');
      await devices.chooseLink('HL7');

      // HL7 has somewhere to connect to; a serial cable does not, and an empty
      // host on one of those reads as a setting somebody forgot.
      devices.seeAddressFields();
      await devices.enterHost('192.168.1.52');
      await devices.enterPort('5200');
      await devices.saveDevice();

      final registered =
          harness.api.requireCall('POST', '/api/integrations/machines');
      expect(registered.jsonBody['machineName'], 'Mindray BC-6200');
      expect(registered.jsonBody['machineType'], MachineType.labAnalyzer);
      expect(registered.jsonBody['connectionType'], MachineConnection.hl7);
      expect(
        registered.jsonBody['connectionDetails'],
        {'ip_address': '192.168.1.52', 'port': 5200},
      );

      await devices.assertOnHub();
      devices.seeDevice('mi-new-1');
      // The toast the save raised sits over the bottom of the next screen, and
      // the control this flow reaches for next is a bar at the bottom of it.
      await devices.letToastsExpire();

      // ── And removing it ─────────────────────────────────────────────────
      await devices.openDevice('mi-new-1');
      devices.seeFixedLinkFacts();
      devices.seeDeleteAction();

      await devices.tapRemoveDevice();
      // The route runs a **hard** delete and the queued results cascade with
      // it, so the confirm names that rather than asking whether somebody is
      // sure.
      devices.seeConfirmSays('removed with it');
      await devices.confirmRemoveDevice();

      harness.api.requireCall('DELETE', '/api/integrations/machines/:id');
      await devices.assertOnHub();
      devices.seeNoDevice('mi-new-1');

      await devices.letToastsExpire();
    });

    testWidgets('an edit never sends the two fields the update DTO forbids',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.superAdmin,
        overrides: installIntegrationsFixtures,
      );
      final devices = IntegrationsRobot(harness);

      await devices.openHub();
      await devices.openDevice('mi-1');
      devices.seeFixedLinkFacts();

      await devices.enterDeviceName('Sysmex XN-1000 (bench 2)');
      await devices.saveDevice();

      final saved =
          harness.api.requireCall('PATCH', '/api/integrations/machines/:id');
      expect(saved.jsonBody['machineName'], 'Sysmex XN-1000 (bench 2)');
      // `UpdateMachineDto` declares neither, and `forbidNonWhitelisted` refuses
      // the whole request over either — taking the rename down with it.
      expect(saved.jsonBody.containsKey('machineType'), isFalse);
      expect(saved.jsonBody.containsKey('connectionType'), isFalse);
      // Nor `connectionStatus`. It is what the machine last said about itself;
      // a person typing it in is a board reporting a link nobody has.
      expect(saved.jsonBody.containsKey('connectionStatus'), isFalse);
      // The rest of the stored connection block survives a rename. A site's
      // integrator may have put a protocol version or a facility code in it,
      // and replacing the map would drop them silently.
      expect(
        saved.jsonBody['connectionDetails'],
        {'ip_address': '192.168.1.50', 'port': 5000},
      );

      await devices.assertOnHub();
      await devices.letToastsExpire();
    });

    testWidgets('an import refused after the gate says so, and keeps the file',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.superAdmin,
        overrides: (FakeApi api) {
          installIntegrationsFixtures(api);
          // The access map said yes and the server says no — which is what
          // happens when a role is changed under a running session.
          api.forbid('POST', '/api/integrations/results/upload');
        },
      );
      final devices = IntegrationsRobot(harness);

      await devices.openHub();
      await devices.showUpload();
      await devices.chooseFile();
      await devices.sendFile();

      devices.seeUploadError(containing: 'permission');
      // Still theirs. A refusal they can do nothing about must not also cost
      // them the file they chose.
      devices.seeChosenFile(named: 'analyser-results.csv');
    });

    testWidgets('a lab technician is not shown the instrument link',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.labTechnician,
        overrides: installIntegrationsFixtures,
      );
      final devices = IntegrationsRobot(harness);

      // The shell never offers her a Devices tab; this is the deep link, the
      // stale shortcut, or the role an administrator changed under a running
      // session.
      await devices.openHub();
      await devices.assertNoAccess();
      devices.seeNoAddDeviceAction();
    });
  });
}
