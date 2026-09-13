import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/app_clock.dart';
import 'package:medihive/app/data/utils/formatters.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `Formatters`
///
/// Three of these read the clock, so every test that does not pass `now:`
/// explicitly pins [AppClock] first. A duration test that reads the real clock
/// is a test that fails at a midnight nobody was watching.
///
/// The properties that matter clinically, and that a careless rewrite loses:
///
///  * A wait past an hour is never a bare minute count — a reader under load
///    converts `147m` wrongly, and a number converted wrongly is worse than no
///    number at all.
///  * A length of stay counts calendar days, not 24-hour blocks, because that
///    is what a ward round means by "day three".
///  * An age is stated in the unit a clinician would say it in. A neonate
///    charted as `0y` is a neonate whose weight-based dose nobody can check.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('elapsed', () {
    final now = DateTime(2026, 9, 13, 14, 30);

    /// What a board whose clock says [now] prints for something that started
    /// [ago] before it.
    String elapsed(Duration ago) =>
        Formatters.elapsed(now.subtract(ago), now: now);

    test('under an hour is a bare minute count', () {
      expect(elapsed(const Duration(minutes: 8)), '8m');
      expect(elapsed(const Duration(minutes: 59)), '59m');
      expect(elapsed(Duration.zero), '0m');
    });

    test('past an hour it is hours and padded minutes, never 147m', () {
      // The shape matters: `1h 04m` reads at a glance, `64m` does not, and
      // `1h 4m` in a column of `1h 04m` does not line up.
      expect(elapsed(const Duration(minutes: 64)), '1h 04m');
      expect(elapsed(const Duration(minutes: 60)), '1h 00m');
      expect(elapsed(const Duration(minutes: 147)), '2h 27m');
      expect(elapsed(const Duration(minutes: 1439)), '23h 59m');
    });

    test('past a day it is days and hours, and drops a zero hour', () {
      expect(elapsed(const Duration(days: 3, hours: 6)), '3d 6h');
      expect(elapsed(const Duration(days: 1)), '1d');
      expect(elapsed(const Duration(days: 14)), '14d');
    });

    test('a missing or future instant never reads as a wait', () {
      // Clock skew between a ward tablet and the server is routine, and a
      // negative wait rendered as `-3m` looks like a defect to a clinician.
      expect(Formatters.elapsed(null), '—');
      expect(elapsed(const Duration(minutes: -5)), '0m');
    });

    test('with no now: given it reads the app clock', () {
      AppClock.freeze(now);
      addTearDown(AppClock.unfreeze);

      expect(
        Formatters.elapsed(now.subtract(const Duration(minutes: 20))),
        '20m',
      );
    });
  });

  group('age', () {
    setUp(() {
      // A Sunday in September, well away from a month or year boundary, so a
      // failure here is about the arithmetic and not about the date chosen.
      AppClock.freeze(DateTime(2026, 9, 13, 10, 30));
      addTearDown(AppClock.unfreeze);
    });

    test('above two years it is whole years', () {
      expect(Formatters.age(DateTime(2000, 5, 1)), '26y');
      expect(Formatters.age(DateTime(2024, 9, 13)), '2y');
      // A birthday that has not come round yet this year does not count.
      expect(Formatters.age(DateTime(2000, 12, 25)), '25y');
    });

    test('between one month and two years it is whole months', () {
      // The unit a paediatric chart is written in: `1y` for a child of
      // fourteen months loses the half a weight-based dose is worked out from.
      expect(Formatters.age(DateTime(2024, 9, 14)), '23mo');
      expect(Formatters.age(DateTime(2025, 9, 13)), '12mo');
      expect(Formatters.age(DateTime(2026, 8, 13)), '1mo');
    });

    test('below one month it is days, so a neonate is never charted as 0y', () {
      expect(Formatters.age(DateTime(2026, 8, 14)), '30d');
      expect(Formatters.age(DateTime(2026, 9, 6)), '7d');
      expect(Formatters.age(DateTime(2026, 9, 13)), '0d');
    });

    test('the time of day never moves the answer', () {
      // Both instants are floored to their calendar day first: a baby born at
      // 23:50 last night is one day old this morning, not zero.
      expect(Formatters.age(DateTime(2026, 9, 12, 23, 50)), '1d');
      expect(Formatters.age(DateTime(2026, 9, 13, 23, 50)), '0d');
    });

    test('a missing or impossible date of birth is a dash, not a number', () {
      expect(Formatters.age(null), '—');
      expect(Formatters.age(DateTime(2026, 9, 14)), '—');
    });
  });

  group('lengthOfStayDays', () {
    test('counts calendar days, the way a ward round counts them', () {
      // Admitted 23:40 on Monday, seen on the Wednesday round: that is day
      // two. Counting 24-hour blocks gives one — thirty-one hours have passed
      // — and a board that says one when the round says two is a board the
      // round stops reading.
      final admitted = DateTime(2026, 9, 7, 23, 40);
      final wednesday = DateTime(2026, 9, 9, 7, 0);

      expect(Formatters.lengthOfStayDays(admitted, now: wednesday), 2);
      expect(wednesday.difference(admitted).inDays, 1);
    });

    test('the day of admission is day zero', () {
      final admitted = DateTime(2026, 9, 13, 2, 0);
      expect(
        Formatters.lengthOfStayDays(admitted,
            now: DateTime(2026, 9, 13, 23, 59)),
        0,
      );
    });

    test('a missing or future admission is zero, never negative', () {
      expect(Formatters.lengthOfStayDays(null), 0);
      expect(
        Formatters.lengthOfStayDays(
          DateTime(2026, 9, 20),
          now: DateTime(2026, 9, 13),
        ),
        0,
      );
    });

    test('with no now: given it reads the app clock', () {
      AppClock.freeze(DateTime(2026, 9, 13, 8, 0));
      addTearDown(AppClock.unfreeze);

      expect(Formatters.lengthOfStayDays(DateTime(2026, 9, 10, 22, 15)), 3);
    });
  });

  group('icuPattern', () {
    test('translates the moment tokens the backend sends', () {
      expect(Formatters.icuPattern('DD/MM/YYYY'), 'dd/MM/yyyy');
      expect(Formatters.icuPattern('YYYY-MM-DD'), 'yyyy-MM-dd');
      expect(Formatters.icuPattern('DD-MM-YY'), 'dd-MM-yy');
      expect(Formatters.icuPattern('D/M/YYYY'), 'd/M/yyyy');
    });

    test('the day-name tokens become their ICU spelling', () {
      // The one pair that is not a case change: moment writes a weekday with
      // Ds, ICU writes it with Es.
      expect(Formatters.icuPattern('DDDD'), 'EEEE');
      expect(Formatters.icuPattern('DDD, DD MMM YYYY'), 'EEE, dd MMM yyyy');
    });

    test('a token the two conventions already agree on is left alone', () {
      expect(Formatters.icuPattern('MM'), 'MM');
      expect(Formatters.icuPattern('DD MMMM YYYY'), 'dd MMMM yyyy');
      expect(Formatters.icuPattern('HH:mm'), 'HH:mm');
    });

    test('separators and literals survive untouched', () {
      expect(Formatters.icuPattern('DD.MM.YYYY'), 'dd.MM.yyyy');
      expect(Formatters.icuPattern('  DD/MM/YYYY  '), 'dd/MM/yyyy');
    });

    test('an empty pattern falls back rather than formatting to nothing', () {
      // `DateFormat('')` renders an empty string, so a site with no
      // `date_format` row would show blank dates on every row.
      expect(Formatters.icuPattern(''), 'dd/MM/yyyy');
      expect(Formatters.icuPattern('   '), 'dd/MM/yyyy');
    });

    test('what it produces is what date() formats with', () {
      // The two are only useful together: the translation has to survive being
      // handed to `DateFormat`.
      final date = DateTime(2026, 3, 12);
      expect(Formatters.date(date, pattern: 'DD/MM/YYYY'), '12/03/2026');
      expect(Formatters.date(date, pattern: 'YYYY-MM-DD'), '2026-03-12');
      expect(Formatters.date(null), '—');
    });
  });
}
