import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_log.dart';
import '../../../../data/models/drafts/patient_portal_drafts.dart';
import '../../../../data/repositories/patient_portal_repository.dart';
import '../../../../data/services/settings_service.dart';
import '../../patient_portal_messages.dart';
import '../../patient_shell.dart';

/// Spending the claim: a password, and an address to sign in with.
///
/// This is where a wrong hospital card finally surfaces. The claim route
/// answers identically whether or not the MRN existed, so a token issued
/// against nothing looks exactly like a good one until it is spent here and
/// comes back 401 — which is why the refusal copy on this screen carries the
/// weight, and why it is the same sentence for five different server error
/// codes. See `patient_portal_messages.dart`.
class PatientActivateController extends GetxController {
  final PatientPortalRepository _repository = const PatientPortalRepository();

  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final RxBool isPasswordHidden = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString errorMessage = RxnString();

  /// Set when the server says the record carries no email of its own.
  ///
  /// Sign-in is `POST /auth/login`, which looks an account up by address, so
  /// an activation that ends with no email anywhere creates an account nobody
  /// can ever reach. The field is offered from the start and becomes required
  /// only when the server asks — the app cannot know beforehand, because the
  /// claim response deliberately tells it nothing about the record.
  final RxBool emailRequired = false.obs;

  /// The token from the claim screen. Ten minutes, single use.
  late final String claimToken = _tokenFromArguments(Get.arguments);

  /// True when this screen was opened without one — a deep link, or a return
  /// to it after the token expired and the app was restarted.
  bool get hasClaim => claimToken.isNotEmpty;

  static String _tokenFromArguments(Object? arguments) {
    if (arguments is Map && arguments['claimToken'] != null) {
      return arguments['claimToken'].toString();
    }
    return '';
  }

  void togglePassword() => isPasswordHidden.toggle();

  /// The rule, and it is written on the screen as well as enforced here.
  ///
  /// Eight is the server's floor. Seventy-two is its ceiling and it is not
  /// arbitrary — bcrypt hashes the first 72 bytes and ignores the rest, so a
  /// longer password is not the password the patient thinks they set, and they
  /// would find that out at their next sign-in.
  ///
  /// Nothing about capitals, digits or symbols. The server asks for none of
  /// them, and a rule this app invented would refuse a password a frightened
  /// person in a waiting room had already managed to think of.
  String? validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Choose a password';
    if (text.length < 8) return 'Use at least 8 characters';
    if (text.length > 72) return 'Use no more than 72 characters';
    return null;
  }

  String? validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'Type the password again';
    if (value != passwordController.text) return 'The two do not match';
    return null;
  }

  String? validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return emailRequired.value
          ? 'We need an email address to sign you in'
          : null;
    }
    final ok = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(text);
    return ok ? null : 'That does not look like an email address';
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    if (!hasClaim) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      await _repository.activate(
        PatientActivationDraft(
          claimToken: claimToken,
          password: passwordController.text,
          // Not lower-cased. `findByEmail` matches exactly, so normalising the
          // case here would create an account that cannot sign in.
          email: emailController.text.trim(),
        ),
      );

      // Branding before the first screen paints, exactly as sign-in does — a
      // site whose brand is not the default would otherwise show one frame of
      // teal to somebody who has just been told this is their hospital's app.
      await SettingsService.to.load();

      // `AccessService.load` has already run inside `activate`, so the landing
      // is resolved from a real access map rather than an empty one.
      unawaited(
        Get.offAllNamed<void>(PatientShell.currentLanding) ??
            Future<void>.value(),
      );
    } catch (e, stack) {
      if (portalErrorCode(e) == PatientPortalErrors.emailRequired) {
        emailRequired.value = true;
        errorMessage.value = 'We need an email address for you — it is how you '
            'will sign in. Add one below and try again.';
        // Re-run the validators so the field itself is marked, not just the
        // banner: the address box is several lines above the button on a
        // phone, and a banner alone leaves nothing to look at.
        formKey.currentState?.validate();
      } else {
        errorMessage.value = patientPortalMessage(e);
      }
      AppLog.error('PatientActivateController', 'activation refused', e, stack);
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmController.dispose();
    emailController.dispose();
    super.onClose();
  }
}
