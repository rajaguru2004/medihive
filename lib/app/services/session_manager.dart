import 'package:get/get.dart';

import '../network/token_manager.dart';
import '../routes/app_pages.dart';

class SessionManager extends GetxService {
  static SessionManager get to => Get.find();

  /// Lock to prevent multiple concurrent redirects.
  bool _isRedirecting = false;

  /// Cleans up all user-specific data and redirects to the login screen safely.
  void logout() {
    if (_isRedirecting) return;
    _isRedirecting = true;

    try {
      // 1. Clean up user-specific data (tokens, etc.)
      TokenManager.clear();

      // 2. Redirect to login screen safely using Get.offAllNamed
      if (Get.currentRoute != Routes.LOGIN) {
        Get.offAllNamed(Routes.LOGIN);
      }
    } finally {
      _isRedirecting = false;
    }
  }

  /// Handles invalid authentication token events (e.g. 401 Unauthorized responses).
  void handleInvalidToken() {
    // Show a user-friendly message or alert before redirecting
    if (Get.currentRoute != Routes.LOGIN) {
      Get.snackbar(
        'Session Expired',
        'Your session has expired. Please log in again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    logout();
  }
}
