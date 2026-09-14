import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/data/models/access_map.dart';

import '../../fixtures/modules/clinical_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/consultation_detail_robot.dart';
import '../../robots/consultation_form_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerConsultationFlows();
}

/// Writing up a consultation, and reading one back.
void registerConsultationFlows() {
  group('observations', () {
    testWidgets('a reading outside its range is flagged in words as it is '
        'typed', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final form = ConsultationFormRobot(harness);

      await form.open();
      await form.assertVisible();

      await form.enterVitals(temperature: '39.8', pulse: '128');
      // In words, and naming which readings. A coloured unit is invisible to
      // eight percent of men, to a printed record, and to anybody reading the
      // screen from across the room.
      form.seeVitalsWarning(containing: 'outside the normal adult range');
      form.seeVitalsWarning(containing: 'Temperature');
      form.seeVitalsWarning(containing: 'Pulse');
    });

    testWidgets('readings inside their ranges raise nothing', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final form = ConsultationFormRobot(harness);

      await form.open();
      await form.assertVisible();

      await form.enterVitals(
        temperature: '37.0',
        systolic: '120',
        diastolic: '78',
        pulse: '76',
      );
      form.seeNoVitalsWarning();
    });

    testWidgets('a vital nobody recorded is not hypothermia', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final form = ConsultationFormRobot(harness);

      await form.open();
      await form.assertVisible();

      // Zero, not blank. This backend stores an unobserved numeric vital as
      // `0` and a half-typed field parses the same way — so a screen guarding
      // only against null paints an empty record red, which is the one thing
      // red is not allowed to be.
      await form.enterVitals(
        temperature: '0',
        systolic: '0',
        diastolic: '0',
        pulse: '0',
        respiratoryRate: '0',
        oxygenSaturation: '0',
      );
      form.seeNoVitalsWarning();
    });

    testWidgets('the record that opens afterwards says the same thing',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = ConsultationDetailRobot(harness);

      // 39.8 °C, 168/96, pulse 128, 24 breaths, 91%. The form warns while
      // these are typed; the record has to warn about the same patient. The
      // app shipped a bug once where only one of the two did.
      await detail.open(ClinicalWorld.flaggedConsultation);
      await detail.assertVisible();
      detail.seeOpenOn(ClinicalWorld.flaggedConsultation);

      detail.seeVitals();
      detail.seeVitalsWarning(containing: 'outside the normal adult range');
      detail.seeVitalsWarning(containing: 'Temperature');
    });

    testWidgets('and says nothing about a record that is in range',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = ConsultationDetailRobot(harness);

      await detail.open(ClinicalWorld.normalConsultation);
      await detail.assertVisible();

      detail.seeVitals();
      detail.seeNoVitalsWarning();
    });

    testWidgets('and nothing about one nobody examined', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = ConsultationDetailRobot(harness);

      // Every numeric vital stored as `0`. An absence, not a reading — and a
      // zero temperature rendered as hypothermia is a red that is not a
      // deteriorating patient.
      await detail.open(ClinicalWorld.unrecordedConsultation);
      await detail.assertVisible();

      detail.seeNoVitalsWarning();
    });
  });

  group('writing one up', () {
    testWidgets('the script goes in the same request as the consultation',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final form = ConsultationFormRobot(harness);

      await form.open();
      await form.assertVisible();

      await form.choosePatient(ClinicalWorld.scheduledPatient);
      await form.chooseClinician(ClinicalWorld.doctorName);
      await form.enterComplaint('Productive cough and fever for three days');
      await form.enterDiagnosis('Community-acquired pneumonia');
      await form.addIcdCode('J18.9');
      form.seeIcdCode('J18.9');

      await form.prescribe(
        drug: ClinicalWorld.amoxicillinName,
        dosage: '500mg',
        frequency: 'Three times daily',
        duration: '7 days',
        quantity: '21',
      );

      await form.save();

      final post = harness.api.requireCall('POST', '/api/consultations');
      final body = post.jsonBody;

      // One request, not two. A script written in a second call can be
      // orphaned by a failure between them, and an orphaned script is a
      // patient who does not get their antibiotics.
      expect(body['prescriptionItems'], [
        {
          'drugId': ClinicalWorld.amoxicillinId,
          'drugName': ClinicalWorld.amoxicillinName,
          'genericName': 'Amoxicillin trihydrate',
          'dosage': '500mg',
          'frequency': 'Three times daily',
          'duration': '7 days',
          'quantity': 21,
        },
      ]);
      expect(body['patientId'], 'p-1');
      expect(body['doctorId'], ClinicalWorld.doctorId);
      expect(body['chiefComplaint'], 'Productive cough and fever for three days');
      expect(body['icd10Codes'], ['J18.9']);

      await form.letToastsExpire();
    });

    testWidgets('a save refused by a field on another tab goes to that tab',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final form = ConsultationFormRobot(harness);

      await form.open();
      await form.assertVisible();

      await form.choosePatient(ClinicalWorld.scheduledPatient);
      await form.chooseClinician(ClinicalWorld.doctorName);
      // The complaint is required and lives on Notes. Saving from Vitals must
      // take the reader to it: marking a field three tabs away is a form that
      // appears to do nothing.
      await form.openTab('vitals');
      await form.save();

      harness.api.requireNoCall('POST', '/api/consultations');
      expect(form.isOnTab('Notes'), isTrue);
      form.seeStillOnForm();
    });

    testWidgets('an account that can order neither tests nor imaging is not '
        'offered the card', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.doctor,
        // No seeded role writes consultations without also holding both
        // diagnostic modules, so the account this rule is about has to be
        // built.
        overrides: (api) => installAccessWithout(
          api,
          role: WorldRole.doctor,
          modules: const [Modules.laboratory, Modules.radiology],
        ),
      );
      final form = ConsultationFormRobot(harness);

      await form.open();
      await form.assertVisible();
      await form.openTab('plan');

      form.seeNoOrdersCard();
      // And no catalogue was fetched for a card that does not exist.
      harness.api.requireNoCall('GET', '/api/laboratory/tests');
      harness.api.requireNoCall('GET', '/api/radiology/exams');
    });

    testWidgets('a read-only account is not offered a save bar',
        (tester) async {
      // A nurse holds CONSULTATION_READ and nothing else on this module.
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
      );
      final form = ConsultationFormRobot(harness);

      await form.open();
      await form.assertVisible();

      form.seeNoSaveBar();
    });
  });

  group('one record', () {
    testWidgets('shows what the encounter produced', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = ConsultationDetailRobot(harness);

      await detail.open(ClinicalWorld.flaggedConsultation);
      await detail.assertVisible();

      await detail.seeLabOrders();
      await detail.seeImagingOrders();
    });

    testWidgets('carries the script it was written with', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = ConsultationDetailRobot(harness);

      await detail.open(ClinicalWorld.normalConsultation);
      await detail.assertVisible();

      await detail.seePrescription();
      detail.seeText(ClinicalWorld.amoxicillinName);
    });

    testWidgets('a read-only account sees no actions', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
      );
      final detail = ConsultationDetailRobot(harness);

      await detail.open(ClinicalWorld.normalConsultation);
      await detail.assertVisible();

      await detail.seeNoActionsAtAll();
    });
  });
}
