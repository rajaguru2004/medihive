import 'package:flutter/widgets.dart';

/// Widget keys for the interview.
///
/// One screen, and more keys than most, because almost everything on it is a
/// control a flow has to drive: four ways to answer one question, a microphone
/// with three states, and a notice that must be provable as present *and*
/// provable as saying nothing it should not.
///
/// The answer tiles are keyed by their **token** rather than by their position.
/// A key of `case_answer_1` would pass just as happily if "No" and "I don't
/// know" swapped places, which is the one rearrangement on this screen that
/// changes what lands on a patient's chart.
abstract final class CaseTakingKeys {
  // ── The screen ────────────────────────────────────────────────────────────

  static const Key screen = Key('case_taking_screen');

  /// The rail that says which question this is. Reads server state; see
  /// `CaseProgress`.
  static const Key progress = Key('case_taking_progress');

  /// The scrolling conversation.
  static const Key transcript = Key('case_taking_transcript');

  /// The question on the table, at the top of the answer area.
  static const Key question = Key('case_taking_question');

  /// Where the interview says it could not be opened, with its retry.
  static const Key error = Key('case_taking_error');

  /// Where an answer that did not reach the hospital says so.
  ///
  /// A second key rather than a reuse of [error]: the two can be on screen at
  /// once — a turn fails, the patient retries, and the retry fails the load —
  /// and one key in two places is a `findsOneWidget` that fails for a reason
  /// nobody can read from the message.
  static const Key answerError = Key('case_taking_answer_error');

  /// The whole answer area: tiles, keyboard and microphone.
  static const Key answers = Key('case_taking_answers');

  /// Where the panel says an answer is on its way.
  ///
  /// Keyed because its job is to be *present*: between the question moving into
  /// the conversation and the next one arriving, this is the only thing on the
  /// answer panel, and on a dropped connection that gap is the connect timeout
  /// rather than the milliseconds the happy path measures.
  static const Key sending = Key('case_taking_sending');

  // ── Answering by touch ────────────────────────────────────────────────────

  /// One tile, by the token it sends.
  ///
  /// `case_answer_not_sure` and `case_answer_no` are different strings for
  /// different clinical facts, which is exactly the property a test of this
  /// screen exists to hold still.
  static Key answer(String token) => Key('case_answer_$token');

  /// The tile that moves past a question. Sends no value — a skip carries its
  /// meaning in the modality.
  static const Key skip = Key('case_answer_skip');

  // ── Answering by keyboard ─────────────────────────────────────────────────

  static const Key typed = Key('case_taking_typed_answer');
  static const Key send = Key('case_taking_send');

  // ── Answering out loud ────────────────────────────────────────────────────

  static const Key mic = Key('case_taking_mic');

  /// The bars that move with the patient's voice.
  static const Key listening = Key('case_taking_listening');

  /// What the app thinks it heard, before it is filed.
  static const Key draft = Key('case_taking_transcript_draft');
  static const Key draftAccept = Key('case_taking_draft_accept');
  static const Key draftRetry = Key('case_taking_draft_retry');

  /// The sentence shown where the microphone is not available — a refused
  /// permission, or a transcriber that is down. Keyed rather than matched on
  /// words because the assertion is that the screen *says something and keeps
  /// working*, not which sentence it chose.
  static const Key voiceUnavailable = Key('case_taking_voice_unavailable');

  // ── Safety ────────────────────────────────────────────────────────────────

  /// The one red thing on this surface. Present means a rule fired; what it
  /// may contain is fixed by `RedFlagNotice`, which can render no free text
  /// except the patient's own quoted words.
  static const Key redFlag = Key('case_taking_red_flag');

  // ── The end ───────────────────────────────────────────────────────────────

  /// Shown once every applicable question has been addressed **and** nothing is
  /// still being read.
  static const Key finished = Key('case_taking_finished');
  static const Key finishedDone = Key('case_taking_finished_done');

  /// Where the screen says an answer is still being understood. Quiet, and
  /// never in the way of the next question.
  static const Key stillReading = Key('case_taking_still_reading');
}
