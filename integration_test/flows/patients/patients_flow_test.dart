import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/modules/patient_hub/controllers/patient_hub_controller.dart';

import '../../fixtures/modules/patients_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/patients_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerPatientsFlows();
}

/// The register and the hub.
///
/// Every flow here installs [installPatientsFixtures] as an override as well
/// as through the world, so the patient-aware `/api/appointments` and
/// `/api/consultations` handlers are the ones answering whichever order
/// `world.dart` ends up installing things in. Later registrations win.
void registerPatientsFlows() {
  group('the patient register', () {
    testWidgets('sends the search term to the server rather than filtering '
        'the page it already has', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installPatientsFixtures,
      );
      final patients = PatientsRobot(harness);

      await patients.open();
      await patients.assertOnRegister();

      await patients.search('whit');

      // The point of the assertion: the term left the device. A register that
      // filtered the rows it already held would find Tom Whitfield on page one
      // and nobody on page four, and the bug would only show up on a hospital
      // with more than one page of patients.
      final searched = harness.api.callsTo(
        'GET',
        '/api/patients',
        where: (request) => request.query['search'] == 'whit',
      );
      expect(
        searched,
        isNotEmpty,
        reason: 'the search term must be sent as ?search=, because the server '
            'matches MRN and phone as well as the name',
      );

      expect(
        patients.rowIds(),
        ['p-2'],
        reason: 'the server answered with one match and the list shows it',
      );
    });

    testWidgets('asks the server for page two as the list runs out',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installPatientsFixtures,
      );
      final patients = PatientsRobot(harness);

      await patients.open();
      await patients.assertOnRegister();

      await patients.scrollToEnd();

      expect(
        harness.api.callsTo(
          'GET',
          '/api/patients',
          where: (request) => request.query['page'] == '2',
        ),
        isNotEmpty,
        reason: 'the register must page rather than stop at whatever the '
            'first response happened to hold',
      );

      // And the second page is actually on screen. A request that arrives and
      // is dropped looks identical to one that was never made.
      expect(
        patients.rowIds().length,
        greaterThan(6),
        reason: 'page two arrived and was appended',
      );
    });

    testWidgets('the status filter narrows the register through the server',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installPatientsFixtures,
      );
      final patients = PatientsRobot(harness);

      await patients.open();
      await patients.assertOnRegister();

      await patients.showStatus('inactive');

      expect(
        harness.api.callsTo(
          'GET',
          '/api/patients',
          where: (request) => request.query['status'] == 'inactive',
        ),
        isNotEmpty,
        reason: 'status is a server filter — the DTO accepts all/active/'
            'inactive and rejects anything else',
      );
      expect(patients.rowIds(), [kInactivePatientId]);
    });

    testWidgets('a receptionist can register somebody and a nurse cannot',
        (tester) async {
      final desk = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.receptionist,
        overrides: installPatientsFixtures,
      );
      final atTheDesk = PatientsRobot(desk);

      await atTheDesk.open();
      await atTheDesk.assertOnRegister();
      atTheDesk.seeRegisterAction();
    });

    testWidgets('a nurse reads the register without the Register control',
        (tester) async {
      final ward = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
        overrides: installPatientsFixtures,
      );
      final onTheWard = PatientsRobot(ward);

      await onTheWard.open();
      await onTheWard.assertOnRegister();

      // Absent, not disabled. A greyed-out button on a ward tablet is a
      // question the person holding it cannot answer.
      onTheWard.seeNoRegisterAction();
      expect(
        onTheWard.rowIds(),
        isNotEmpty,
        reason: 'a nurse may read the register; only writing is refused',
      );
    });
  });

  group('the patient hub', () {
    testWidgets('each tab fetches its own collection the first time it is '
        'looked at', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installPatientsFixtures,
      );
      final hub = PatientHubRobot(harness);

      await hub.open(kHubPatientId);
      await hub.assertOnHub();

      hub.seeBand();
      // The summary is the tab on open, so its two collections are the only
      // ones that have been asked for.
      hub.seeAllergyNotice();
      expect(
        harness.api.callCount('GET', '/api/billing/invoices'),
        0,
        reason: 'a tab nobody has opened must not have cost a request — that '
            'is what makes one slow endpoint cost one tab',
      );
      expect(
        harness.api.callCount('GET', '/api/pharmacy/prescriptions'),
        0,
      );

      await hub.openTab(PatientHubTab.billing);
      await hub.seeTabLoaded(PatientHubTab.billing);
      expect(harness.api.callCount('GET', '/api/billing/invoices'), 1);

      await hub.openTab(PatientHubTab.vitals);
      await hub.seeTabLoaded(PatientHubTab.vitals);
      // Said in words, because colour alone fails a colour-blind reader, a
      // printout and anybody standing more than a metre away.
      await hub.seeVitalsNotice();

      await hub.openTab(PatientHubTab.results);
      await hub.seeTabLoaded(PatientHubTab.results);
      await hub.seeCriticalNotice();

      // Going back to a tab that has already answered does not ask again.
      await hub.openTab(PatientHubTab.billing);
      expect(
        harness.api.callCount('GET', '/api/billing/invoices'),
        1,
        reason: 'a section that has already loaded is not refetched on every '
            'tap of its tab',
      );
    });

    testWidgets('a refused tab locks that tab and leaves the rest working',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: (api) {
          installPatientsFixtures(api);
          // One module refused, exactly as the server refuses it: 403 with
          // `errorCode: FORBIDDEN`, which `ApiEnvelope` turns into
          // `ApiForbiddenException` and the section turns into a locked panel.
          api.forbid('GET', '/api/billing/invoices');
        },
      );
      final hub = PatientHubRobot(harness);

      await hub.open(kHubPatientId);
      await hub.assertOnHub();

      await hub.openTab(PatientHubTab.billing);
      await hub.seeTabNoAccess(PatientHubTab.billing);

      // The band is still there, and so is everything else. A hub with one
      // load state would have blanked the whole record over one 403.
      hub.seeBand();
      hub.seeNoErrorBanner();

      await hub.openTab(PatientHubTab.orders);
      await hub.seeTabLoaded(PatientHubTab.orders);

      await hub.openTab(PatientHubTab.prescriptions);
      await hub.seeTabLoaded(PatientHubTab.prescriptions);

      await hub.openTab(PatientHubTab.summary);
      await hub.seeTabLoaded(PatientHubTab.summary);
    });

    testWidgets('opening a patient from the register lands on their record',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installPatientsFixtures,
      );
      final patients = PatientsRobot(harness);
      final hub = PatientHubRobot(harness);

      await patients.open();
      await patients.assertOnRegister();

      await patients.openPatient(kHubPatientId);
      await hub.assertOnHub();

      expect(
        harness.api.callsTo(
          'GET',
          '/api/patients/:id',
          where: (request) => request.pathParams['id'] == kHubPatientId,
        ),
        isNotEmpty,
        reason: 'the hub refetches the whole record — a row carries seven '
            'fields and the hub shows forty',
      );
    });
  });
}
