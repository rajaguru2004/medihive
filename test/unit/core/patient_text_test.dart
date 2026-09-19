import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/i18n/patient_text.dart';
import 'package:medihive/app/core/i18n/patient_text_translations.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the language seam
///
/// This build ships English and only English. What is pinned here is the
/// promise the translation phase is relying on: that it can install a lookup
/// and **not one call site changes**.
///
/// Two properties carry that. A lookup has to actually be consulted, and a
/// parameterised line has to keep its placeholders until after the lookup has
/// run — because `'Question $step of $total'` has already lost them by the
/// time anything could translate it, and a phase that discovers that late
/// re-writes every call site it was supposed to leave alone.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  tearDown(() => PatientText.useLookup(null));

  test('with no lookup installed, the English is what renders', () {
    expect(PatientText.yes, 'Yes');
    expect(PatientText.iDontKnow, "I don't know");
    expect(PatientText.questionProgress(3, 11), 'Question 3 of 11');
  });

  test('a lookup is consulted, by key', () {
    final asked = <String>[];
    PatientText.useLookup((key, english) {
      asked.add(key);
      return key == 'answer.yes' ? 'Ja' : english;
    });

    expect(PatientText.yes, 'Ja');
    expect(PatientText.no, 'No', reason: 'an untranslated line keeps English');
    expect(asked, contains('answer.yes'));
  });

  test('a translated template keeps the call site out of it', () {
    // The point of `{step}` over `$step`: a language that puts the total first
    // re-orders the template, and nothing above this line has to know.
    PatientText.useLookup(
      (key, english) =>
          key == 'progress.step' ? 'Of {total}, question {step}' : english,
    );

    expect(PatientText.questionProgress(3, 11), 'Of 11, question 3');
  });

  test('a missing translation renders the sentence, not the key', () {
    // A patient seeing `answer.unknown` on screen is worse than a patient
    // seeing it in the wrong language.
    PatientText.useLookup((key, english) => english);
    expect(PatientText.iDontKnow, "I don't know");
    expect(PatientText.tellANurseNow, isNot(contains('redflag')));
  });

  test('the red-flag copy names no condition', () {
    // `RedFlagNotice` can only render these three lines plus the patient's own
    // words. This is the half of that guarantee that lives in the copy.
    final lines = [
      PatientText.tellANurseNow,
      PatientText.doNotWaitForTheRest,
      PatientText.tellANurse,
    ].join(' ').toLowerCase();

    for (final diagnosis in [
      'heart attack',
      'stroke',
      'sepsis',
      'emergency',
      'serious',
      'dangerous',
    ]) {
      expect(lines, isNot(contains(diagnosis)), reason: diagnosis);
    }
  });

  group('the language picker says what the choice actually does', () {
    // This sentence is the first thing on the first screen of the interview,
    // and it has now said three different things, each true of the build it
    // shipped in:
    //
    //   1. "The questions will be asked in the language you pick." True of a
    //      build that phrased every question in the patient's own language.
    //   2. "The questions will be in English." True of the build that replaced
    //      it, where ten of eleven languages had no phrasebook and the honest
    //      promise was the narrow one.
    //   3. What it says now. The interview is conducted in the patient's own
    //      language again — but this time the picker only offers the languages
    //      that is actually true of, which is what makes the promise keepable.
    //
    // A screen that lies in its first sentence has spent the trust the rest of
    // the interview runs on, so what these tests really pin is that the line
    // and the build agree.

    test('it names speaking as the thing being chosen', () {
      final detail = PatientText.chooseYourLanguageDetail.toLowerCase();
      expect(detail, contains('speak'));
    });

    test('it promises the questions in the same language', () {
      final detail = PatientText.chooseYourLanguageDetail.toLowerCase();
      expect(detail, contains('same language'));
      // And no longer promises English, which is what it said while ten of the
      // eleven Indian languages had no questions written in them.
      expect(detail, isNot(contains('english')));
    });

    test('every offered language can keep that promise', () {
      // The promise is only keepable because the picker is narrow. Each of
      // these has a full phrasebook on the server, answer phrase lists that
      // read it without a model, and a voice on disk — and this app has its own
      // copy in it, which is what this assertion actually checks.
      for (final code in const ['en', 'ta', 'hi']) {
        expect(PatientTextTranslations.has(code), isTrue, reason: code);
      }
    });

    test('the missing-microphone notice offers no reading in that language',
        () {
      // Said on the picker and again where the microphone would have been. It
      // used to end on "the questions can still be read to you", which read as
      // a promise of Odia; read-aloud is English for everybody now, so that is
      // neither this line's news nor this language's exception.
      final notice = PatientText.cannotAnswerOutLoudIn('ଓଡ଼ିଆ');

      expect(notice, contains('ଓଡ଼ିଆ'));
      expect(notice, isNot(contains('read to you')));
      // It still ends on the two ways forward, which is the half a patient
      // holding the tablet actually needs.
      expect(notice, contains('type'));
      expect(notice, contains('tap'));
    });
  });

  test('nothing a patient reads ends in an exclamation mark', () {
    // DESIGN.md §9. Nobody in a waiting room wants to be cheered up by a form.
    final everything = [
      PatientText.yes,
      PatientText.no,
      PatientText.iDontKnow,
      PatientText.skip,
      PatientText.notSure,
      PatientText.skipped,
      PatientText.change,
      PatientText.speakYourAnswer,
      PatientText.listening,
      PatientText.tapWhenFinished,
      PatientText.writingThatDown,
      PatientText.youSaid,
      PatientText.thatIsRight,
      PatientText.sayItAgain,
      PatientText.typeItInstead,
      PatientText.heardClearly,
      PatientText.pleaseCheckThis,
      PatientText.didNotCatchThat,
      PatientText.spoken,
      PatientText.typed,
      PatientText.chosen,
      PatientText.fromYourRecord,
      PatientText.tellANurseNow,
      PatientText.doNotWaitForTheRest,
      PatientText.tellANurse,
      PatientText.microphoneDenied,
      PatientText.microphoneBlocked,
      PatientText.cameraDenied,
      PatientText.cameraBlocked,
      PatientText.photosDenied,
      PatientText.photosBlocked,
      PatientText.openSettings,
      PatientText.questionProgress(1, 2),
      PatientText.chooseYourLanguage,
      PatientText.chooseYourLanguageDetail,
      PatientText.cannotAnswerOutLoudIn('ଓଡ଼ିଆ'),
    ];

    for (final line in everything) {
      expect(line, isNot(contains('!')), reason: line);
      expect(line.trim(), isNotEmpty);
    }
  });
}
