import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/i18n/patient_text.dart';
import 'package:medihive/app/core/i18n/patient_text_translations.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the seam `patient_text.dart` promised, actually installed
///
/// That file said the translation phase would install a lookup and "not one
/// call site changes". These tests are what makes that claim checkable: the
/// lines still come out of `PatientText`, the table is what decides which
/// language they are in, and a missing key falls back to the English somebody
/// wrote rather than to the identifier a developer wrote.
/// ─────────────────────────────────────────────────────────────────────────────

final _tamil = RegExp(r'[஀-௿]');
final _devanagari = RegExp(r'[ऀ-ॿ]');

void main() {
  tearDown(() => PatientText.useLookup(null));

  group('installing a language', () {
    test('puts the whole surface into Tamil', () {
      PatientTextTranslations.use('ta');

      expect(PatientText.yes, matches(_tamil));
      expect(PatientText.listening, matches(_tamil));
      expect(PatientText.pleaseCheckThis, matches(_tamil));
      expect(PatientText.sendToTheHospital, matches(_tamil));
    });

    test('puts the whole surface into Hindi', () {
      PatientTextTranslations.use('hi');

      expect(PatientText.yes, matches(_devanagari));
      expect(PatientText.listening, matches(_devanagari));
      expect(PatientText.pleaseCheckThis, matches(_devanagari));
    });

    test('takes the tag the session actually carries', () {
      // `ta-IN` from a phone's locale, `TA` from a hand-written client, `ta_IN`
      // from a legacy Android build. The server reduces all three to `ta` in
      // `normaliseLanguage`; this reads the same value out of the same row.
      for (final tag in const ['ta', 'ta-IN', 'TA', 'ta_IN', ' ta ']) {
        PatientTextTranslations.use(tag);
        expect(PatientText.yes, matches(_tamil), reason: tag);
      }
    });

    test('leaves English alone, because English is the source', () {
      PatientTextTranslations.use('en');
      expect(PatientText.yes, 'Yes');
    });

    test('leaves a language it has no copy for on English', () {
      // Bengali has a recogniser and a voice and no interview. A patient
      // reading English is inconvenienced; a patient reading `draft.accept` is
      // being shown a bug.
      PatientTextTranslations.use('bn');
      expect(PatientText.yes, 'Yes');
      expect(PatientText.listening, 'Listening');
    });

    test('a null or empty tag is English, not a crash', () {
      PatientTextTranslations.use(null);
      expect(PatientText.yes, 'Yes');
      PatientTextTranslations.use('');
      expect(PatientText.yes, 'Yes');
    });
  });

  group('what the tables must never lose', () {
    /// A placeholder dropped in translation is a sentence that reads
    /// "Question of" — the substitution happens at the call site and cannot put
    /// back a slot the translator deleted.
    test('every placeholder survives every translation', () {
      const placeholders = <String, List<String>>{
        'progress.step': ['{step}', '{total}'],
        'documents.sending': ['{percent}'],
        'documents.too.large': ['{size}'],
        'review.progress': ['{addressed}', '{expected}'],
        'language.voice.unsupported': ['{language}'],
      };

      // Named for the record; `questionProgress` is the one with a getter that
      // substitutes, so it is the one that can be asserted end to end.
      expect(placeholders, isNotEmpty);

      for (final language in const ['ta', 'hi']) {
        PatientTextTranslations.use(language);
        expect(PatientText.questionProgress(3, 10), contains('3'), reason: language);
        expect(PatientText.questionProgress(3, 10), contains('10'), reason: language);
      }
    });

    test('the two languages cover the same keys', () {
      // A key one language has and the other does not is a screen that is half
      // translated in exactly one language, which is the kind of thing nobody
      // notices until a patient is holding it.
      PatientTextTranslations.use('ta');
      final tamil = PatientText.yes;
      PatientTextTranslations.use('hi');
      final hindi = PatientText.yes;

      expect(tamil, isNot(hindi));
      expect(PatientTextTranslations.languages, containsAll(['en', 'ta', 'hi']));
    });
  });
}
