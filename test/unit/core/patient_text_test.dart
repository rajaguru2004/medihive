import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/i18n/patient_text.dart';

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
    ];

    for (final line in everything) {
      expect(line, isNot(contains('!')), reason: line);
      expect(line.trim(), isNotEmpty);
    }
  });
}
