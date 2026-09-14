import 'dart:async';

import 'package:get/get.dart';

import '../../core/app_log.dart';
import '../../core/live_obx.dart';
import '../../routes/app_pages.dart';
import 'access_service.dart';
import 'auth_service.dart';
import 'settings_service.dart';

/// Why a session ended. Surfaced on the sign-in screen so the user is told
/// what happened instead of being dropped on a blank form.
enum SessionEndReason {
  /// The server rejected the token — expired, revoked, or the account was
  /// deactivated elsewhere.
  expired,

  /// The user tapped "Sign out".
  userLogout,

  /// Authentication succeeded but the account has no usable role, so every
  /// screen in this app would fail.
  noAccess,
}

extension SessionEndReasonNotice on SessionEndReason {
  /// What the sign-in screen says about it. Null for a deliberate sign-out —
  /// telling someone "you signed out" after they tapped Sign out is noise.
  String? get notice => switch (this) {
        SessionEndReason.expired =>
          'Your session expired. Please sign in again.',
        SessionEndReason.userLogout => null,
        SessionEndReason.noAccess =>
          'That account has no access to MediHive. Contact your administrator.',
      };
}

/// Owns the single path out of an authenticated session.
///
/// Every sign-out — user-initiated or forced by a 401 — must go through
/// [endSession] so teardown happens exactly once and in the same order.
///
/// Controllers register themselves for disposal through [registerScoped]
/// rather than being listed here by type: the binding that creates a
/// user-scoped controller is the thing that says so, which means a new tab is
/// one line in its own binding rather than one more import here that somebody
/// has to remember.
///
/// This matters more in a clinical app than in most. Handover on a shared
/// ward tablet is one person signing out and the next signing in, on the same
/// process, minutes apart — and a permanent controller that survives that
/// carries the previous clinician's patient list into the next one's session.
class SessionManager extends GetxService {
  static SessionManager get to => Get.find<SessionManager>();

  /// Guards against concurrent teardown. A shell that fires three requests
  /// through one `Future.wait` sees all three fail with 401 at once, and each
  /// would otherwise clear the session and call `Get.offAllNamed`.
  bool _isEnding = false;

  /// Disposers for controllers holding the current user's data, keyed so a
  /// re-registration replaces rather than duplicates.
  final Map<String, void Function()> _scoped = {};

  /// Registers a teardown for a user-scoped controller.
  ///
  /// Call from the binding that registers the controller `permanent: true`.
  /// `Get.offAllNamed` does not dispose permanent instances, so without this
  /// the next user to sign in on the same process inherits the previous user's
  /// data until each screen happens to refetch.
  void registerScoped<T>() {
    _scoped['$T'] = () {
      if (Get.isRegistered<T>()) {
        // `force` is required — a plain delete is a no-op for a permanent
        // instance.
        Get.delete<T>(force: true);
      }
    };
  }

  /// Tears down the session and returns to the sign-in screen.
  ///
  /// Safe to call from several failing requests at once — only the first call
  /// does any work.
  Future<void> endSession({
    SessionEndReason reason = SessionEndReason.expired,
    bool revokeToken = false,
  }) async {
    // Both checks must happen before the first await. Dart is single-threaded,
    // so concurrent 401 callbacks queue on the event loop: the first sets the
    // flag synchronously and the rest return here. Setting it after an await
    // would reopen the window it exists to close.
    if (_isEnding) return;
    if (Get.currentRoute == Routes.LOGIN) return;
    _isEnding = true;

    AppLog.info('SessionManager', 'ending session: ${reason.name}');

    if (revokeToken) await AuthService.to.revokeToken();

    // Bump BEFORE dropping anything: every `LiveObx` on screen re-reads,
    // finds its controller still present for one last frame, and is then
    // rebuilt to nothing as the drops land. Bumping afterwards would let a
    // dirty Obx run against a controller that is already gone.
    liveScopeEpoch.value++;
    _disposeScoped();
    await AuthService.to.clearSession();

    // The two services that hold the *site* rather than the screens.
    // `registerScoped` covers controllers; these are permanent by design and
    // would otherwise carry one clinician's modules and their hospital's
    // branding into the next person's session on the same ward tablet — the
    // access map deciding which tabs they see being the half that matters.
    if (Get.isRegistered<AccessService>()) await AccessService.to.clear();
    if (Get.isRegistered<SettingsService>()) SettingsService.to.clear();

    // Not awaited: the future completes when the *next* route is popped,
    // which for a sign-in screen is never. Awaiting it hangs every caller of
    // endSession, including the 401 interceptor.
    unawaited(
      Get.offAllNamed(
        Routes.LOGIN,
        arguments: {'sessionEndReason': reason.name},
      ) ??
          Future<void>.value(),
    );
  }

  /// Re-arms the guard. Called from the sign-in screen rather than a `finally`,
  /// because clearing it as soon as [endSession] returns would let a late 401
  /// from an in-flight request trigger a second redirect.
  void armForNextSession() => _isEnding = false;

  void _disposeScoped() {
    for (final entry in _scoped.entries) {
      try {
        entry.value();
      } catch (e) {
        // Teardown must never block the redirect to sign-in.
        AppLog.warn('SessionManager', 'disposing ${entry.key} failed: $e');
      }
    }
  }
}
