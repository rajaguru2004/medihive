import 'dart:async';

import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../routes/app_pages.dart';
import '../../patient_portal/patient_shell.dart';

/// Decides where the app opens.
///
/// `main()` restores the token from encrypted storage before the first frame,
/// but a restored token is only a *claim*: it may have expired, the account
/// may have been deactivated, or a clinician's role may have changed since
/// this device last looked. This screen is where that claim is checked, so
/// every other screen can assume a live session.
///
/// It also loads the site's settings, because the brand and the triage scale
/// have to be right before the shell paints — re-theming after the first frame
/// is visible and reads as a bug.
class SplashController extends GetxController {
  SplashController({this.minimumHold = const Duration(milliseconds: 450)});

  /// How long the wordmark stays up even when the checks finish instantly.
  ///
  /// Without it a warm start flashes the splash for two frames, which reads as
  /// a glitch rather than as a launch. Tests pass `Duration.zero`.
  final Duration minimumHold;

  @override
  void onReady() {
    super.onReady();
    // onReady, not onInit: routing away during the first build throws.
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final started = DateTime.now();

    var destination = Routes.LOGIN;
    if (AuthService.to.isAuthenticated) {
      // Settings and the user in parallel — neither needs the other, and a
      // cold start on hospital wifi pays for every round trip it makes in
      // series.
      await Future.wait([
        SettingsService.to.load(),
        AuthService.to.refreshCurrentUser(),
      ]);

      // Still authenticated? A 401 during either call has already torn the
      // session down through SessionManager and routed to sign-in, so this
      // check is what stops us routing on top of that.
      if (!AuthService.to.isAuthenticated) return;

      // A warm start lands where sign-in would have. `refreshCurrentUser`
      // has just re-read the access map through `AccessService`, so this is
      // resolved from what the server says now rather than from what was
      // cached — a record claimed since the last launch opens the portal on
      // this launch.
      destination = PatientShell.currentLanding;
    }

    final elapsed = DateTime.now().difference(started);
    final remaining = minimumHold - elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

    AppLog.info('SplashController', 'opening $destination');
    if (Get.currentRoute == Routes.SPLASH) {
      await Get.offAllNamed(destination);
    }
  }
}
