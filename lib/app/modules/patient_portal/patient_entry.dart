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

/// A language a patient can be interviewed in.
///
/// One entry, today. The spec asks for Tamil, English and Hindi and the
/// translation phase is deliberately last — a vocabulary that is still moving
/// is one that gets translated twice — so this ships with the one that is
/// real. Adding the other two is an entry each here, and the screen grows a
/// row without a line of layout changing.
///
/// Speech is the reason the list is not longer already: an interview offered
/// in a language whose speech-to-text has not been benchmarked is an interview
/// that mishears a patient's symptoms, and a misheard symptom is worse than an
/// untranslated one.
enum PatientLanguage {
  english('en', 'English', 'English');

  const PatientLanguage(this.code, this.englishName, this.nativeName);

  /// The tag the case session stores — `en`, and later `ta` and `hi`.
  final String code;

  /// What this language is called in English, for a log or a doctor's view.
  final String englishName;

  /// What it is called in itself. The name a speaker recognises at a glance is
  /// the one written in their own script, which is the whole point of the
  /// screen — so when Tamil arrives it is "தமிழ்" here and "Tamil" above.
  final String nativeName;

  /// What the language screen offers. The enum itself, while there is one of
  /// each; a named getter so P10 can ship a language to staff before patients.
  static List<PatientLanguage> get available => values;

  static PatientLanguage fromCode(String? code) => values.firstWhere(
        (language) => language.code == code,
        orElse: () => PatientLanguage.english,
      );
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
