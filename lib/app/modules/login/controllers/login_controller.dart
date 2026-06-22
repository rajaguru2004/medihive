import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../providers/auth_provider.dart';

class LoginController extends GetxController {
  final _provider = AuthProvider();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final isPasswordHidden = true.obs;
  final errorMessage = ''.obs;

  void togglePassword() => isPasswordHidden.toggle();

  String? validateEmail(String? val) {
    if (val == null || val.trim().isEmpty) return 'Email required';
    final ok = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(val.trim());
    return ok ? null : 'Enter a valid email';
  }

  String? validatePassword(String? val) {
    if (val == null || val.isEmpty) return 'Password required';
    return null;
  }

  Future<void> login() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final res = await _provider.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final tokenData = data['data'] as Map<String, dynamic>;
        final accessToken = tokenData['accessToken'] as String;
        // TODO: persist tokens via GetStorage / SecureStorage
        if (kDebugMode) debugPrint('Login success — token: $accessToken');
        Get.offAllNamed(Routes.HOME);
      } else {
        errorMessage.value =
            data['message'] as String? ?? 'Login failed. Try again.';
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String?;
      errorMessage.value = msg ?? 'Network error. Check connection.';
    } catch (_) {
      errorMessage.value = 'Unexpected error. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
