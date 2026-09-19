import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/i18n/patient_text.dart';
import 'package:medihive/app/data/models/case_session.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what the screen shows when the patient interrupts
///
/// A patient being interviewed out loud does what anybody does: they interrupt.
/// "Why do you ask?" "How much longer?" "Is it serious?" The server recognises
/// a closed set of those, answers from a phrasebook a clinician has read, and
/// asks the same question again.
///
/// Two things arrive on the wire, and which one reaches the screen is the whole
/// subject of this file:
///
///   * `intent` — the name of the closed-set member. The screen draws **this**,
///     through its own copy in `PatientText`.
///   * `reply` — the server's wording. The room says it out loud. It reaches
///     the screen only for an intent this build has never heard of, which
///     happens when the server ships one first.
///
/// The rule being protected is the one `_Notices` and
/// `CaseTakingController._followAgent` both record: server free text is not
/// rendered on this surface, because that is the hole through which a sentence
/// telling a patient what is wrong with them would arrive. An intent name
/// cannot carry one — which is why the server sends one at all.
/// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('reading an aside off a turn', () {
    test('carries both halves', () {
      final result = CaseTurnResult.fromJson(<String, dynamic>{
        'turnId': 't1',
        'aside': <String, dynamic>{
          'intent': 'why_ask',
          'reply': 'It helps the doctor see the whole picture.',
        },
      });

      expect(result.aside?.intent, 'why_ask');
      expect(result.aside?.reply, 'It helps the doctor see the whole picture.');
    });

    test('an ordinary turn has none', () {
      final result = CaseTurnResult.fromJson(<String, dynamic>{'turnId': 't1'});
      expect(result.aside, isNull);
    });

    test('an empty one is no aside at all, not an empty bubble', () {
      // A server that sends `{}` must not put a blank line in the middle of a
      // conversation.
      expect(CaseAside.maybeFrom(<String, dynamic>{}), isNull);
      expect(
        CaseAside.maybeFrom(<String, dynamic>{'intent': '', 'reply': ''}),
        isNull,
      );
      expect(CaseAside.maybeFrom('why_ask'), isNull);
      expect(CaseAside.maybeFrom(null), isNull);
    });
  });

  group('what gets drawn', () {
    test('the app\'s own sentence, never the server\'s, for a known intent', () {
      const serverWording = 'SERVER TEXT THAT MUST NOT BE DRAWN';

      for (final intent in const [
        'repeat',
        'not_understood',
        'why_ask',
        'how_long',
        'is_it_serious',
        'want_human',
        'who_are_you',
        'greeting',
        'thanks',
        'wait',
        'unrelated',
      ]) {
        final drawn = PatientText.asideReply(intent, fallback: serverWording);
        expect(drawn, isNotNull, reason: '$intent has no copy in the app');
        expect(drawn, isNot(serverWording), reason: '$intent drew server text');
        expect(drawn!.trim(), isNotEmpty);
      }
    });

    test('falls back to the server wording for an intent this build predates', () {
      expect(
        PatientText.asideReply('parking_validation', fallback: 'Ask the desk.'),
        'Ask the desk.',
      );
    });

    test('draws nothing when there is neither', () {
      expect(PatientText.asideReply('parking_validation'), isNull);
      expect(PatientText.asideReply('parking_validation', fallback: '   '), isNull);
    });

    test('the frightened question is declined, and not left as a refusal', () {
      final reply = PatientText.asideIsItSerious;

      // This screen never tells a patient what is wrong with them.
      expect(reply, contains('cannot tell you'));
      // But it says who can, and what to do if waiting stops being safe —
      // the same routing instruction `RedFlagNotice` gives.
      expect(reply, contains('doctor'));
      expect(reply, contains('front desk'));
    });
  });
}
