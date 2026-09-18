import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/case_session.dart';
import 'package:medihive/app/modules/patient_portal/patient_entry.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the language a patient is interviewed in
///
/// Three properties, and each of them fails silently in the app.
///
///   * **The code survives the journey.** Language is collected on one screen
///     and used on three others, and it travels as a route argument rather than
///     in a service. A tag dropped anywhere along that path does not throw: it
///     falls back to English, and the interview runs in English while the
///     screen that asked says Tamil. Nobody notices until a doctor reads a
///     transcript.
///
///   * **Odia can be heard and cannot be spoken.** `faster-whisper` publishes
///     no Odia checkpoint. A microphone offered there records an answer that
///     comes back empty, and an empty transcript reads downstream as *the
///     patient said nothing* — a clinical statement nobody made.
///
///   * **The server narrows the list; it does not name it.** A code this build
///     cannot write in its own script is dropped rather than rendered, because
///     the alternative is a row on the picker that lies about what tapping it
///     does.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('the catalogue', () {
    test('offers twelve languages, each with its own code', () {
      final codes = PatientLanguage.available.map((l) => l.code).toSet();
      expect(codes.length, PatientLanguage.available.length);
      expect(codes.length, 12);
      expect(
        codes,
        containsAll(const [
          'en',
          'as',
          'bn',
          'gu',
          'hi',
          'kn',
          'ml',
          'mr',
          'or',
          'pa',
          'ta',
          'te',
        ]),
      );
    });

    test('writes every name in its own script', () {
      // The placeholder that would otherwise ship: a row added with the English
      // name copied into both columns, which renders a picker of twelve Latin
      // words to the one patient it exists for. English is the exception by
      // definition and is the only one.
      for (final language in PatientLanguage.available) {
        if (language == PatientLanguage.english) continue;
        expect(
          language.nativeName,
          isNot(language.englishName),
          reason: '${language.code} has no native name of its own',
        );
        expect(
          language.nativeName.codeUnits.every((unit) => unit < 128),
          isFalse,
          reason: '${language.code} is written in Latin script',
        );
      }
    });

    test('Odia can be read aloud and cannot be spoken back', () {
      expect(PatientLanguage.odia.canHear, isTrue);
      expect(PatientLanguage.odia.canSpeak, isFalse);
    });

    test('every other language can do both', () {
      for (final language in PatientLanguage.available) {
        if (language == PatientLanguage.odia) continue;
        expect(language.canSpeak, isTrue, reason: language.code);
        expect(language.canHear, isTrue, reason: language.code);
      }
    });
  });

  group('reading a code back', () {
    test('an unknown tag is an absence, not English', () {
      // The distinction the picker depends on. `fromCode` has to answer
      // something for a route argument; `tryFromCode` is what stops a language
      // the app cannot name being drawn as a row that says "English".
      expect(PatientLanguage.tryFromCode('ur'), isNull);
      expect(PatientLanguage.fromCode('ur'), PatientLanguage.english);
    });

    test('nothing at all reads as English', () {
      expect(PatientLanguage.fromCode(null), PatientLanguage.english);
      expect(PatientLanguage.fromCode(''), PatientLanguage.english);
      expect(PatientLanguage.fromCode('   '), PatientLanguage.english);
    });

    test('case and padding do not lose a language', () {
      expect(PatientLanguage.fromCode('TA'), PatientLanguage.tamil);
      expect(PatientLanguage.fromCode(' or '), PatientLanguage.odia);
    });
  });

  group('the entry a screen hands forward', () {
    test('a chosen language survives the route arguments', () {
      const entry = PatientEntry(
        language: PatientLanguage.tamil,
        consentGiven: true,
      );

      final restored = PatientEntry.fromArguments(entry.toArguments());

      expect(restored.language, PatientLanguage.tamil);
      expect(restored.consentGiven, isTrue);
    });

    test('a deep link with no arguments renders rather than throwing', () {
      final entry = PatientEntry.fromArguments(null);
      expect(entry.language, PatientLanguage.english);
      expect(entry.consentGiven, isFalse);
    });

    test('consent is never carried over by choosing a language', () {
      const entry = PatientEntry();
      final chosen = entry.copyWith(language: PatientLanguage.odia);
      expect(chosen.language, PatientLanguage.odia);
      expect(chosen.consentGiven, isFalse);
    });
  });

  group('the server’s list, folded onto the catalogue', () {
    test('narrows to what the hospital offers, in the catalogue’s order', () {
      final offers = PatientLanguageOffer.merge(const [
        CaseLanguage(code: 'ta'),
        CaseLanguage(code: 'en'),
      ]);

      // English first, then ISO order — the screen's order, not the query's.
      expect(offers.map((o) => o.code), ['en', 'ta']);
    });

    test('a flag the server sent overrides the one the app shipped', () {
      final offers = PatientLanguageOffer.merge(const [
        CaseLanguage(code: 'or', canSpeak: true),
        CaseLanguage(code: 'ta', canSpeak: false),
      ]);

      expect(offers.firstWhere((o) => o.code == 'or').canSpeak, isTrue);
      expect(offers.firstWhere((o) => o.code == 'ta').canSpeak, isFalse);
    });

    test('a flag the server left out keeps the app’s own answer', () {
      final offers = PatientLanguageOffer.merge(const [
        CaseLanguage(code: 'or'),
      ]);

      expect(offers.single.canSpeak, isFalse);
      expect(offers.single.canHear, isTrue);
    });

    test('a code this build cannot name is dropped, never guessed at', () {
      final offers = PatientLanguageOffer.merge(const [
        CaseLanguage(code: 'ur'),
        CaseLanguage(code: 'ta'),
      ]);

      expect(offers.map((o) => o.code), ['ta']);
    });

    test('a list of nothing recognisable is empty, which is the caller’s cue',
        () {
      // Empty rather than a default list, because the controller reads empty as
      // "keep what you already have". A merge that quietly returned the
      // catalogue here would make a broken payload indistinguishable from a
      // working one.
      expect(PatientLanguageOffer.merge(const []), isEmpty);
      expect(
        PatientLanguageOffer.merge(const [CaseLanguage(code: 'ur')]),
        isEmpty,
      );
    });

    test('the same language twice is one row', () {
      final offers = PatientLanguageOffer.merge(const [
        CaseLanguage(code: 'ta', canSpeak: true),
        CaseLanguage(code: 'ta', canSpeak: false),
      ]);

      expect(offers.length, 1);
      // The first wins, so a duplicate appended later cannot silently withdraw
      // a microphone the row above it offered.
      expect(offers.single.canSpeak, isTrue);
    });
  });

  group('the row the server sent', () {
    test('reads the flags under whichever name they arrived with', () {
      final stt = CaseLanguage.fromJson(const {
        'code': 'ta',
        'stt': false,
        'tts': true,
      });
      expect(stt.canSpeak, isFalse);
      expect(stt.canHear, isTrue);

      final named = CaseLanguage.fromJson(const {
        'language': 'or',
        'canSpeak': false,
      });
      expect(named.code, 'or');
      expect(named.canSpeak, isFalse);
      // Absent is not false. The app's own answer stands.
      expect(named.canHear, isNull);
    });

    test('a row with no code is empty and is thrown away upstream', () {
      expect(CaseLanguage.fromJson(const {}).isEmpty, isTrue);
    });
  });
}
