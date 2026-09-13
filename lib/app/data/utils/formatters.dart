import 'package:intl/intl.dart';

import '../../core/app_clock.dart';
import '../models/site_settings.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Formatters
///
/// Every date, amount and relative time in the app is rendered here, so a
/// change of convention is one edit rather than forty.
///
/// The rule that matters: **formatting takes the site's settings, it does
/// not assume them.** A hard-coded `$` or `dd/MM/yyyy` is correct for exactly
/// one deployment and quietly wrong for every other.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class Formatters {
  // ── Dates ─────────────────────────────────────────────────────────────────

  /// Translates the backend's moment-style tokens (`DD/MM/YYYY`) into the
  /// ICU pattern `intl` speaks (`dd/MM/yyyy`).
  ///
  /// Only the tokens the seed data actually uses are translated; anything
  /// unrecognised falls through untouched, which `DateFormat` will either
  /// honour or treat as a literal.
  static String icuPattern(String momentPattern) {
    final buffer = StringBuffer();
    final pattern = momentPattern.trim();
    var i = 0;
    while (i < pattern.length) {
      final ch = pattern[i];
      var run = 0;
      while (i + run < pattern.length && pattern[i + run] == ch) {
        run++;
      }
      final token = ch * run;
      buffer.write(switch (token) {
        'YYYY' => 'yyyy',
        'YY' => 'yy',
        'DDDD' => 'EEEE',
        'DDD' => 'EEE',
        'DD' => 'dd',
        'D' => 'd',
        _ => token,
      });
      i += run;
    }
    final out = buffer.toString();
    return out.isEmpty ? 'dd/MM/yyyy' : out;
  }

  /// A date in the site's configured format.
  static String date(DateTime? value, {String pattern = 'DD/MM/YYYY'}) {
    if (value == null) return '—';
    return DateFormat(icuPattern(pattern)).format(value.toLocal());
  }

  /// A clock time, in the site's clock.
  ///
  /// 24-hour is the clinical default and this app's: `14:05` cannot be
  /// misread, and a drug chart written in 12-hour without a meridiem is how a
  /// dose gets given twice.
  static String time(DateTime? value, {bool use24Hour = true}) {
    if (value == null) return '—';
    final local = value.toLocal();
    return DateFormat(use24Hour ? 'HH:mm' : 'h:mm a').format(local);
  }

  // ── Clinical durations ────────────────────────────────────────────────────

  /// How long since [since] — a wait, a time on the board, a length of stay.
  ///
  /// `8m`, `1h 04m`, `3d 6h`. Never a bare minute count past an hour: a reader
  /// under load converts `147m` wrongly, and a number they convert wrongly is
  /// worse than no number.
  static String elapsed(DateTime? since, {DateTime? now}) {
    if (since == null) return '—';
    final delta = (now ?? AppClock.now()).difference(since.toLocal());
    if (delta.isNegative) return '0m';

    final days = delta.inDays;
    if (days >= 1) {
      final hours = delta.inHours % 24;
      return hours == 0 ? '${days}d' : '${days}d ${hours}h';
    }
    final hours = delta.inHours;
    final minutes = delta.inMinutes % 60;
    if (hours >= 1) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    return '${delta.inMinutes}m';
  }

  /// A length of stay in whole days, as a ward board counts it.
  ///
  /// Counted in calendar days rather than in 24-hour blocks, because that is
  /// what a ward round means by "day three": admitted late on Monday is day
  /// three on Wednesday, whatever the clock says.
  static int lengthOfStayDays(DateTime? admitted, {DateTime? now}) {
    if (admitted == null) return 0;
    final days = _floor(now ?? AppClock.now())
        .difference(_floor(admitted.toLocal()))
        .inDays;
    return days < 0 ? 0 : days;
  }

  /// An age from a date of birth, in the unit a clinician would say it in.
  ///
  /// Years above two, months above one, days below that. A neonate charted as
  /// "0y" is a neonate whose weight-based dose nobody can sanity-check.
  static String age(DateTime? dob, {DateTime? now}) {
    if (dob == null) return '—';
    final today = _floor(now ?? AppClock.now());
    final born = _floor(dob.toLocal());
    if (born.isAfter(today)) return '—';

    var years = today.year - born.year;
    if (today.month < born.month ||
        (today.month == born.month && today.day < born.day)) {
      years--;
    }
    if (years >= 2) return '${years}y';

    final months = (today.year - born.year) * 12 +
        (today.month - born.month) -
        (today.day < born.day ? 1 : 0);
    if (months >= 1) return '${months}mo';

    return '${today.difference(born).inDays}d';
  }

  /// `12 Mar 2026` — used where the site's numeric format would be ambiguous
  /// beside other numbers, such as in a list row next to an amount.
  static String dateMedium(DateTime? value) =>
      value == null ? '—' : DateFormat('d MMM yyyy').format(value.toLocal());

  static String dateTime(DateTime? value, {String pattern = 'DD/MM/YYYY'}) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${date(local, pattern: pattern)} · '
        '${DateFormat('HH:mm').format(local)}';
  }

  /// `in 3 days`, `today`, `6 days ago` — how a due date is read.
  ///
  /// Both instants are floored to their calendar day first, so a document due
  /// tonight at 23:00 reads "today" rather than "in 0 days".
  static String relativeDay(DateTime? value, {DateTime? now}) {
    if (value == null) return '—';
    final today = _floor(now ?? AppClock.now());
    final target = _floor(value.toLocal());
    final days = target.difference(today).inDays;

    return switch (days) {
      0 => 'today',
      1 => 'tomorrow',
      -1 => 'yesterday',
      > 1 && <= 30 => 'in $days days',
      < -1 && >= -30 => '${-days} days ago',
      > 30 => 'in ${(days / 30).round()} months',
      _ => '${(-days / 30).round()} months ago',
    };
  }

  /// How many days past due, or zero when it is not.
  static int daysOverdue(DateTime? due, {DateTime? now}) {
    if (due == null) return 0;
    final days = _floor(now ?? AppClock.now())
        .difference(_floor(due.toLocal()))
        .inDays;
    return days > 0 ? days : 0;
  }

  static DateTime _floor(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Parses the backend's ISO-8601 timestamps, tolerating null and blank.
  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  // ── Money ─────────────────────────────────────────────────────────────────

  /// An amount in the site's currency and grouping.
  static String money(num? amount, MoneyFormat format) => format(amount);

  /// The same amount without its symbol, for a column that carries the
  /// currency in its header instead of on every row.
  static String amount(num? amount, MoneyFormat format) =>
      format(amount, withSymbol: false);

  /// A compact amount for a tile too narrow for the full figure:
  /// `$1.2M`, `$48.5k`. Falls back to the full form below a thousand.
  static String moneyCompact(num? value, MoneyFormat format) {
    final amount = value ?? 0;
    final magnitude = amount.abs();
    if (magnitude < 1000) return format(amount);

    final (divisor, suffix) = switch (magnitude) {
      >= 1000000000 => (1000000000, 'B'),
      >= 1000000 => (1000000, 'M'),
      _ => (1000, 'k'),
    };

    final scaled = magnitude / divisor;
    // One decimal below ten, none above: `$9.4k` then `$49k`.
    final digits = scaled < 10 ? 1 : 0;
    final number = scaled.toStringAsFixed(digits);
    final trimmed = number.endsWith('.0')
        ? number.substring(0, number.length - 2)
        : number;

    // Sign outside the symbol, exactly as MoneyFormat does it.
    final withCurrency = format.symbolBefore
        ? '${format.symbol}$trimmed$suffix'
        : '$trimmed$suffix${format.symbol}';
    return amount < 0 ? '-$withCurrency' : withCurrency;
  }

  /// `48%`. Clamped, and safe when the total is zero.
  static String percent(num? part, num? total) {
    final t = (total ?? 0).toDouble();
    if (t == 0) return '0%';
    final fraction = ((part ?? 0).toDouble() / t).clamp(0.0, 1.0);
    return '${(fraction * 100).round()}%';
  }

  /// The fraction behind [percent], for a progress bar. Never NaN.
  static double fraction(num? part, num? total) {
    final t = (total ?? 0).toDouble();
    if (t == 0) return 0;
    final value = (part ?? 0).toDouble() / t;
    return value.isFinite ? value.clamp(0.0, 1.0) : 0;
  }

  // ── Text ──────────────────────────────────────────────────────────────────

  /// `inv-0042` → `INV-0042`. The backend stores prefixes lower-case and the
  /// documents themselves print them upper-case.
  static String documentNumber(String? prefix, dynamic number, dynamic year) {
    final p = (prefix ?? '').trim().toUpperCase().replaceAll(RegExp(r'-$'), '');
    final n = (number ?? '').toString();
    final y = (year ?? '').toString();
    if (n.isEmpty) return p.isEmpty ? '—' : p;
    final padded = n.padLeft(4, '0');
    return [
      if (p.isNotEmpty) p,
      padded,
      if (y.isNotEmpty) y,
    ].join('-');
  }

  /// Shortens a long name to fit a dense row without cutting mid-word where a
  /// word boundary is close by.
  static String truncate(String value, int max) {
    final text = value.trim();
    if (text.length <= max) return text;
    final cut = text.substring(0, max);
    final space = cut.lastIndexOf(' ');
    return '${space > max - 8 ? cut.substring(0, space) : cut}…';
  }
}
