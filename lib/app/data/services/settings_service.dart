import 'package:get/get.dart';

import '../../core/app_log.dart';
import '../../theme/theme_service.dart';
import '../models/site_settings.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../utils/api_envelope.dart';
import '../utils/formatters.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Settings Service
///
/// The site's own conventions — its name, its brand, its triage scale, its
/// currency and date format — held once and read everywhere.
///
/// This is the single place new branding reaches the app. A screen never calls
/// `ThemeService` itself: it lands here, and [adopt] decides whether anything
/// actually changed before a theme is rebuilt.
/// ─────────────────────────────────────────────────────────────────────────────
class SettingsService extends GetxService {
  static SettingsService get to => Get.find<SettingsService>();

  final _settings = SiteSettings.empty.obs;

  /// Which modules this site has switched on, from the organisation record.
  ///
  /// Held beside the settings rather than inside them because it is a
  /// different kind of thing: settings change how a screen behaves, this
  /// decides whether the screen exists here at all.
  final _modulesEnabled = <String, dynamic>{}.obs;

  SiteSettings get settings => _settings.value;
  Rx<SiteSettings> get rx => _settings;

  /// A module absent from this map is **on**.
  ///
  /// The server's stored default carries `inpatient: false`, and plenty of
  /// sites have never opened the settings screen — so treating a missing key
  /// as off would hide the ward board from all of them. Only an explicit
  /// `false` hides anything.
  Map<String, dynamic> get modulesEnabled => _modulesEnabled;

  /// Records the organisation's module switches, from `GET /api/auth/me`.
  void adoptModules(Map<String, dynamic> modules) {
    _modulesEnabled
      ..clear()
      ..addAll(modules);
  }

  DioClient get _client => Get.find<DioClient>();

  /// The site's money convention, as one callable:
  /// `SettingsService.to.money(1250)` → `₹1,250`.
  String money(num? amount, {bool withSymbol = true}) =>
      settings.money(amount, withSymbol: withSymbol);

  /// A date in the site's own pattern.
  String date(DateTime? value) => Formatters.date(value, pattern: settings.dateFormat);

  /// A time, in the site's clock.
  String time(DateTime? value) =>
      Formatters.time(value, use24Hour: settings.use24HourClock);

  /// How long a queue ticket may wait before the board flags it.
  int get waitBreachMinutes => settings.waitBreachMinutes;

  /// Fetches the site's settings and applies anything that changed.
  ///
  /// Never throws: a site whose settings route is down still gets a working
  /// app on the documented defaults, which is a far better outcome than a
  /// sign-in that fails because branding could not be read.
  Future<void> load() async {
    try {
      final response = await _client.get(Endpoints.settings);
      final envelope = ApiEnvelope.of(response);
      if (!envelope.success) {
        AppLog.warn('SettingsService', 'settings unavailable: ${envelope.message}');
        return;
      }
      adopt(SiteSettings.fromResult(envelope.result));
    } catch (e, stack) {
      AppLog.error('SettingsService', 'settings load failed', e, stack);
    }
  }

  /// Takes on new settings and re-themes only if the brand or face moved.
  void adopt(SiteSettings next) {
    _settings.value = next;
    if (Get.isRegistered<ThemeService>()) {
      final changed = ThemeService.to.adopt(next);
      if (changed) {
        AppLog.info('SettingsService', 'brand → ${ThemeService.to.brand.name}');
      }
    }
  }

  /// Clears back to defaults. Called on sign-out so the next account on a
  /// shared ward tablet does not inherit the previous site's branding — or its
  /// module switches, which decide what the next person's navigation offers.
  void clear() {
    _settings.value = SiteSettings.empty;
    _modulesEnabled.clear();
  }
}
