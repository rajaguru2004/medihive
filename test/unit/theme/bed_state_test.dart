import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `BedState.resolve`
///
/// One safety property carries this whole file: a bed nobody can account for
/// must not be offered to the next admission. Every unrecognised string — a new
/// backend status, a typo in a seed row, a null from a partial payload —
/// resolves to [BedState.blocked], never to [BedState.vacant].
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('the states the backend actually stores', () {
    test('every spelling of an empty bed is vacant', () {
      for (final raw in ['vacant', 'available', 'free', 'empty']) {
        expect(BedState.resolve(raw), BedState.vacant, reason: raw);
      }
    });

    test('every spelling of a bed with a patient in it is occupied', () {
      for (final raw in ['occupied', 'admitted', 'in use']) {
        expect(BedState.resolve(raw), BedState.occupied, reason: raw);
      }
    });

    test('every spelling of a held bed is reserved', () {
      for (final raw in ['reserved', 'booked', 'pending']) {
        expect(BedState.resolve(raw), BedState.reserved, reason: raw);
      }
    });

    test('a bed out of service is blocked', () {
      expect(BedState.resolve('blocked'), BedState.blocked);
    });

    test('the state is matched case- and whitespace-insensitively', () {
      // It arrives from a ward system that does its own casing.
      expect(BedState.resolve('  VACANT '), BedState.vacant);
      expect(BedState.resolve('In Use'), BedState.occupied);
      expect(BedState.resolve('Booked'), BedState.reserved);
    });
  });

  group('the safety property', () {
    test('an unknown bed state is blocked, never vacant', () {
      // The whole point of the fallback. A status this build has never seen —
      // a new backend value, a typo, a partial payload — must not put a
      // patient in a bed nobody can account for.
      for (final raw in <String?>[
        null,
        '',
        '   ',
        'cleaning',
        'decontamination',
        'vacnat',
        'unknown',
        'closed',
        'out of service',
      ]) {
        final state = BedState.resolve(raw);
        expect(state, BedState.blocked, reason: 'resolve($raw)');
        expect(state, isNot(BedState.vacant), reason: 'resolve($raw)');
      }
    });
  });

  group('a bed tile is readable without its colour', () {
    test('every state carries a word and a glyph of its own', () {
      // Rule three: a state that is only a colour is unreadable to eight
      // percent of men and to every screenshot. A grid is the one place a pill
      // will not fit, so each state owes the reader an icon instead.
      final labels = BedState.values.map((s) => s.label).toSet();
      final icons = BedState.values.map((s) => s.icon).toSet();
      final colors = BedState.values.map((s) => s.color).toSet();

      expect(labels, hasLength(BedState.values.length));
      expect(icons, hasLength(BedState.values.length));
      expect(colors, hasLength(BedState.values.length));
    });

    test('no bed state is painted with the brand teal', () {
      // Teal is the brand, never a state — a teal "vacant" tile beside a teal
      // primary button makes the brand unreadable as an affordance.
      for (final state in BedState.values) {
        expect(state.color, isNot(AppColors.primary), reason: state.name);
      }
    });
  });
}
