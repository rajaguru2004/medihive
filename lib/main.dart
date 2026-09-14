import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/core/app_log.dart';
import 'app/data/network/dio_client.dart';
import 'app/data/network/endpoints.dart';
import 'app/data/services/access_service.dart';
import 'app/data/services/auth_service.dart';
import 'app/data/services/data_bus.dart';
import 'app/data/services/session_manager.dart';
import 'app/data/services/settings_service.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge, declared rather than inherited.
  //
  // Android 15 draws every app this way whether or not it asks, and opting out
  // is already deprecated — so the only question is whether the app knows it.
  // Declaring it here means the ground runs under the system bars on every API
  // level the app supports, instead of the layout changing shape the year the
  // platform stops asking. `SafeArea` and `MediaQuery.paddingOf` keep the
  // content itself clear.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // A build nobody pointed at a server reaches a host that does not exist,
  // over cleartext both platforms refuse, and shows a network error on its
  // first screen with nothing explaining why. `Endpoints.isLoopback` has always
  // promised that main() says so; until now it did not.
  if (Endpoints.isLoopback) {
    AppLog.warn(
      'main',
      'API base is ${Endpoints.baseUrl} — a developer loopback. '
          'Pass --dart-define=MEDIHIVE_API=https://… for any build that '
          'leaves this machine.',
    );
  }

  // ── Services ──────────────────────────────────────────────────────────────
  // Order matters: DioClient first, because AuthInterceptor reads AuthService
  // per request and SessionManager needs both.
  Get.put(DataBus());
  Get.put(DioClient());
  final authService = Get.put(AuthService());
  Get.put(SessionManager());
  Get.put(SettingsService());
  final accessService = Get.put(AccessService());

  // The services every module reaches for with `Get.find`. Registered here
  // rather than through `initialBinding:`, which runs after the first route is
  // resolved — and the splash screen is a route.
  registerDomainServices();

  // Rehydrate from secure storage before the first route resolves. Without
  // this, AuthMiddleware sees no session on a cold start and bounces a
  // signed-in clinician back to sign-in — which on a ward is the difference
  // between picking the tablet up and using it, and picking it up and hunting
  // for a password.
  await authService.tryRestoreSession();

  // The access map from the same storage, so the shell paints the tabs this
  // account actually has rather than all of them and then fewer. Refreshed
  // against the server on the splash screen.
  await accessService.restore();

  // Both restored before the first frame — reading either later paints one
  // frame in the wrong theme, which is visible and looks like a bug.
  await Get.put(AppThemeController()).restore();
  await Get.put(ThemeService()).restore();

  runApp(const MediHiveApp());
}

class MediHiveApp extends StatelessWidget {
  const MediHiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Deliberately not wrapped in Obx. Reading an observable here rebuilds the
    // entire GetMaterialApp — and with it the navigator — on every sign-in and
    // sign-out, which races against Get.offAllNamed. Theme changes stay
    // reactive without it: AppThemeController calls Get.changeThemeMode and
    // ThemeService pushes to Get.rootController, both of which GetX applies
    // directly.
    final themeCtrl = Get.find<AppThemeController>();
    final themes = Get.find<ThemeService>();

    return GetMaterialApp(
      title: 'MediHive',
      debugShowCheckedModeBanner: false,

      // ── Themes ────────────────────────────────────────────────────────────
      // Built once from the restored snapshot. A later branding change is
      // handed to GetX's root controller by ThemeService, which repaints
      // through the same path Get.changeThemeMode uses.
      theme: themes.lightTheme,
      darkTheme: themes.darkTheme,
      themeMode: themeCtrl.themeMode,

      // ── Navigation ────────────────────────────────────────────────────────
      // The splash screen decides where to go once it has checked the restored
      // session.
      //
      // `initialRoute` is left null on a cold start from a link:
      // `MaterialApp` consults `platformDispatcher.defaultRouteName` *only*
      // when it is null, so passing a constant here would silently discard the
      // deep link that launched the app.
      initialRoute: _launchRoute,
      getPages: AppPages.routes,
      unknownRoute: AppPages.unknown,

      // ── Text scaling ──────────────────────────────────────────────────────
      // Honoured, and bounded. A ward tablet is often left at the largest
      // system size by whoever used it last, and this app's dense boards stop
      // being readable past 1.3 — rows collapse into each other and an acuity
      // pill wraps onto two lines. Clamping is a worse answer than reflowing
      // and a much better one than a board nobody can parse.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// The route this launch asked for, or null to let the platform's deep link
  /// through.
  static String? get _launchRoute {
    final incoming =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    // '/' is what the platform reports when nothing asked for anything.
    return (incoming.isEmpty || incoming == '/') ? Routes.SPLASH : null;
  }
}
