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
/// **Every line in this file is still English and only English.** Translation
/// is the last phase of this project, deliberately: a vocabulary that is still
/// moving is one that gets translated twice. What this file is for is making
/// that phase cheap — every patient-facing line already has a stable key,
/// already flows through one function, and already carries its placeholders as
/// `{name}` rather than as Dart interpolation. The later phase installs a
/// lookup with [useLookup] and **not one call site changes**.
///
/// The patient now *chooses* a language, and that is not the same thing and
/// must not be read as it. What the choice moves is one thing: **the language
/// the patient answers in.** `/stt` is told which language to listen for and
/// the server turns what it hears into English. Everything in the other
/// direction — the questions, the read-aloud voice, and every sentence in this
/// file — is English. So a patient who picks Tamil speaks Tamil and reads
/// English, which is worth knowing before somebody reads this header as a
/// claim that nothing is translated.
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

  // ── Before anything is asked ──────────────────────────────────────────────
  //
  // The language screen, and it is the one block in this file whose English is
  // **not** the fallback a lookup improves on. A patient who reads only Tamil
  // meets this screen before anything has been translated for them, which is
  // why the rows themselves are native names out of `PatientLanguage` rather
  // than strings from here: a heading nobody on the screen can read is
  // survivable when the twelve things under it are each written in their own
  // script, and is not survivable otherwise.

  static String get beforeWeStart => _of('entry.title', 'Before we start');

  static String get chooseYourLanguage =>
      _of('language.heading', 'Choose your language');

  /// Under the heading, and the one sentence that makes this screen honest.
  ///
  /// The choice governs **only what the patient says**: the recogniser is told
  /// which language to listen for, and what comes back is turned into English
  /// before anybody reads it. Everything in the other direction stays English —
  /// on the screen and in the voice that reads it out.
  ///
  /// So the sentence has to do two things in a row a patient can hold at once:
  /// name what they are picking *for*, and say plainly what they will get back.
  /// The line it replaced — "The questions will be asked in the language you
  /// pick" — was true of a different build, and a patient who picks Tamil and
  /// then meets an English question would have been told wrong by the app
  /// rather than let down by it.
  ///
  /// It still promises nothing about changing the choice later: the language is
  /// recorded on the case session when it is created, and this screen is not
  /// the thing that can move it.
  static String get chooseYourLanguageDetail => _of(
        'language.detail',
        'Pick the language you will speak. The questions will be in English, '
            'on screen and read aloud.',
      );

  static String get languageContinue => _of('language.continue', 'Continue');

  /// Where the patient's own language cannot be spoken back to the app,
  /// because the transcriber has no model for it — Odia, today.
  ///
  /// Said twice and in one wording: once on the picker, under the row they just
  /// tapped, and again in the interview where the microphone would have been.
  /// It names the language, because "answering out loud does not work" with no
  /// subject reads as a broken app rather than as a fact about one of twelve
  /// choices — and it ends on the two ways forward, which is the half a patient
  /// holding the tablet actually needs.
  ///
  /// It no longer offers "the questions can still be read to you" as the
  /// consolation. That read as a promise of Odia, and read-aloud is English for
  /// every patient now — so it is neither this line's news nor this language's
  /// exception, and a sentence about a missing microphone is the wrong place to
  /// discover it.
  static String cannotAnswerOutLoudIn(String language) => _of(
        'language.voice.unsupported',
        'Answering out loud does not work in {language} yet. You can type your '
            'answer or tap one of the choices.',
        {'language': language},
      );

  // ── Asking, and answering out loud ────────────────────────────────────────

  /// The switch under the question. Both say what a tap will *do*, because a
  /// label next to a speaker icon that states the current state instead leaves
  /// somebody guessing which of the two they are looking at.
  static String get readAloud => _of('speak.on', 'Read the questions to me');
  static String get stopReadingAloud =>
      _of('speak.off', 'Stop reading out loud');

  static String get speakYourAnswer =>
      _of('mic.idle', 'Answer out loud instead');
  static String get listening => _of('mic.listening', 'Listening');
  static String get tapWhenFinished =>
      _of('mic.stop', 'Tap when you have finished');
  static String get writingThatDown =>
      _of('mic.working', 'Writing that down');

  // ── Answering out loud, as a conversation ─────────────────────────────────
  //
  // The four lines the live room adds, and the register they are written in is
  // the point of them: **none of them names the feature.** A patient taps the
  // same microphone they have always tapped; whether their words come back a
  // sentence at a time or a recording at a time is a fact about the hospital's
  // servers, and a sentence that made them choose between two kinds of
  // microphone would be the app asking somebody with chest pain to care about
  // its architecture.
  //
  // So the two failures below say what changed and what still works, and
  // neither says the word that would invite the question "why don't I have
  // the other one".

  /// While the room is being dialled. Short, and on screen the moment the
  /// microphone is tapped: a tap that shows nothing for several seconds is a
  /// tap somebody makes again, and the second one would end what the first
  /// started.
  static String get connectingYourVoice =>
      _of('live.connecting', 'Connecting you…');

  /// Above the words arriving while the patient is still speaking.
  ///
  /// Present tense, and deliberately not [youSaid]. What is under this heading
  /// is unfinished — the recogniser revises it several times a sentence — and
  /// a patient who read "You said" over it would correct text that was about
  /// to correct itself. It is also the honest signal that the microphone is
  /// working, which is the job `ListeningIndicator` does on the other path.
  static String get weAreHearing => _of('live.interim', 'We are hearing');

  /// The room would not open. Said once, as a passing note rather than a
  /// banner: the microphone is still on screen, still works, and the patient
  /// has lost nothing they knew they had.
  static String get couldNotOpenLiveVoice => _of(
        'live.error.open',
        'We could not listen as you speak just now. You can still answer out '
            'loud one question at a time, or type your answer.',
      );

  /// It was working and it stopped. Past tense, because the difference matters
  /// to somebody who watched their words appear and then stop appearing — it
  /// tells them the app noticed, which is the part that decides whether they
  /// trust the next thing it says.
  static String get liveVoiceEnded => _of(
        'live.error.dropped',
        'We have stopped listening as you speak. You can still answer out loud '
            'one question at a time, or type your answer.',
      );

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

  // ── The interview ─────────────────────────────────────────────────────────
  //
  // The screen a patient spends the longest on, so this is the block where the
  // register matters most. Every line is about them rather than about the
  // system: "We are still reading that" and not "Extraction in progress", and
  // nothing anywhere says what might be wrong with them.

  static String get interviewTitle => _of('interview.title', 'Your answers');

  /// The heading of the answer area, above the tiles and the keyboard.
  static String get howToAnswer => _of(
        'interview.how',
        'Tap an answer, type it, or say it out loud.',
      );

  /// The keyboard path, offered on every question — voice is never required.
  static String get typeYourAnswer =>
      _of('interview.type.label', 'Type your answer');
  static String get typeHere => _of('interview.type.hint', 'Type here');
  static String get sendAnswer => _of('interview.type.send', 'Send');

  /// While a turn is in flight. Short: the next question is milliseconds away,
  /// so this is a state nobody should have time to read twice.
  static String get sending => _of('interview.sending', 'Sending');

  /// The same moment, said as a sentence rather than as a button label.
  ///
  /// The turn route answers in milliseconds *when the hospital answers at all*.
  /// On a dropped connection it is the connect timeout instead — thirty
  /// seconds during which the question has already moved into the conversation
  /// and there is nothing left on the answer panel. This is what goes there, so
  /// the patient is never looking at a question with no controls under it and
  /// nothing on screen saying why.
  static String get sendingYourAnswer => _of(
        'interview.sending.long',
        'Sending your answer to the hospital…',
      );

  /// Under an answer the app has taken but has not finished reading.
  ///
  /// **Not a spinner and not a blocker.** Understanding a long answer costs the
  /// model up to twenty seconds on this hardware, and the next question is
  /// already on screen — so this says what is happening and gets out of the
  /// way. "Still" is doing real work in the sentence: it tells somebody the
  /// answer arrived, which is the part they were worried about.
  static String get stillReadingThat =>
      _of('interview.extracting', 'Still reading that');

  /// Where the microphone is not available at all.
  static String get voiceUnavailable => _of(
        'interview.voice.unavailable',
        'Answering out loud is not working right now. You can type your '
            'answer or tap one below.',
      );

  /// When the recogniser heard nothing worth showing back.
  static String get didNotHearAnything => _of(
        'interview.voice.empty',
        'We did not hear anything. Try again, or type your answer.',
      );

  /// A recording that was a thumb on the button rather than an answer.
  static String get recordingTooShort => _of(
        'interview.voice.short',
        'That was too short to hear. Hold on a moment longer, or type your '
            'answer.',
      );

  // ── Finishing ─────────────────────────────────────────────────────────────

  static String get thatIsEverything =>
      _of('interview.done.heading', 'That is everything we needed to ask');

  static String get aDoctorWillRead => _of(
        'interview.done.body',
        'A doctor will read your answers before they see you. You can go back '
            'and change anything you need to.',
      );

  static String get done => _of('interview.done.action', 'Done for now');

  /// Starting again, and the two things it does.
  ///
  /// The label names the send first because the send is the part that cannot be
  /// taken back — the new interview is the *consequence*, not the price. A
  /// button that said only "Start a new conversation" would file a clinical
  /// document to the hospital on a tap that did not mention one.
  ///
  /// Short because `SecondaryBar` gives a label one line and ellipsises the
  /// rest, and it was measured doing it: "Send this and start a new
  /// conversation" rendered as "Send this and start a new c…" on the handset,
  /// which is a button whose irreversible half is the half that fits and whose
  /// consequence trails off into a character nobody can act on. The full
  /// sentence lives in the dialog, which has room for it and is where the
  /// patient is asked to agree.
  static String get sendAndStartNew =>
      _of('interview.done.restart', 'Send and start a new one');

  static String get sendAndStartNewTitle =>
      _of('interview.done.restart.title', 'Send this to the hospital?');

  /// Said in the order it happens, and it does not promise a reply. "A doctor
  /// will read it" is already on the card above; repeating it here in a dialog
  /// that is asking permission would read as a commitment about when.
  static String get sendAndStartNewBody => _of(
        'interview.done.restart.body',
        'Your answers will be sent to the hospital as they are, and cannot be '
            'changed afterwards. You will then start a fresh set of questions.',
      );

  static String get sendAndStartNewConfirm =>
      _of('interview.done.restart.confirm', 'Send and start');

  static String get caseSentNewStarted => _of(
        'interview.done.restart.sent',
        'Sent. You can start answering the new questions.',
      );

  /// Sent, but the next interview did not open — a connection that went between
  /// two requests. It leads with the fact that matters and does not call it a
  /// failure, because nothing failed that the patient did.
  static String get caseSentNotReopened => _of(
        'interview.done.restart.halfway',
        'Your answers were sent. We could not open the new questions just yet — '
            'try again in a moment.',
      );

  /// Nothing left to ask, but an answer is still being read. **Not the same as
  /// finished**: saying so would invite somebody to close the app while the
  /// last thing they said was still being written down.
  static String get almostThere => _of(
        'interview.settling',
        'We are finishing writing down your last answer.',
      );

  /// The settling state, still there after the screen has waited it out.
  ///
  /// [almostThere] stops being true at some point, and a screen that keeps
  /// saying it is a screen lying to a patient who is doing nothing wrong. This
  /// says what is actually the case and hands them the only two useful moves:
  /// look again, or leave and come back to it.
  static String get stillNothingToAsk => _of(
        'interview.settling.stalled',
        'Your last answer is taking longer than usual to save. Your answers so '
            'far are safe. You can check again, or come back to this later.',
      );

  static String get checkAgain => _of('interview.settling.retry', 'Check again');

  // ── When something goes wrong ─────────────────────────────────────────────

  static String get couldNotStart => _of(
        'interview.error.start',
        'We could not open your questions. Check your connection and try '
            'again.',
      );

  static String get couldNotSendAnswer => _of(
        'interview.error.turn',
        'That answer did not reach us. Try it again.',
      );

  static String get tryAgain => _of('interview.error.retry', 'Try again');

  /// Where the phone has a saved position and the server could not be reached.
  ///
  /// Says what is on screen and how old it is, rather than pretending the
  /// interview is live. A patient answering questions into a screen that is
  /// not recording them is the worst outcome available here.
  static String get showingWhereYouLeftOff => _of(
        'interview.offline',
        'This is where you left off. We could not reach the hospital just '
            'now, so nothing new can be saved until you try again.',
      );

  // ── Documents ─────────────────────────────────────────────────────────────
  //
  // Conspicuously short, and that is the design. **Every sentence about what
  // happened to a document comes from the server**, which writes one for each
  // outcome in `pipeline/messages.ts` and sends it on the row as `message`.
  // The app prints it verbatim. Documents §27 names the failure this avoids —
  // `PP-OCR inference exception` reaching somebody who only wanted to know
  // whether to take another photograph — and the way that leaks is never a
  // decision: it is one layer inventing its own wording for a state it did not
  // measure. So what is here is the furniture around the sentence, and never a
  // second opinion about the sentence itself.

  static String get documentsTitle => _of('documents.title', 'Your documents');

  static String get addADocument =>
      _of('documents.add', 'Add a document');

  static String get takeAPhoto => _of('documents.camera', 'Take a photo');
  static String get chooseAPhoto =>
      _of('documents.gallery', 'Choose a photo you already have');
  static String get chooseAPdf => _of('documents.pdf', 'Choose a PDF');

  static String get noDocumentsYet =>
      _of('documents.empty.title', 'Nothing added yet');

  static String get noDocumentsYetBody => _of(
        'documents.empty.body',
        'Photograph a prescription, a report or a discharge letter and we '
            'will read it through with you.',
      );

  /// `Sending — 40%`. Tabular, and never a bare spinner: a send with no figure
  /// on it reads as a hung screen, and the second tap sends the photo twice.
  static String sendingPercent(int percent) => _of(
        'documents.sending',
        'Sending — {percent}%',
        {'percent': '$percent'},
      );

  /// A file the route would drop the connection on. Refused here so the
  /// patient is told a fact about their photo rather than shown a network
  /// error for a file that is merely too big.
  static String fileTooLarge(String size) => _of(
        'documents.too.large',
        'That file is {size}, which is more than we can take. Photograph one '
            'page at a time, or send a smaller file.',
        {'size': size},
      );

  static String get couldNotSendDocument => _of(
        'documents.error.send',
        'That document did not reach us. Try it again.',
      );

  static String get couldNotLoadDocuments => _of(
        'documents.error.list',
        "We couldn't load your documents just now.",
      );

  static String get couldNotOpenDocument => _of(
        'documents.error.read',
        "We couldn't open that document just now.",
      );

  static String get couldNotOpenFile => _of(
        'documents.error.pick',
        "We couldn't open that file.",
      );

  /// A file type the route would refuse. Local, and not a second opinion about
  /// a server sentence: this one is said about a file that was never uploaded,
  /// so there is no server outcome to quote. The picker already filters by
  /// extension — this covers the file browsers that treat that filter as
  /// advisory and hand back anything the patient tapped.
  static String get unsupportedDocument => _of(
        'documents.error.type',
        'That kind of file cannot be read. Choose a photo of the document, or '
            'a PDF.',
      );

  /// The heading over the extracted values. Never "what we found in your
  /// record": nothing on this screen has been added to anything yet.
  static String get checkWhatWeFound =>
      _of('documents.review.title', 'Please check what we found');

  static String get seeTheOriginal =>
      _of('documents.original', 'See the original');

  static String get couldNotOpenOriginal => _of(
        'documents.original.error',
        "We couldn't open the original just now. Try again.",
      );

  /// The two measured numbers, each named for what it measures.
  ///
  /// Two figures and never one. They are measurements of different things —
  /// how well the page was *read*, and how much of what was structured out of
  /// it was actually **on** the page — and a single blended "accuracy" is a
  /// number nobody measured presented as one somebody did.
  static String get howThisWasRead =>
      _of('documents.confidence.title', 'How this was read');

  static String get textRecognition =>
      _of('documents.confidence.ocr', 'Text read from the page');

  static String get informationFound =>
      _of('documents.confidence.extraction', 'Information found in that text');

  static String get notMeasured =>
      _of('documents.confidence.none', 'Not measured');

  /// Section headings inside one document.
  static String get medicines => _of('documents.section.medications', 'Medicines');
  static String get testResults =>
      _of('documents.section.investigations', 'Test results');
  static String get diagnosesRecorded => _of(
        'documents.section.diagnoses',
        // §14: the document recorded it. The app did not decide it, and the
        // heading is the reminder.
        'Diagnoses written in this document',
      );
  static String get proceduresRecorded =>
      _of('documents.section.procedures', 'Procedures');
  static String get followUpRecorded =>
      _of('documents.section.followup', 'What to do next');
  static String get allergiesRecorded =>
      _of('documents.section.allergies', 'Allergies');

  /// Under a value the patient has corrected. Replaces the document as the
  /// authority for that line, and says so.
  static String get youCorrectedThis =>
      _of('documents.value.corrected', 'You corrected this');

  static String get youConfirmedThis =>
      _of('documents.value.confirmed', 'You confirmed this');

  static String get youAreNotSure =>
      _of('documents.value.unsure', 'You are not sure about this');

  static String get notCheckedYet =>
      _of('documents.value.unchecked', 'Not checked yet');

  static String get whatShouldItSay =>
      _of('documents.correct.hint', 'What should it say?');

  static String get saveCorrection => _of('documents.correct.save', 'Save');

  /// The document-level confirmation. Offered only when every value on the
  /// screen has been agreed with, because that is what the server's `verify`
  /// route means — see [documentGoesToAClinician] for the other ending.
  static String get confirmThisDocument =>
      _of('documents.verify', 'Confirm this document');

  static String get documentConfirmedGoBack =>
      _of('documents.verify.done', 'Thank you. That is confirmed.');

  static String get documentGoesToAClinician => _of(
        'documents.verify.blocked',
        'Because something here is wrong or uncertain, we will not mark this '
            'document as correct. A clinician will look at it with you.',
      );

  static String get couldNotConfirmDocument => _of(
        'documents.verify.error',
        "We couldn't record that just now. Try again.",
      );

  // ── Reviewing everything, and sending it ──────────────────────────────────

  static String get reviewTitle =>
      _of('review.title', 'What we understood');

  static String get reviewIntro => _of(
        'review.intro',
        'Here is what we understood about you. Please read it and change '
            'anything that is not right before we send it.',
      );

  /// §43. On screen, above the sections, and not in a footnote.
  static String get notADiagnosis => _of(
        'review.disclaimer',
        'This is what you told us, written down. It is not a diagnosis, and '
            'nothing here has been decided about you.',
      );

  /// §36: printed, never omitted. An omitted line reads as nothing to report.
  static String get stillToAsk => _of('review.missing.title', 'Still to ask');

  static String get stillToAskBody => _of(
        'review.missing.body',
        'Nobody has asked you about these yet. They are listed so that silence '
            'is not read as an answer.',
      );

  /// §33 / §20. Both values are shown and neither is changed.
  static String get pleaseCheckThese =>
      _of('review.contradiction.title', 'Please check these');

  static String get contradictionIntro => _of(
        'review.contradiction.body',
        'These differ from what the hospital already holds. We have changed '
            'nothing either way — please tell the desk which is right.',
      );

  static String get inYourDocument =>
      _of('review.contradiction.document', 'In the document you sent');

  static String get inYourRecord =>
      _of('review.contradiction.record', 'In your record already');

  /// The first entry case, which is new information rather than a conflict.
  static String get notInYourRecordYet => _of(
        'review.contradiction.new',
        'Your record does not mention this yet',
      );

  static String get sendToTheHospital =>
      _of('review.submit', 'Send this to the hospital');

  static String get caseSent =>
      _of('review.submitted.title', 'Your answers have been sent');

  static String get caseSentBody => _of(
        'review.submitted.body',
        'A doctor will read them before they see you.',
      );

  static String get alreadySent => _of(
        'review.submitted.locked',
        'This has already been sent to the hospital, so it cannot be changed '
            'here. Tell the desk if something is wrong.',
      );

  static String get couldNotLoadReview => _of(
        'review.error.load',
        "We couldn't load your answers just now.",
      );

  static String get couldNotSendCase => _of(
        'review.error.submit',
        'That did not reach the hospital. Try again.',
      );

  static String get couldNotChangeAnswer => _of(
        'review.error.correct',
        'That change did not reach us. Try it again.',
      );

  /// `4 of 11 answered`, under the rail on the review screen.
  static String answeredProgress(int addressed, int expected) => _of(
        'review.progress',
        '{addressed} of {expected} answered',
        {'addressed': '$addressed', 'expected': '$expected'},
      );
}
