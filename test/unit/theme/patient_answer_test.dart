import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `PatientAnswer` and `AnswerConfidence`
///
/// `UnknownAnswerRow` offers four answers to a yes/no question, and this file
/// holds the reason there are four. The failure it guards against is not a
/// rendering bug: it is a case note that says something the patient never
/// said.
///
///  * A patient who **does not know** whether a relative had a heart attack is
///    not a patient whose relative did not. Resolving an unreadable stored
///    value to "no" would write a family history this app invented.
///  * A patient who **skipped** has not made a finding at all, and a skip
///    filed as a finding is a gap nobody can see to go back and fill.
///
/// So the safety property below is the same shape as `BedState.resolve`
/// refusing to read an unrecognised bed as vacant: **an unrecognised answer is
/// never yes and never no.**
///
/// The second half of the file pins `AnswerConfidence`, where the equivalent
/// property is that a transcript the app cannot vouch for is never labelled
/// "Clear".
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('the answers the backend actually stores', () {
    test('every spelling of a yes is yes', () {
      for (final raw in ['yes', 'Y', 'true', '1', 'present', 'POSITIVE']) {
        expect(PatientAnswer.resolve(raw), PatientAnswer.yes, reason: raw);
      }
    });

    test('every spelling of a no is no', () {
      for (final raw in ['no', 'N', 'false', '0', 'absent', 'denies']) {
        expect(PatientAnswer.resolve(raw), PatientAnswer.no, reason: raw);
      }
    });

    test('every spelling of not knowing is unknown', () {
      for (final raw in [
        'unknown',
        'unsure',
        'not sure',
        'dont know',
        "don't know",
        'do not know',
        'DK',
      ]) {
        expect(PatientAnswer.resolve(raw), PatientAnswer.unknown, reason: raw);
      }
    });

    test('every spelling of moving past it is skipped', () {
      for (final raw in ['skip', 'skipped', 'declined', 'refused']) {
        expect(PatientAnswer.resolve(raw), PatientAnswer.skipped, reason: raw);
      }
    });

    test('casing, spacing and a curly apostrophe are all forgiven', () {
      // It arrives from a backend that does its own casing, and from a
      // transcriber that punctuates like a word processor.
      expect(PatientAnswer.resolve('  YES '), PatientAnswer.yes);
      expect(PatientAnswer.resolve('Not   Sure'), PatientAnswer.unknown);
      expect(PatientAnswer.resolve('Don’t know'), PatientAnswer.unknown);
    });

    test('every value round-trips through what is stored', () {
      for (final answer in PatientAnswer.values) {
        expect(
          PatientAnswer.resolve(answer.storageValue),
          answer,
          reason: answer.storageValue,
        );
      }
    });
  });

  group('the safety property', () {
    test('an unrecognised answer is unknown — never yes, never no', () {
      // Something was recorded that this build cannot read. Reading it as a
      // denial writes "denies chest pain" onto a case where nobody said it.
      for (final raw in [
        'maybe',
        'sometimes',
        'ys',
        'nope',
        'n/a',
        'refused to answer in English',
        'peut-être',
        '2',
        '-1',
        'null',
      ]) {
        final answer = PatientAnswer.resolve(raw);
        expect(answer, PatientAnswer.unknown, reason: raw);
        expect(answer.isDefinite, isFalse, reason: raw);
      }
    });

    test('nothing recorded is a skip, because nothing was answered', () {
      for (final raw in <String?>[null, '', '   ', '\n']) {
        expect(
          PatientAnswer.resolve(raw),
          PatientAnswer.skipped,
          reason: raw ?? 'null',
        );
      }
    });

    test('a skip is the one answer that is not a finding', () {
      expect(PatientAnswer.yes.isRecorded, isTrue);
      expect(PatientAnswer.no.isRecorded, isTrue);
      expect(PatientAnswer.unknown.isRecorded, isTrue);
      expect(PatientAnswer.skipped.isRecorded, isFalse);
    });

    test('only yes and no settle the question that was asked', () {
      expect(PatientAnswer.yes.isDefinite, isTrue);
      expect(PatientAnswer.no.isDefinite, isTrue);
      expect(PatientAnswer.unknown.isDefinite, isFalse);
      expect(PatientAnswer.skipped.isDefinite, isFalse);
    });
  });

  group('four answers must never read as two', () {
    test('no two share a word', () {
      final labels = PatientAnswer.values.map((a) => a.label).toSet();
      expect(labels, hasLength(PatientAnswer.values.length));
      expect(labels.any((l) => l.trim().isEmpty), isFalse);
    });

    test('no two share a mark', () {
      // The second channel, for a reader who is colour-blind, looking at a
      // screenshot, or reading the screen from across a waiting room.
      final icons = PatientAnswer.values.map((a) => a.icon).toSet();
      expect(icons, hasLength(PatientAnswer.values.length));
    });

    test('the transcript says what happened, not what to do', () {
      // "Skip" is an instruction on a button; "Skipped" is a fact in a
      // transcript, where the row of buttons is no longer on screen.
      expect(PatientAnswer.skipped.transcriptLabel,
          isNot(PatientAnswer.skipped.label));
      expect(PatientAnswer.unknown.transcriptLabel,
          isNot(PatientAnswer.unknown.label));

      final spoken =
          PatientAnswer.values.map((a) => a.transcriptLabel).toSet();
      expect(spoken, hasLength(PatientAnswer.values.length));
    });
  });

  group('how sure the app is that it heard right', () {
    test('a high score is clear and a low one was not heard', () {
      expect(AnswerConfidence.fromScore(0.99), AnswerConfidence.clear);
      expect(AnswerConfidence.fromScore(0.1), AnswerConfidence.unheard);
    });

    test('the boundaries turn where they say they turn', () {
      expect(AnswerConfidence.fromScore(0.8), AnswerConfidence.clear);
      expect(AnswerConfidence.fromScore(0.7999), AnswerConfidence.unsure);
      expect(AnswerConfidence.fromScore(0.5), AnswerConfidence.unsure);
      expect(AnswerConfidence.fromScore(0.4999), AnswerConfidence.unheard);
    });

    test('no score at all is unsure, never clear', () {
      // A transcript this app cannot vouch for, marked "Clear", asks the
      // patient to confirm it on the app's authority instead of on their own
      // memory of what they just said.
      expect(AnswerConfidence.fromScore(null), AnswerConfidence.unsure);
      expect(AnswerConfidence.fromScore(double.nan), AnswerConfidence.unsure);
    });

    test('a score outside 0…1 still lands somewhere sensible', () {
      expect(AnswerConfidence.fromScore(1.4), AnswerConfidence.clear);
      expect(AnswerConfidence.fromScore(-2), AnswerConfidence.unheard);
    });

    test('the three states have three different words and three marks', () {
      expect(
        AnswerConfidence.values.map((c) => c.label).toSet(),
        hasLength(AnswerConfidence.values.length),
      );
      expect(
        AnswerConfidence.values.map((c) => c.icon).toSet(),
        hasLength(AnswerConfidence.values.length),
      );
    });
  });

  group('where an answer came from', () {
    test('the four sources are four different words', () {
      // A clinician reading this back needs to know whether "no chest pain" is
      // what the patient said, what they tapped, or what the register already
      // held. Those are three strengths of evidence and only two happened
      // today.
      expect(
        AnswerSource.values.map((s) => s.label).toSet(),
        hasLength(AnswerSource.values.length),
      );
      expect(
        AnswerSource.values.map((s) => s.icon).toSet(),
        hasLength(AnswerSource.values.length),
      );
    });
  });
}
