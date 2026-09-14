import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../data/services/access_service.dart';
import '../../data/services/auth_service.dart';
import '../app_pages.dart';

/// Keeps unauthenticated navigation off the authenticated routes.
///
/// Every page except splash and sign-in carries this. It is a *navigation*
/// guard, not an authorisation one: the server still decides what a given
/// clinician may read, and this only stops the app from opening a screen that
/// would immediately 401 and bounce.
///
/// The check reads `AuthService` rather than a cached flag, so a session torn
/// down mid-flight by `SessionManager` is already reflected here.
class AuthMiddleware extends GetMiddleware {
  AuthMiddleware({this.module, this.moduleName, this.verb = AccessVerb.read});

  /// The access-map module this route belongs to, when it has one.
  final String? module;

  /// What to call it in the refusal. A module key is a database word:
  /// "pre-triage" is not what anybody calls it out loud.
  final String? moduleName;

  final AccessVerb verb;

  @override
  int? get priority => 0;

  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AuthService>() || !AuthService.to.isAuthenticated) {
      return const RouteSettings(name: Routes.LOGIN);
    }

    final gated = module;
    if (gated == null || !Get.isRegistered<AccessService>()) return null;

    final access = AccessService.to;

    // An unloaded map lets the request through on purpose. A cold deep link
    // can arrive before the bootstrap answers, and refusing then would turn a
    // slow network into a permission error — which is the one message a user
    // cannot act on. The screen's own 403 handling catches the real case.
    if (access.map.isEmpty && access.loadedAt == null) return null;

    if (access.can(gated, verb)) return null;

    return RouteSettings(
      name: Routes.NO_ACCESS,
      arguments: {'module': gated, 'moduleName': moduleName ?? gated},
    );
  }
}

/// Keeps a signed-in user off the sign-in screen.
///
/// Without it, a deep link to `/login` on a device that already has a session
/// drops a clinician onto a form they cannot dismiss without signing out.
class GuestMiddleware extends GetMiddleware {
  GuestMiddleware();

  @override
  int? get priority => 0;

  @override
  RouteSettings? redirect(String? route) {
    if (Get.isRegistered<AuthService>() && AuthService.to.isAuthenticated) {
      return const RouteSettings(name: Routes.HOME);
    }
    return null;
  }
}
