import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/drafts.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/formatters.dart';
import '../../settings/controllers/settings_form_controller.dart';

/// Money, dates, the clock and the clinic day.
///
/// These are the settings most likely to be wrong on a fresh site and least
/// likely to be noticed: a hospital in Muscat reading `1,200.00` where it
/// writes `1.200,00` still reads a number, just not its own. So every format
/// control on this screen carries a live example of what it produces, rendered
/// through the same `MoneyFormat` and `Formatters` the rest of the app uses —
/// with the **pending** value, before anything is saved.
class SettingsLocaleController extends SettingsFormController {
  static SettingsLocaleController get to => Get.find<SettingsLocaleController>();

  /// The currencies the settings UI offers, and the symbol each one defaults
  /// to. Mirrors `CURRENCY_SYMBOLS` in
  /// `hms_v2/src/modules/settings/organization-settings.ts` — the console and
  /// the app have to offer one list, or a site picks a currency here that the
  /// console cannot name.
  static const Map<String, String> currencies = {
    'INR': '₹',
    'ETB': 'Br',
    'KES': 'KSh',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
  };

  /// `DATE_FORMATS` on the DTO. `@IsIn` rejects anything else, so this is the
  /// whole vocabulary and not a convenience list.
  static const List<String> dateFormats = [
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'yyyy-MM-dd',
    'dd MMM yyyy',
  ];

  /// `CALENDARS` on the DTO.
  static const List<String> calendars = ['gregorian', 'ethiopian'];

  /// `@IsIn(['.', ','])`.
  static const List<String> decimalSeparators = ['.', ','];

  /// Three of the four the DTO accepts.
  ///
  /// The fourth is `''` — "group nothing" — and it is deliberately not offered:
  /// `draftBody` prunes a blank string, because on every other field in this
  /// app a blank means "the form did not touch this". A site that wants the
  /// least grouping picks the space, which is visibly ungrouped and is a value
  /// the write can actually carry.
  static const List<String> thousandSeparators = [',', '.', ' '];

  /// 0 to 3 on the DTO. Three is real: some currencies quote to a thousandth.
  static const List<int> centPrecisions = [0, 1, 2, 3];

  /// The languages a first deployment is in. Free-form on the DTO
  /// (`@Length(2, 10)`), offered as a list here because a typed language code
  /// nobody bundles a translation for is a setting that silently does nothing.
  static const Map<String, String> languages = {
    'en': 'English',
    'hi': 'Hindi',
    'am': 'Amharic',
    'sw': 'Swahili',
    'fr': 'French',
    'ar': 'Arabic',
  };

  /// The zones the first deployments sit in. `@MaxLength(64)` and nothing else
  /// on the DTO, so this is a shortlist rather than the vocabulary — a site's
  /// own zone is kept and offered even when it is not here.
  static const List<String> timezones = [
    'Asia/Kolkata',
    'Africa/Addis_Ababa',
    'Africa/Nairobi',
    'Africa/Lagos',
    'Europe/London',
    'America/New_York',
    'UTC',
  ];

  /// What the previews are drawn against.
  ///
  /// A fixed moment rather than the clock: a preview that changes while
  /// somebody is comparing two date formats is a preview that cannot be
  /// compared. Chosen so every field is unambiguous — the 14th cannot be
  /// mistaken for a month, and 16:40 is a time the 12-hour clock has to move.
  static final DateTime sampleMoment = DateTime(2026, 9, 14, 16, 40);

  /// Big enough to group twice, and with real cents on it, so the separators
  /// and the precision are all visible in one figure.
  static const num sampleAmount = 1234567.5;

  final formKey = GlobalKey<FormState>();

  final currencySymbol = TextEditingController();
  final workingHoursStart = TextEditingController();
  final workingHoursEnd = TextEditingController();
  final appointmentDuration = TextEditingController();

  // The four text fields, mirrored.
  //
  // A `TextEditingController` is not an `Rx`, so an `Obx` over the previews or
  // the save bar never hears a keystroke. Mirroring is what makes the money
  // example move while somebody is typing a symbol, which is the whole point
  // of this screen.
  final rxSymbol = ''.obs;
  final rxStart = ''.obs;
  final rxEnd = ''.obs;
  final rxDuration = ''.obs;

  final rxCurrency = 'INR'.obs;
  final rxCurrencyPosition = 'before'.obs;
  final rxDecimalSeparator = '.'.obs;
  final rxThousandSeparator = ','.obs;
  final rxCentPrecision = 2.obs;
  final rxLanguage = 'en'.obs;
  final rxTimezone = 'Asia/Kolkata'.obs;
  final rxDateFormat = 'dd/MM/yyyy'.obs;
  final rx24Hour = true.obs;
  final rxCalendar = 'gregorian'.obs;

  /// Set by a failed submit, so the summary appears when somebody presses Save
  /// rather than while they are still working down the form.
  final rxSubmitted = false.obs;

  late String _initialSymbol;
  late String _initialCurrency;
  late String _initialPosition;
  late String _initialDecimal;
  late String _initialThousand;
  late int _initialPrecision;
  late String _initialLanguage;
  late String _initialTimezone;
  late String _initialDateFormat;
  late bool _initial24Hour;
  late String _initialCalendar;
  late String _initialStart;
  late String _initialEnd;
  late int _initialDuration;

  /// Whether cents are shown on a whole amount. Not edited here — no control on
  /// this screen owns it — but it is part of the money convention, so the
  /// preview has to be drawn with the site's real value or it lies about what
  /// the separators produce.
  late bool _showZeroCents;

  bool get canWrite => AccessService.to.can(Modules.settings, AccessVerb.update);

  @override
  void onInit() {
    super.onInit();

    final s = SettingsService.to.settings;
    final money = s.money;

    _initialCurrency = money.code;
    _initialSymbol = money.symbol;
    _initialPosition = money.symbolBefore ? 'before' : 'after';
    _initialDecimal = money.decimalSeparator;
    _initialThousand = money.thousandSeparator;
    _initialPrecision = money.precision.clamp(0, 3);
    _showZeroCents = money.showZeroCents;

    _initialLanguage = s.language;
    _initialTimezone = s.timezone;
    _initialDateFormat = normaliseDateFormat(s.dateFormat);
    _initial24Hour = s.use24HourClock;
    _initialCalendar =
        calendars.contains(s.calendar) ? s.calendar : calendars.first;
    _initialStart = s.workingHoursStart;
    _initialEnd = s.workingHoursEnd;
    _initialDuration = s.appointmentDuration.clamp(5, 240);

    rxCurrency.value = _initialCurrency;
    rxCurrencyPosition.value = _initialPosition;
    rxDecimalSeparator.value =
        decimalSeparators.contains(_initialDecimal) ? _initialDecimal : '.';
    rxThousandSeparator.value = thousandSeparators.contains(_initialThousand)
        ? _initialThousand
        : ',';
    rxCentPrecision.value = _initialPrecision;
    rxLanguage.value = _initialLanguage;
    rxTimezone.value = _initialTimezone;
    rxDateFormat.value = _initialDateFormat;
    rx24Hour.value = _initial24Hour;
    rxCalendar.value = _initialCalendar;

    currencySymbol.text = _initialSymbol;
    workingHoursStart.text = _initialStart;
    workingHoursEnd.text = _initialEnd;
    appointmentDuration.text = '$_initialDuration';

    _bind(currencySymbol, rxSymbol);
    _bind(workingHoursStart, rxStart);
    _bind(workingHoursEnd, rxEnd);
    _bind(appointmentDuration, rxDuration);
  }

  final _listeners = <TextEditingController, VoidCallback>{};

  void _bind(TextEditingController field, RxString mirror) {
    mirror.value = field.text;
    void listener() => mirror.value = field.text;
    _listeners[field] = listener;
    field.addListener(listener);
  }

  @override
  void onClose() {
    _listeners.forEach((field, listener) {
      field
        ..removeListener(listener)
        ..dispose();
    });
    _listeners.clear();
    super.onClose();
  }

  /// Maps a stored pattern onto the vocabulary the DTO accepts.
  ///
  /// The console writes moment tokens (`DD/MM/YYYY`) and the DTO's `@IsIn`
  /// wants the ICU spelling (`dd/MM/yyyy`). For these four the two differ only
  /// in case, so a case-insensitive match is the whole translation — and
  /// without it a site provisioned by the console opens this screen with no
  /// format selected and saves a 400.
  static String normaliseDateFormat(String stored) {
    final value = stored.trim().toLowerCase();
    for (final format in dateFormats) {
      if (format.toLowerCase() == value) return format;
    }
    return dateFormats.first;
  }

  // ── Choosing ──────────────────────────────────────────────────────────────

  /// Picking a currency also moves the symbol.
  ///
  /// A site that switches to euros and keeps `₹` prices every invoice in the
  /// wrong currency while looking configured. The field stays editable, so a
  /// site that writes `Rs` rather than `₹` can still say so.
  void selectCurrency(String code) {
    rxCurrency.value = code;
    currencySymbol.text = currencies[code] ?? code;
  }

  void selectPosition(String value) => rxCurrencyPosition.value = value;
  void selectDecimalSeparator(String value) => rxDecimalSeparator.value = value;
  void selectThousandSeparator(String value) =>
      rxThousandSeparator.value = value;
  void selectCentPrecision(int value) => rxCentPrecision.value = value;
  void selectLanguage(String value) => rxLanguage.value = value;
  void selectTimezone(String value) => rxTimezone.value = value;
  void selectDateFormat(String value) => rxDateFormat.value = value;
  void select24Hour(bool value) => rx24Hour.value = value;
  void selectCalendar(String value) => rxCalendar.value = value;

  /// The site's own zone stays on the list even when it is not one of the
  /// shortlisted ones, so opening this screen cannot quietly drop it.
  List<String> get timezoneOptions => timezones.contains(rxTimezone.value)
      ? timezones
      : [rxTimezone.value, ...timezones];

  List<String> get languageOptions => languages.containsKey(rxLanguage.value)
      ? languages.keys.toList()
      : [rxLanguage.value, ...languages.keys];

  static String languageLabel(String code) =>
      languages[code] ?? code.toUpperCase();

  static String thousandSeparatorLabel(String value) =>
      value == ' ' ? 'Space' : value;

  static String centPrecisionLabel(int value) => '$value';

  // ── The previews ──────────────────────────────────────────────────────────

  /// The money convention as it stands right now, saved or not.
  MoneyFormat get pendingMoney => MoneyFormat(
        code: rxCurrency.value,
        symbol: rxSymbol.value.trim(),
        symbolBefore: rxCurrencyPosition.value != 'after',
        decimalSeparator: rxDecimalSeparator.value,
        thousandSeparator: rxThousandSeparator.value,
        precision: rxCentPrecision.value,
        showZeroCents: _showZeroCents,
      );

  /// `₹1,234,567.50` — what a bill will look like.
  String get moneyExample => pendingMoney(sampleAmount);

  /// `14/09/2026` — the sample date in the pending pattern.
  String get dateExample =>
      Formatters.date(sampleMoment, pattern: rxDateFormat.value);

  /// `16:40`, or `4:40 PM`.
  String get timeExample =>
      Formatters.time(sampleMoment, use24Hour: rx24Hour.value);

  // ── Validation ────────────────────────────────────────────────────────────

  /// `08:00`. The DTO matches a 24-hour clock and rejects anything else, so
  /// this is the same check said in advance and in words.
  static final RegExp _clock = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');

  String? validateClock(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Give a time, such as 08:00';
    return _clock.hasMatch(text) ? null : 'Use a 24-hour time, such as 08:00';
  }

  String? validateSymbol(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'What symbol goes on a price?';
    // `@MaxLength(5)`: long enough for `CHF`, short enough that nobody pastes
    // a sentence into a column that appears on every row of a bill.
    return text.length > 5 ? 'Five characters at most' : null;
  }

  String? validateDuration(String? value) {
    final minutes = int.tryParse((value ?? '').trim());
    if (minutes == null) return 'How long is a slot?';
    // 5 to 240 on the DTO. A zero-minute slot is a diary that books
    // infinitely, which is why the server refuses it.
    if (minutes < 5 || minutes > 240) return 'Between 5 and 240 minutes';
    return null;
  }

  int get invalidFieldCount => [
        validateSymbol(rxSymbol.value),
        validateClock(rxStart.value),
        validateClock(rxEnd.value),
        validateDuration(rxDuration.value),
      ].where((message) => message != null).length;

  int get _duration =>
      (int.tryParse(rxDuration.value.trim()) ?? _initialDuration)
          .clamp(5, 240);

  // ── The save ──────────────────────────────────────────────────────────────

  @override
  bool get isDirty =>
      rxCurrency.value != _initialCurrency ||
      rxSymbol.value.trim() != _initialSymbol ||
      rxCurrencyPosition.value != _initialPosition ||
      rxDecimalSeparator.value != _initialDecimal ||
      rxThousandSeparator.value != _initialThousand ||
      rxCentPrecision.value != _initialPrecision ||
      rxLanguage.value != _initialLanguage ||
      rxTimezone.value != _initialTimezone ||
      rxDateFormat.value != _initialDateFormat ||
      rx24Hour.value != _initial24Hour ||
      rxCalendar.value != _initialCalendar ||
      rxStart.value.trim() != _initialStart ||
      rxEnd.value.trim() != _initialEnd ||
      _duration != _initialDuration;

  /// `locale` and `scheduling`, and nothing else.
  ///
  /// `appearance` and `clinical` are not here and must not be: the draft drops
  /// a group it was given nothing for, and the backend preserves a group it is
  /// not sent — which is what keeps the theme somebody set on the Appearance
  /// screen from being stamped by a phone saving a date format.
  @override
  OrganizationSettingsDraft buildDraft() => OrganizationSettingsDraft(
        currency: rxCurrency.value,
        currencySymbol: rxSymbol.value,
        currencyPosition: rxCurrencyPosition.value,
        decimalSeparator: rxDecimalSeparator.value,
        thousandSeparator: rxThousandSeparator.value,
        centPrecision: rxCentPrecision.value,
        language: rxLanguage.value,
        timezone: rxTimezone.value,
        dateFormat: rxDateFormat.value,
        use24HourClock: rx24Hour.value,
        calendar: rxCalendar.value,
        workingHoursStart: rxStart.value,
        workingHoursEnd: rxEnd.value,
        appointmentDuration: _duration,
      );

  @override
  Future<void> save() async {
    rxSubmitted.value = true;
    // Both checks: the `Form` covers the fields that carry a validator, and
    // the count covers the slot length, whose stepper is not a `FormField` and
    // would otherwise sail past `validate()` with a 400 waiting for it.
    if (!(formKey.currentState?.validate() ?? false) ||
        invalidFieldCount > 0) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await super.save();
  }

  @override
  void onSaved() {
    rxSubmitted.value = false;
    _initialCurrency = rxCurrency.value;
    _initialSymbol = rxSymbol.value.trim();
    _initialPosition = rxCurrencyPosition.value;
    _initialDecimal = rxDecimalSeparator.value;
    _initialThousand = rxThousandSeparator.value;
    _initialPrecision = rxCentPrecision.value;
    _initialLanguage = rxLanguage.value;
    _initialTimezone = rxTimezone.value;
    _initialDateFormat = rxDateFormat.value;
    _initial24Hour = rx24Hour.value;
    _initialCalendar = rxCalendar.value;
    _initialStart = rxStart.value.trim();
    _initialEnd = rxEnd.value.trim();
    _initialDuration = _duration;
    _showZeroCents = SettingsService.to.settings.money.showZeroCents;
  }
}
