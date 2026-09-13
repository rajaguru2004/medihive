import 'dart:convert';

import 'package:flutter/services.dart'
    show FontLoader, MethodChannel, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/app_clock.dart';
import 'package:medihive/app/core/app_log.dart';
import 'package:medihive/app/data/network/dio_client.dart';
import 'package:medihive/app/data/services/appointment_service.dart';
import 'package:medihive/app/data/services/auth_service.dart';
import 'package:medihive/app/data/services/consultation_service.dart';
import 'package:medihive/app/data/services/data_bus.dart';
import 'package:medihive/app/data/services/home_service.dart';
import 'package:medihive/app/data/services/inpatient_service.dart';
import 'package:medihive/app/data/services/pre_triage_service.dart';
import 'package:medihive/app/data/services/queue_service.dart';
import 'package:medihive/app/data/services/session_manager.dart';
import 'package:medihive/app/data/services/settings_service.dart';
import 'package:medihive/app/modules/home/controllers/home_controller.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';
import 'package:medihive/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_api_adapter.dart';
import '../fixtures/world.dart';
import 'pump.dart';

/// Boots the real app against a fake server, and tears it down completely.
///
/// Tests pump `MediHiveApp` itself — the real theme, the real route table and
/// the real `AuthMiddleware` — rather than a hand-built widget tree, so a
/// routing or middleware regression is visible to the suite.
///
/// The fake sits *below* the interceptor chain, as a Dio `HttpClientAdapter`,
/// so the bearer header is attached for real and a 401 returned here produces
/// a genuine `DioException` that `AuthInterceptor` routes into
/// `SessionManager`. A stubbed client could not reach that path.
class AppHarness {
  AppHarness._(this.tester, this.api);

  final WidgetTester tester;
  final FakeApi api;

  /// Boots signed in, on the shell.
  static Future<AppHarness> bootSignedIn(
    WidgetTester tester, {
    bool fonts = false,
    void Function(FakeApi api)? overrides,
  }) =>
      _boot(tester, signedIn: true, fonts: fonts, overrides: overrides);

  /// Boots signed out, on the sign-in screen.
  static Future<AppHarness> bootSignedOut(
    WidgetTester tester, {
    bool fonts = false,
    void Function(FakeApi api)? overrides,
  }) =>
      _boot(tester, signedIn: false, fonts: fonts, overrides: overrides);

  static Future<AppHarness> _boot(
    WidgetTester tester, {
    required bool signedIn,
    required bool fonts,
    void Function(FakeApi api)? overrides,
  }) async {
    // Quiet. A thirty-flow suite that logs every request buries its own
    // failure output.
    AppLog.enabled = false;

    // A fixed clock, so "42 minutes ago" is 42 minutes ago in every run and a
    // screenshot taken today matches one taken next week.
    AppClock.freeze(DateTime(2026, 3, 12, 14, 20));
    addTearDown(AppClock.unfreeze);

    // Reduce Motion, so no ticker runs forever and `pumpUntil` has something
    // to converge on.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    _installFakeSecureStorage(signedIn: signedIn);

    final api = FakeApi();
    World.install(api);
    overrides?.call(api);

    Get.reset();

    Get.put(DataBus());
    Get.put(DioClient(adapter: FakeApiAdapter(api)));
    final auth = Get.put(AuthService());
    Get.put(SessionManager());
    Get.put(SettingsService());

    // The domain services every module reaches for through `Get.find`.
    Get.put(HomeService());
    Get.put(QueueService());
    Get.put(AppointmentService());
    Get.put(InpatientService());
    Get.put(PreTriageService());
    Get.put(ConsultationService());

    await auth.tryRestoreSession();
    await Get.put(AppThemeController()).restore();
    await Get.put(ThemeService()).restore();

    if (fonts) await _loadRealFonts();

    await tester.pumpWidget(const MediHiveApp());
    await tester.pumpUntilRouteSettled(
      expectRoute: signedIn ? Routes.HOME : Routes.LOGIN,
    );

    final harness = AppHarness._(tester, api);
    addTearDown(harness.dispose);
    return harness;
  }

  /// Fails the test if the app called an endpoint nothing answered.
  ///
  /// A 501 from the fake router renders the app's real error UI rather than
  /// crashing, which is right for the screen and wrong for the suite: without
  /// this a missing fixture reads as a passing test of an error state.
  Future<void> dispose() async {
    final missing = api.unstubbed;
    if (missing.isNotEmpty) {
      fail(
        'The app called ${missing.length} endpoint(s) with no fixture:\n'
        '  ${missing.join('\n  ')}',
      );
    }
  }

  /// Pumps until the app stops talking to the server.
  ///
  /// The in-memory router answers synchronously, so this is a settled frame
  /// rather than a quiet network. It exists so a flow reads the same against
  /// the fake and against a real server.
  Future<void> settle() => tester.pumpUntilRouteSettled();

  /// Puts the app into dark mode and waits for the repaint.
  Future<void> useDarkTheme() async {
    AppThemeController.to.setDark();
    await tester.pumpUntilRouteSettled();
  }

  Future<void> useLightTheme() async {
    AppThemeController.to.setLight();
    await tester.pumpUntilRouteSettled();
  }

  /// Switches the shell to the tab at [route] without pushing a second copy.
  ///
  /// Driving the controller rather than tapping the bar is deliberate for the
  /// screenshot suite: a tap animates, and a capture taken during that is a
  /// blurred half-screen. Flow tests tap.
  Future<void> showTab(String route) async {
    HomeController.to.selectRoute(route);
    await tester.pumpUntilRouteSettled();
  }

  // ── Storage ───────────────────────────────────────────────────────────────

  /// Answers `flutter_secure_storage`'s platform channel in memory.
  ///
  /// The plugin's Android implementation needs a real `Activity`, which an
  /// integration test running under the test binding does not have. Seeding
  /// the token here is also what makes `bootSignedIn` a *restored* session
  /// rather than a simulated one — `AuthService.tryRestoreSession` reads it
  /// through its own code path.
  static void _installFakeSecureStorage({required bool signedIn}) {
    final store = <String, String>{
      if (signedIn) ...{
        'auth_token': 'fake-token',
        'auth_refresh_token': 'fake-refresh',
        'auth_user': jsonEncode(World.signedInUser),
      },
    };

    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
        final key = args['key'] as String?;
        return switch (call.method) {
          'read' => store[key],
          'write' => () {
              if (key != null) store[key] = args['value'] as String? ?? '';
              return null;
            }(),
          'delete' => store.remove(key),
          'deleteAll' => store.clear(),
          'readAll' => Map<String, String>.from(store),
          'containsKey' => store.containsKey(key),
          _ => null,
        };
      },
    );
  }

  // ── Fonts ─────────────────────────────────────────────────────────────────

  /// Loads the app's real faces into the test binding.
  ///
  /// Without this every glyph draws as a filled box — fine for a flow that
  /// asserts on keys, worthless for a screenshot. Only the screenshot suite
  /// pays the cost.
  static Future<void> _loadRealFonts() async {
    const faces = <String, List<String>>{
      'Montserrat': ['assets/fonts/Montserrat.ttf'],
      'Inter': ['assets/fonts/Inter.ttf'],
    };

    for (final entry in faces.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  }
}
