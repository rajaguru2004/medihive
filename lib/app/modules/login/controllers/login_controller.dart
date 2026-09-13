import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/session_manager.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../routes/app_pages.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isSubmitting = false.obs;
  final isPasswordHidden = true.obs;
  final errorMessage = RxnString();

  /// Why the last session ended, when it ended on its own.
  ///
  /// Read from the route arguments `SessionManager` passes. Shown once, above
  /// the form: a clinician whose token expired mid-round needs to know that is
  /// what happened, not to wonder whether they mistyped a password they never
  /// typed.
  final sessionNotice = RxnString();

  @override
  void onInit() {
    super.onInit();

    final reason = (Get.arguments as Map?)?['sessionEndReason'];
    if (reason is String) {
      sessionNotice.value = SessionEndReason.values
          .firstWhereOrNull((r) => r.name == reason)
          ?.notice;
    }

    // Re-arm the teardown guard here rather than in a `finally` inside
    // endSession: clearing it the moment that returns would let a late 401
    // from a request still in flight trigger a second redirect onto this
    // screen.
    SessionManager.to.armForNextSession();
  }

  void togglePassword() => isPasswordHidden.toggle();

  String? validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter your work email';
    final ok = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(text);
    return ok ? null : 'That does not look like an email address';
  }

  String? validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password';
    return null;
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    // Dismiss the keyboard before the request: on a phone the error banner
    // renders above the fold and behind the keyboard otherwise, so a failed
    // sign-in looks like nothing happened at all.
    FocusManager.instance.primaryFocus?.unfocus();

    isSubmitting.value = true;
    errorMessage.value = null;
    sessionNotice.value = null;

    try {
      await AuthService.to.signIn(
        email: emailController.text,
        password: passwordController.text,
      );

      // Branding before the shell paints. A site whose brand is not the
      // default would otherwise show one frame of teal on sign-in.
      await SettingsService.to.load();

      await Get.offAllNamed<void>(Routes.HOME);
    } catch (e, stack) {
      errorMessage.value = parseErrorMessage(
        e,
        "That didn't work. Check your email and password, then try again.",
      );
      AppLog.error('LoginController', 'sign-in failed', e, stack);
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
