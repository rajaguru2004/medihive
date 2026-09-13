import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `CaseStatus`
///
/// Two of the three clinical rules are enforced here rather than in review, so
/// a well-meant refactor that maps a status onto the brand teal, or paints a
/// missed appointment red, fails a build instead of reaching a ward board:
///
///  * **Teal is the brand, never an acuity** — no status in either vocabulary
///    may resolve to `AppColors.primary`.
///  * **Red means one thing** — `DNA` is amber. A clinician scanning for red is
///    scanning for a deteriorating patient, not for an empty chair.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('colorOf, over the word vocabulary', () {
    test('each vocabulary word lands on its own ramp colour', () {
      const expected = <String, Color>{
        'critical': AppColors.acuityCritical,
        'resuscitation': AppColors.acuityCritical,
        'red': AppColors.acuityCritical,
        'very urgent': AppColors.acuityUrgent,
        'orange': AppColors.acuityUrgent,
        'awaiting sign-off': AppColors.acuityReview,
        'pending': AppColors.acuityReview,
        'completed': AppColors.acuityStable,
        'cleared': AppColors.acuityStable,
        'lwbs': AppColors.acuityDischarged,
        'transferred out': AppColors.acuityDischarged,
        'in progress': AppColors.acuityStandard,
        'yellow': AppColors.acuityStandard,
        'non-urgent': AppColors.acuityRoutine,
        'draft': AppColors.acuityRoutine,
      };

      expected.forEach((word, color) {
        expect(CaseStatus.colorOf(word), color, reason: 'colorOf($word)');
      });
    });

    test('the word is matched case- and whitespace-insensitively', () {
      // Sites chart in their own casing, and one ward export arrives padded.
      expect(CaseStatus.colorOf('  CRITICAL '), AppColors.acuityCritical);
      expect(CaseStatus.colorOf('In Progress'), AppColors.acuityStandard);
    });

    test('an empty, blank or unknown status rests at routine', () {
      // The resting state of a record nobody has flagged. Never critical: a
      // colour the board did not earn is a colour the board stops believing.
      for (final unknown in <String?>[null, '', '   ', 'banana', 'p9']) {
        expect(
          CaseStatus.colorOf(unknown),
          AppColors.acuityRoutine,
          reason: 'colorOf($unknown)',
        );
      }
    });

    test('labelOf sentence-cases the word and dashes an empty one', () {
      expect(CaseStatus.labelOf('in progress'), 'In progress');
      expect(CaseStatus.labelOf('CRITICAL'), 'Critical');
      expect(CaseStatus.labelOf(null), '—');
      expect(CaseStatus.labelOf('  '), '—');
    });
  });

  group('the stored triage codes', () {
    test('every code in the picker resolves in both tables', () {
      // A picker reads `codes`; a row reads the other two. A code present in
      // one and missing from another is a blank pill on a ward board.
      for (final code in CaseStatus.codes) {
        expect(CaseStatus.isCode(code), isTrue, reason: code);
        expect(CaseStatus.labelOfCode(code), isNot('—'), reason: code);
      }
    });

    test('each code resolves to its documented colour', () {
      const expected = <String, Color>{
        'P1': AppColors.acuityCritical,
        'P2': AppColors.acuityUrgent,
        'P3': AppColors.acuityUrgent,
        'P4': AppColors.acuityStandard,
        'P5': AppColors.acuityRoutine,
        'ADM': AppColors.acuityStandard,
        'OBS': AppColors.acuityStable,
        'DIS': AppColors.acuityDischarged,
        'TRF': AppColors.acuityDischarged,
        'REV': AppColors.acuityReview,
        'DNA': AppColors.warning,
      };

      // Fails loudly if a code is added to the picker without landing here.
      expect(expected.keys, containsAll(CaseStatus.codes));
      expected.forEach((code, color) {
        expect(
          CaseStatus.colorOfCode(code),
          color,
          reason: 'colorOfCode($code)',
        );
      });
    });

    test('each code resolves to its documented words', () {
      const expected = <String, String>{
        'P1': 'Immediate',
        'P2': 'Very urgent',
        'P3': 'Urgent',
        'P4': 'Standard',
        'P5': 'Non-urgent',
        'ADM': 'Admitted',
        'OBS': 'Observation',
        'DIS': 'Discharged',
        'TRF': 'Transferred',
        'REV': 'Awaiting review',
        'DNA': 'Did not attend',
      };

      expect(expected.keys, containsAll(CaseStatus.codes));
      expected.forEach((code, label) {
        expect(
          CaseStatus.labelOfCode(code),
          label,
          reason: 'labelOfCode($code)',
        );
      });
    });

    test('a code arrives in whatever casing the backend stored it', () {
      expect(CaseStatus.colorOfCode('p1'), AppColors.acuityCritical);
      expect(CaseStatus.labelOfCode(' dna '), 'Did not attend');
    });

    test('a word that is not a code still resolves through the word ramp', () {
      // A board mixing two ward conventions has to read as one board.
      expect(CaseStatus.colorOfCode('resuscitation'), AppColors.acuityCritical);
      expect(CaseStatus.labelOfCode('in progress'), 'In progress');
    });
  });

  group('priorityOf orders a mixed-acuity queue by urgency', () {
    test('P1 sorts ahead of P2 ahead of P3 ahead of P4 ahead of P5', () {
      // Strictly ahead, at every step. P2 and P3 share amber on purpose — a
      // reader should not have to tell two ambers apart — but they are a
      // ten-minute target and a sixty-minute one, and a rank that ties them
      // hands the choice between them back to arrival order.
      final ranks = [
        for (final code in ['P1', 'P2', 'P3', 'P4', 'P5'])
          CaseStatus.priorityOf(code),
      ];
      for (var i = 1; i < ranks.length; i++) {
        expect(
          ranks[i - 1],
          lessThan(ranks[i]),
          reason: 'P$i must sort ahead of P${i + 1}',
        );
      }
    });

    test('a shuffled board sorts back into triage order', () {
      // The property the queue actually leans on: a sprained ankle never seats
      // ahead of the chest pain that walked in two minutes later.
      final board = ['P4', 'P1', 'P5', 'P3', 'P2']
        ..sort(
          (a, b) =>
              CaseStatus.priorityOf(a).compareTo(CaseStatus.priorityOf(b)),
        );
      expect(board, ['P1', 'P2', 'P3', 'P4', 'P5']);
    });

    test('an unknown status rests at routine, never ahead of a triaged one',
        () {
      // A status this build has never seen must not jump the queue. It ranks
      // where its colour puts it — routine — so it sorts behind every code a
      // clinician actually assigned.
      for (final unknown in <String?>[null, '', 'something new']) {
        expect(
          CaseStatus.priorityOf('P4'),
          lessThan(CaseStatus.priorityOf(unknown)),
          reason: 'priorityOf($unknown)',
        );
        expect(
          CaseStatus.priorityOf(unknown),
          CaseStatus.priorityOf('P5'),
          reason: 'priorityOf($unknown)',
        );
      }
    });
  });

  group('the clinical colour rules, as tests', () {
    test('no status in either vocabulary is ever the brand teal', () {
      // Rule two: teal is the brand, never an acuity. A teal "stable" pill
      // beside a teal primary button makes the brand unreadable as an
      // affordance, so both vocabularies are swept, including their fallbacks.
      const words = <String?>[
        null,
        '',
        'critical',
        'immediate',
        'very urgent',
        'in progress',
        'admitted',
        'routine',
        'stable',
        'completed',
        'discharged',
        'no-show',
        'awaiting review',
        'submitted',
        'green',
        'blue',
        'yellow',
        'orange',
        'red',
        'a status nobody has defined',
      ];

      for (final word in words) {
        expect(
          CaseStatus.colorOf(word),
          isNot(AppColors.primary),
          reason: 'colorOf($word)',
        );
        expect(
          CaseStatus.colorOfCode(word),
          isNot(AppColors.primary),
          reason: 'colorOfCode($word)',
        );
      }
      for (final code in CaseStatus.codes) {
        expect(
          CaseStatus.colorOfCode(code),
          isNot(AppColors.primary),
          reason: 'colorOfCode($code)',
        );
      }
    });

    test('a missed appointment is amber, because red means one thing', () {
      // Rule one. `DNA` is an administrative problem; red on a ward board says
      // a patient is deteriorating, and every red that is not one costs the
      // scan its meaning.
      expect(CaseStatus.colorOfCode('DNA'), AppColors.warning);
      expect(CaseStatus.colorOfCode('DNA'), isNot(AppColors.acuityCritical));
      expect(CaseStatus.colorOfCode('DNA'), isNot(AppColors.error));
    });

    test('P1 is the only code that earns red', () {
      // The other half of rule one: nothing drifts into red from the side.
      for (final code in CaseStatus.codes) {
        if (CaseStatus.colorOfCode(code) == AppColors.acuityCritical) {
          expect(code, 'P1', reason: '$code must not be red');
        }
      }
    });
  });
}
