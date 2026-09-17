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
import '../../../data/services/speech_player.dart';
import '../../../data/services/voice_session.dart';
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

  /// True when the interview settled with no question and stayed that way past
  /// every re-check. The screen stops promising that an answer is being written
  /// down — because by this point nothing is — and offers the way out instead.
  final RxBool rxSettleStalled = false.obs;

  /// Re-checks a settling interview. See [_watchSettling].
  Timer? _settle;

  /// How many re-checks have gone by without a question arriving.
  int _settleAttempts = 0;

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

  /// How the column is divided, as fractions of the height it actually has.
  ///
  /// Four states, because three bands compete and which of them is on screen
  /// changes what the others can have. The rail takes roughly 0.08 on top of
  /// these, so a pair must leave room for it.
  ///
  /// Every number here was paid for by a defect:
  ///
  /// * **Nothing said, no notice.** The other two bands are collapsed, so their
  ///   caps are height nobody can use. Give it to the panel: a contact sheet
  ///   caught the first question rendered with a blank half-screen above it and
  ///   the answer tiles sliced through their own glyphs.
  /// * **A conversation, no notice.** The panel yields. The transcript is a
  ///   `ListView.builder` and builds only what it has room to show — starve it
  ///   and it renders *nothing*, so the answer just given is neither on screen
  ///   nor in the tree.
  /// * **A notice, nothing said.** All three are up but there is no history to
  ///   show, so the notice and the question take the screen between them.
  /// * **A notice and a conversation** — the red-flag screen, and the one that
  ///   is hardest to satisfy. `0.34 + 0.52` fits the column but leaves the
  ///   transcript about six per cent, which is the starved case above: the
  ///   patient reads "we could not reach" and "here is the question" and cannot
  ///   see the answer they just gave. Both caps come down so the history keeps
  ///   about a fifth. Raising the panel to `0.72` instead overflowed this
  ///   screen by 91 points, which is how the ceiling was found.
  double get livePanelHeightFraction {
    if (!hasNotices) return rxTurns.isEmpty ? 0.86 : 0.58;
    return rxTurns.isEmpty ? 0.52 : 0.44;
  }

  /// The notices band's share, by the same argument.
  ///
  /// Smaller once there is a conversation, so the transcript is not squeezed
  /// out by a banner. The band scrolls inside whatever it is given and never
  /// ellipsises the patient's quoted words, so a long notice loses nothing —
  /// it just needs a scroll.
  double get noticesHeightFraction => rxTurns.isEmpty ? 0.34 : 0.28;

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

  // ── Answering out loud, as a conversation ─────────────────────────────────
  //
  // A live room is an **enhancement on the same microphone**, never a second
  // one. The patient taps the control they have always tapped; what changes is
  // that their words arrive a sentence at a time instead of a recording at a
  // time, and that a final sentence lands in [rxDraft] on exactly the path
  // `_finishRecording` puts one on — so `acceptDraft`, `recordAgain` and
  // `typeInstead` are the same three ways out of it either way.
  //
  // Everything here degrades to nothing. A build with no WebRTC, a site with
  // no media server, a token route that 404s, a dial that times out and a room
  // that closes halfway are five different causes and one behaviour: the
  // record-then-upload microphone, which was never conditional on any of it.

  /// Where the live room has got to. [VoiceSessionState.idle] covers both "not
  /// asked for" and "the patient stopped talking", which are the same thing to
  /// the screen.
  final Rx<VoiceSessionState> rxLive = VoiceSessionState.idle.obs;

  /// The words arriving while the patient is still speaking.
  ///
  /// **Never filed.** The recogniser revises this several times a sentence;
  /// what reaches [rxDraft] is the final segment and nothing else. It is here
  /// so somebody can see they are being heard, which on the recorded path is
  /// what the level meter is for.
  final RxnString rxLiveHeard = RxnString();

  /// One dial per interview.
  ///
  /// A room that would not open is not going to open on the next question
  /// either, and a microphone that spends eight seconds trying before every
  /// spoken answer is a slower interview bought with a convenience. Set before
  /// the attempt rather than after it, so a second tap during the dial cannot
  /// start a second one.
  bool _liveTried = false;

  StreamSubscription<VoiceTranscript>? _heard;
  StreamSubscription<VoiceSessionState>? _liveState;

  // ── Asking out loud ───────────────────────────────────────────────────────

  /// Whether each new question is read to the patient.
  ///
  /// On by default, because the patient this helps most is the one least able
  /// to discover a setting: somebody who cannot comfortably read the screen.
  /// A patient who does not want it turns it off once and hears nothing more —
  /// and `toggleReadAloud` silences the sentence already in the air, since a
  /// waiting room is the usual place to realise you would rather it stopped.
  ///
  /// Not persisted. A shared ward device should not carry one patient's choice
  /// into the next patient's interview.
  final RxBool rxReadAloud = true.obs;

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

  /// Built on first use and remembered, for the reasons above [_recorder].
  SpeechPlayer? _player;

  SpeechPlayer get _speech => _player ??= Get.find<SpeechPlayer>();

  /// Built on first use and remembered, for the reasons above [_recorder] —
  /// and one more that is specific to this seam: constructing it is what puts
  /// a WebRTC stack in the process, so a patient who never presses the
  /// microphone never causes one to exist.
  VoiceSession? _voice;

  /// The room seam, or null where there is not one registered.
  ///
  /// Guarded rather than assumed, the way `_touchLock` guards
  /// `SessionLockService` and for a stronger reason. A harness that registers a
  /// recorder and a player but no room is a harness testing the interview this
  /// feature is not allowed to require, and a controller that threw looking for
  /// a seam it can do without would turn "there is no live conversation here"
  /// into "the microphone crashes" — which is the one outcome §5 of this
  /// module's brief rules out.
  VoiceSession? get _room {
    final found = _voice;
    if (found != null) return found;
    if (!Get.isRegistered<VoiceSession>()) return null;
    return _voice = Get.find<VoiceSession>();
  }

  /// Opens or closes the published microphone on a room that exists.
  ///
  /// Fire-and-forget: nothing the interview does next depends on the platform
  /// having finished muting, and awaiting it would put a round trip to the
  /// audio device between a patient's answer and the next question.
  void _liveMic(bool talking) {
    final room = _voice;
    if (room == null) return;
    unawaited(room.setMicrophoneEnabled(talking));
  }

  /// Whether a room is up *right now*.
  ///
  /// Read from the seam rather than from [rxLive], deliberately. The state
  /// stream is delivered asynchronously, so for a microtask after a successful
  /// join the observable still says `connecting` — and the two places that ask
  /// this question, `_submit` and `_readAloud`, are both on paths where being
  /// one microtask wrong means a recording spanning two questions or two
  /// voices reading one question.
  bool get _isTalkingLive => _voice?.isLive ?? false;

  String get _sessionId => rxSession.value?.id ?? '';

  /// The session's one language tag, and the floor under both halves below.
  ///
  /// **The session's language wins.** The server decides what language an
  /// interview is being conducted in, and the two can differ once a session is
  /// resumed on a different device or on a different day from the one the entry
  /// screen was answered on. The entry's own answer is the floor for the moment
  /// before the session lands, and for the case where it never does.
  String get _languageCode => rxSession.value?.language ?? entry.language.code;

  /// The tag `/stt` is told — **what the patient speaks**, which is the only
  /// thing the language screen now chooses.
  ///
  /// The raw string rather than [spokenLanguage.code], deliberately: a tag this
  /// build has no row for still has to reach the sidecar, which may well have a
  /// model for it. Narrowing it to a known language here would quietly
  /// transcribe somebody's answer as English.
  ///
  /// Falls back through [_languageCode] rather than to a constant, so a
  /// deployment whose sessions carry one tag behaves exactly as it did before
  /// the split existed.
  String get _inputLanguageCode =>
      rxSession.value?.inputLanguage ?? _languageCode;

  /// The tag `/tts` is told — **the language the question on screen is written
  /// in**, which the server settles and which is English under the current
  /// rule.
  ///
  /// Read-aloud speaks the prompt the server sent, so the only correct voice is
  /// the one that matches that text. That is the server's fact, not the
  /// patient's choice, which is why this reads the session and never the entry
  /// screen — and why the fallback is [_languageCode] rather than `en`: a
  /// server still phrasing questions in one language would otherwise be read
  /// aloud in an English voice.
  String get _outputLanguageCode =>
      rxSession.value?.outputLanguage ?? _languageCode;

  /// What the patient speaks, as this build knows it — the capability question
  /// behind the microphone. A tag with no row here lands on English.
  PatientLanguage get spokenLanguage =>
      PatientLanguage.fromCode(_inputLanguageCode);

  /// What the patient is read to in, as this build knows it — the capability
  /// question behind the read-aloud switch.
  PatientLanguage get readAloudLanguage =>
      PatientLanguage.fromCode(_outputLanguageCode);

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
    _settle?.cancel();
    unawaited(_level?.cancel());
    unawaited(_heard?.cancel());
    unawaited(_liveState?.cancel());
    // A room left open after the patient has walked away is a live microphone
    // on a shared ward tablet, which is the same disclosure `_player?.stop()`
    // below is here to prevent and a worse one. `dispose` rather than `leave`:
    // the screen is going away and there will be no next conversation.
    unawaited(_voice?.dispose());
    // Bytes, not a file. Cancelling clears the buffer, which is the point of
    // the recorder seam on a shared device — and only if one was ever built,
    // because a patient who typed every answer has nothing to clear.
    unawaited(_recorder?.cancel());
    // A question still being read aloud after the patient has left the screen
    // is audible to whoever picks the device up next, which on a shared ward
    // tablet is a disclosure rather than an annoyance.
    unawaited(_player?.stop());
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

    // Again here for the path `_adopt` never reached: the session call failed
    // and the language in force is the one the patient chose on the entry
    // screen. A restored snapshot has a question on it and therefore controls
    // under it, so the microphone has to be right on this path too.
    _applyLanguageVoiceRule();
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
    // Before the awaits below, because the question is already on screen and a
    // question on screen has an answer panel under it. A resumed interview
    // waits on the snapshot read, and a microphone drawn for the length of that
    // read is a microphone somebody can press.
    _applyLanguageVoiceRule();
    // The first question of the sitting, or the one a resumed interview came
    // back to. Read here as well as in `_apply`, because a patient who needs
    // the questions read to them needs the first one most — it is the one that
    // tells them the screen talks.
    _readAloud(current.currentQuestion);

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
    // A resumed interview can land straight into the settling state — which is
    // exactly how the stuck session presented: opened from the portal, no
    // question, nothing to press.
    _watchSettling();
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

    // The patient has answered. Whatever the microphone was doing belongs to
    // the question on screen *now*, and this one is about to leave it.
    //
    // Both lines are here for the same defect, and it is the one
    // `case_taking_drafts.dart` calls worse than a missing answer: an unspoken
    // draft used to survive a tapped or typed answer, reappear under the *next*
    // question, and file its stale text against that question's `fieldPath` —
    // an answer to a question nobody asked, reading as a finding. Stopping the
    // recorder is the other half: left running, it kept listening across the
    // boundary and produced audio spanning two questions.
    rxDraft.value = null;
    // The room stays up across a question boundary — that is what makes it a
    // conversation — but the audio must not. Muted rather than left running,
    // for the defect above: a live microphone across the boundary publishes a
    // sentence that spans two questions, and the room would file it against
    // whichever one is on screen when it finishes.
    rxLiveHeard.value = null;
    if (_isTalkingLive) {
      // Given back on the next question, but **only for an answer the room
      // itself produced**. Somebody who tapped a tile chose not to speak, and
      // a microphone that reopened itself in a waiting room on the strength of
      // that is publishing audio nobody asked it to.
      _resumeTalking = draft.modality == CaseAnswerModality.voice;
      rxMic.value = MicState.idle;
      _liveMic(false);
    } else if (rxMic.value == MicState.listening) {
      rxMic.value = MicState.idle;
      unawaited(_level?.cancel());
      _level = null;
      // `cancel`, not `stop` - a recording the patient abandoned by answering
      // another way is not evidence, and on a shared device it should not
      // outlive the question it belonged to.
      unawaited(_audio.cancel());
    }

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

  /// Whether the microphone goes back on when the next question lands. Set by
  /// `_submit`, which is the only place that knows how the last answer was
  /// given.
  bool _resumeTalking = false;

  void _apply(CaseTurnResult result, {required String quoting}) {
    rxProgress.value = result.progress;
    rxStatus.value = result.interviewStatus;
    rxQuestion.value = result.nextQuestion;
    _readAloud(result.nextQuestion);

    // After the question is on screen, never before: a room listening to a
    // patient who has not been asked anything yet records an answer to the
    // previous question. Only where there is a next question at all — a
    // finished interview has nothing left to say into.
    if (_resumeTalking) {
      _resumeTalking = false;
      if (result.nextQuestion != null && _isTalkingLive) {
        _talkLive(true);
      }
    }

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
    // After the status is set, because it reads it. A turn that lands on
    // `awaiting_extraction` with no question is the state nothing else on this
    // screen can move.
    _watchSettling();

    if (result.interviewStatus.isFinished) unawaited(_cache.clear());
  }

  /// Re-checks an interview that has nothing to ask.
  ///
  /// `awaiting_extraction` means the questions have run out but an answer is
  /// still being read, and it is the one status this screen cannot act on: there
  /// is no question to answer and no control to press. Every other state moves
  /// because the patient moves it. This one moves only when the server changes
  /// its mind, and until now nothing ever asked it again — `reload()` ran once
  /// in `onReady` and that was the only read of the session in the screen's
  /// life. A patient who landed here stayed here, watching a sentence about an
  /// answer being written down, for as long as they were willing to.
  ///
  /// The server can now always leave this state on its own: a lost extraction is
  /// released on the clock, and the question comes back. What was missing was
  /// anybody on this side to notice. So while the interview is settling, ask
  /// again — and stop asking, rather than poll a waiting room forever.
  ///
  /// [_settleAttempts] is not a retry count in the usual sense: nothing here has
  /// failed. It bounds a wait. Six looks at five seconds covers half a minute,
  /// which is past the twenty the longest measured extraction takes and well
  /// short of the two minutes the server's own backstop needs — after which the
  /// session is genuinely stuck rather than slow, and saying so with a way out
  /// beats a sentence that is no longer true.
  void _watchSettling() {
    final settling = rxStatus.value == CaseInterviewStatus.awaitingExtraction &&
        rxQuestion.value == null;

    if (!settling) {
      _settle?.cancel();
      _settle = null;
      _settleAttempts = 0;
      rxSettleStalled.value = false;
      return;
    }

    if (_settle != null) return; // Already watching this one.

    _settle = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final session = rxSession.value;
      // Nothing to re-read against, or the screen has moved on under us.
      if (session == null || rxFromSnapshot.value) {
        timer.cancel();
        _settle = null;
        return;
      }

      _settleAttempts += 1;
      if (_settleAttempts > 6) {
        timer.cancel();
        _settle = null;
        rxSettleStalled.value = true;
        AppLog.warn(
          'CaseTakingController',
          'the interview has been settling for ${_settleAttempts * 5}s with no '
              'question; offering the way out',
        );
        return;
      }

      try {
        final fresh = await _repository.session(session.id);
        rxSession.value = fresh;
        rxProgress.value = fresh.progress;
        rxStatus.value = fresh.interviewStatus;
        rxQuestion.value = fresh.currentQuestion;
        if (fresh.currentQuestion != null || fresh.interviewStatus.isFinished) {
          timer.cancel();
          _settle = null;
          _settleAttempts = 0;
          rxSettleStalled.value = false;
          _settlePreviousReading();
          _readAloud(fresh.currentQuestion);
          unawaited(_saveSnapshot());
        }
      } catch (error, stack) {
        // Swallowed on purpose. This is a background re-check of a screen the
        // patient is not being asked to do anything on; surfacing a network
        // error here would put a failure in front of them for something they
        // never asked for. The attempt counter still advances, so a connection
        // that is down lands on the same way out as a session that is stuck.
        AppLog.error(
          'CaseTakingController',
          'a settling re-check did not reach the hospital',
          error,
          stack,
        );
      }
    });
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

  // ── Asking out loud ───────────────────────────────────────────────────────

  /// Reads [question] to the patient, if this device can and they want it.
  ///
  /// Deliberately **not** awaited by any caller, and the ordering is the whole
  /// design: `_apply` puts the question on screen first and calls this after,
  /// so the text never waits on the audio. Synthesis costs a second or two on
  /// the sidecar's CPU Piper, and a patient watching a blank panel for that
  /// long — every turn — would be a slower interview bought with a
  /// convenience.
  ///
  /// So the question is readable immediately and becomes audible shortly
  /// after. If the audio never arrives, nothing on screen changes and the
  /// patient loses nothing they can see — the same posture the server already
  /// takes: "We cannot read this aloud right now. The question is on screen."
  void _readAloud(CaseQuestion? question) {
    final text = question?.prompt.trim() ?? '';
    if (text.isEmpty) return;
    if (!rxReadAloud.value || !canReadAloud) return;
    // The room has a voice of its own and is already speaking. Two voices
    // reading one clinical question over each other in a waiting room is worse
    // than either of them alone, and the switch above is not the thing that
    // can tell them apart.
    //
    // Asked as "is the room *speaking*", not "is the room open". A room whose
    // agent never publishes audio must leave this alone — silencing it there
    // would take the questions away from the one patient read-aloud exists
    // for, somebody who cannot comfortably read the screen.
    if (_voice?.carriesTheVoice ?? false) return;
    final asked = question!.fieldPath;

    unawaited(() async {
      try {
        final wav = await _repository.speak(
          text,
          language: _outputLanguageCode,
        );
        // The interview can move on while synthesis is in flight, and a
        // patient who has already answered must not then hear the question
        // they just answered. After the await is the only point where this can
        // have changed.
        if (rxQuestion.value?.fieldPath != asked) return;
        await _speech.play(wav);
      } catch (error, stack) {
        // Not shown, and not disabled. Read-aloud assists a question that is
        // already on screen, so a toast about audio on top of a clinical
        // question is noise at the worst moment. Unlike the microphone, one
        // failure costs the patient nothing, so the next question is free to
        // try again rather than the control disappearing for good.
        AppLog.error('CaseTakingController',
            'a question could not be read aloud', error, stack);
      }
    }());
  }

  /// Whether this device can read a question aloud at all.
  ///
  /// False on a platform with no audio implementation, false once a player has
  /// failed in a way it will not retry, and false in a language the synthesiser
  /// has no voice for. The switch is hidden rather than disabled when this is
  /// false — a control that plainly is not there beats one that takes a tap and
  /// does nothing.
  ///
  /// **The language it asks about is [readAloudLanguage], not what the patient
  /// picked.** The questions are asked in English however the patient answers,
  /// so this is available to all twelve — including Odia, whose missing half is
  /// the microphone and not the voice. Gating it on the patient's own language
  /// would take the audio away from the one patient it was built for: somebody
  /// who cannot comfortably read the screen and now cannot hear it either.
  ///
  /// Kept as a capability question rather than collapsed to `_speech
  /// .isAvailable`, because the tag the server sends is what decides which
  /// voice speaks: an interview whose output moved off English would need this
  /// to answer for that language.
  ///
  /// Touching this builds the player, which is why it is read from the switch
  /// and not from the interview: a patient who never sees the control never
  /// causes an `AudioPlayer` to exist.
  bool get canReadAloud => readAloudLanguage.canHear && _speech.isAvailable;

  /// Turns read-aloud off, and silences anything mid-sentence.
  ///
  /// The off switch matters more than the on switch. An interview asks a
  /// patient about their own body, often in a waiting room, and a question
  /// read out loud is audible to everyone in it. Somebody who realises that
  /// halfway through needs it to stop on the first tap, not at the end of the
  /// current sentence.
  void toggleReadAloud() {
    _touchLock();
    final next = !rxReadAloud.value;
    rxReadAloud.value = next;
    if (!next) {
      unawaited(_speech.stop());
      return;
    }
    // Turning it back on reads the question on the table, rather than leaving
    // the patient to wait for the next one to learn whether it worked.
    _readAloud(rxQuestion.value);
  }

  // ── Answering out loud ────────────────────────────────────────────────────

  /// Starts or stops the microphone.
  ///
  /// One control, two mechanisms underneath it. Where a room is open the taps
  /// mute and unmute it; everywhere else they start and finish a recording, as
  /// they always have. The patient is not asked to know which — see the note
  /// on the live block in `patient_text.dart`.
  Future<void> toggleMicrophone() async {
    if (!rxVoiceAvailable.value || rxSending.value) return;
    // A tap while the room is being dialled would start a second dial, or end
    // what the first is still opening.
    if (rxLive.value == VoiceSessionState.connecting) return;
    _touchLock();

    switch (rxMic.value) {
      case MicState.listening:
        if (_isTalkingLive) {
          _talkLive(false);
          return;
        }
        await _finishRecording();
      case MicState.working:
        // The transcriber has it. A second tap here would start a recording
        // over the top of the one being written down.
        return;
      case MicState.idle:
        if (_isTalkingLive) {
          _talkLive(true);
          return;
        }
        // The one dial of the interview, if there is one to make. It takes the
        // tap either way: a room that failed has already cost the patient
        // several seconds, and starting a recording they are no longer
        // expecting would capture whatever the waiting room is saying.
        if (await _openLiveVoice()) return;
        await _startRecording();
    }
  }

  /// Opens a live room, once, and says whether it took this tap.
  ///
  /// True means "handled" and not "connected" — a failed attempt has been
  /// reported and the microphone is idle and ready for the next tap. False
  /// means no attempt was made and the caller should record as usual: this
  /// build cannot hold a room, one has already been tried, or there is no
  /// session to open one against.
  Future<bool> _openLiveVoice() async {
    // `rxFromSnapshot` is the phone showing what was on screen when the
    // connection went. A room needs the hospital, and so does the answer it
    // would produce.
    if (_liveTried || rxFromSnapshot.value) return false;
    final sessionId = _sessionId;
    if (sessionId.isEmpty) return false;
    // Reading this constructs the seam, which is why it is the last of the
    // cheap checks rather than the first — and null where a harness never
    // registered one, which reads as "there is no live conversation here".
    final room = _room;
    if (room == null || !room.isSupported) return false;

    _liveTried = true;
    rxLive.value = VoiceSessionState.connecting;

    try {
      final grant = await _repository.voiceGrant(
        CaseVoiceTokenDraft(
          sessionId: sessionId,
          inputLanguage: _inputLanguageCode,
          outputLanguage: _outputLanguageCode,
        ),
      );

      // Subscribed before the join, not after it. The room announces `live`
      // and can deliver its first segment from inside `join`, and a
      // subscription taken out afterwards would miss both.
      _heard = room.transcripts.listen(_onHeard);
      _liveState = room.state.listen(_onLiveState);

      await room.join(
        grant,
        inputLanguage: _inputLanguageCode,
        outputLanguage: _outputLanguageCode,
      );

      if (room.isLive) {
        rxMic.value = MicState.listening;
        return true;
      }

      // The seam reported `dropped` rather than throwing — an unusable grant,
      // an unreachable server, a dial past its budget. `_onLiveState` has
      // already said so.
      return true;
    } on MediaRefusal catch (refusal) {
      // A refusal is never a null — `media_access.dart` is explicit — and the
      // exception *is* the sentence. Handled here rather than falling through
      // to the recorder, which would ask for the same microphone and be told
      // the same thing.
      _withdrawVoice(refusal.message, needsSettings: refusal.canOpenSettings);
      rxLive.value = VoiceSessionState.idle;
      return true;
    } catch (error, stack) {
      // A site with no media server configured, which is most of them today.
      // The route answers 404, this lands, and the interview goes on with the
      // microphone it already had.
      AppLog.error(
          'CaseTakingController', 'no live voice room', error, stack);
      _endLiveVoice(notice: PatientText.couldNotOpenLiveVoice);
      return true;
    }
  }

  /// Mutes or unmutes an open room, without closing it.
  void _talkLive(bool talking) {
    rxMic.value = talking ? MicState.listening : MicState.idle;
    // Whatever was half-heard belonged to the moment the microphone was open.
    if (!talking) rxLiveHeard.value = null;
    _liveMic(talking);
  }

  void _onHeard(VoiceTranscript heard) {
    // The agent's own words come down the same stream and are **never** an
    // answer. Dropped here rather than filtered further down, so there is one
    // place to read and no path by which the room can put words on a chart
    // that the patient did not say.
    if (heard.speaker != VoiceSpeaker.patient || heard.isEmpty) return;

    if (!heard.isFinal) {
      rxLiveHeard.value = heard.text;
      return;
    }

    rxLiveHeard.value = null;
    // Onto exactly the path a recorded answer takes: the patient is shown what
    // was heard and confirms it. Nothing a room produces reaches a chart
    // without that tap.
    //
    // No confidence, because the room measured none — and
    // `AnswerConfidence.fromScore(null)` reads that as "check this", which is
    // the honest reading of a sentence nothing scored.
    rxDraft.value = CaseTranscript(
      text: heard.text,
      language: heard.language,
    );
    // Muted while the draft is on screen. Left open, the next thing said in
    // the waiting room would arrive as a second final segment and replace a
    // transcript the patient was in the middle of reading.
    _liveMic(false);
    rxMic.value = MicState.idle;
  }

  void _onLiveState(VoiceSessionState next) {
    rxLive.value = next;
    switch (next) {
      case VoiceSessionState.dropped:
        _endLiveVoice(
          // Past tense, and only where a room was actually open: somebody who
          // watched their words appear and then stop needs to know the app
          // noticed. A dial that never connected says the other sentence.
          notice: _liveWasOpen
              ? PatientText.liveVoiceEnded
              : PatientText.couldNotOpenLiveVoice,
        );
      case VoiceSessionState.live:
        _liveWasOpen = true;
      case VoiceSessionState.connecting:
      case VoiceSessionState.idle:
        break;
    }
  }

  /// Whether a room ever actually opened, which decides which sentence a
  /// failure gets. Not derived from [rxLive], which by then says `dropped`.
  bool _liveWasOpen = false;

  /// Closes the room and puts the interview back on the recorder.
  ///
  /// **Never withdraws the microphone.** That is the difference between this
  /// and [_withdrawVoice], and it is the whole promise of this feature: a room
  /// that failed costs a patient the live transcript and nothing else, because
  /// the control it was behind still records, still uploads and still answers.
  void _endLiveVoice({String? notice}) {
    rxLive.value = VoiceSessionState.idle;
    rxLiveHeard.value = null;
    rxMic.value = MicState.idle;
    unawaited(_heard?.cancel());
    _heard = null;
    unawaited(_liveState?.cancel());
    _liveState = null;
    unawaited(_voice?.leave());

    // A toast rather than the banner `_withdrawVoice` raises, and deliberately
    // — §3.3 forbids reporting a *load failure* only through a toast because
    // it takes the retry with it. There is nothing to retry here: the
    // microphone is still on screen, still works, and is the retry.
    if (notice != null) showBentoToast(notice, tone: ToastTone.info);
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
        language: _inputLanguageCode,
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
    // An open room does not need starting again; it needs the microphone back.
    // Starting a recorder here would run one alongside the room and post the
    // same sentence twice.
    if (_isTalkingLive) {
      _talkLive(true);
      return;
    }
    await _startRecording();
  }

  /// The way out for somebody the microphone is never going to hear.
  void typeInstead() {
    rxDraft.value = null;
    rxLiveHeard.value = null;
    rxMic.value = MicState.idle;
    // Somebody who has given up on speaking should not still be published into
    // a room while they type. The room stays open — the next question may go
    // better — but it stops listening.
    if (_isTalkingLive) _liveMic(false);
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
    // The microphone is gone, so the room has nothing left to carry. Closed
    // without a notice: this path has already put a sentence on screen, and a
    // toast about a live conversation on top of "the microphone is turned off
    // for MediHive" is the app explaining itself twice.
    if (_voice != null) _endLiveVoice();
  }

  /// Set when the microphone was put away because of the language rather than
  /// because of a fault, so [_applyLanguageVoiceRule] can take that decision
  /// back and a refused permission's cannot.
  bool _voiceWithdrawnByLanguage = false;

  /// Takes the microphone away where the language the patient speaks cannot be
  /// transcribed.
  ///
  /// Still the right gate after the questions moved to English: what the
  /// picker chooses is now *only* the language answers are given in, so it
  /// governs exactly one control, and this is it.
  ///
  /// `faster-whisper` publishes no Odia checkpoint. A microphone offered there
  /// records an answer that comes back empty, and an empty transcript reads
  /// downstream as *the patient said nothing* — which is a clinical statement
  /// nobody made, and the same failure `_finishRecording` refuses a thumb-brush
  /// recording over. So the control is absent rather than present-and-broken,
  /// which is `.agents/RULES.md` §0.1's rule pointed at a patient.
  ///
  /// It goes through [_withdrawVoice] rather than around it because everything
  /// that has to be true afterwards — no half-recorded draft, no live level
  /// subscription, no buffer sitting in a recorder on a shared tablet — is
  /// already written there, and a second path that set only `rxVoiceAvailable`
  /// would be the one that forgot.
  ///
  /// Reversible, unlike every other caller, and that is the reason for the
  /// flag. The entry screen's answer is what is in force until the session
  /// lands, and a patient who chose Odia on a phone that then resumed an
  /// English interview must get their microphone back. A refused permission is
  /// not reversible and is not touched here.
  void _applyLanguageVoiceRule() {
    if (!spokenLanguage.canSpeak) {
      _voiceWithdrawnByLanguage = true;
      _withdrawVoice(
        PatientText.cannotAnswerOutLoudIn(spokenLanguage.nativeName),
      );
      return;
    }

    if (!_voiceWithdrawnByLanguage) return;
    _voiceWithdrawnByLanguage = false;
    rxVoiceAvailable.value = true;
    rxVoiceNotice.value = null;
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
          language: _languageCode,
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
