import 'package:flutter/widgets.dart';

/// Widget keys for locale and money — `/settings/locale`.
///
/// The three `*Example` keys are on the live previews rather than on the
/// controls beside them. They are what the screen is *for*: a reader choosing
/// a thousand separator is choosing what `₹123,456.00` looks like, and an
/// assertion on the control alone would pass against a preview that never
/// re-rendered.
abstract final class SettingsLocaleKeys {
  static const Key screen = Key('settings_locale_screen');
  static const Key noAccess = Key('settings_locale_no_access');

  // ── Money ─────────────────────────────────────────────────────────────────
  static const Key currency = Key('settings_locale_currency');
  static const Key currencySymbol = Key('settings_locale_currency_symbol');
  static const Key currencyPosition = Key('settings_locale_currency_position');
  static const Key decimalSeparator = Key('settings_locale_decimal_separator');
  static const Key thousandSeparator =
      Key('settings_locale_thousand_separator');
  static const Key centPrecision = Key('settings_locale_cent_precision');
  static const Key moneyExample = Key('settings_locale_money_example');

  // ── Dates and clock ───────────────────────────────────────────────────────
  static const Key dateFormat = Key('settings_locale_date_format');
  static const Key dateExample = Key('settings_locale_date_example');
  static const Key clock24 = Key('settings_locale_clock_24');
  static const Key timeExample = Key('settings_locale_time_example');
  static const Key calendar = Key('settings_locale_calendar');

  // ── Place ─────────────────────────────────────────────────────────────────
  static const Key language = Key('settings_locale_language');
  static const Key timezone = Key('settings_locale_timezone');

  // ── The clinic day ────────────────────────────────────────────────────────
  static const Key workingHoursStart = Key('settings_locale_hours_start');
  static const Key workingHoursEnd = Key('settings_locale_hours_end');
  static const Key appointmentDuration =
      Key('settings_locale_appointment_duration');

  // ── Save bar ──────────────────────────────────────────────────────────────
  static const Key errors = Key('settings_locale_errors');
  static const Key save = Key('settings_locale_save');

  /// A segment inside one of the segmented controls above, named by the value
  /// it selects — `before`, `after`, `dot`, `comma`, `2`.
  static Key option(String control, String value) =>
      Key('settings_locale_${control}_$value');
}
