import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../fixtures/modules/case_taking_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/case_taking_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerCaseTakingFlows();
}

/// The interview: a patient telling somebody what is wrong.
///
/// None of these is the happy path, and that is deliberate. The happy path here
/// is one question and one tap, and a suite made of those would pass on a screen
/// that collapsed "I don't know" into "No", blocked on the model for twenty
/// seconds, lost a patient's place when their wifi dropped, and refused to run
/// at all without a microphone. Each of the cases below is one of those.
///
/// The turn route is `/api/case-taking/sessions/:sessionId/turns` throughout;
/// several flows read the request body back off the fake, because the assertion
/// that matters is frequently about **what was sent** rather than about what is
/// on screen. A screen can show the word "Not sure" while posting `no`.
void registerCaseTakingFlows() {
  const turnsRoute = '/api/case-taking/sessions/:sessionId/turns';

  group('the interview', () {
    testWidgets('every question can be answered by tap, keyboard or voice',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final interview = CaseTakingRobot(harness);

      interview.useWorkingMicrophone();
      await interview.open();

      await interview.assertVisible();
      interview.seeQuestion('bothering you the most');

      // All three at once. §10 says voice, text and touch are all available,
      // and the way to break that quietly is to make two of them a second
      // choice behind a mode switch.
      await interview.seeAllThreeWaysToAnswer();

      // And the position comes from the server's own count, which on a fresh
      // interview is the first of eight.
      interview.seeProgress(1, 8);
    });

    testWidgets('a spoken answer is shown back before anything is filed',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final interview = CaseTakingRobot(harness);

      interview.useWorkingMicrophone();
      await interview.open();
      await interview.assertVisible();

      await interview.speak();

      // The confirmation step is not politeness. A transcriber that mishears
      // "no allergies" as "no, allergies" has written the opposite of what was
      // said, and the only person in the building who can catch that is the
      // one who just spoke.
      await interview.seeTranscriptDraft('middle of my chest');
      await interview.acceptTranscript();

      final turn = harness.api.requireCall('POST', turnsRoute);
      expect(turn.jsonBody['modality'], 'voice');
      expect(
        turn.jsonBody['text'],
        kSpokenAnswer,
        reason: 'the transcript was tidied up on the way out; what the patient '
            'said is what gets filed',
      );
      // A real measurement from the recogniser, not a model's opinion of
      // itself. It travels so the server can tell a confident transcript from
      // a doubtful one.
      expect(turn.jsonBody['transcriptConfidence'], closeTo(0.84, 0.001));
    });

    testWidgets("\"I don't know\" is filed as unknown, never as a no",
        (tester) async {
      // Straight to the allergies question, which is the one where this
      // matters most: a chart that says "no known allergies" when nobody ever
      // asked is not an incomplete chart, it is a wrong one, and it is wrong in
      // the direction that gets somebody prescribed the drug that kills them.
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) => installCaseTakingFixtures(api, from: 6),
      );
      final interview = CaseTakingRobot(harness);

      await interview.open();
      await interview.assertVisible();
      interview.seeQuestion('allergies');

      // Four tiles for four different clinical facts, not two and two.
      interview.seeFourAnswers();
      await interview.tapAnswer('not_sure');

      final turn = harness.api.requireCall('POST', turnsRoute);
      expect(turn.jsonBody['fieldPath'], 'allergies.reported');
      expect(turn.jsonBody['modality'], 'choice');
      expect(
        turn.jsonBody['value'],
        'not_sure',
        reason: "\"I don't know\" went out as something else, which is the one "
            'path by which this app invents a denial',
      );

      // On screen it reads as what it is, and the screen never says the
      // sentence this whole design exists to prevent.
      interview.seeAnswerInTranscript('Not sure');
      interview.seeNoText('No known allergies');
      interview.seeNoText('No allergies');
    });

    testWidgets('a skipped question is a refusal, not a blank', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) => installCaseTakingFixtures(api, from: 6),
      );
      final interview = CaseTakingRobot(harness);

      await interview.open();
      await interview.assertVisible();
      await interview.skipQuestion();

      final turn = harness.api.requireCall('POST', turnsRoute);
      expect(turn.jsonBody['modality'], 'skip');
      expect(
        turn.jsonBody.containsKey('value'),
        isFalse,
        reason: 'a skip that carried a value would be an answer nobody gave',
      );
    });

    testWidgets('a long answer does not hold up the next question',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final interview = CaseTakingRobot(harness);

      await interview.open();
      await interview.assertVisible();

      // Two sentences: long enough that the server sends it to the model,
      // which on this hardware costs eight to twenty seconds.
      await interview.typeAnswer(
        'I have had a pain in my chest since Tuesday. It is worse when I walk '
        'up the stairs.',
      );

      // The next question is already here. This is the requirement: the
      // selector answers the turn, and the model runs behind it.
      await interview.waitForQuestion('How long have you had this');
      await interview.seeAllThreeWaysToAnswer();

      // The previous answer says quietly that it is still being read...
      interview.seeStillReading();
      // ...and there is nothing on this screen the patient has to wait for. A
      // spinner here would also schedule frames forever and ignore Reduce
      // Motion, which is what hangs this suite with no message.
      interview.seeNothingSpinning();
    });

    testWidgets('breathlessness and sweating raise the notice, with no '
        'diagnosis', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) => installCaseTakingFixtures(api, from: 4),
      );
      final interview = CaseTakingRobot(harness);

      await interview.open();
      await interview.assertVisible();

      interview.seeQuestion('short of breath');
      interview.seeNoRedFlag();
      await interview.tapAnswer('yes');

      await interview.waitForQuestion('sweating');
      await interview.tapAnswer('yes');

      await interview.seeRedFlag();

      // The two halves of §29, and the second is the one that needs asserting
      // because it is an absence: it says where to go, and it never says what
      // might be wrong. A screen that guessed "this may be a heart attack" has
      // made a diagnosis nobody qualified made; one that guessed wrong teaches
      // the next patient that the red notice means nothing.
      interview.seeRedFlagSaysWhatToDo();
      interview.seeNoDiagnosis();

      // And the interview carries on. The notice is a reason to go and find
      // somebody, not a dead end that loses the rest of the history.
      await interview.waitForQuestion('allergies');
      await interview.seeAllThreeWaysToAnswer();
    });

    testWidgets('it resumes where the server says it is', (tester) async {
      // What a patient comes back to after the app was killed: the session is
      // still open on the server, three questions in.
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) =>
            installCaseTakingFixtures(api, from: 3, resumed: true),
      );
      final interview = CaseTakingRobot(harness);

      await interview.open();
      await interview.assertVisible();

      // The severity question, not the first one — and the rail agrees.
      interview.seeQuestion('Zero to ten');

      // The assertion that matters: the phone is showing a position it could
      // not have computed. There is nothing in the conversation above to have
      // counted, so "Question 4 of 8" can only have come from the server.
      interview.seeNothingSaidYet();
      interview.seeProgress(4, 8);

      // And the phone writes down where it is, so the next dropped connection
      // has something to put back on screen.
      await interview.tapAnswer('7');
      await interview.seeSavedForResume(kCaseSessionId);
    });

    testWidgets('a microphone that will not work does not stop the interview',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) {
          // The transcriber is down. The server answers a written 400 rather
          // than a 500, because voice is never the only way to answer.
          api.failWith(
            'POST',
            '/api/case-taking/stt',
            400,
            message: 'Speech recognition is unavailable.',
          );
        },
      );
      final interview = CaseTakingRobot(harness);

      interview.useWorkingMicrophone();
      await interview.open();
      await interview.assertVisible();

      await interview.speak();

      // Gone, with a sentence in its place. Not a disabled button that fails
      // again on the next tap.
      await interview.seeVoiceWithdrawn();

      // And the interview finishes on the keyboard and the tiles.
      await interview.typeAnswer('Chest pain');
      await interview.waitForQuestion('How long have you had this');
      await interview.skipQuestion();
      await interview.waitForQuestion('start suddenly');
      await interview.tapAnswer('sudden');
      await interview.waitForQuestion('Zero to ten');
    });

    testWidgets('a refused microphone is a sentence, not a dead control',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final interview = CaseTakingRobot(harness);

      interview.useRefusedMicrophone();
      await interview.open();
      await interview.assertVisible();

      // One press, and the control is gone. A refusal is not a null and is not
      // a silence: `media_access.dart` throws a written sentence, and this is
      // where it lands.
      await interview.tapMicrophone();
      await interview.seeVoiceWithdrawn();

      // A patient who declined the microphone has not made a mistake and is
      // not told they have; they are told what they can do instead.
      interview.seeText('type your answer');
      await interview.typeAnswer('Chest pain');
      await interview.waitForQuestion('How long have you had this');
    });

    testWidgets('it survives the largest text size and the night shift',
        (tester) async {
      // The two conditions a ward device is actually used in, together: a
      // system text size somebody left at the top of its range, and dark mode
      // at three in the morning. An overflow at either reports a `RenderFlex`
      // error, which fails this test on its own — that is the assertion.
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        // The 0–10 severity scale: thirteen tiles plus a keyboard plus a
        // microphone, which is the tallest answer area the interview has.
        overrides: (api) => installCaseTakingFixtures(api, from: 3),
      );
      final interview = CaseTakingRobot(harness);

      await interview.open();
      await interview.assertVisible();

      await interview.useLargestText();
      await harness.useDarkTheme();

      interview.seeStillReadable();
      interview.seeQuestion('Zero to ten');

      // Still usable, not merely still rendered.
      await interview.tapAnswer('7');
      await interview.waitForQuestion('short of breath');
    });

    testWidgets('it says so when the interview will not open', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) => api.failWith(
          'POST',
          '/api/case-taking/sessions',
          500,
          message: 'The hospital did not answer.',
        ),
      );
      final interview = CaseTakingRobot(harness);

      await interview.open();
      await interview.assertVisible();

      // Inline and persistent, with the retry attached. Never a toast: a toast
      // disappears in three seconds and takes the retry with it, leaving a
      // patient looking at an empty screen with nothing to press.
      interview.seeErrorBanner();
    });

    testWidgets('a question on screen stays answerable while the hospital is '
        'being tried again', (tester) async {
      // The screen a dropped connection actually produces, photographed on a
      // ward: the hospital is unreachable, the phone puts back where the
      // interview had got to, and the patient presses the retry.
      //
      // Every flow above this one runs against a server that answers, so none
      // of them has ever been on the screen *during* a request — and that is
      // where this screen was unusable. `_Answers` was gated on `!rxLoading`,
      // and the retry sets `rxLoading` true for as long as the request takes:
      // on a network that is not there, that is the thirty second connect
      // timeout. The tiles, the keyboard and the microphone went away, the
      // error banner had been cleared by the very tap that hid them, and what
      // the patient was left holding was a question with nothing to answer it
      // with and nothing on screen saying why.
      const sessionRoute = '/api/case-taking/sessions';

      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) => api.failWith(
          'POST',
          sessionRoute,
          500,
          message: 'The hospital did not answer.',
        ),
      );
      final interview = CaseTakingRobot(harness);

      await interview.savePositionOnThePhone(
        sessionId: kCaseSessionId,
        fieldPath: kCaseScript.first.fieldPath,
        prompt: kCaseScript.first.prompt,
      );

      await interview.open();
      await interview.assertVisible();

      // The degraded screen the design promises, and it is a good one: the
      // question back off the phone, the reason it is not live, and the retry.
      await interview.waitForQuestion('bothering you the most');
      interview.seeProgress(1, 8);
      await interview.seeAllThreeWaysToAnswer();
      interview.seeErrorBanner();

      // Now the retry, against a hospital that is still not answering. Held
      // long enough that the in-flight window is a window and not a race.
      harness.api.delay('POST', sessionRoute, const Duration(seconds: 3));
      await interview.tapRetryWithoutWaiting();

      // The retry has taken its own banner off the screen — which is correct,
      // it is trying — so the controls are now the only thing standing between
      // the patient and a question they can do nothing with.
      interview.seeNoErrorBanner();
      interview.seeQuestion('bothering you the most');
      await interview.seeAllThreeWaysToAnswer();

      // And when it fails again it says so again, with the retry back.
      await interview.waitForErrorBanner();
    });

    testWidgets('an answer that is still travelling says so', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final interview = CaseTakingRobot(harness);

      await interview.open();
      await interview.assertVisible();

      // The other half of the same rule. `_submit` moves the question into the
      // conversation before the round trip, because the answer belongs under
      // the question it answered — so between the tap and the reply there is
      // nothing on the answer panel at all. That was justified on the turn
      // route answering in milliseconds, and it does when the hospital answers:
      // when it does not, the same gap is the connect timeout, and the screen
      // is a question bubble with a blank half-page under it.
      harness.api.delay(
        'POST',
        '/api/case-taking/sessions/:sessionId/turns',
        const Duration(seconds: 3),
      );
      await interview.tapAnswerWithoutWaiting('skip');

      await interview.seeAnswerOnItsWay();
      // Still a mark rather than a blocker — nothing here schedules frames
      // forever, which is what hangs this suite with no message.
      interview.seeNothingSpinning();

      // And the interview carries on when the answer lands.
      await interview.waitForQuestion('How long have you had this');
    });
  });
}
