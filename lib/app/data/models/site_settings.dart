import 'json.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Site settings
///
/// The backend stores settings as a flat collection of
/// `{settingCategory, settingKey, settingValue}` documents and returns the
/// whole set from `GET /api/settings`. That shape is convenient for the admin
/// console that edits it and hostile to every screen that reads it, so this is
/// the one place the app translates it into named, typed fields.
///
/// Everything is nullable-tolerant on purpose: a site provisioned before a key
/// existed simply has no document for it, and the app must render rather than
/// throw. Each getter names the default it falls back to.
/// ─────────────────────────────────────────────────────────────────────────────
class SiteSettings {
  const SiteSettings(this._values);

  /// `settingKey` → raw `settingValue`, exactly as stored.
  final Map<String, dynamic> _values;

  /// Empty settings — a cold start before the first fetch lands. Every getter
  /// below returns its documented default.
  static const SiteSettings empty = SiteSettings({});

  /// Builds from the `result` of `GET /api/settings`.
  ///
  /// Tolerates both shapes the backend has returned over its life: the array
  /// of setting documents, and a plain `{key: value}` map.
  factory SiteSettings.fromResult(dynamic result) {
    final out = <String, dynamic>{};
    if (result is List) {
      for (final row in result) {
        if (row is Map && row['settingKey'] != null) {
          out[row['settingKey'].toString()] = row['settingValue'];
        }
      }
    } else if (result is Map) {
      result.forEach((k, v) => out[k.toString()] = v);
    }
    return SiteSettings(out);
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.unmodifiable(_values);

  // ── Raw access ────────────────────────────────────────────────────────────

  dynamic raw(String key) => _values[key];

  String string(String key, String fallback) {
    final v = _values[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    // Seed data writes the literal strings 'None' and '' for "unset".
    if (s.isEmpty || s == 'None' || s == 'null') return fallback;
    return s;
  }

  bool boolean(String key, {required bool fallback}) {
    final v = _values[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  int integer(String key, int fallback) =>
      asInt(_values[key], fallback: fallback);

  // ── Identity ──────────────────────────────────────────────────────────────

  /// What the site calls itself. The shell's title and the sign-in wordmark.
  String get siteName => string('site_name', 'MediHive');

  String get siteLogo => string('site_logo', '');

  // ── Theming ───────────────────────────────────────────────────────────────
  //
  // The three keys `ThemeService` watches. Changing anything else in settings
  // must never rebuild a theme — see `ThemeService.signatureOf`.

  String get themePreset => string('theme_preset', 'default');
  String get themeCustomColors => string('theme_custom_colors', '');
  String get themeFont => string('theme_font', 'montserrat');

  // ── Clinical conventions ──────────────────────────────────────────────────

  /// The triage scale this site charts in. Decides which vocabulary a triage
  /// picker offers; `CaseStatus` resolves both either way, so a mixed estate
  /// still reads as one board.
  String get triageScale => string('triage_scale', 'p1-p5');

  /// How long a queue ticket may wait before the board flags it, in minutes.
  ///
  /// A board with no breach threshold is a board nobody escalates from. Zero
  /// turns the flag off for sites that escalate out of band.
  int get waitBreachMinutes => integer('wait_breach_minutes', 30);

  /// Whether a ward board shows patient names or bed numbers alone.
  ///
  /// Off in departments whose screens are visible from a waiting area — the
  /// same board, with the identifying column suppressed.
  bool get showPatientNames => boolean('show_patient_names', fallback: true);

  // ── Money ─────────────────────────────────────────────────────────────────
  //
  // Billing is a corner of this app rather than its subject, but the corner
  // still has to be right: a site chooses its currency, and a symbol
  // concatenated onto a number is how an app ships "₹1,200.00" to a site that
  // writes "1.200,00 ₹".

  /// The site's money convention, as one callable. Every figure with a
  /// currency on it in this app goes through it.
  MoneyFormat get money => MoneyFormat(
        code: string('default_currency_code', 'INR'),
        symbol: string('currency_symbol', '₹'),
        // 'before' or 'after'.
        symbolBefore: string('currency_position', 'before') != 'after',
        decimalSeparator: string('decimal_sep', '.'),
        thousandSeparator: string('thousand_sep', ','),
        precision: integer('cent_precision', 2),
        showZeroCents: boolean('zero_format', fallback: false),
      );

  // ── Dates ─────────────────────────────────────────────────────────────────

  /// The site's date pattern, in `intl` syntax. See `Formatters.date`.
  String get dateFormat => string('date_format', 'dd/MM/yyyy');

  /// 24-hour clocks are the clinical default and the app's, but a site that
  /// charts in 12-hour gets 12-hour.
  bool get use24HourClock => boolean('use_24_hour_clock', fallback: true);
}

class MoneyFormat {
  const MoneyFormat({
    required this.code,
    required this.symbol,
    required this.symbolBefore,
    required this.decimalSeparator,
    required this.thousandSeparator,
    required this.precision,
    required this.showZeroCents,
  });

  final String code;
  final String symbol;
  final bool symbolBefore;
  final String decimalSeparator;
  final String thousandSeparator;
  final int precision;

  /// When false, a whole amount drops its `.00`.
  final bool showZeroCents;

  static const MoneyFormat fallback = MoneyFormat(
    code: 'USD',
    symbol: r'$',
    symbolBefore: true,
    decimalSeparator: '.',
    thousandSeparator: ',',
    precision: 2,
    showZeroCents: false,
  );

  /// Formats [amount] in this site's convention.
  ///
  /// Grouping is applied by hand rather than through `intl`'s `NumberFormat`
  /// because the separators are site settings, not locale facts — a site
  /// in Muscat may well choose `1,234.56`.
  String call(num? amount, {bool withSymbol = true}) {
    final value = amount ?? 0;
    final negative = value < 0;
    final digits = value.abs().toStringAsFixed(precision);

    final dot = digits.indexOf('.');
    final whole = dot == -1 ? digits : digits.substring(0, dot);
    var cents = dot == -1 ? '' : digits.substring(dot + 1);

    if (!showZeroCents && cents.isNotEmpty && int.tryParse(cents) == 0) {
      cents = '';
    }

    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(thousandSeparator);
      grouped.write(whole[i]);
    }

    final number =
        cents.isEmpty ? grouped.toString() : '$grouped$decimalSeparator$cents';

    // The sign goes outside the symbol — "-$1,234.50", never "$-1,234.50".
    // Every accounting convention in the currencies this product ships to
    // agrees on that, and the other way round reads as a typo.
    final withCurrency = !withSymbol
        ? number
        : (symbolBefore ? '$symbol$number' : '$number$symbol');
    return negative ? '-$withCurrency' : withCurrency;
  }

  /// Reads a number a user typed in this site's convention.
  ///
  /// The inverse of [call], and the reason it has to exist: a site whose
  /// decimal separator is a comma has staff typing `1.234,56`, and
  /// `double.parse` reads that as `1.234`. Silently billing a thousandth of
  /// the intended amount is the kind of bug nobody reports as a bug.
  ///
  /// Returns null for anything that is not a number, so a caller can tell an
  /// empty field from a zero.
  double? parse(String? raw) {
    var text = (raw ?? '').trim();
    if (text.isEmpty) return null;

    // The symbol comes off first, and as a whole string. Plenty of sites write
    // theirs with more than one character — `kr`, `Rs`, `RM`, `CHF` — and a
    // loop comparing one rune at a time never matches any of them, so the
    // figure this class had just formatted came back out as null.
    if (symbol.isNotEmpty) text = text.replaceAll(symbol, '');

    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char == thousandSeparator || char == ' ') continue;
      if (char == decimalSeparator) {
        buffer.write('.');
        continue;
      }
      // A stray grouping mark from a keyboard that does not match the site's
      // setting: '1,234.56' typed where the site groups with a space.
      if (char == ',' && decimalSeparator != ',') continue;
      buffer.write(char);
    }

    return double.tryParse(buffer.toString());
  }

  /// What a form field should hold for [amount] — digits and the site's
  /// decimal mark, with no symbol and no grouping, because grouping inserted
  /// while somebody is typing moves the cursor out from under their thumb.
  String editable(num? amount) {
    if (amount == null) return '';
    var fixed = amount.toStringAsFixed(precision);
    // A whole amount loses its '.00': a price field pre-filled with "1250.00"
    // invites somebody to select the lot and retype it, which is how a digit
    // goes missing.
    if (fixed.contains('.')) {
      fixed = fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return decimalSeparator == '.'
        ? fixed
        : fixed.replaceAll('.', decimalSeparator);
  }

  @override
  bool operator ==(Object other) =>
      other is MoneyFormat &&
      other.code == code &&
      other.symbol == symbol &&
      other.symbolBefore == symbolBefore &&
      other.decimalSeparator == decimalSeparator &&
      other.thousandSeparator == thousandSeparator &&
      other.precision == precision &&
      other.showZeroCents == showZeroCents;

  @override
  int get hashCode => Object.hash(code, symbol, symbolBefore,
      decimalSeparator, thousandSeparator, precision, showZeroCents);
}
