import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/i18n/patient_text.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/data/services/audio_source.dart';
import 'package:medihive/app/data/services/media_access.dart';
import 'package:medihive/app/modules/case_taking/case_taking_cache.dart';
import 'package:medihive/app/modules/patient_portal/patient_portal_routes.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The interview.
///
/// Most of what this robot knows is about *distinguishing* things a looser
/// assertion would run together:
///
///  * the four answers to a yes/no question are keyed by their token, so a
///    flow can prove that "I don't know" went out as `not_sure` and not as
///    `no` — which is the one rearrangement on this screen that changes what
///    lands on a patient's chart;
///  * [seeNoDiagnosis] asserts on what the red notice does *not* say, because
///    the requirement is an absence and an absence has to be checked for;
///  * [seeQuestion] reads the pinned live question rather than anything in the
///    conversation above it, so a screen that left the last question on screen
///    while asking a new one cannot pass.
final class CaseTakingRobot extends Robot {
  CaseTakingRobot(super.harness);

  @override
  String? get route => PatientPortalRoutes.caseTaking;

  @override
  Key get anchor => CaseTakingKeys.screen;

  // ── The microphone, as a seam ─────────────────────────────────────────────
  //
  // All three of these register **before** the route is opened, because the
  // binding only reaches for a recorder when there is not one already — which
  // is the whole point of the guard it puts around `RecordAudioSource`.

  /// A microphone that works and hands back a real, playable WAV.
  void useWorkingMicrophone() => _useAudio(StubAudioSource());

  /// A microphone the patient declined.
  ///
  /// A refusal throws rather than returning null — `media_access.dart` is
  /// explicit about why, and this reproduces it rather than approximating it
  /// with a null the screen would read as "changed their mind".
  void useRefusedMicrophone({bool permanently = false}) =>
      _useAudio(_RefusingAudioSource(permanently: permanently));

  void _useAudio(AudioSource source) {
    if (Get.isRegistered<AudioSource>()) Get.delete<AudioSource>(force: true);
    Get.put<AudioSource>(source, permanent: true);
    addTearDown(() => Get.delete<AudioSource>(force: true));
  }

  /// Opens the interview directly, the way the consent screen does.
  ///
  /// Never awaited: `Get.toNamed` completes when the route is *popped*, so a
  /// test that awaited it would wait for the patient to leave.
  Future<void> open({bool consented = true, String language = 'en'}) async {
    unawaited(
      Get.toNamed<void>(
        PatientPortalRoutes.caseTaking,
        arguments: {'language': language, 'consentGiven': consented},
      ),
    );
    await tester.pumpUntilFound(find.byKey(CaseTakingKeys.screen));
    await settle();
  }

  // ── The question ──────────────────────────────────────────────────────────

  /// The question on the table says this.
  ///
  /// Scoped to the pinned live question, not to the screen: the same words
  /// appear again in the conversation above once the question has been
  /// answered, and a bare text search would call that "still being asked".
  void seeQuestion(String containing) {
    expect(
      find.descendant(
        of: find.byKey(CaseTakingKeys.question),
        matching: find.textContaining(containing),
      ),
      findsOneWidget,
      reason: 'the question on screen is not "$containing"',
    );
  }

  Future<void> waitForQuestion(String containing) async {
    await tester.pumpUntilFound(
      find.descendant(
        of: find.byKey(CaseTakingKeys.question),
        matching: find.textContaining(containing),
      ),
    );
  }

  /// "Question 3 of 8", from the server's own count.
  void seeProgress(int step, int total) {
    expect(
      find.descendant(
        of: find.byKey(CaseTakingKeys.progress),
        matching: find.textContaining('Question $step of $total'),
      ),
      findsOneWidget,
      reason: 'the rail does not read "Question $step of $total"',
    );
  }

  // ── All three ways to answer, at once ─────────────────────────────────────

  /// Every question is answerable by tap, by keyboard and out loud.
  ///
  /// All three asserted together rather than one per flow, because the
  /// requirement is that none of them is a second choice — and a mode switch
  /// that hid two of them would pass three separate assertions one at a time.
  Future<void> seeAllThreeWaysToAnswer() async {
    await tester.scrollToKey(CaseTakingKeys.answers);
    expect(find.byKey(CaseTakingKeys.answers), findsOneWidget);
    expect(
      find.byKey(CaseTakingKeys.typed),
      findsOneWidget,
      reason: 'there is no way to type an answer to this question',
    );
    expect(
      find.byKey(CaseTakingKeys.mic),
      findsOneWidget,
      reason: 'there is no way to answer this question out loud',
    );
    expect(
      find.byKey(CaseTakingKeys.skip),
      findsWidgets,
      reason: 'there is no way past this question without answering it',
    );
  }

  /// The four answers to a yes/no question, as four separate tiles.
  ///
  /// Keyed by the token each one sends, so this asserts what the patient's tap
  /// will *become* rather than which widget drew it. "I don't know" and "No"
  /// are different keys because they are different clinical facts: a family
  /// history answered *no* by somebody who was adopted is a family history this
  /// app invented.
  void seeFourAnswers() {
    for (final token in const ['yes', 'no', 'not_sure']) {
      expect(
        find.byKey(CaseTakingKeys.answer(token)),
        findsOneWidget,
        reason: 'the yes/no row is missing its "$token" tile',
      );
    }
    expect(
      find.byKey(CaseTakingKeys.skip),
      findsOneWidget,
      reason: 'the yes/no row offers no way past the question',
    );
  }

  Future<void> tapAnswer(String token) async {
    await tester.scrollToKey(CaseTakingKeys.answer(token));
    await tester.tapKeyWithoutKeyboard(CaseTakingKeys.answer(token));
    await settle();
  }

  Future<void> skipQuestion() async {
    await tester.scrollToKey(CaseTakingKeys.skip);
    await tester.tapKeyWithoutKeyboard(CaseTakingKeys.skip);
    await settle();
  }

  Future<void> typeAnswer(String text) async {
    await tester.scrollToKey(CaseTakingKeys.typed);
    await tester.enterTextByKey(CaseTakingKeys.typed, text);
    await tester.tapKeyWithoutKeyboard(CaseTakingKeys.send);
    await settle();
  }

  /// What the patient said is in the conversation.
  void seeAnswerInTranscript(String text) {
    expect(
      find.descendant(
        of: find.byKey(CaseTakingKeys.transcript),
        matching: find.textContaining(text),
      ),
      findsWidgets,
      reason: 'the conversation does not show "$text"',
    );
  }

  void seeNoAnswerInTranscript(String text) {
    expect(
      find.descendant(
        of: find.byKey(CaseTakingKeys.transcript),
        matching: find.textContaining(text),
      ),
      findsNothing,
      reason: 'the conversation shows "$text", which was never said',
    );
  }

  // ── Out loud ──────────────────────────────────────────────────────────────

  /// Presses the microphone once.
  ///
  /// Separate from [speak] because a refusal ends the interaction on the first
  /// press: the control is gone by the time a second tap would land, and a
  /// robot that always tapped twice would fail on the case it was written for.
  Future<void> tapMicrophone() async {
    await tester.scrollToKey(CaseTakingKeys.mic);
    await tester.tapKeyWithoutKeyboard(CaseTakingKeys.mic);
    await settle();
  }

  /// Records an answer and stops, leaving the draft on screen.
  Future<void> speak() async {
    await tapMicrophone();
    await tapMicrophone();
  }

  /// The words are shown back before anything is filed.
  Future<void> seeTranscriptDraft(String containing) async {
    await tester.pumpUntilFound(find.byKey(CaseTakingKeys.draft));
    expect(
      find.descendant(
        of: find.byKey(CaseTakingKeys.draft),
        matching: find.textContaining(containing),
      ),
      findsOneWidget,
    );
  }

  /// Files what the app heard.
  ///
  /// Found by its words rather than by a key: the button belongs to
  /// `TranscriptDraft` in the shared kit, which no module may key for its own
  /// test. That is exactly the case the "no `find.*` in a flow" rule leaves for
  /// a robot.
  Future<void> acceptTranscript() async {
    final accept = find.text(PatientText.thatIsRight);
    await tester.scrollToFinder(accept);
    await tester.tap(accept);
    await tester.pump();
    await settle();
  }

  /// The microphone is gone and the screen says why.
  Future<void> seeVoiceWithdrawn() async {
    await tester.pumpUntilFound(find.byKey(CaseTakingKeys.voiceUnavailable));
    expect(
      find.byKey(CaseTakingKeys.mic),
      findsNothing,
      reason: 'the microphone is still on screen after it proved unusable',
    );
  }

  // ── Safety ────────────────────────────────────────────────────────────────

  Future<void> seeRedFlag() async {
    await tester.pumpUntilFound(find.byKey(CaseTakingKeys.redFlag));
  }

  void seeNoRedFlag() => expect(find.byKey(CaseTakingKeys.redFlag), findsNothing);

  /// The notice says what to do and never what might be wrong.
  ///
  /// The list is the diagnostic vocabulary a well-meaning "helpful" screen
  /// would reach for. Any of them on this surface is either a diagnosis nobody
  /// qualified made, or — when it is wrong — the thing that teaches the next
  /// patient to ignore the one red notice in the app.
  void seeNoDiagnosis() {
    for (final word in const [
      'heart attack',
      'myocardial',
      'angina',
      'infarction',
      'stroke',
      'embolism',
      'sepsis',
      'cardiac',
      'diagnos',
      'likely',
      'probably',
      'suspect',
    ]) {
      expect(
        find.textContaining(word, findRichText: true),
        findsNothing,
        reason: 'the interview said "$word" to a patient',
      );
    }
  }

  /// It tells them where to go, which is the only thing that resolves this.
  void seeRedFlagSaysWhatToDo() {
    expect(
      find.descendant(
        of: find.byKey(CaseTakingKeys.redFlag),
        matching: find.textContaining('nurse'),
      ),
      findsWidgets,
    );
  }

  // ── Understanding, behind the next question ───────────────────────────────

  /// The previous answer is marked as still being read.
  void seeStillReading() {
    expect(
      find.byKey(CaseTakingKeys.stillReading),
      findsOneWidget,
      reason: 'a long answer went to the model with nothing on screen to say '
          'it had arrived',
    );
  }

  /// And it is a mark, not a blocker.
  ///
  /// The assertion that matters: nothing on this screen is a spinner. A
  /// `CircularProgressIndicator` would also schedule frames forever and ignore
  /// Reduce Motion, which is what hangs this suite with no message.
  void seeNothingSpinning() {
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }

  // ── The end ───────────────────────────────────────────────────────────────

  Future<void> seeFinished() async {
    await tester.pumpUntilFound(find.byKey(CaseTakingKeys.finished));
  }

  // ── Conditions a ward device is actually used in ──────────────────────────

  /// Re-lays the screen out at the largest text size a device is left at.
  ///
  /// `PRODUCT.md` puts the clamp at 1.3, and a layout that overflows at it
  /// reports a `RenderFlex` error that fails the test on its own — which is
  /// the assertion. The scale is put back at the end of the test, so a flow
  /// that raises one does not have to remember to.
  Future<void> useLargestText({double scale = 1.3}) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpUntilViewportStable();
    await settle();
  }

  /// Nothing on this screen is painted with an unreadable contrast.
  ///
  /// Checked through the two derived roles rather than by sampling pixels:
  /// `brandInkColor` and `semanticInk` are the only two functions in the app
  /// that decide what a colour becomes when it is used as a word, and both are
  /// pinned by their own unit tests. What this asserts is that the screen is
  /// still *built* — a dark repaint that threw would leave nothing to read at
  /// all.
  void seeStillReadable() {
    expect(find.byKey(CaseTakingKeys.screen), findsOneWidget);
    expect(find.byKey(CaseTakingKeys.answers), findsWidgets);
  }

  // ── Where it is picked up from ────────────────────────────────────────────

  /// Nothing has been said yet.
  ///
  /// The other half of a resume assertion: a rail reading "Question 4 of 8"
  /// above an empty conversation can only have come from the server, because
  /// there is nothing on the phone to have counted.
  void seeNothingSaidYet() {
    expect(
      find.descendant(
        of: find.byKey(CaseTakingKeys.transcript),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  }

  /// The phone has written down where the interview stands.
  ///
  /// The write-behind `PRODUCT.md` asks for. Read through the same class the
  /// app writes with, so a change to the storage key breaks this rather than
  /// silently leaving a patient with nothing to come back to.
  Future<void> seeSavedForResume(String sessionId) async {
    final snapshot = await const CaseTakingCache().read();
    expect(
      snapshot?.sessionId,
      sessionId,
      reason: 'nothing was saved for a patient whose wifi is about to drop',
    );
    expect(
      snapshot!.turns,
      isNotEmpty,
      reason: 'the saved position holds no conversation to come back to',
    );
  }
}

/// A microphone the patient said no to.
///
/// Throws a [MediaRefusal] carrying finished copy, which is the contract
/// `media_access.dart` sets: a refusal is never a null, because a null is what
/// "changed their mind" means and the two need different screens.
class _RefusingAudioSource implements AudioSource {
  _RefusingAudioSource({this.permanently = false});

  /// True where the operating system will not show the prompt again, which is
  /// the one case where "Open Settings" is the only way forward.
  final bool permanently;

  @override
  Future<void> start() => throw MediaRefusal(
        permanently
            ? PatientText.microphoneBlocked
            : PatientText.microphoneDenied,
        canOpenSettings: permanently,
      );

  @override
  Future<RecordedAudio?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  bool get isRecording => false;

  @override
  Stream<double> get level => const Stream<double>.empty();

  @override
  Future<void> dispose() async {}
}
