/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the two answers the interview needs before it can start
///
/// Language and consent. Neither is written anywhere yet: the case session is
/// created by `POST /api/case-taking`, which the interview owns and which does
/// not exist on the server yet, and the session is where both of these belong
/// — a language chosen on the phone and stored on the phone is a language the
/// doctor reading the transcript never learns about.
///
/// So they travel forward in the route arguments, as [PatientEntry], from the
/// language screen through consent and into the interview. That is deliberately
/// the *only* place they live: a service holding them would survive a sign-out
/// on a shared device, and the next patient would be asked to consent to
/// nothing because the last one already had.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../../data/models/case_session.dart';

/// A language a patient can be interviewed in.
///
/// Twelve, and the list is not symmetric — which is the reason this is an enum
/// with flags on it rather than a map of code to name. **Speech and hearing are
/// separate capabilities and a language can have one without the other.**
/// `faster-whisper` ships no Odia model, so a patient who speaks Odia can be
/// read to and cannot be heard; offering a microphone there would be offering a
/// control that records an answer nothing can transcribe, and a dropped answer
/// is worse than an absent button.
///
/// The names in the second and third columns are not interchangeable. The
/// native name is what a speaker recognises at a glance and is the prominent
/// line on the picker; the English name is the fallback for somebody who reads
/// neither, and the label a log or a doctor's view uses.
enum PatientLanguage {
  // English first because it is the floor: it is what [fromCode] falls back to,
  // what this build's own copy is written in, and what a patient who cannot
  // read any row on the screen is left with. The eleven below it are in ISO
  // code order — any other ordering is a claim about which languages matter
  // more here, and that is not a claim an app should make on a waiting-room
  // screen.
  english('en', 'English', 'English'),
  assamese('as', 'Assamese', 'অসমীয়া'),
  bengali('bn', 'Bengali', 'বাংলা'),
  gujarati('gu', 'Gujarati', 'ગુજરાતી'),
  hindi('hi', 'Hindi', 'हिन्दी'),
  kannada('kn', 'Kannada', 'ಕನ್ನಡ'),
  malayalam('ml', 'Malayalam', 'മലയാളം'),
  marathi('mr', 'Marathi', 'मराठी'),

  /// Read aloud, never spoken back — the one row where the two capabilities
  /// come apart, so both are written out rather than left to a default.
  odia('or', 'Odia', 'ଓଡ଼ିଆ', canSpeak: false, canHear: true),
  punjabi('pa', 'Punjabi', 'ਪੰਜਾਬੀ'),
  tamil('ta', 'Tamil', 'தமிழ்'),
  telugu('te', 'Telugu', 'తెలుగు');

  const PatientLanguage(
    this.code,
    this.englishName,
    this.nativeName, {
    this.canSpeak = true,
    this.canHear = true,
  });

  /// The tag the case session stores, and the one `/stt` is given.
  ///
  /// Not `/tts`: the questions are asked in English however the patient
  /// answers, so the voice that reads them follows the session's output
  /// language and not this.
  final String code;

  /// What this language is called in English, for a log or a doctor's view.
  final String englishName;

  /// What it is called in itself.
  ///
  /// The name a speaker recognises at a glance is the one written in their own
  /// script, which is the whole point of the picker — so "தமிழ்" is the line
  /// that is read and "Tamil" is the line underneath it.
  final String nativeName;

  /// Whether the **patient can speak** this language to the app.
  ///
  /// False where the transcriber has no model for it. Both flags are named
  /// from the patient's side rather than the server's, because that is the
  /// sentence the screen has to write: "answering out loud does not work in
  /// this language" is about them, and "no `or` checkpoint is published" is
  /// not.
  ///
  /// A default, not the last word — the server's language list may say
  /// otherwise, and [PatientLanguageOffer] is where the two are reconciled.
  final bool canSpeak;

  /// Whether the **patient can be read to** in this language.
  ///
  /// Separate from [canSpeak] because the two are separate models on the
  /// sidecar and either can be missing on its own.
  ///
  /// Asked of the language the interview *outputs* — English today — and not
  /// of the row the patient tapped, which is why picking Odia no longer costs
  /// anybody the read-aloud switch. It stays on the row because the server's
  /// language list still answers for both halves and the picker still shows
  /// what it said.
  final bool canHear;

  /// What the language screen offers with no help from the server.
  static List<PatientLanguage> get available => values;

  /// The language with this code, or null where this build has no native name
  /// for it.
  ///
  /// Null rather than English, which is the difference that matters when the
  /// server names a language the app has not been taught: rendering it as
  /// "English" would put a row on the picker that lies about what tapping it
  /// does, and dropping it leaves a list that is short rather than wrong.
  static PatientLanguage? tryFromCode(String? code) {
    final tag = (code ?? '').trim().toLowerCase();
    if (tag.isEmpty) return null;
    for (final language in values) {
      if (language.code == tag) return language;
    }
    return null;
  }

  /// The same lookup with English as the floor, for a call site that must
  /// resolve to *something* — a route argument, a resumed session's tag.
  static PatientLanguage fromCode(String? code) =>
      tryFromCode(code) ?? PatientLanguage.english;
}

/// One row of the language picker: a language, and the capabilities actually
/// in force for it.
///
/// It exists because the two facts have different owners. Which languages this
/// build can *name* is settled here, in the app, by whether somebody wrote the
/// native name into [PatientLanguage]. Which of them the hospital's sidecar can
/// currently *hear and speak* is settled on the server, changes without a
/// release, and arrives from `GET /api/case-taking/languages`.
///
/// So the app ships the catalogue and the server refines it. A list that never
/// arrives leaves [catalogue] standing, which is a picker that works on a
/// waiting-room tablet with no signal — and a picker that refused to render
/// until a network call came back would be a patient staring at a spinner
/// before they had been asked anything.
class PatientLanguageOffer {
  PatientLanguageOffer(this.language, {bool? canSpeak, bool? canHear})
      : canSpeak = canSpeak ?? language.canSpeak,
        canHear = canHear ?? language.canHear;

  final PatientLanguage language;

  /// See [PatientLanguage.canSpeak] — the server's answer where it gave one,
  /// this build's default where it did not.
  final bool canSpeak;

  /// See [PatientLanguage.canHear].
  final bool canHear;

  String get code => language.code;
  String get nativeName => language.nativeName;
  String get englishName => language.englishName;

  /// Everything this build can name, with its own capability defaults.
  static List<PatientLanguageOffer> get catalogue =>
      PatientLanguage.available.map(PatientLanguageOffer.new).toList();

  /// The server's list, folded onto the catalogue.
  ///
  /// The server decides *which* rows and *what they can do*; the app decides
  /// what they are called, because a native name rendered from a server string
  /// is a native name that can arrive mojibake'd or missing and be shown to the
  /// one patient who cannot read anything else on the screen.
  ///
  /// A code this build cannot name is dropped rather than guessed at — see
  /// [PatientLanguage.tryFromCode]. An empty result is the caller's signal to
  /// keep the [catalogue] it already had.
  static List<PatientLanguageOffer> merge(List<CaseLanguage> rows) {
    final offers = <PatientLanguageOffer>[];
    final seen = <PatientLanguage>{};

    for (final row in rows) {
      final language = PatientLanguage.tryFromCode(row.code);
      if (language == null || !seen.add(language)) continue;
      offers.add(
        PatientLanguageOffer(
          language,
          canSpeak: row.canSpeak,
          canHear: row.canHear,
        ),
      );
    }

    // Back into the catalogue's order rather than the server's. The order this
    // screen is read in is a design decision — English first, then ISO code —
    // and a list handed back in query order would re-rank the picker every time
    // somebody reordered a table.
    offers.sort(
      (a, b) => a.language.index.compareTo(b.language.index),
    );
    return offers;
  }
}

/// What the entry sequence collected, on its way to the interview.
///
/// A class rather than a bare map so the two keys cannot be misspelled at one
/// of the three call sites that pass them along.
class PatientEntry {
  const PatientEntry({
    this.language = PatientLanguage.english,
    this.consentGiven = false,
  });

  final PatientLanguage language;

  /// True only once the patient has read what is collected, who reads it, and
  /// that it is not a diagnosis, and has then said yes.
  ///
  /// Not a timestamp. The moment consent was given is a fact about the case
  /// session, and the server stamps that when the session is created — a clock
  /// read on the phone would be the patient's device time, which is whatever
  /// it happens to be set to.
  final bool consentGiven;

  PatientEntry copyWith({PatientLanguage? language, bool? consentGiven}) =>
      PatientEntry(
        language: language ?? this.language,
        consentGiven: consentGiven ?? this.consentGiven,
      );

  Map<String, dynamic> toArguments() => {
        'language': language.code,
        'consentGiven': consentGiven,
      };

  /// Reads the arguments a previous screen passed, falling back to a fresh
  /// entry when there are none — which is what a deep link straight to consent
  /// hands over, and which must render rather than throw.
  factory PatientEntry.fromArguments(Object? arguments) {
    if (arguments is! Map) return const PatientEntry();
    return PatientEntry(
      language: PatientLanguage.fromCode(arguments['language']?.toString()),
      consentGiven: arguments['consentGiven'] == true,
    );
  }
}
