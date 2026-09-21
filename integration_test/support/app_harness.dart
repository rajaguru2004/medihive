import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart'
    show FontLoader, MethodChannel, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/app_clock.dart';
import 'package:medihive/app/core/app_log.dart';
import 'package:medihive/app/data/network/dio_client.dart';
import 'package:medihive/app/data/services/access_service.dart';
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
import 'package:medihive/app/data/services/speech_player.dart';
import 'package:medihive/app/modules/home/controllers/home_controller.dart';
import 'package:medihive/app/modules/patient_portal/patient_shell.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';
import 'package:medihive/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_api_adapter.dart';
import '../fixtures/world.dart';
import '../fixtures/world_roles.dart';
import 'device_class.dart';
import 'pump.dart';
import 'watch_mode.dart';

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
///
/// Two dimensions are parameterised, and both default to what the suite
/// already ran: the **account** ([WorldRole], default the super admin, who can
/// reach every screen) and the **viewport** ([DeviceClass], selected with
/// `--dart-define=NEX_HIVE_DEVICE_CLASS`).
class AppHarness {
  AppHarness._(this.tester, this.api, this.role);

  final WidgetTester tester;
  final FakeApi api;

  /// The account this run is signed in as. Read by a flow that wants to say
  /// what this role should and should not be able to see.
  final WorldRole role;

  /// The system text size this run asks for.
  ///
  /// `--dart-define=NEX_HIVE_TEXT_SCALE=1.3` runs the whole suite at the size
  /// a ward tablet is usually left at by whoever used it last, which is the
  /// size this app's dense boards actually have to survive. Unset means
  /// "whatever the platform reports", which under `flutter test` is 1.0.
  ///
  /// A string rather than a number because Dart has no `double.fromEnvironment`
  /// — only bool, int and String.
  static const String _textScaleDefine =
      String.fromEnvironment('NEX_HIVE_TEXT_SCALE');

  /// Boots signed in, on the shell.
  static Future<AppHarness> bootSignedIn(
    WidgetTester tester, {
    WorldRole role = WorldRole.superAdmin,
    bool fonts = false,
    void Function(FakeApi api)? overrides,
  }) =>
      _boot(
        tester,
        signedIn: true,
        role: role,
        fonts: fonts,
        overrides: overrides,
      );

  /// Boots signed out, on the sign-in screen.
  ///
  /// [role] still matters: it is the account `POST /auth/login` will hand a
  /// token for, so a flow can sign in as a nurse and assert what she lands on.
  static Future<AppHarness> bootSignedOut(
    WidgetTester tester, {
    WorldRole role = WorldRole.superAdmin,
    bool fonts = false,
    void Function(FakeApi api)? overrides,
  }) =>
      _boot(
        tester,
        signedIn: false,
        role: role,
        fonts: fonts,
        overrides: overrides,
      );

  static Future<AppHarness> _boot(
    WidgetTester tester, {
    required bool signedIn,
    required WorldRole role,
    required bool fonts,
    void Function(FakeApi api)? overrides,
  }) async {
    // Quiet. A thirty-flow suite that logs every request buries its own
    // failure output.
    AppLog.enabled = false;

    // A fixed clock, so "42 minutes ago" is 42 minutes ago in every run and a
    // screenshot taken today matches one taken next week. Frozen before the
    // token is minted, because the token's `iat` and `exp` come off it.
    AppClock.freeze(DateTime(2026, 3, 12, 14, 20));
    addTearDown(AppClock.unfreeze);

    // Before the first frame: a viewport changed after `pumpWidget` lays the
    // shell out twice, and the first of those is the one a breakpoint
    // assertion would catch mid-change.
    _applyDeviceClass(tester);
    _applyTextScale(tester);

    // Reduce Motion, so no ticker runs forever and `pumpUntil` has something
    // to converge on.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    // A no-op unless `--dart-define=NEX_HIVE_WATCH=true`; see watch_mode.dart.
    WatchMode.arm();

    SharedPreferences.setMockInitialValues(<String, Object>{});
    _installFakeSecureStorage(signedIn: signedIn, role: role);

    final api = FakeApi();
    World.install(api, role: role);
    overrides?.call(api);

    Get.reset();

    Get.put(DataBus());
    Get.put(DioClient(adapter: FakeApiAdapter(api)));
    final auth = Get.put(AuthService());
    Get.put(SessionManager());
    Get.put(SettingsService());
    // After `AuthService`, which it reads the token and the session state
    // from, and before `tryRestoreSession` — `AuthService.signIn` and
    // `refreshCurrentUser` both delegate to it when it is registered, and a
    // harness without it silently takes a different path through `/auth/me`
    // than the app does.
    final access = Get.put(AccessService());

    // Read-aloud, stubbed before any binding can reach for the real one.
    //
    // `CaseTakingBinding` registers `AudioPlayersSpeechPlayer` only when
    // nothing is registered already, and that guard exists for exactly this.
    // Left to itself the real player runs: every question is read aloud as it
    // arrives, so the plugin starts a `FramePositionUpdater` whose ticker is
    // still registered when the tree is torn down, and the flow fails on "an
    // animation is still running even after the widget tree was disposed" -
    // an audio plugin's heartbeat reported as the test's own leak.
    //
    // `StubSpeechPlayer` reports itself unavailable, which also hides the
    // read-aloud control. That is the honest default here: no flow asserts on
    // that control, and a suite that silently played audio through a real
    // plugin was testing the plugin.
    Get.put<SpeechPlayer>(const StubSpeechPlayer(), permanent: true);

    // The domain services every module reaches for through `Get.find`.
    Get.put(HomeService());
    Get.put(QueueService());
    Get.put(AppointmentService());
    Get.put(InpatientService());
    Get.put(PreTriageService());
    Get.put(ConsultationService());

    await auth.tryRestoreSession();
    // The access map from the same storage, so the shell paints this account's
    // tabs on the first frame rather than all of them and then fewer. Mirrors
    // `main()`, which restores both before `runApp`.
    await access.restore();
    await Get.put(AppThemeController()).restore();
    await Get.put(ThemeService()).restore();

    if (fonts) await _loadRealFonts();

    await tester.pumpWidget(const MediHiveApp());
    // Where this account's session actually opens, resolved the way the app
    // resolves it rather than from a second table here. A portal account does
    // not land on the staff shell — that is the whole point of `PatientShell`
    // — so a harness that waited for `/home` would hang for fifteen seconds
    // and then report the wrong thing.
    await tester.pumpUntilRouteSettled(
      expectRoute: signedIn ? PatientShell.currentLanding : Routes.LOGIN,
    );

    final harness = AppHarness._(tester, api, role);
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
  ///
  /// Fails when the shell has no such tab. It is a silent no-op otherwise, and
  /// now that the bar is resolved per account that is a screenshot of the
  /// previous screen filed under the name of the one nobody could reach.
  Future<void> showTab(String route) async {
    expect(
      HomeController.to.selectRoute(route),
      isTrue,
      reason: 'this account has no $route tab, so the shell stayed where it '
          'was',
    );
    await tester.pumpUntilRouteSettled();
  }

  // ── Viewport ──────────────────────────────────────────────────────────────

  /// Pins the viewport to the class this run asked for.
  ///
  /// `--dart-define=NEX_HIVE_DEVICE_CLASS=tablet` runs the same flow at
  /// 1280×800, which is the only way the headless tier can assert a breakpoint
  /// without a tablet.
  ///
  /// **Never on a real device.** `LiveTestWidgetsFlutterBinding` scales a
  /// pinned `physicalSize` down to fit the window it actually has, so pinning a
  /// phone size on a tablet renders a letterboxed phone and the layout under
  /// test never appears — see the comment on [DeviceClass.device]. The default
  /// class is `phone`, so without this guard the documented device commands
  /// (`flutter test integration_test/… -d emulator-5554`, `flutter drive`)
  /// would all start letterboxing.
  ///
  /// The *binding* cannot answer this: `IntegrationTestWidgetsFlutterBinding`
  /// is a live binding whether it is driving an emulator or running headless on
  /// the developer's machine. The platform can — a device run is compiled for
  /// Android or iOS, a headless one runs in `flutter_tester` on the host.
  static void _applyDeviceClass(WidgetTester tester) {
    final deviceClass = DeviceClass.fromDefine;
    if (!deviceClass.isPinned) return;
    if (Platform.isAndroid || Platform.isIOS) return;

    tester.view
      ..physicalSize = deviceClass.physicalSize!
      ..devicePixelRatio = deviceClass.devicePixelRatio!;
    // Both, and separately: the view is shared across tests in a file, and a
    // size left behind by one is a layout nobody chose in the next.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Applies `--dart-define=NEX_HIVE_TEXT_SCALE`, so the large-text pass is one
  /// flag rather than an edit.
  ///
  /// Set on the platform dispatcher rather than by wrapping the app in a
  /// `MediaQuery`: `MediaQueryData.fromView` is where the app's own scaler
  /// comes from, and `main()` clamps it to 1.3 on the way through. A wrapper
  /// would sit *inside* that clamp and test a scale the app never applies.
  static void _applyTextScale(WidgetTester tester) {
    final scale = double.tryParse(_textScaleDefine);
    // Zero and negative are not sizes; an unset define parses to null.
    if (scale == null || scale <= 0) return;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  // ── Storage ───────────────────────────────────────────────────────────────

  /// Answers `flutter_secure_storage`'s platform channel in memory.
  ///
  /// The plugin's Android implementation needs a real `Activity`, which an
  /// integration test running under the test binding does not have. Seeding
  /// the token here is also what makes `bootSignedIn` a *restored* session
  /// rather than a simulated one — `AuthService.tryRestoreSession` and
  /// `AccessService.restore` both read it through their own code paths.
  ///
  /// All four keys, because the app writes all four. A session seeded without
  /// `auth_access` paints a shell with no modules on its first frame and fills
  /// it in when `/auth/me` lands, which is a state no warm start is ever in.
  static void _installFakeSecureStorage({
    required bool signedIn,
    required WorldRole role,
  }) {
    final store = <String, String>{
      if (signedIn) ...{
        // A real three-segment JWT, not an opaque string: `tryRestoreSession`
        // checks its `exp` before trusting it, and an unreadable token skipped
        // that check entirely.
        'auth_token': World.tokenFor(role),
        'auth_refresh_token': World.refreshToken,
        'auth_user': jsonEncode(World.cachedUser(role)),
        'auth_access': jsonEncode(World.cachedAccess(role)),
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
