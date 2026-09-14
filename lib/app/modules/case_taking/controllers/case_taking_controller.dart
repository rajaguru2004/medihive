import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../core/i18n/patient_text.dart';
import '../../../data/models/case_session.dart';
import '../../../data/models/drafts/case_taking_drafts.dart';
import '../../../data/repositories/case_taking_repository.dart';
import '../../../data/services/audio_source.dart';
import '../../../data/services/media_access.dart';
import '../../../data/services/session_lock_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../patient_portal/patient_entry.dart';
import '../../patient_portal/patient_portal_navigation.dart';
import '../case_taking_cache.dart';
import '../interview_turn.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the interview
///
/// ## The one decision everything here follows from
///
/// On the hardware this was measured on, speech recognition costs **1.1 to 1.45
/// seconds** and the language model costs **8 to 20**. So the model is never
/// between an answer and the next question. `POST /turns` answers from a
/// deterministic selector on the server and comes back in milliseconds; the
/// next question is rendered the moment it arrives, and anything the model has
/// to read runs behind it and lands as facts later.
///
/// What that leaves this controller to get right is the honest reporting of it.
/// An answer still being read gets a quiet mark under its own bubble and
/// nothing else: no spinner, no disabled controls, no screen that will not move
/// on. A patient who has to watch a wheel turn for twenty seconds, sixty times,
/// does not finish the interview — and an unfinished interview is the failure
/// mode this whole feature exists to avoid.
///
/// ## Three ways to answer, and none of them privileged
///
/// Speak, type, tap. Voice is never required and is never the only way past a
/// question: if the microphone is refused or the transcriber is down, the
/// control goes away with a sentence saying so and the interview finishes on
/// the keyboard and the tiles. The tiles themselves always carry "I don't know"
/// and "Skip" as separate answers — see `CaseQuestion.touchOptions`, where that
/// rule lives so a test can hold it still.
///
/// ## Where the truth is
///
/// The server. Progress, section completion and what to ask next are read from
/// it and never computed here, because the phone does not know which questions
/// apply to this patient. The `flutter_secure_storage` snapshot is a
/// write-behind for a dropped connection: it restores what was *on screen*, and
/// it restores nothing the server has not already been told.
/// ─────────────────────────────────────────────────────────────────────────────
class CaseTakingController extends GetxController with LoadStateMixin {
  CaseTakingController({
    CaseTakingRepository repository = const CaseTakingRepository(),
    CaseTakingCache cache = const CaseTakingCache(),
  })  : _repository = repository,
        _cache = cache;

  final CaseTakingRepository _repository;
  final CaseTakingCache _cache;

  /// The language and the consent the entry sequence collected. They travel in
  /// the route arguments rather than in a service, so a sign-out on a shared
  /// device cannot leave the next patient consented to something they never
  /// read.
  late final PatientEntry entry = PatientEntry.fromArguments(Get.arguments);

  // ── What is on screen ─────────────────────────────────────────────────────

  final Rxn<CaseSession> rxSession = Rxn<CaseSession>();

  /// The question on the table. Null while a turn is in flight, and null again
  /// when the interview has run out of questions.
  final Rxn<CaseQuestion> rxQuestion = Rxn<CaseQuestion>();

  /// The conversation so far. History only — the live question is [rxQuestion],
  /// so it can be pinned above the controls rather than scrolled away from the
  /// answers it is asking for.
  final RxList<InterviewTurn> rxTurns = <InterviewTurn>[].obs;

  /// **The server's figures.** Never derived from `rxTurns.length`.
  final Rx<CaseProgress> rxProgress = CaseProgress.empty.obs;

  final Rx<CaseInterviewStatus> rxStatus = CaseInterviewStatus.ready.obs;

  /// True while an answer is on its way. Drives the disabled state of the
  /// controls, and nothing else — it is measured in milliseconds.
  final RxBool rxSending = false.obs;

  /// An answer that did not reach the server. Inline and persistent, with the
  /// retry attached: a toast here would take the retry with it and leave the
  /// patient looking at a question they have already answered.
  final RxnString rxTurnError = RxnString();

  /// True when what is on screen came out of the phone's own snapshot rather
  /// than from the hospital. Said out loud, because a patient answering
  /// questions into a screen that is not recording them is the worst outcome
  /// available here.
  final RxBool rxFromSnapshot = false.obs;

  // ── Safety ────────────────────────────────────────────────────────────────

  /// What the patient said that raised a flag, in their own words.
  ///
  /// Their words and nothing else. `RedFlagNotice` can render no other free
  /// text, which is the structural half of "never a diagnosis"; this is the
  /// half that decides what gets quoted.
  final RxnString rxRedFlagQuote = RxnString();

  final RxBool rxRedFlagRaised = false.obs;

  /// Whether the notices band has anything to draw.
  ///
  /// The view needs this as well as the band itself: an empty band still holds
  /// the height cap its parent gave it, and on the first question that cap is
  /// space nobody can use while the question below it is squeezed into a
  /// scroll. One getter rather than the same three-way condition written twice,
  /// because the copy that drifts is the one that leaves a blank half-screen.
  bool get hasNotices =>
      rxRedFlagRaised.value || rxFromSnapshot.value || rxLoadError.value != null;

  /// How much of the column the question and its answers may take.
  ///
  /// Three cases, and each of the numbers was paid for:
  ///
  /// * **A notice is up.** All three bands are on screen, so the panel takes
  ///   the smaller share. `0.34 + 0.52` plus the rail is what fits; raising the
  ///   panel to `0.72` here overflowed the red-flag screen by 91 points.
  /// * **Nothing said yet.** The transcript is empty and the notices band is
  ///   collapsed, so their caps are height nobody can use. Handing it to the
  ///   panel is the difference between the question being readable and being
  ///   scrolled off the top of its own scroll view — a contact sheet caught it
  ///   showing the answer tiles sliced through their own glyphs.
  /// * **A conversation exists.** The panel yields. The transcript is a
  ///   `ListView.builder`, which builds only what it has room to show: starve
  ///   it and it renders *nothing*, so the answer the patient just gave is not
  ///   on screen and not in the tree. That is a silent failure, and it is why
  ///   this is not simply "as much as the panel wants".
  double get livePanelHeightFraction {
    if (hasNotices) return 0.52;
    return rxTurns.isEmpty ? 0.86 : 0.58;
  }

  // ── Answering out loud ────────────────────────────────────────────────────

  final Rx<MicState> rxMic = MicState.idle.obs;
  final RxDouble rxLevel = 0.0.obs;

  /// False once the microphone has proved unavailable — a refused permission,
  /// or a transcriber that is down. The control goes away rather than staying
  /// on screen to fail again.
  final RxBool rxVoiceAvailable = true.obs;

  /// The sentence that goes where the microphone was.
  final RxnString rxVoiceNotice = RxnString();

  /// True only where the operating system will no longer show the prompt, so
  /// "Open Settings" is offered exactly when it is the only way forward.
  final RxBool rxVoiceNeedsSettings = false.obs;

  /// What the app thinks it heard, waiting to be confirmed.
  final Rxn<CaseTranscript> rxDraft = Rxn<CaseTranscript>();

  // ── The keyboard ──────────────────────────────────────────────────────────

  final TextEditingController typed = TextEditingController();
  final FocusNode typedFocus = FocusNode();

  StreamSubscription<double>? _level;

  /// Kept so the retry on a failed turn re-sends the same answer rather than
  /// asking the patient to compose it again.
  CaseTurnDraft? _unsent;
  InterviewTurn? _unsentTurn;

  /// Built on first use and remembered.
  ///
  /// Remembered rather than looked up each time because `onClose` runs *after*
  /// the route's dependencies have been disposed, and a `Get.find` there
  /// throws — which surfaces as an exception while the widget tree is being
  /// finalised, well away from anything that explains it. Holding the
  /// reference also means a patient who typed every answer never causes a
  /// recorder to be built at all.
  AudioSource? _recorder;

  AudioSource get _audio => _recorder ??= Get.find<AudioSource>();

  String get _sessionId => rxSession.value?.id ?? '';

  /// True while the questions have run out but an answer is still being read.
  /// Deliberately not the same as finished.
  bool get isSettling =>
      rxStatus.value == CaseInterviewStatus.awaitingExtraction;

  bool get isFinished => rxStatus.value.isFinished;

  @override
  void onReady() {
    super.onReady();
    // `onReady`, never `onInit`: the first widget to touch `controller`
    // constructs it, and a write to an observable during that build marks the
    // building `Obx` dirty.
    reload();
  }

  @override
  void onClose() {
    unawaited(_level?.cancel());
    // Bytes, not a file. Cancelling clears the buffer, which is the point of
    // the recorder seam on a shared device — and only if one was ever built,
    // because a patient who typed every answer has nothing to clear.
    unawaited(_recorder?.cancel());
    typed.dispose();
    typedFocus.dispose();
    super.onClose();
  }

  // ── Opening ───────────────────────────────────────────────────────────────

  /// Opens the interview, or resumes the one already open.
  ///
  /// **Not `refresh()`.** `GetxController.refresh()` exists and returns void,
  /// so a callback that awaited one would silently never await anything.
  Future<void> reload() async {
    await runGuarded(
      () async {
        final started = await _repository.startOrResume(
          CaseSessionStartDraft(language: entry.language.code),
        );
        await _adopt(started);
      },
      fallback: PatientText.couldNotStart,
    );

    // Only after the server has been given its chance. The snapshot is a
    // fallback for a dropped connection, not a cache in front of the record —
    // showing it first would put a stale question in front of somebody whose
    // wifi was fine.
    if (hasLoadError) await _restoreSnapshot();
  }

  Future<void> _adopt(CaseSession session) async {
    var current = session;

    // Consent is a property of the case session, and the session did not exist
    // until a moment ago — so the answer the consent screen collected is
    // recorded here, against the version the server says it is asking for. An
    // app shipping its own constant would record agreement to a paragraph that
    // had since been rewritten.
    if (!current.consent.isSettled && entry.consentGiven) {
      current = await _repository.recordConsent(
        current.id,
        CaseConsentDraft(
          consentVersion: current.consent.requiredVersion,
          accepted: true,
        ),
      );
    }

    rxSession.value = current;
    rxProgress.value = current.progress;
    rxStatus.value = current.interviewStatus;
    rxQuestion.value = current.currentQuestion;
    rxFromSnapshot.value = false;

    // A resumed interview has a history the server does not send back — its
    // session view carries state, not a transcript. The phone's own snapshot
    // is what puts the conversation back on screen, and only when it is about
    // this same session.
    if (current.resumed && rxTurns.isEmpty) {
      final snapshot = await _cache.read();
      if (snapshot != null && snapshot.sessionId == current.id) {
        rxTurns.assignAll(snapshot.turns);
      }
    }

    if (current.redFlags.isNotEmpty) {
      // Resumed into a flag that fired before the app was closed. The quote is
      // whatever the transcript still holds; a flag with nothing to quote is
      // still shown, because the notice's fixed copy is the part that matters.
      rxRedFlagRaised.value = true;
      rxRedFlagQuote.value ??= _lastPatientWords();
    }

    _touchLock();
    unawaited(_saveSnapshot());
  }

  /// Puts back what was on screen when the connection went.
  ///
  /// It restores the conversation and the question; it restores no facts and
  /// unlocks no controls. Answering is refused while [rxFromSnapshot] is true,
  /// because an answer with nowhere to go is worse than a question that will
  /// not move on.
  Future<void> _restoreSnapshot() async {
    final snapshot = await _cache.read();
    if (snapshot == null || snapshot.sessionId.isEmpty) return;

    rxTurns.assignAll(snapshot.turns);
    rxProgress.value = snapshot.progress;
    rxQuestion.value = snapshot.question;
    rxFromSnapshot.value = true;
  }

  // ── Answering ─────────────────────────────────────────────────────────────

  /// A tapped tile.
  void answerByTouch(CaseAnswerOption option) {
    final question = rxQuestion.value;
    if (question == null) return;
    unawaited(
      _submit(
        CaseTurnDraft.tapped(fieldPath: question.fieldPath, option: option),
        turn: InterviewTurn.answered(
          option.label,
          source: AnswerSource.chosen,
          fieldPath: question.fieldPath,
        ),
      ),
    );
  }

  /// The four-answer row, for a yes/no question.
  ///
  /// The mapping is the whole point of the row, so it is spelled out rather
  /// than derived: "I don't know" becomes the reserved token `not_sure`, which
  /// the server reads as a statement about what the patient knows. It does
  /// **not** become "no", and there is no branch here that could make it one.
  void answerYesNo(PatientAnswer answer) {
    final question = rxQuestion.value;
    if (question == null) return;

    final option = switch (answer) {
      PatientAnswer.yes => CaseAnswerOption(
          token: CaseChoiceTokens.yes,
          label: answer.transcriptLabel,
          modality: CaseAnswerModality.choice,
        ),
      PatientAnswer.no => CaseAnswerOption(
          token: CaseChoiceTokens.no,
          label: answer.transcriptLabel,
          modality: CaseAnswerModality.choice,
        ),
      PatientAnswer.unknown => CaseAnswerOption(
          token: CaseChoiceTokens.unsure,
          label: answer.transcriptLabel,
          modality: CaseAnswerModality.choice,
        ),
      PatientAnswer.skipped => CaseAnswerOption(
          token: '',
          label: answer.transcriptLabel,
          modality: CaseAnswerModality.skip,
        ),
    };

    answerByTouch(option);
  }

  /// A typed answer.
  void answerByTyping() {
    final question = rxQuestion.value;
    final text = typed.text.trim();
    if (question == null || text.isEmpty) return;

    typed.clear();
    unawaited(
      _submit(
        CaseTurnDraft.typed(fieldPath: question.fieldPath, text: text),
        turn: InterviewTurn.answered(
          text,
          source: AnswerSource.typed,
          fieldPath: question.fieldPath,
        ),
      ),
    );
  }

  /// Files the transcript the patient has just confirmed.
  void acceptDraft() {
    final question = rxQuestion.value;
    final draft = rxDraft.value;
    if (question == null || draft == null) return;

    rxDraft.value = null;
    unawaited(
      _submit(
        CaseTurnDraft.spoken(
          fieldPath: question.fieldPath,
          // Verbatim. Not trimmed of the hedge that makes it an uncertainty:
          // "I think maybe three days" is read differently from "three days",
          // and the difference is the server's to notice.
          text: draft.text,
          confidence: draft.confidence,
        ),
        turn: InterviewTurn.answered(
          draft.text,
          source: AnswerSource.spoken,
          confidence: AnswerConfidence.fromScore(draft.confidence),
          fieldPath: question.fieldPath,
        ),
      ),
    );
  }

  /// Re-sends an answer that did not reach the hospital.
  void retryAnswer() {
    final draft = _unsent;
    final turn = _unsentTurn;
    if (draft == null || turn == null) return;
    unawaited(_submit(draft, turn: turn));
  }

  Future<void> _submit(CaseTurnDraft draft, {required InterviewTurn turn}) async {
    final question = rxQuestion.value;
    if (question == null || rxSending.value) return;

    if (rxFromSnapshot.value) {
      // Nothing to send to. Said out loud rather than silently dropped: a tile
      // that does nothing is a tile the patient taps again.
      showBentoToast(PatientText.showingWhereYouLeftOff, tone: ToastTone.info);
      return;
    }

    // An interview is a long sit-down, and a lock that fires mid-sentence
    // throws the patient onto a password screen holding somebody else's
    // device. `SessionLockScope` sees pointers; it does not see the twenty
    // seconds a spoken answer takes, which is why this is here too.
    _touchLock();

    _unsent = draft;
    _unsentTurn = turn;
    rxTurnError.value = null;
    rxSending.value = true;

    // The question moves into the conversation and the answer goes under it,
    // before the response. Optimistic on purpose: the round trip is
    // milliseconds, and a bubble that appears only afterwards makes a fast
    // path look slow.
    _settlePreviousReading();
    rxTurns
      ..add(InterviewTurn.asked(question.prompt, fieldPath: question.fieldPath))
      ..add(turn);
    rxQuestion.value = null;

    try {
      final result = await _repository.submitTurn(_sessionId, draft);
      _apply(result, quoting: turn.text);
      _unsent = null;
      _unsentTurn = null;
    } catch (error, stack) {
      // Taken back off the screen. An answer that never reached the server is
      // not part of the conversation, and leaving it there is the app telling
      // a patient something was recorded when it was not.
      if (rxTurns.length >= 2) rxTurns.removeRange(rxTurns.length - 2, rxTurns.length);
      rxQuestion.value = question;
      rxTurnError.value =
          parseErrorMessage(error, PatientText.couldNotSendAnswer);
      AppLog.error('CaseTakingController', 'a turn did not send', error, stack);
    } finally {
      rxSending.value = false;
    }
  }

  void _apply(CaseTurnResult result, {required String quoting}) {
    rxProgress.value = result.progress;
    rxStatus.value = result.interviewStatus;
    rxQuestion.value = result.nextQuestion;

    // The answer went to the model to be read properly. The mark goes under
    // that bubble and the next question is already on screen — see the note on
    // `InterviewTurn.stillReading` for why it lives one question long.
    if (result.extraction.queued && rxTurns.isNotEmpty) {
      rxTurns[rxTurns.length - 1] = rxTurns.last.reading();
    }

    if (result.redFlags.isNotEmpty || (result.patientMessage ?? '').isNotEmpty) {
      rxRedFlagRaised.value = true;
      rxRedFlagQuote.value = quoting;
    }

    _touchLock();
    unawaited(_saveSnapshot());

    if (result.interviewStatus.isFinished) unawaited(_cache.clear());
  }

  /// Retires the mark on the previous answer.
  ///
  /// The extraction it describes may well still be running; what has ended is
  /// the moment the mark was for. It says "your long answer arrived and is
  /// being read", and a patient who has since answered another question has
  /// already had that answered.
  void _settlePreviousReading() {
    for (var i = rxTurns.length - 1; i >= 0; i--) {
      if (!rxTurns[i].stillReading) continue;
      rxTurns[i] = rxTurns[i].settled();
      break;
    }
  }

  // ── Answering out loud ────────────────────────────────────────────────────

  /// Starts or stops recording.
  Future<void> toggleMicrophone() async {
    if (!rxVoiceAvailable.value || rxSending.value) return;
    _touchLock();

    switch (rxMic.value) {
      case MicState.listening:
        await _finishRecording();
      case MicState.working:
        // The transcriber has it. A second tap here would start a recording
        // over the top of the one being written down.
        return;
      case MicState.idle:
        await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _audio.start();
      rxMic.value = MicState.listening;
      // The only honest source of a level meter is the audio itself. Without
      // one, somebody speaking quietly cannot tell a working microphone from a
      // dead one, and the usual response is to give up and type.
      _level = _audio.level.listen((value) => rxLevel.value = value);
    } on MediaRefusal catch (refusal) {
      // A refusal is never a null — `media_access.dart` is explicit — and the
      // exception *is* the sentence, already written for a patient.
      _withdrawVoice(refusal.message, needsSettings: refusal.canOpenSettings);
    } catch (error, stack) {
      AppLog.error(
          'CaseTakingController', 'the microphone would not start', error,
          stack);
      _withdrawVoice(PatientText.voiceUnavailable);
    }
  }

  Future<void> _finishRecording() async {
    final recording = await _audio.stop();
    await _level?.cancel();
    _level = null;
    rxLevel.value = 0;

    if (recording == null) {
      rxMic.value = MicState.idle;
      return;
    }

    // A thumb brushing the button. Sending it produces an empty transcript,
    // which reads downstream as "the patient said nothing" — a clinical fact
    // that is not true.
    if (recording.isTooShort) {
      rxMic.value = MicState.idle;
      showBentoToast(PatientText.recordingTooShort, tone: ToastTone.info);
      return;
    }

    if (recording.isTooLarge) {
      rxMic.value = MicState.idle;
      showBentoToast(PatientText.recordingTooShort, tone: ToastTone.info);
      return;
    }

    rxMic.value = MicState.working;
    try {
      final transcript = await _repository.transcribe(
        recording,
        language: rxSession.value?.language ?? entry.language.code,
      );
      if (transcript.isEmpty) {
        showBentoToast(PatientText.didNotHearAnything, tone: ToastTone.info);
      } else {
        rxDraft.value = transcript;
      }
    } catch (error, stack) {
      // The transcriber is down. Not an error worth stopping the interview
      // for: voice was never the only way to answer, so the control goes away
      // with a sentence and the keyboard and the tiles carry on.
      AppLog.error('CaseTakingController', 'transcription failed', error, stack);
      _withdrawVoice(PatientText.voiceUnavailable);
    } finally {
      if (rxMic.value == MicState.working) rxMic.value = MicState.idle;
    }
  }

  /// Throws the draft away and listens again.
  Future<void> recordAgain() async {
    rxDraft.value = null;
    await _startRecording();
  }

  /// The way out for somebody the microphone is never going to hear.
  void typeInstead() {
    rxDraft.value = null;
    rxMic.value = MicState.idle;
    typedFocus.requestFocus();
  }

  Future<void> openVoiceSettings() => MediaAccess.openSystemSettings();

  void _withdrawVoice(String message, {bool needsSettings = false}) {
    rxVoiceAvailable.value = false;
    rxVoiceNotice.value = message;
    rxVoiceNeedsSettings.value = needsSettings;
    rxDraft.value = null;
    rxMic.value = MicState.idle;
    rxLevel.value = 0;
    unawaited(_level?.cancel());
    _level = null;
    unawaited(_recorder?.cancel());
  }

  // ── Leaving ───────────────────────────────────────────────────────────────

  /// Back to the patient's own screen.
  ///
  /// The interview is not abandoned by leaving it: the session stays open on
  /// the server and `POST /sessions` hands the same one back. That is §37's
  /// resume, and it is why there is no "are you sure" here — nothing is lost.
  void leave() => PatientPortalNavigation.backToDashboard();

  // ── Internals ─────────────────────────────────────────────────────────────

  String? _lastPatientWords() {
    for (var i = rxTurns.length - 1; i >= 0; i--) {
      if (rxTurns[i].speaker == ConversationSpeaker.patient) {
        return rxTurns[i].text;
      }
    }
    return null;
  }

  Future<void> _saveSnapshot() => _cache.save(
        CaseInterviewSnapshot(
          sessionId: _sessionId,
          savedAt: DateTime.now(),
          language: rxSession.value?.language ?? entry.language.code,
          progress: rxProgress.value,
          question: rxQuestion.value,
          turns: rxTurns.toList(),
        ),
      );

  /// Restarts the idle countdown.
  ///
  /// Guarded rather than assumed: `SessionLockService` is registered in
  /// `main()` and not in every harness, and a screen that threw looking for a
  /// lock would be a worse failure than a lock that did not fire.
  void _touchLock() {
    if (Get.isRegistered<SessionLockService>()) SessionLockService.to.touch();
  }
}
