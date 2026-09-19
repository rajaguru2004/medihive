import '../../theme/theme.dart';

/// One line of the conversation as it stands on screen.
///
/// Deliberately **not** the server's `CaseTurn`. This is what is drawn: who
/// spoke, the words, and the marks that qualify them. The server's turn log is
/// the record and this is a view of it, which matters because the two disagree
/// on purpose in one place — an answer that failed to send is removed from here
/// and was never in the record at all.
class InterviewTurn {
  const InterviewTurn({
    required this.speaker,
    required this.text,
    this.source,
    this.confidence,
    this.fieldPath,
    this.stillReading = false,
  });

  final ConversationSpeaker speaker;
  final String text;

  /// How the answer arrived — spoken, typed or tapped. A clinician reading
  /// this back needs to know which, because they are three strengths of
  /// evidence. Null on an assistant turn.
  final AnswerSource? source;

  /// How well the app heard it. Only ever set on a spoken answer: a tapped
  /// tile has no transcription to be unsure about, and marking one "Clear"
  /// would be the app vouching for something it did not do.
  final AnswerConfidence? confidence;

  /// Which question this belongs to.
  final String? fieldPath;

  /// True while the model is still reading this answer properly.
  ///
  /// Carried on the turn rather than held as one flag on the controller so it
  /// can only ever describe the bubble it is drawn under. It is cleared when
  /// the next answer is given — see `CaseTakingController._appendAnswer` for
  /// why the mark's life is one question long.
  final bool stillReading;

  InterviewTurn settled() => InterviewTurn(
        speaker: speaker,
        text: text,
        source: source,
        confidence: confidence,
        fieldPath: fieldPath,
      );

  InterviewTurn reading() => InterviewTurn(
        speaker: speaker,
        text: text,
        source: source,
        confidence: confidence,
        fieldPath: fieldPath,
        stillReading: true,
      );

  /// A question the interview asked.
  factory InterviewTurn.asked(String prompt, {String? fieldPath}) =>
      InterviewTurn(
        speaker: ConversationSpeaker.assistant,
        text: prompt,
        fieldPath: fieldPath,
      );

  /// Something the interview said that was not a question.
  ///
  /// Today there is exactly one kind: the answer to an interruption — the
  /// patient asked "why do you ask?" and was told. It is an assistant turn like
  /// a question, because that is who said it, and it carries no `fieldPath`
  /// because it belongs to no question. The question it interrupted is asked
  /// again straight after and arrives as its own turn.
  factory InterviewTurn.said(String text) => InterviewTurn(
        speaker: ConversationSpeaker.assistant,
        text: text,
      );

  /// What the patient answered.
  factory InterviewTurn.answered(
    String text, {
    required AnswerSource source,
    AnswerConfidence? confidence,
    String? fieldPath,
  }) =>
      InterviewTurn(
        speaker: ConversationSpeaker.patient,
        text: text,
        source: source,
        confidence: confidence,
        fieldPath: fieldPath,
      );

  Map<String, dynamic> toJson() => {
        'speaker': speaker.name,
        'text': text,
        'source': source?.name,
        'confidence': confidence?.name,
        'fieldPath': fieldPath,
      };

  /// Reads a turn back out of the write-behind snapshot.
  ///
  /// A speaker this build cannot read resolves to the **assistant**, not the
  /// patient. Drawing an unreadable line as something the patient said would
  /// put words in their mouth on a screen they are about to confirm; drawing it
  /// as a question the app asked is merely odd.
  factory InterviewTurn.fromJson(Map<String, dynamic> json) => InterviewTurn(
        speaker: json['speaker'] == ConversationSpeaker.patient.name
            ? ConversationSpeaker.patient
            : ConversationSpeaker.assistant,
        text: (json['text'] ?? '').toString(),
        source: _sourceOf(json['source']),
        confidence: _confidenceOf(json['confidence']),
        fieldPath: json['fieldPath']?.toString(),
      );

  static AnswerSource? _sourceOf(Object? raw) {
    for (final source in AnswerSource.values) {
      if (source.name == raw) return source;
    }
    return null;
  }

  static AnswerConfidence? _confidenceOf(Object? raw) {
    for (final confidence in AnswerConfidence.values) {
      if (confidence.name == raw) return confidence;
    }
    return null;
  }
}
