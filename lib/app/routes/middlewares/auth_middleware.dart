import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

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
  AuthMiddleware();

  @override
  int? get priority => 0;

  @override
  RouteSettings? redirect(String? route) {
    if (Get.isRegistered<AuthService>() && AuthService.to.isAuthenticated) {
      return null;
    }
    return const RouteSettings(name: Routes.LOGIN);
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
