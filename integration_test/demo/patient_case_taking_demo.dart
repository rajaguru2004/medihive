import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../fixtures/modules/case_taking_fixtures.dart';
import '../fixtures/world_roles.dart';
import '../robots/case_taking_robot.dart';
import '../robots/patient_portal_robot.dart';
import '../support/app_harness.dart';
import '../support/pump.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the patient case-taking demo
///
/// One run, start to finish, paced so a room can follow it. Not a gate: the
/// suite in `integration_test/flows/` is what proves the feature works, and it
/// runs flat out. This exists to be *watched*.
///
/// ```sh
/// flutter test integration_test/demo/patient_case_taking_demo.dart \
///   -d emulator-5554 \
///   --dart-define=NEX_HIVE_WATCH=true \
///   --dart-define=NEX_HIVE_WATCH_PACE=1600 \
///   --timeout none
/// ```
///
/// `NEX_HIVE_WATCH` puts the binding into fully-live mode so the device paints
/// between pumps — without it the app is genuinely running and genuinely
/// invisible, because every screen exists for about sixteen milliseconds.
/// `NEX_HIVE_WATCH_PACE` is the pause after each action; 1600 reads comfortably,
/// 2200 if somebody is narrating over it.
///
/// **It runs against fixtures, not the live backend.** That is deliberate for a
/// demo: the story is identical every time, it cannot be derailed by a model
/// taking twenty seconds to extract a fact, and it works with no network. To
/// show the real stack instead, run the app itself against the tunnelled API —
/// this file is for when the walkthrough has to be reliable.
///
/// The order below is the argument the feature makes, in sequence:
///
///   1. a patient signs in and lands on their own screen, not the ward board
///   2. language, then consent — asked, not assumed
///   3. the interview, answered three different ways
///   4. a red flag, raised without ever naming a condition
///   5. "I don't know" filed as itself, never as a no
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a patient tells their story', (tester) async {
    final harness = await AppHarness.bootSignedIn(
      tester,
      role: WorldRole.patient,
      fonts: true,
      overrides: installCaseTakingFixtures,
    );

    final portal = PatientPortalRobot(harness);
    final interview = CaseTakingRobot(harness);

    // ── 1. Their own screen ──────────────────────────────────────────────────
    //
    // Which shell an account lands in is read from the server's access map, so
    // this is the same build a clinician signs into and a different screen.
    await portal.assertOnPortal();
    await portal.seeRecord();
    await portal.seeDocuments();

    // ── 2. Asked, not assumed ────────────────────────────────────────────────
    await portal.startCaseTaking();

    await portal.assertOnLanguage();
    await portal.chooseLanguage('en');
    await portal.continueFromLanguage();

    await portal.assertOnConsent();
    // What is collected, who reads it, that it is not a diagnosis, and that
    // they can stop. Then it asks.
    portal.seeConsentTold();
    portal.seeConsentAsksRatherThanAssumes();
    await portal.agreeToConsent();

    // ── 3. Three ways to answer, none of them privileged ─────────────────────
    interview.useWorkingMicrophone();
    await interview.waitForQuestion('bothering you');

    // Every question carries all three at once: no mode to switch, because a
    // mode switch makes two of them a second choice.
    await interview.seeAllThreeWaysToAnswer();

    // Typed.
    await interview.typeAnswer('Pain in the middle of my chest');
    await interview.waitForQuestion('How long');
    await interview.typeAnswer('Three days');

    // Tapped.
    await interview.waitForQuestion('start suddenly');
    await interview.tapAnswer('sudden');

    // Tapped, on a scale — where a "Yes" tile would be a control the engine
    // would reject, which is why the four-answer rule is about uncertainty
    // rather than literally four buttons everywhere.
    await interview.waitForQuestion('scale of nothing at all');
    await interview.tapAnswer('7');

    // ── 4. The red flag ──────────────────────────────────────────────────────
    //
    // Chest pain, sudden, severe, with breathlessness and sweating. The rule
    // that fires is data in `safety-rules.ts`, evaluated by code — the model is
    // never asked whether something is dangerous.
    await interview.waitForQuestion('short of breath');
    await interview.tapAnswer('yes');

    await interview.waitForQuestion('sweating');
    await interview.tapAnswer('yes');

    // Pinned above everything but the progress rail, and the only red on this
    // surface. It quotes the patient's own words and can render no other free
    // text — which is the structural half of "never a diagnosis". It does not
    // say heart attack, and it does not say this is nothing.
    await interview.seeRedFlag();

    // ── 5. "I don't know" is not a no ────────────────────────────────────────
    //
    // The most important twenty seconds of the demo. A chart that reads "no
    // known allergies" when nobody ever asked is not incomplete, it is wrong —
    // and wrong in the direction that gets somebody prescribed the drug that
    // kills them.
    await interview.waitForQuestion('any allergies');
    interview.seeFourAnswers();
    await interview.tapAnswer('not_sure');

    // It reads back as what it is, and the screen never says the sentence this
    // whole design exists to prevent.
    interview.seeAnswerInTranscript('Not sure');
    interview.seeNoText('No known allergies');

    // ── One more, to show the conversation ───────────────────────────────────
    //
    // The transcript keeps the newest exchange at the bottom, so what is on
    // screen above the question is what was just said rather than how the
    // conversation opened.
    await interview.waitForQuestion('close family');
    await interview.tapAnswer('yes');

    // Left on screen for the room to read.
    //
    // Voice is deliberately not driven here. It works — `seeAllThreeWaysToAnswer`
    // above proves the microphone is offered on every question, and the voice
    // flows in `integration_test/flows/case_taking/` cover recording,
    // transcription, the draft and a refused permission. But a demo is a
    // performance, and the microphone is the one control whose timing depends
    // on a platform channel. Showing it live is a job for the app running
    // against the real stack, not for a scripted walkthrough that must not
    // stall in front of a room.
    await tester.pumpSeconds(5);
  });
}
