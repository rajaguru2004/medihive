import 'json.dart';
import 'site_settings.dart';

/// The settings blob, whichever way the route sent it.
///
/// `/auth/me` answers the organisation as a structure; Prisma stores the same
/// column as JSON inside text, and `/settings/organization` has returned it
/// unparsed. A model that reads only the object form silently themes a site
/// with the product defaults.
Map<String, dynamic> _jsonObject(dynamic value) {
  final maps = asMapList(value);
  return maps.isEmpty ? const {} : maps.first;
}

/// A site's day, as the scheduler reads it.
class WorkingHours {
  const WorkingHours({this.start = '08:00', this.end = '17:00'});

  /// `08:00`. 24-hour, because the clinical default is and because `8:00`
  /// with no meridiem is a rota nobody can read across a corridor.
  final String start;
  final String end;

  static const WorkingHours fallback = WorkingHours();

  factory WorkingHours.fromJson(Map<String, dynamic> json) => WorkingHours(
        start: asString(json['start'], fallback: '08:00'),
        end: asString(json['end'], fallback: '17:00'),
      );

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
}

/// The three hex overrides a site on the `custom` preset sets.
class BrandColors {
  const BrandColors({this.primary, this.secondary, this.accent});

  final String? primary;
  final String? secondary;
  final String? accent;

  bool get isEmpty => primary == null && secondary == null && accent == null;

  factory BrandColors.fromJson(Map<String, dynamic> json) => BrandColors(
        primary: asStringOrNull(json['primary']),
        secondary: asStringOrNull(json['secondary']),
        accent: asStringOrNull(json['accent']),
      );

  Map<String, dynamic> toJson() => {
        'primary': ?primary,
        'secondary': ?secondary,
        'accent': ?accent,
      };
}

/// Money, dates and language.
class OrganizationLocale {
  const OrganizationLocale({
    this.currency = 'INR',
    this.currencySymbol = '₹',
    this.currencyPosition = 'before',
    this.decimalSeparator = '.',
    this.thousandSeparator = ',',
    this.centPrecision = 2,
    this.showZeroCents = false,
    this.language = 'en',
    this.timezone = 'Asia/Kolkata',
    this.dateFormat = 'dd/MM/yyyy',
    this.use24HourClock = true,
    this.calendar = 'gregorian',
  });

  final String currency;
  final String currencySymbol;

  /// `before` or `after`.
  final String currencyPosition;

  final String decimalSeparator;
  final String thousandSeparator;
  final int centPrecision;
  final bool showZeroCents;

  final String language;
  final String timezone;
  final String dateFormat;
  final bool use24HourClock;

  /// `gregorian` or `ethiopian`.
  final String calendar;

  static const OrganizationLocale fallback = OrganizationLocale();

  /// The site's money convention, as one callable. **Every figure with a
  /// currency on it goes through this** — a symbol concatenated onto a number
  /// is how an app ships `₹1,200.00` to a site that writes `1.200,00 ₹`.
  MoneyFormat get money => MoneyFormat(
        code: currency,
        symbol: currencySymbol,
        symbolBefore: currencyPosition != 'after',
        decimalSeparator: decimalSeparator,
        thousandSeparator: thousandSeparator,
        precision: centPrecision,
        showZeroCents: showZeroCents,
      );

  /// Reads the grouped shape, falling back to the flat keys a site
  /// provisioned before the groups existed still stores.
  factory OrganizationLocale.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> flat = const {},
  }) {
    Object? pick(String key, [String? legacy]) =>
        json[key] ?? flat[key] ?? (legacy == null ? null : flat[legacy]);

    return OrganizationLocale(
      currency: asString(
        pick('currency', 'defaultCurrency'),
        fallback: 'INR',
      ),
      currencySymbol: asString(json['currencySymbol'], fallback: '₹'),
      currencyPosition:
          asString(json['currencyPosition'], fallback: 'before'),
      decimalSeparator: asString(json['decimalSeparator'], fallback: '.'),
      thousandSeparator: asString(json['thousandSeparator'], fallback: ','),
      centPrecision: asInt(json['centPrecision'], fallback: 2),
      showZeroCents: asBool(json['showZeroCents']),
      language: asString(pick('language', 'defaultLanguage'), fallback: 'en'),
      timezone: asString(
        pick('timezone', 'defaultTimezone'),
        fallback: 'Asia/Kolkata',
      ),
      dateFormat: asString(json['dateFormat'], fallback: 'dd/MM/yyyy'),
      use24HourClock: asBool(json['use24HourClock'], fallback: true),
      calendar: asString(
        pick('calendar', 'defaultCalendar'),
        fallback: 'gregorian',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'currencySymbol': currencySymbol,
        'currencyPosition': currencyPosition,
        'decimalSeparator': decimalSeparator,
        'thousandSeparator': thousandSeparator,
        'centPrecision': centPrecision,
        'showZeroCents': showZeroCents,
        'language': language,
        'timezone': timezone,
        'dateFormat': dateFormat,
        'use24HourClock': use24HourClock,
        'calendar': calendar,
      };
}

/// The brand and the face. The three keys a theme rebuild watches.
class OrganizationAppearance {
  const OrganizationAppearance({
    this.themePreset = 'default',
    this.themeFont = 'montserrat',
    this.customColors = const BrandColors(),
  });

  final String themePreset;
  final String themeFont;
  final BrandColors customColors;

  static const OrganizationAppearance fallback = OrganizationAppearance();

  factory OrganizationAppearance.fromJson(Map<String, dynamic> json) =>
      OrganizationAppearance(
        themePreset: asString(json['themePreset'], fallback: 'default'),
        themeFont: asString(json['themeFont'], fallback: 'montserrat'),
        customColors: BrandColors.fromJson(asMap(json['customColors'])),
      );

  Map<String, dynamic> toJson() => {
        'themePreset': themePreset,
        'themeFont': themeFont,
        if (!customColors.isEmpty) 'customColors': customColors.toJson(),
      };
}

/// The conventions a ward board is read against.
class OrganizationClinical {
  const OrganizationClinical({
    this.waitBreachMinutes = 30,
    this.triageScale = 'p1-p5',
    this.showPatientNames = true,
    this.sessionLockMinutes = 5,
  });

  /// How long a queue ticket may wait before the board flags it. Zero turns
  /// the flag off for sites that escalate out of band.
  final int waitBreachMinutes;

  final String triageScale;

  /// Off in departments whose screens are visible from a waiting area.
  final bool showPatientNames;

  /// Idle minutes before a shared device locks itself. Zero is never.
  final int sessionLockMinutes;

  static const OrganizationClinical fallback = OrganizationClinical();

  factory OrganizationClinical.fromJson(Map<String, dynamic> json) =>
      OrganizationClinical(
        waitBreachMinutes: asInt(json['waitBreachMinutes'], fallback: 30),
        triageScale: asString(json['triageScale'], fallback: 'p1-p5'),
        showPatientNames: asBool(json['showPatientNames'], fallback: true),
        sessionLockMinutes: asInt(json['sessionLockMinutes'], fallback: 5),
      );

  Map<String, dynamic> toJson() => {
        'waitBreachMinutes': waitBreachMinutes,
        'triageScale': triageScale,
        'showPatientNames': showPatientNames,
        'sessionLockMinutes': sessionLockMinutes,
      };
}

/// The clinic day.
class OrganizationScheduling {
  const OrganizationScheduling({
    this.workingHours = WorkingHours.fallback,
    this.appointmentDuration = 30,
  });

  final WorkingHours workingHours;

  /// How long a slot is, in minutes.
  final int appointmentDuration;

  static const OrganizationScheduling fallback = OrganizationScheduling();

  /// Reads the grouped shape, falling back to the flat keys the console still
  /// writes.
  factory OrganizationScheduling.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> flat = const {},
  }) =>
      OrganizationScheduling(
        workingHours: WorkingHours.fromJson(
          asMap(json['workingHours'] ?? flat['workingHours']),
        ),
        appointmentDuration: asInt(
          json['appointmentDuration'] ?? flat['appointmentDuration'],
          fallback: 30,
        ),
      );

  Map<String, dynamic> toJson() => {
        'workingHours': workingHours.toJson(),
        'appointmentDuration': appointmentDuration,
      };
}

/// The four groups of `Organization.settings`.
class OrganizationSettings {
  const OrganizationSettings({
    this.locale = OrganizationLocale.fallback,
    this.appearance = OrganizationAppearance.fallback,
    this.clinical = OrganizationClinical.fallback,
    this.scheduling = OrganizationScheduling.fallback,
  });

  final OrganizationLocale locale;
  final OrganizationAppearance appearance;
  final OrganizationClinical clinical;
  final OrganizationScheduling scheduling;

  static const OrganizationSettings fallback = OrganizationSettings();

  factory OrganizationSettings.fromJson(Map<String, dynamic> json) =>
      OrganizationSettings(
        // The flat keys are the console's older vocabulary, still stored on
        // every site provisioned before the groups existed. Read as a
        // fallback, never written back: the backend lifts and discards them.
        locale: OrganizationLocale.fromJson(asMap(json['locale']), flat: json),
        appearance: OrganizationAppearance.fromJson(asMap(json['appearance'])),
        clinical: OrganizationClinical.fromJson(asMap(json['clinical'])),
        scheduling: OrganizationScheduling.fromJson(
          asMap(json['scheduling']),
          flat: json,
        ),
      );

  Map<String, dynamic> toJson() => {
        'locale': locale.toJson(),
        'appearance': appearance.toJson(),
        'clinical': clinical.toJson(),
        'scheduling': scheduling.toJson(),
      };
}

/// The site this device belongs to, as the `organization` block of
/// `GET /api/auth/me` answers it.
class Organization {
  const Organization({
    this.id = '',
    this.name = '',
    this.slug = '',
    this.logoUrl,
    this.logoTextUrl,
    this.primaryColor = '',
    this.secondaryColor = '',
    this.email,
    this.phone,
    this.address,
    this.city,
    this.region,
    this.country,
    this.isActive = true,
    this.settings = OrganizationSettings.fallback,
    this.modulesEnabled = const {},
  });

  final String id;
  final String name;
  final String slug;

  final String? logoUrl;

  /// The wordmark, where a site has one drawn separately from its mark.
  final String? logoTextUrl;

  final String primaryColor;
  final String secondaryColor;

  // Contact block. Present on `/settings/organization`, absent from
  // `/auth/me`, so all of it is nullable rather than defaulted.
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? region;
  final String? country;

  final bool isActive;

  final OrganizationSettings settings;

  /// Which modules this site licenses. A screen for a module a site does not
  /// have is a tab that 403s.
  final Map<String, bool> modulesEnabled;

  static const Organization empty = Organization();

  bool get isEmpty => id.isEmpty && name.isEmpty;

  /// Absent reads as **on**: a site provisioned before a module existed has no
  /// key for it, and hiding a module because a key is missing is how a
  /// pharmacy disappears from a working deployment.
  bool moduleEnabled(String module) => modulesEnabled[module] ?? true;

  /// The site's money convention.
  MoneyFormat get money => settings.locale.money;

  /// The same site in the flat shape `SiteSettings` reads, so the one settings
  /// reader in this app stays the only one.
  SiteSettings get siteSettings => SiteSettings.fromOrganization(toJson());

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: asString(json['id'] ?? json['_id']),
        name: asString(json['name']),
        slug: asString(json['slug']),
        logoUrl: asStringOrNull(json['logoUrl']),
        logoTextUrl: asStringOrNull(json['logoTextUrl']),
        primaryColor: asString(json['primaryColor']),
        secondaryColor: asString(json['secondaryColor']),
        email: asStringOrNull(json['email']),
        phone: asStringOrNull(json['phone']),
        address: asStringOrNull(json['address']),
        city: asStringOrNull(json['city']),
        region: asStringOrNull(json['region']),
        country: asStringOrNull(json['country']),
        isActive: asBool(json['isActive'], fallback: true),
        settings: OrganizationSettings.fromJson(_jsonObject(json['settings'])),
        modulesEnabled: {
          for (final entry in _jsonObject(json['modulesEnabled']).entries)
            entry.key: asBool(entry.value),
        },
      );

  factory Organization.of(dynamic value) => value is Map
      ? Organization.fromJson(value.cast<String, dynamic>())
      : empty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'logoUrl': ?logoUrl,
        'logoTextUrl': ?logoTextUrl,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'email': ?email,
        'phone': ?phone,
        'address': ?address,
        'city': ?city,
        'region': ?region,
        'country': ?country,
        'isActive': isActive,
        'settings': settings.toJson(),
        'modulesEnabled': modulesEnabled,
      };
}
