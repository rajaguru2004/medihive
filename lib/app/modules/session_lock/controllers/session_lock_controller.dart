import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../data/services/auth_service.dart';
import '../../../data/services/session_lock_service.dart';
import '../../../data/services/session_manager.dart';
import '../../../data/utils/error_handler.dart';

/// The lock screen's own state.
///
/// Re-authenticates against the same endpoint sign-in uses, with the email
/// already known. Nothing else changes: the session, the cached user and every
/// tab's loaded data are still there, so unlocking returns the person to the
/// row they were reading.
class SessionLockController extends GetxController {
  static SessionLockController get to => Get.find<SessionLockController>();

  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final _busy = false.obs;
  final _error = ''.obs;

  bool get busy => _busy.value;
  String get error => _error.value;

  String get email => AuthService.to.currentUser?.email ?? '';
  String get name => AuthService.to.currentUser?.name ?? '';
  String get initials => AuthService.to.currentUser?.initials ?? '?';

  @override
  void onClose() {
    password.dispose();
    super.onClose();
  }

  Future<void> unlock() async {
    if (_busy.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    _busy.value = true;
    _error.value = '';
    try {
      // The same call sign-in makes. A device that has been asleep may also
      // have a session the server has since revoked, and this is where that
      // surfaces — as a refusal to unlock rather than as a 401 on the next
      // tap.
      await AuthService.to.signIn(email: email, password: password.text);
      password.clear();
      SessionLockService.to.unlock();
    } catch (e) {
      _error.value = parseErrorMessage(e, 'That did not work. Try again.');
    } finally {
      _busy.value = false;
    }
  }

  /// The handover path: this is somebody else now.
  Future<void> signOutInstead() async {
    SessionLockService.to.reset();
    await SessionManager.to.endSession(
      reason: SessionEndReason.userLogout,
      revokeToken: true,
    );
  }
}
