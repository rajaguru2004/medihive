/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the words a patient reads
///
/// Every other string in this app is read by somebody who works here. These
/// are read by somebody who does not: a patient holding a borrowed tablet in a
/// waiting room, answering questions about their own body before anybody has
/// seen them. DESIGN.md §9 is the register — plain, specific, about the
/// patient rather than the system — and it matters more here than anywhere
/// else in the product, because this is the only surface where a badly worded
/// line produces a *wrong clinical answer* rather than a confused user.
///
/// **This build ships English and only English.** Translation is the last
/// phase of this project, deliberately: a vocabulary that is still moving is
/// one that gets translated twice. What this file is for is making that phase
/// cheap — every patient-facing line already has a stable key, already flows
/// through one function, and already carries its placeholders as `{name}`
/// rather than as Dart interpolation. The later phase installs a lookup with
/// [useLookup] and **not one call site changes**.
///
/// That is the whole seam. There is no `Translations` subclass here, no
/// `flutter_localizations`, and nothing touching the staff screens — adding
/// any of those now would be building the phase rather than the seam.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// A line of patient-facing copy, by key, with the English as the fallback.
///
/// The lookup is handed the English rather than only the key so that a
/// missing translation renders the sentence somebody wrote instead of the
/// identifier a developer wrote. A patient seeing `answer.unknown` on screen
/// is worse than a patient seeing it in the wrong language.
typedef PatientTextLookup = String Function(String key, String english);

/// The sentences this surface says out loud.
///
/// Read as `PatientText.iDontKnow`. Never assemble one of these by
/// concatenation at a call site: a line built out of fragments is a line that
/// cannot be re-ordered, and word order is the first thing translation moves.
abstract final class PatientText {
  /// Installed by the translation phase; null for as long as this build ships
  /// one language.
  ///
  /// Static because the alternative — threading a resolver through every
  /// widget in `app_bento_conversation.dart` — is an argument on forty
  /// constructors to serve a phase that has not happened yet. Passing null
  /// puts the build back on English, which is what a test that needs a known
  /// string does.
  static PatientTextLookup? _lookup;

  static void useLookup(PatientTextLookup? lookup) => _lookup = lookup;

  /// Resolves one line and fills its placeholders.
  ///
  /// Substitution happens *after* the lookup, on whichever string won, so a
  /// translated template written with the same `{step}` / `{total}` names
  /// works with no help from the call site. This is the reason the
  /// parameterised lines below are not plain Dart interpolation: `'Question
  /// $step of $total'` has already lost its placeholders by the time anything
  /// could translate it.
  static String _of(
    String key,
    String english, [
    Map<String, String> values = const {},
  ]) {
    var text = _lookup?.call(key, english) ?? english;
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  // ── The four answers ──────────────────────────────────────────────────────
  //
  // Four, not two. See `UnknownAnswerRow` in the conversation kit for why the
  // last two are as load-bearing as the first two.

  static String get yes => _of('answer.yes', 'Yes');
  static String get no => _of('answer.no', 'No');
  static String get iDontKnow => _of('answer.unknown', "I don't know");
  static String get skip => _of('answer.skip', 'Skip');

  /// What a recorded answer reads as in the transcript above, where the row of
  /// buttons is no longer on screen to give it context.
  static String get notSure => _of('answer.unknown.past', 'Not sure');
  static String get skipped => _of('answer.skip.past', 'Skipped');

  /// Going back to an answer already given. Present on every answer worth
  /// having: somebody who realises at question nine that they misread question
  /// three and cannot go back abandons the form, and an abandoned form is
  /// worse than a wrong one because nobody knows it is wrong.
  static String get change => _of('answer.change', 'Change');

  // ── Asking, and answering out loud ────────────────────────────────────────

  static String get speakYourAnswer =>
      _of('mic.idle', 'Answer out loud instead');
  static String get listening => _of('mic.listening', 'Listening');
  static String get tapWhenFinished =>
      _of('mic.stop', 'Tap when you have finished');
  static String get writingThatDown =>
      _of('mic.working', 'Writing that down');

  /// Above the text the app thinks it heard, before the patient confirms it.
  static String get youSaid => _of('draft.heading', 'You said');
  static String get thatIsRight => _of('draft.accept', "That's right");
  static String get sayItAgain => _of('draft.retry', 'Say it again');
  static String get typeItInstead => _of('draft.type', 'Type it instead');

  // ── How sure the app is that it heard correctly ───────────────────────────

  static String get heardClearly => _of('confidence.clear', 'Clear');
  static String get pleaseCheckThis => _of('confidence.unsure', 'Check this');
  static String get didNotCatchThat =>
      _of('confidence.unheard', 'Not heard');

  // ── Where an answer came from ─────────────────────────────────────────────

  static String get spoken => _of('source.spoken', 'Spoken');
  static String get typed => _of('source.typed', 'Typed');
  static String get chosen => _of('source.chosen', 'Chosen');
  static String get fromYourRecord => _of('source.record', 'From your record');

  // ── Progress ──────────────────────────────────────────────────────────────

  /// `Question 3 of 11`.
  static String questionProgress(int step, int total) => _of(
        'progress.step',
        'Question {step} of {total}',
        {'step': '$step', 'total': '$total'},
      );

  // ── A red flag ────────────────────────────────────────────────────────────
  //
  // These three lines are the only copy `RedFlagNotice` can put on screen, and
  // none of them names a condition. What the patient described may be a heart
  // attack or may be indigestion; the app is not the thing that decides, and a
  // sentence that guesses is either a diagnosis nobody qualified made or a
  // false alarm that teaches the next patient to ignore the notice.

  static String get tellANurseNow => _of('redflag.heading', 'Tell a nurse now');
  static String get doNotWaitForTheRest => _of(
        'redflag.body',
        'Do not wait until the end of these questions. Show this screen to '
            'somebody at the desk.',
      );
  static String get tellANurse => _of('redflag.action', 'Tell a nurse');

  // ── When the device says no ───────────────────────────────────────────────
  //
  // Each one names the problem and the way out, per DESIGN.md §9. A patient
  // who declines the microphone has not made a mistake and is not told they
  // have; they are told what they can do instead.

  static String get microphoneDenied => _of(
        'permission.microphone.denied',
        'Without the microphone you cannot answer out loud. You can type your '
            'answer instead.',
      );
  static String get microphoneBlocked => _of(
        'permission.microphone.blocked',
        'The microphone is turned off for MediHive. Turn it on in Settings, or '
            'type your answer instead.',
      );
  static String get cameraDenied => _of(
        'permission.camera.denied',
        'Without the camera you cannot take a photo here. You can describe it '
            'instead.',
      );
  static String get cameraBlocked => _of(
        'permission.camera.blocked',
        'The camera is turned off for MediHive. Turn it on in Settings, or '
            'describe it instead.',
      );
  static String get photosDenied => _of(
        'permission.photos.denied',
        'Without access to your photos you cannot attach one. You can take a '
            'new photo instead.',
      );
  static String get photosBlocked => _of(
        'permission.photos.blocked',
        'Your photos are turned off for MediHive. Turn them on in Settings, or '
            'take a new photo instead.',
      );
  static String get openSettings => _of('permission.settings', 'Open Settings');
}
