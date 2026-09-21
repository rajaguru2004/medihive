import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/modules/patient_hub/controllers/patient_hub_controller.dart';

import '../../fixtures/modules/case_intake_fixtures.dart';
import '../../fixtures/modules/patients_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/case_intake_robot.dart';
import '../../robots/patients_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerCaseIntakeFlows();
}

/// The doctor's side of the patient's intake.
///
/// `case_review_flow_test.dart` is the patient writing and sending a case.
/// This is the other half of the same document, and every assertion here is
/// about a difference between the two rather than about the screen working:
///
///  * the clinician sees **which rules fired**, by their own titles, where
///    the patient is shown a count — §43 keeps a rule set's titles off a
///    patient's screen because they name syndromes;
///  * the clinician sees what was **not asked**, because silence is not a
///    negative finding for them either (§36);
///  * and the clinician cannot change any of it, because an intake a
///    clinician can rewrite stops being evidence of what the patient said.
void registerCaseIntakeFlows() {
  group('reading a patient intake', () {
    Future<(PatientHubRobot, CaseIntakeRobot)> openChart(
      WidgetTester tester, {
      bool withIntake = true,
    }) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        // A doctor, not a super admin: the point is that the grant a real
        // clinician holds — `case-taking: read`, and nothing else — is enough
        // to open this and not enough to change it.
        role: WorldRole.doctor,
        overrides: (api) {
          installPatientsFixtures(api);
          installCaseIntakeFixtures(api, withIntake: withIntake);
        },
      );
      return (PatientHubRobot(harness), CaseIntakeRobot(harness));
    }

    testWidgets('a doctor opens the intake from the chart', (tester) async {
      final (hub, intake) = await openChart(tester);

      await hub.open('p-1');
      await hub.assertOnHub();
      await hub.openTab(PatientHubTab.intake);
      await hub.seeTabLoaded(PatientHubTab.intake);

      await intake.openFromChart(kIntakeId);
      await intake.assertOnIntake();

      // The line that changes how everything under it is read.
      await intake.seeItIsUnverified();
    });

    testWidgets('the clinician is shown the rules the patient was not',
        (tester) async {
      final (hub, intake) = await openChart(tester);

      await hub.open('p-1');
      await hub.openTab(PatientHubTab.intake);
      await intake.openFromChart(kIntakeId);

      // The title, and the two sentences a clinician acts on. All three come
      // from keys the engine chose — `ruleId`, `clinicianSummary`,
      // `recommendedAction` — and reading them as `id`/`rationale`/`action`
      // parsed without error and drew a card with nothing on it but a title.
      await intake.seeRedFlag(
        kIntakeRedFlagId,
        titled: kIntakeRedFlagTitle,
        saying: kIntakeRedFlagSummary,
        advising: kIntakeRedFlagAction,
      );

      // A second rule at once. Two flags with an empty id would be two
      // siblings under the same key, which is a duplicate-key exception in
      // debug and ambiguous element matching in release.
      await intake.seeRedFlag(
        'breathlessness_at_rest',
        titled: 'Breathlessness at rest',
      );

      // And the reassurance written for the patient stays on the patient's
      // screen.
      intake.seeNoPatientWording('Tell the desk if this gets worse');
    });

    testWidgets('a denial reads as a finding and silence reads as silence',
        (tester) async {
      final (hub, intake) = await openChart(tester);

      await hub.open('p-1');
      await hub.openTab(PatientHubTab.intake);
      await intake.openFromChart(kIntakeId);

      // "Denies fever" is something a clinician writes down; a blank is not.
      await intake.seeItem('hpi.associated.fever', saying: 'None reported');
      // §36: printed, never omitted.
      await intake.seeNotAsked(naming: kIntakeUnansweredLabel);
    });

    testWidgets('there is nothing on the screen a clinician could change',
        (tester) async {
      final (hub, intake) = await openChart(tester);

      await hub.open('p-1');
      await hub.openTab(PatientHubTab.intake);
      await intake.openFromChart(kIntakeId);

      await intake.seeNothingIsEditable();
    });

    testWidgets('a chart with no intake says so rather than looking broken',
        (tester) async {
      final (hub, _) = await openChart(tester, withIntake: false);

      await hub.open('p-1');
      await hub.openTab(PatientHubTab.intake);

      // "Nothing sent in yet", and not "no intake": the patient may be filling
      // one in right now, and this list only ever holds the ones they sent.
      await hub.seeTabEmpty(PatientHubTab.intake);
    });
  });
}
