/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the interview, as the phone reads it
///
/// `/api/case-taking/*` answers with a session, a question and a progress
/// report, and this file is the only place those shapes are parsed. Three of
/// its decisions are worth stating up front, because each of them is a clinical
/// property rather than a parsing convenience:
///
///  * **Presence is read, never invented.** [FactPresence] has six members and
///    an unrecognised token resolves to [FactPresence.notAssessed] — "nobody
///    established this" — and never to [FactPresence.none], which means the
///    patient said no. A parser that read an unknown string as a denial would
///    write "no known allergies" out of a typo.
///
///  * **Progress comes from the server.** [CaseProgress] is parsed whole and
///    there is no constructor here that derives a percentage from a count of
///    turns on screen. The phone does not know which questions apply to this
///    patient — the registry's `appliesWhen` does, on the server — so a local
///    count would tell somebody they were 80% done through an interview that
///    had just unlocked eleven more questions.
///
///  * **A red flag carries a message and nothing else.** [CaseRedFlag] has no
///    title, no rule id and no clinician summary, mirroring the server's own
///    patient view: the rule set's titles name syndromes, and a syndrome on a
///    patient's screen is a diagnosis nobody qualified made.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../../core/i18n/patient_text.dart';
import 'json.dart';

/// What is known about one field, and on whose authority.
///
/// Six states, because the alternative — a `bool?` — cannot tell "no" from
/// "nobody asked" from "the patient does not know", and the gap between those
/// three is where a fabricated allergy history comes from.
enum FactPresence {
  /// A value was recorded.
  recorded,

  /// The patient denied it. A finding, not a blank: "denies chest pain" is
  /// something a clinician writes down.
  none,

  /// The patient does not know. Never the same as [none].
  unknown,

  /// The question does not apply to this patient.
  notApplicable,

  /// Nobody has established this yet. The only presence with no provenance,
  /// and the safe landing for anything this build cannot read.
  notAssessed,

  /// The patient would rather not say. A refusal, which is its own answer.
  declined;

  /// Reads the server's token.
  ///
  /// Unrecognised resolves to [notAssessed], the same way `BedState.resolve`
  /// refuses to read an unknown bed as vacant. Something was recorded that
  /// this build cannot read; calling that a denial writes a clinical statement
  /// nobody made.
  static FactPresence resolve(String? raw) => switch ((raw ?? '').trim()) {
        'recorded' => recorded,
        'none' => none,
        'unknown' => unknown,
        'not_applicable' => notApplicable,
        'declined' => declined,
        _ => notAssessed,
      };

  String get wireValue => switch (this) {
        recorded => 'recorded',
        none => 'none',
        unknown => 'unknown',
        notApplicable => 'not_applicable',
        notAssessed => 'not_assessed',
        declined => 'declined',
      };

  /// True for everything except [notAssessed]: five of the six are claims
  /// about the patient, and only the sixth is a claim about the interview.
  bool get isSettled => this != FactPresence.notAssessed;
}

/// How an answer reached the server.
///
/// The vocabulary is the engine's `ANSWER_MODALITIES` and nowhere else — the
/// backend ledger records a build where the schema said a tapped answer was
/// `touch` while the engine said `choice`, and two spellings of one concept is
/// one of them eventually being missed.
enum CaseAnswerModality {
  voice('voice'),
  text('text'),

  /// A tapped tile. Never `touch`.
  choice('choice'),

  /// The patient moved past the question. Derived as `declined`, which is what
  /// a skip is — not a blank.
  skip('skip'),

  /// Nobody answered at all. The client does not send this; it exists so the
  /// vocabulary here is the same length as the server's.
  noAnswer('no_answer'),

  uploadedDocument('uploaded_document'),
  existingRecord('existing_record'),
  correction('correction');

  const CaseAnswerModality(this.wireValue);

  final String wireValue;
}

/// What shape of answer a question takes.
enum CaseQuestionKind {
  boolean,
  text,
  number,
  choice,
  duration,
  scale,

  /// A widget this build does not know.
  ///
  /// Not an error. The registry is data a deployment may extend, and the
  /// engine's own rule is that an unknown widget still asks the question — so
  /// this renders as free text plus the two reserved answers, which every
  /// question can be answered with.
  other;

  static CaseQuestionKind resolve(String? raw) => switch ((raw ?? '').trim()) {
        'boolean' => boolean,
        'text' => text,
        'number' => number,
        'choice' => choice,
        'duration' => duration,
        'scale' => scale,
        _ => other,
      };
}

/// Why the interview is not asking anything right now.
enum CaseInterviewStatus {
  /// There is a question to ask.
  ready,

  /// Nothing is askable, but answers are still being read. **Not finished** —
  /// submitting here loses whatever the model is still working on.
  awaitingExtraction,

  /// Every applicable question has been addressed.
  complete;

  static CaseInterviewStatus resolve(String? raw) =>
      switch ((raw ?? '').trim()) {
        'complete' => complete,
        'awaiting_extraction' => awaitingExtraction,
        _ => ready,
      };

  bool get isFinished => this == CaseInterviewStatus.complete;
}

// ── The question ────────────────────────────────────────────────────────────

/// The reserved answer tokens. They mean a *presence*, not a value.
///
/// "Not sure" is not an answer to the question; it is a statement about what
/// the patient knows, and the server's `derivePresence` reads these three
/// before it reads anything else. Spelled here exactly as `tri-state.ts`
/// spells them.
abstract final class CaseChoiceTokens {
  static const String unsure = 'not_sure';
  static const String declined = 'prefer_not_to_say';
  static const String no = 'no';
  static const String yes = 'yes';
  static const String notApplicable = 'not_applicable';
}

/// One tile in the touch row.
///
/// A token and the words on the tile, kept together so a call site cannot pair
/// the label of one answer with the token of another — which is the single
/// most dangerous typo available on this screen.
class CaseAnswerOption {
  const CaseAnswerOption({
    required this.token,
    required this.label,
    required this.modality,
  });

  /// What is sent as `value`. Empty for [CaseAnswerModality.skip], which
  /// carries its meaning in the modality rather than in a value.
  final String token;

  final String label;
  final CaseAnswerModality modality;

  /// "I don't know", always offered and never merged into "No".
  static CaseAnswerOption get unsure => CaseAnswerOption(
        token: CaseChoiceTokens.unsure,
        label: PatientText.iDontKnow,
        modality: CaseAnswerModality.choice,
      );

  /// "Skip", always offered. Recorded as a refusal rather than as a blank, so
  /// a clinician can see the question was put and not answered.
  static CaseAnswerOption get skip => CaseAnswerOption(
        token: '',
        label: PatientText.skip,
        modality: CaseAnswerModality.skip,
      );

  @override
  bool operator ==(Object other) =>
      other is CaseAnswerOption &&
      other.token == token &&
      other.modality == modality;

  @override
  int get hashCode => Object.hash(token, modality);
}

/// The question on the table.
class CaseQuestion {
  const CaseQuestion({
    required this.fieldPath,
    required this.section,
    required this.label,
    required this.kind,
    required this.prompt,
    this.spokenPrompt = '',
    this.choices = const [],
    this.remaining = 0,
  });

  /// The field this answers — `hpi.duration`. Sent back with the answer so an
  /// answer given while the next question was already on its way cannot be
  /// filed against the wrong field.
  final String fieldPath;

  final String section;

  /// What a clinician calls it. Not what the patient is asked — that is
  /// [prompt] — but it is what a review screen prints beside the answer.
  final String label;

  final CaseQuestionKind kind;

  /// The sentence the patient reads, phrased by the server.
  final String prompt;

  /// The same question with no answer hint — what it sounds like out loud.
  ///
  /// [prompt] ends in the shape of the expected answer, "You can answer yes or
  /// no.", which is written for the row of tiles underneath it. In a spoken
  /// conversation it is the clause that makes every question sound like a form,
  /// so the agent says this instead and the screen shows this while a
  /// conversation is running.
  ///
  /// Empty against a server that does not send it; [spoken] resolves that.
  final String spokenPrompt;

  /// The question as it is said aloud, falling back to the written one.
  String get spoken => spokenPrompt.trim().isEmpty ? prompt : spokenPrompt;

  /// The field's own options, in the engine's snake_case. Empty for a question
  /// with no fixed answers.
  final List<String> choices;

  /// How many applicable questions, including this one, are still unanswered.
  final int remaining;

  bool get isEmpty => fieldPath.isEmpty;

  /// The tiles the touch row shows.
  ///
  /// **"I don't know" and "Skip" are on every question, and they are never the
  /// same tile as "No".** That is the whole rule, and it is here rather than in
  /// the view so it can be held still by a test:
  ///
  ///  * a yes/no question offers exactly four — yes, no, not sure, skip — which
  ///    is what `UnknownAnswerRow` draws as four equal tiles;
  ///  * a question with its own options offers those, and then the same two;
  ///  * a question with no options at all — free text, a duration, a number —
  ///    still offers the two, so there is a way past every question without
  ///    typing a word.
  ///
  /// A "Yes" tile is not forced onto a question that has no yes: a 0–10
  /// severity scale with a Yes on it is a tile whose answer the engine would
  /// reject, and a control that cannot be answered correctly teaches the
  /// patient to distrust the row it sits in.
  List<CaseAnswerOption> get touchOptions => [
        for (final choice in choices)
          CaseAnswerOption(
            token: choice,
            label: humaniseChoice(choice),
            modality: CaseAnswerModality.choice,
          ),
        CaseAnswerOption.unsure,
        CaseAnswerOption.skip,
      ];

  /// True where the four-tile row is the right control: the question has two
  /// clinical answers and the two reserved ones.
  bool get isYesNo => kind == CaseQuestionKind.boolean;

  /// How wide to lay the touch row out.
  ///
  /// Two for a handful of tiles, four once there are enough that two columns
  /// would run off the bottom of the screen — a 0–10 scale is thirteen tiles,
  /// and seven rows of two puts "Skip" below the fold on every phone.
  int get touchColumns => touchOptions.length > 8 ? 4 : 2;

  /// `woke_up_with_it` → `Woke up with it`.
  ///
  /// The engine stores tokens in snake_case and speaks them as words; this is
  /// the same conversion its `fallbackPhrasing` does, so the tile and the
  /// spoken prompt name the option identically.
  static String humaniseChoice(String token) {
    final words = token.replaceAll('_', ' ').trim();
    if (words.isEmpty) return token;
    return words[0].toUpperCase() + words.substring(1);
  }

  static const CaseQuestion empty = CaseQuestion(
    fieldPath: '',
    section: '',
    label: '',
    kind: CaseQuestionKind.other,
    prompt: '',
  );

  factory CaseQuestion.fromJson(Map<String, dynamic> json) => CaseQuestion(
        fieldPath: asString(json['fieldPath']),
        section: asString(json['section']),
        label: asString(json['label']),
        kind: CaseQuestionKind.resolve(asStringOrNull(json['kind'])),
        prompt: asString(json['prompt']),
        spokenPrompt: asString(json['spokenPrompt']),
        choices: asStringList(json['choices']),
        remaining: asInt(json['remaining']),
      );

  /// Null-safe: `nextQuestion` is null when the interview has run out.
  ///
  /// Deliberately **not** `asRefObject`, which is for a populated relation and
  /// refuses anything without an `_id`. A question is an embedded object with
  /// no identity of its own, so that helper reads every one of them as absent —
  /// and an absent question is a screen with nothing on it, which is what this
  /// cost the first time.
  static CaseQuestion? maybeFrom(dynamic value) {
    if (value is! Map) return null;
    final question = CaseQuestion.fromJson(value.cast<String, dynamic>());
    return question.isEmpty ? null : question;
  }
}

// ── Progress ────────────────────────────────────────────────────────────────

/// One section's completion, as the server counts it.
class CaseSectionProgress {
  const CaseSectionProgress({
    this.section = '',
    this.title = '',
    this.expected = 0,
    this.addressed = 0,
    this.percent = 0,
    this.complete = false,
  });

  final String section;
  final String title;
  final int expected;
  final int addressed;
  final int percent;
  final bool complete;

  factory CaseSectionProgress.fromJson(Map<String, dynamic> json) =>
      CaseSectionProgress(
        section: asString(json['section']),
        title: asString(json['title']),
        expected: asInt(json['expected']),
        addressed: asInt(json['addressed']),
        percent: asInt(json['percent']),
        complete: asBool(json['complete']),
      );
}

/// How far through the interview is — **the server's count, not the phone's**.
///
/// [expected] is the number of questions that apply to *this* patient, which
/// changes as answers arrive: a chest-pain complaint unlocks the cardiac
/// review, and a phone counting the bubbles on screen would have promised a
/// finish line that just moved.
class CaseProgress {
  const CaseProgress({
    this.expected = 0,
    this.addressed = 0,
    this.percent = 0,
    this.complete = false,
    this.sections = const [],
  });

  final int expected;
  final int addressed;
  final int percent;
  final bool complete;
  final List<CaseSectionProgress> sections;

  static const CaseProgress empty = CaseProgress();

  /// Which question the patient is on, one-based.
  ///
  /// Addressed plus one, clamped into the range: a rail reading "Question 12
  /// of 11" is a patient who believes the form is broken, and the clamp costs
  /// nothing.
  int get step => expected == 0 ? 0 : (addressed + 1).clamp(1, expected);

  factory CaseProgress.fromJson(Map<String, dynamic> json) => CaseProgress(
        expected: asInt(json['expected']),
        addressed: asInt(json['addressed']),
        percent: asInt(json['percent']),
        complete: asBool(json['complete']),
        sections: asModelList(json['sections'], CaseSectionProgress.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'expected': expected,
        'addressed': addressed,
        'percent': percent,
        'complete': complete,
      };
}

// ── Safety ──────────────────────────────────────────────────────────────────

/// Something the patient described that should not wait.
///
/// [message] is the only text on it, and that is structural rather than
/// economical: the rule set's own `title` for the chest-pain screen names the
/// symptom cluster and its `clinicianSummary` names the syndrome. Neither
/// crosses this boundary. What does is a routing instruction — go and tell
/// somebody — checked server-side against diagnostic-language patterns.
class CaseRedFlag {
  const CaseRedFlag({
    this.id = '',
    this.severity = '',
    this.message = '',
    this.triggeredAt,
  });

  final String id;

  /// `critical`, `urgent` or `advisory`.
  final String severity;

  final String message;
  final DateTime? triggeredAt;

  bool get isCritical => severity == 'critical';

  factory CaseRedFlag.fromJson(Map<String, dynamic> json) => CaseRedFlag(
        id: asString(json['id']),
        severity: asString(json['severity']),
        message: asString(json['message']),
        triggeredAt: asDate(json['triggeredAt']),
      );
}

// ── The session ─────────────────────────────────────────────────────────────

/// Whether consent has been given, and to which wording.
class CaseConsent {
  const CaseConsent({
    this.given = false,
    this.givenAt,
    this.version,
    this.requiredVersion = '',
  });

  final bool given;
  final DateTime? givenAt;

  /// The wording that was agreed to, if any.
  final String? version;

  /// The wording the client should be presenting. Read from the server rather
  /// than pinned in the app: which text somebody agreed to is a fact about the
  /// session, and an app shipping a stale constant would record agreement to
  /// a paragraph nobody read.
  final String requiredVersion;

  /// True when the interview may start asking.
  bool get isSettled => given && (version ?? '').isNotEmpty;

  factory CaseConsent.fromJson(Map<String, dynamic> json) => CaseConsent(
        given: asBool(json['given']),
        givenAt: asDate(json['givenAt']),
        version: asStringOrNull(json['version']),
        requiredVersion: asString(json['requiredVersion']),
      );
}

/// The whole of `GET /sessions/:id` — and of `POST /sessions`, which answers
/// with the same shape plus `resumed`.
class CaseSession {
  const CaseSession({
    this.id = '',
    this.patientId = '',
    this.kind = '',
    this.language = 'en',
    this.inputLanguage,
    this.outputLanguage,
    this.status = '',
    this.consent = const CaseConsent(),
    this.startedAt,
    this.lastActiveAt,
    this.submittedAt,
    this.progress = CaseProgress.empty,
    this.interviewStatus = CaseInterviewStatus.ready,
    this.currentQuestion,
    this.answeredCount = 0,
    this.redFlags = const [],
    this.patientMessage,
    this.resumed = false,
  });

  final String id;
  final String patientId;
  final String kind;

  /// The session's language, before the server learned to keep two.
  ///
  /// Still read, because it is the floor [inputLanguage] and [outputLanguage]
  /// fall back to — a deployment that has not split yet answers with this one
  /// tag and means it for both halves.
  final String language;

  /// The language the **patient speaks**, and the only one `/stt` is told.
  ///
  /// Null where the server sent no split. Null rather than [language] because
  /// the difference matters to the caller: one is the server saying which
  /// language to listen for, the other is the app guessing, and only the caller
  /// knows what it has to fall back on.
  final String? inputLanguage;

  /// The language the questions are **written and read aloud in** — English,
  /// under the rule that the patient answers in their own language and reads
  /// and hears this one. Null where the server sent no split.
  final String? outputLanguage;

  /// `in_progress`, `review`, `submitted` or `abandoned`.
  final String status;

  final CaseConsent consent;
  final DateTime? startedAt;
  final DateTime? lastActiveAt;
  final DateTime? submittedAt;
  final CaseProgress progress;
  final CaseInterviewStatus interviewStatus;

  /// The question on screen — read off the turn log rather than re-selected,
  /// so a client that dropped the last response gets the same question back
  /// instead of skipping one.
  final CaseQuestion? currentQuestion;

  final int answeredCount;
  final List<CaseRedFlag> redFlags;

  /// The one sentence to put in front of the patient, from the most severe
  /// rule that has fired. Null when nothing has.
  final String? patientMessage;

  /// True when the server handed back an interview that was already open
  /// rather than creating one. 200 either way: from the patient's side both
  /// are "carry on".
  final bool resumed;

  static const CaseSession empty = CaseSession();

  bool get isEmpty => id.isEmpty;
  bool get isSubmitted => status == 'submitted';
  bool get isOpen => status == 'in_progress' || status == 'review';

  /// True once every applicable question has been addressed **and** nothing is
  /// still being read. Both halves: `awaiting_extraction` looks finished and
  /// is not.
  bool get isFinished => interviewStatus.isFinished;

  factory CaseSession.fromJson(Map<String, dynamic> json) => CaseSession(
        id: asString(json['id']),
        patientId: asString(json['patientId']),
        kind: asString(json['kind']),
        language: asString(json['language'], fallback: 'en'),
        inputLanguage: _languageTag(
          json,
          const ['inputLanguage', 'input_language', 'sttLanguage'],
        ),
        outputLanguage: _languageTag(
          json,
          const ['outputLanguage', 'output_language', 'ttsLanguage'],
        ),
        status: asString(json['status']),
        consent: CaseConsent.fromJson(asMap(json['consent'])),
        startedAt: asDate(json['startedAt']),
        lastActiveAt: asDate(json['lastActiveAt']),
        submittedAt: asDate(json['submittedAt']),
        progress: CaseProgress.fromJson(asMap(json['progress'])),
        interviewStatus:
            CaseInterviewStatus.resolve(asStringOrNull(json['interviewStatus'])),
        currentQuestion: CaseQuestion.maybeFrom(json['currentQuestion']),
        answeredCount: asInt(json['answeredCount']),
        redFlags: asModelList(json['redFlags'], CaseRedFlag.fromJson),
        patientMessage: asStringOrNull(json['patientMessage']),
        resumed: asBool(json['resumed']),
      );

  /// The first of [keys] the payload actually carries, or null.
  ///
  /// Tolerant for the reason `CaseLanguage.fromJson` is: the two halves of the
  /// session's language are being split on the server while this screen is
  /// being written, and `inputLanguage` / `input_language` / `sttLanguage` are
  /// three names two people would each pick one of. Null on absence, never a
  /// default — a parser that answered `en` here would be the app deciding what
  /// the patient speaks.
  static String? _languageTag(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final tag = asStringOrNull(json[key]);
      if (tag != null) return tag;
    }
    return null;
  }
}

// ── One turn ────────────────────────────────────────────────────────────────

/// What the server made of the answer just given.
class CaseAcceptedAnswer {
  const CaseAcceptedAnswer({
    this.fieldPath,
    this.presence = FactPresence.notAssessed,
    this.value,
    this.reason,
    this.needsPatientConfirmation = false,
    this.factId,
  });

  final String? fieldPath;

  /// What the answer was read as. Derived in code from the patient's own
  /// words — never asserted by the client and never by the model.
  final FactPresence presence;

  /// The recorded value, when there is one. Absent for every presence except
  /// [FactPresence.recorded].
  final String? value;

  /// Which rule in the derivation decided, so an odd reading can be argued
  /// with rather than guessed at.
  final String? reason;

  /// True when the reading is defensible but not certain. The answer should be
  /// shown back before it is treated as settled.
  final bool needsPatientConfirmation;

  /// The fact row this created. Null when the answer produced none — which is
  /// what happens when a value fails the field's shape, and is why the
  /// question comes round again rather than carrying a guess into the chart.
  final String? factId;

  factory CaseAcceptedAnswer.fromJson(Map<String, dynamic> json) =>
      CaseAcceptedAnswer(
        fieldPath: asStringOrNull(json['fieldPath']),
        presence: FactPresence.resolve(asStringOrNull(json['presence'])),
        value: asStringOrNull(json['value']),
        reason: asStringOrNull(json['reason']),
        needsPatientConfirmation: asBool(json['needsPatientConfirmation']),
        factId: asStringOrNull(json['factId']),
      );
}

/// Whether the model was handed this answer, and why it was or was not.
class CaseExtraction {
  const CaseExtraction({this.queued = false, this.reason = ''});

  /// True when the answer went to the model to be read properly.
  ///
  /// The screen's job when this is true is to say so quietly and carry on: the
  /// model takes eight to twenty seconds on the hardware this was measured on,
  /// and the next question is already on screen.
  final bool queued;

  final String reason;

  factory CaseExtraction.fromJson(Map<String, dynamic> json) => CaseExtraction(
        queued: asBool(json['queued']),
        reason: asString(json['reason']),
      );
}

/// What the interview said back to an interruption.
///
/// Set on a turn where the patient asked something instead of answering. The
/// server has already replied and re-asked, so [CaseTurnResult.nextQuestion]
/// on such a turn is the question that was on the table, not a new one.
///
/// [intent] is the member of a closed set the server holds — `repeat`,
/// `why_ask`, `is_it_serious` and the rest — and it is what the screen draws
/// from, through `PatientText.asideReply`. [reply] is the server's own wording
/// and is what the room said out loud; it is on this object so a voice client
/// can speak it, and is the last resort for a screen that meets an intent this
/// build does not know.
class CaseAside {
  const CaseAside({this.intent = '', this.reply = ''});

  final String intent;
  final String reply;

  bool get isEmpty => intent.isEmpty && reply.isEmpty;

  static CaseAside? maybeFrom(Object? raw) {
    if (raw is! Map) return null;
    final aside = CaseAside(
      intent: asString(raw['intent']),
      reply: asString(raw['reply']),
    );
    return aside.isEmpty ? null : aside;
  }
}

/// `POST /sessions/:id/turns` — an answer in, the next question out.
class CaseTurnResult {
  const CaseTurnResult({
    this.turnId = '',
    this.sessionId = '',
    this.accepted = const CaseAcceptedAnswer(),
    this.extraction = const CaseExtraction(),
    this.nextQuestion,
    this.interviewStatus = CaseInterviewStatus.ready,
    this.progress = CaseProgress.empty,
    this.redFlags = const [],
    this.patientMessage,
    this.aside,
    this.serverTimeMs = 0,
  });

  final String turnId;
  final String sessionId;
  final CaseAcceptedAnswer accepted;
  final CaseExtraction extraction;

  /// Null means there is nothing askable — which is not the same as finished.
  /// [interviewStatus] tells the two apart.
  final CaseQuestion? nextQuestion;

  final CaseInterviewStatus interviewStatus;
  final CaseProgress progress;

  /// Only the flags that fired on **this** turn.
  final List<CaseRedFlag> redFlags;

  final String? patientMessage;

  /// Null on an ordinary turn. Set when the patient interrupted rather than
  /// answered — and then [nextQuestion] is the same question again.
  final CaseAside? aside;

  /// What the handler cost on the server. Reported because the whole design is
  /// built around it staying small; read in debug logging, never on screen.
  final int serverTimeMs;

  factory CaseTurnResult.fromJson(Map<String, dynamic> json) => CaseTurnResult(
        turnId: asString(json['turnId']),
        sessionId: asString(json['sessionId']),
        accepted: CaseAcceptedAnswer.fromJson(asMap(json['accepted'])),
        extraction: CaseExtraction.fromJson(asMap(json['extraction'])),
        nextQuestion: CaseQuestion.maybeFrom(json['nextQuestion']),
        interviewStatus:
            CaseInterviewStatus.resolve(asStringOrNull(json['interviewStatus'])),
        progress: CaseProgress.fromJson(asMap(json['progress'])),
        redFlags: asModelList(json['redFlags'], CaseRedFlag.fromJson),
        patientMessage: asStringOrNull(json['patientMessage']),
        aside: CaseAside.maybeFrom(json['aside']),
        serverTimeMs: asInt(json['serverTimeMs']),
      );
}

// ── Voice ───────────────────────────────────────────────────────────────────

/// What the recogniser made of a spoken answer.
///
/// [confidence] is a **real measurement** from the speech recogniser, unlike
/// anything a language model reports about itself — the backend ledger records
/// a model returning a constant 0.95 on every fact it produced. This one moves,
/// so `AnswerConfidence.fromScore` has something to read.
class CaseTranscript {
  const CaseTranscript({
    this.text = '',
    this.confidence,
    this.language,
    this.durationMs = 0,
  });

  final String text;

  /// 0…1, or null when the recogniser gave none — which reads as "check this",
  /// never as "clear".
  final double? confidence;

  final String? language;
  final int durationMs;

  bool get isEmpty => text.trim().isEmpty;

  factory CaseTranscript.fromJson(Map<String, dynamic> json) => CaseTranscript(
        text: asString(json['text']),
        confidence: json['confidence'] == null
            ? null
            : asDouble(json['confidence']),
        language: asStringOrNull(json['language']),
        durationMs: asInt(json['durationMs']),
      );
}

/// One language the hospital's sidecar can currently work in.
///
/// The row `GET /api/case-taking/languages` answers with. It carries a code and
/// two capabilities and **no names**: what a language is called in its own
/// script is the app's to hold, because that string is the one line on the
/// picker a patient who reads nothing else is depending on, and a name arriving
/// over the wire is a name that can arrive truncated, mojibake'd or absent.
///
/// Both flags are nullable and both parse to null when the key is missing,
/// which is the difference between "the server says no" and "the server did not
/// say". Only the first should override what the app already believes — see
/// `PatientLanguageOffer`, which is where they meet.
class CaseLanguage {
  const CaseLanguage({required this.code, this.canSpeak, this.canHear});

  /// `en`, `ta`, `or`. Matched against the app's own catalogue, so a code this
  /// build cannot name is dropped rather than rendered.
  final String code;

  /// Whether a patient can **speak** this language to the app — the
  /// transcriber's side. Null when the payload said nothing about it.
  final bool? canSpeak;

  /// Whether a patient who picks this row will be **read to** at all.
  ///
  /// Read from `outputTts` in preference to `tts`, and the difference is not
  /// cosmetic. Since the interview answers in English whatever the patient
  /// speaks, the per-row `tts` flag now means "a voice exists for *that*
  /// language on this box" — which for Tamil is false, and which has nothing
  /// to do with whether a Tamil-speaking patient hears their questions. They
  /// hear English, and they hear it fine.
  ///
  /// `outputTts` is the flag that answers the question a speaker button
  /// actually asks. Reading `tts` here would withdraw read-aloud from ten of
  /// the eleven languages — from exactly the patients it exists for, the ones
  /// least able to read the screen.
  final bool? canHear;

  bool get isEmpty => code.isEmpty;

  /// Tolerant on purpose.
  ///
  /// This route is being built alongside this screen, and the two halves of the
  /// pair that decide the flags — `stt`/`tts`, `speech`/`voice`, `canSpeak`/
  /// `canHear` — are exactly the names two people would each pick one of. A
  /// parser that insisted on one spelling would answer a working endpoint with
  /// a picker that silently withdrew every microphone.
  factory CaseLanguage.fromJson(Map<String, dynamic> json) => CaseLanguage(
        code: asString(json['code'] ?? json['language'] ?? json['id']),
        canSpeak: _flag(json, const ['canSpeak', 'speech', 'stt', 'transcribe']),
        // `outputTts` first: it is the only one of these that answers "will
        // this patient hear anything". See the note on [canHear].
        canHear: _flag(
          json,
          const ['outputTts', 'canHear', 'voice', 'tts', 'speak'],
        ),
      );

  /// The first of [keys] the payload actually carries, or null.
  ///
  /// Null rather than a default, because absence here means "the server did not
  /// answer this question" and a default would be the app answering it.
  static bool? _flag(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return asBool(value, fallback: true);
    }
    return null;
  }
}
