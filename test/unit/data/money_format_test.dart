import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/site_settings.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `MoneyFormat`
///
/// A symbol concatenated onto a number is how an app ships `₹1,200.00` to a
/// site that writes `1.200,00 ₹`. Every separator here is a site setting rather
/// than a locale fact, so the two conventions below — a dot-decimal site and a
/// comma-decimal one — are both first-class and both round-trip.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  /// The default: `$1,234.56`, cents hidden on a whole amount.
  const usd = MoneyFormat.fallback;

  /// A comma-decimal site: `€1.234,56`. The reason [MoneyFormat.parse] exists —
  /// `double.parse` reads what its staff type as a thousandth of it.
  const eur = MoneyFormat(
    code: 'EUR',
    symbol: '€',
    symbolBefore: true,
    decimalSeparator: ',',
    thousandSeparator: '.',
    precision: 2,
    showZeroCents: true,
  );

  /// A site that writes its symbol after the figure.
  const trailing = MoneyFormat(
    code: 'SEK',
    symbol: 'kr',
    symbolBefore: false,
    decimalSeparator: '.',
    thousandSeparator: ' ',
    precision: 2,
    showZeroCents: false,
  );

  group('call, grouping', () {
    test('groups the whole part in threes from the right', () {
      expect(usd(1), r'$1');
      expect(usd(999), r'$999');
      expect(usd(1000), r'$1,000');
      expect(usd(999999), r'$999,999');
      expect(usd(1234567), r'$1,234,567');
      expect(usd(1234567.89), r'$1,234,567.89');
    });

    test('groups with whatever mark the site chose', () {
      expect(eur(1234567.89), '€1.234.567,89');
      expect(trailing(1234567.89), '1 234 567.89kr');
    });

    test('a null amount is zero, not a blank', () {
      // A bill that shows nothing where a figure belongs reads as a bill that
      // failed to load.
      expect(usd(null), r'$0');
      expect(eur(null), '€0,00');
    });
  });

  group('call, the sign', () {
    test('the minus goes outside the symbol', () {
      // Every accounting convention this product ships to agrees; the other way
      // round, `$-1,234.50`, reads as a typo.
      expect(usd(-1234.5), r'-$1,234.50');
      expect(eur(-1234.5), '-€1.234,50');
    });

    test('the minus stays outside a trailing symbol too', () {
      expect(trailing(-1234.5), '-1 234.50kr');
    });

    test('the minus survives a figure with no symbol at all', () {
      expect(usd(-1234.5, withSymbol: false), '-1,234.50');
    });
  });

  group('call, showZeroCents', () {
    test('off, a whole amount drops its empty cents', () {
      expect(usd(1250), r'$1,250');
      expect(usd(1250.00), r'$1,250');
      // A fractional amount keeps them: only an all-zero remainder is dropped.
      expect(usd(1250.05), r'$1,250.05');
    });

    test('on, a whole amount keeps them', () {
      expect(eur(1250), '€1.250,00');
      expect(eur(0), '€0,00');
    });
  });

  group('call, symbol placement', () {
    test('before or after the figure, as the site writes it', () {
      expect(usd(42.5), r'$42.50');
      expect(trailing(42.5), '42.50kr');
    });

    test('withSymbol: false leaves the figure alone for a column header', () {
      expect(usd(1234.5, withSymbol: false), '1,234.50');
      expect(trailing(1234.5, withSymbol: false), '1 234.50');
    });
  });

  group('parse', () {
    test('reads back anything call wrote, in either convention', () {
      // The round trip is the contract: a figure shown on a bill has to be the
      // figure that comes back out of the field a user edits it in.
      const amounts = [0, 1, 42.5, 999.99, 1234.56, 1234567.89, 1250];
      for (final amount in amounts) {
        expect(usd.parse(usd(amount)), amount.toDouble(), reason: '$amount');
        expect(eur.parse(eur(amount)), amount.toDouble(), reason: '$amount');
        expect(
          trailing.parse(trailing(amount)),
          amount.toDouble(),
          reason: '$amount',
        );
      }
    });

    test('a comma decimal separator is a decimal point, not a grouping mark',
        () {
      // The bug this method exists to stop: `double.parse('1.234,56')` reads
      // 1.234, and silently billing a thousandth of the intended amount is the
      // kind of bug nobody reports as a bug.
      expect(eur.parse('1.234,56'), 1234.56);
      expect(eur.parse('1234,56'), 1234.56);
      expect(eur.parse('€1.234,56'), 1234.56);
    });

    test('strips the symbol, the grouping mark and stray spaces', () {
      expect(usd.parse(r'$1,234.56'), 1234.56);
      expect(usd.parse('1 234.56'), 1234.56);
      expect(usd.parse('  1,234.56  '), 1234.56);
      expect(trailing.parse('1 234.56kr'), 1234.56);
    });

    test('a negative figure keeps its sign', () {
      expect(usd.parse(r'-$1,234.56'), -1234.56);
      expect(eur.parse('-€1.234,56'), -1234.56);
    });

    test('an empty field is null, so a caller can tell it from a zero', () {
      // An unset price and a price of nothing are different facts, and a form
      // that conflates them posts a zero the user never typed.
      expect(usd.parse(null), isNull);
      expect(usd.parse(''), isNull);
      expect(usd.parse('   '), isNull);
      expect(usd.parse('abc'), isNull);
      expect(usd.parse(r'$'), isNull);
      expect(usd.parse('0'), 0.0);
    });
  });

  group('editable', () {
    test('hands a field digits and the decimal mark, with no grouping', () {
      // Grouping inserted while somebody is typing moves the cursor out from
      // under their thumb.
      expect(usd.editable(1234.5), '1234.5');
      expect(eur.editable(1234.5), '1234,5');
      // A whole amount loses its `.00`: a field pre-filled with `1250.00`
      // invites somebody to select the lot and retype it, and that is how a
      // digit goes missing.
      expect(usd.editable(1250), '1250');
      expect(usd.editable(null), '');
    });

    test('what editable writes, parse reads back', () {
      for (final amount in [0, 42.5, 1250, 1234.56]) {
        expect(usd.parse(usd.editable(amount)), amount.toDouble());
        expect(eur.parse(eur.editable(amount)), amount.toDouble());
      }
    });
  });
}
