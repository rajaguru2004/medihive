import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/theme.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // ── Ambient gradient blobs ────────────────────────────────────────
          _AmbientBlobs(isDark: isDark),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo + name
                      _LogoSection(),
                      const SizedBox(height: AppSpacing.xxxl),

                      // Glass form card
                      _LoginCard(isDark: isDark, controller: controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Logo Section ─────────────────────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App logo from remote URL
        Image.network(
          'https://hms.s3.skillhiveinnovations.com/hmsbucket/cmqckgpi400005kijus0qqbhn/radiology/1782056394225-lwfb7i.png',
          height: 72,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => const Icon(
            Icons.local_hospital_rounded,
            size: 72,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // App name logo
        Image.network(
          'https://hms.s3.skillhiveinnovations.com/hmsbucket/cmqckgpi400005kijus0qqbhn/radiology/1782057909066-lhgbil.png',
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => Text(
            'MediHive',
            style: AppTextStyles.headlineMedium(AppColors.primary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Hospital Management System',
          style: AppTextStyles.bodySmall(AppColors.primary.withValues(alpha: 0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Login Card ───────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.isDark, required this.controller});

  final bool isDark;
  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppDecorations.borderXL,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: AppDecorations.glassCard(isDark: isDark),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxxl,
          ),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Heading
                Text(
                  'Welcome back',
                  style: AppTextStyles.headlineSmall(
                    isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sign in to your account',
                  style: AppTextStyles.bodyMedium(
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Email field
                _InputLabel(label: 'Email Address', isDark: isDark),
                const SizedBox(height: AppSpacing.sm),
                _GlassTextField(
                  controller: controller.emailController,
                  isDark: isDark,
                  hint: 'admin@hms.local',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                  validator: controller.validateEmail,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Password field
                _InputLabel(label: 'Password', isDark: isDark),
                const SizedBox(height: AppSpacing.sm),
                Obx(
                  () => _GlassTextField(
                    controller: controller.passwordController,
                    isDark: isDark,
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: controller.isPasswordHidden.value,
                    validator: controller.validatePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => controller.login(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.isPasswordHidden.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        size: 20,
                      ),
                      onPressed: controller.togglePassword,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: navigate to forgot-password
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: AppTextStyles.labelMedium(AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Error message
                Obx(() {
                  if (controller.errorMessage.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: AppDecorations.borderSM,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              controller.errorMessage.value,
                              style: AppTextStyles.bodySmall(AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Sign in button
                Obx(
                  () => _SignInButton(
                    isLoading: controller.isLoading.value,
                    onPressed: controller.login,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Secured with end-to-end encryption',
                      style: AppTextStyles.labelSmall(
                        isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Input Label ──────────────────────────────────────────────────────────────
class _InputLabel extends StatelessWidget {
  const _InputLabel({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelMedium(
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
    );
  }
}

// ─── Glass TextField ──────────────────────────────────────────────────────────
class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.isDark,
    required this.hint,
    this.keyboardType,
    required this.prefixIcon,
    this.obscureText = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final bool isDark;
  final String hint;
  final TextInputType? keyboardType;
  final IconData prefixIcon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final focusBorderColor = AppColors.primary.withValues(alpha: 0.6);
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.7);
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final hintColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: AppTextStyles.bodyMedium(textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium(hintColor.withValues(alpha: 0.5)),
        filled: true,
        fillColor: fillColor,
        prefixIcon: Icon(prefixIcon, color: hintColor, size: 18),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: BorderSide(color: focusBorderColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide:
              BorderSide(color: AppColors.error.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide:
              BorderSide(color: AppColors.error.withValues(alpha: 0.9)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        errorStyle: AppTextStyles.labelSmall(AppColors.error),
      ),
    );
  }
}

// ─── Sign In Button ───────────────────────────────────────────────────────────
class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.primary,
              Color(0xFF007AFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppDecorations.borderMD,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.borderMD,
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Sign In',
                  style: AppTextStyles.labelLarge(Colors.white),
                ),
        ),
      ),
    );
  }
}

// ─── Ambient Blobs ────────────────────────────────────────────────────────────
class _AmbientBlobs extends StatelessWidget {
  const _AmbientBlobs({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Top-right blob
        Positioned(
          top: -80,
          right: -60,
          child: _Blob(
            size: 280,
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
          ),
        ),
        // Bottom-left blob
        Positioned(
          bottom: -100,
          left: -80,
          child: _Blob(
            size: 320,
            color: AppColors.tertiary.withValues(alpha: isDark ? 0.12 : 0.08),
          ),
        ),
        // Center subtle blob
        Positioned(
          top: size.height * 0.35,
          right: -40,
          child: _Blob(
            size: 180,
            color:
                AppColors.secondary.withValues(alpha: isDark ? 0.10 : 0.06),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
