import 'package:flutter/widgets.dart';

/// Widget keys for the intake a clinician reads — the case a patient filled in
/// themselves, opened from their chart.
///
/// Keyed per **field path** for the same reason `CaseReviewKeys` is: the lines
/// come from the engine's field registry in the registry's own order, and that
/// order changes with the patient. "The third row" is a different question for
/// a different person; `hpi.duration` is `hpi.duration` for everybody.
abstract final class CaseIntakeKeys {
  static const Key screen = Key('case_intake_screen');
  static const Key error = Key('case_intake_error');

  /// Who wrote this, how complete it was, and when it was sent.
  static const Key header = Key('case_intake_header');

  /// The sentence that says nobody has checked any of this. The one line on
  /// the screen whose absence would change how a clinician reads everything
  /// under it, so it is keyed rather than matched on words.
  static const Key unverifiedNotice = Key('case_intake_unverified');

  /// "This build could not read the document." Keyed because the state it
  /// distinguishes — an unreadable case versus an empty one — is invisible on
  /// screen otherwise, and one of the two readings is a clinical claim about
  /// the patient.
  static const Key unreadableNotice = Key('case_intake_unreadable');

  /// The rules that fired, with their own titles — the part the patient's view
  /// of the same case deliberately does not show.
  static const Key redFlags = Key('case_intake_red_flags');
  static Key redFlag(String id) => Key('case_intake_red_flag_$id');

  /// §36: the questions nobody answered, printed rather than omitted. Keyed
  /// because an omitted list and an empty one look identical on screen and
  /// only one of them is honest.
  static const Key missing = Key('case_intake_missing');

  static Key section(String key) => Key('case_intake_section_$key');
  static Key item(String fieldPath) => Key('case_intake_item_$fieldPath');

  /// The whole case as text, for a ward round or a note.
  static const Key transcript = Key('case_intake_transcript');
  static const Key copyTranscript = Key('case_intake_copy');
}
