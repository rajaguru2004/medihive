import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/login_controller.dart';

/// Sign in.
///
/// One column, one job. The mark establishes which app this is, the form is
/// two fields, and the button is the only affordance on the screen — a
/// sign-in that offers a choice is a sign-in that costs a decision at the one
/// moment nobody wants to make one.
///
/// No "forgot password" link: accounts here are provisioned by an
/// administrator and reset in the admin console, so a link would lead
/// somewhere this app cannot go.
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: LoginKeys.screen,
      body: BentoGround(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              // Scrollable because the keyboard takes half a phone, not
              // because the content is long. `AlwaysScrollable` would let it
              // bounce with nothing to scroll, which reads as a loose screen.
              padding: const EdgeInsets.symmetric(
                horizontal: BentoSpace.page,
                vertical: BentoSpace.section,
              ),
              child: MaxWidthBody(
                maxWidth: 420,
                child: Form(
                  key: controller.formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Wordmark(),
                        const SizedBox(height: 28),

                        Obx(() {
                          final notice = controller.sessionNotice.value;
                          if (notice == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: NoticeBanner(
                              key: LoginKeys.sessionNotice,
                              message: notice,
                              icon: Icons.lock_clock_outlined,
                              tint: AppColors.warning,
                            ),
                          );
                        }),

                        Obx(() {
                          final error = controller.errorMessage.value;
                          if (error == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: NoticeBanner(
                              key: LoginKeys.error,
                              message: error,
                              icon: Icons.error_outline_rounded,
                              tint: AppColors.error,
                            ),
                          );
                        }),

                        FormCard(
                          children: [
                            BentoInput(
                              fieldKey: LoginKeys.emailField,
                              label: 'Work email',
                              controller: controller.emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              prefixIcon: Icons.alternate_email_rounded,
                              autofillHints: const [AutofillHints.username],
                              inputFormatters: [
                                // No spaces, ever. A phone keyboard's
                                // autocorrect appends one after a domain and
                                // the server rejects the address with a
                                // message nobody can act on.
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                            ),
                            Obx(
                              () => BentoInput(
                                fieldKey: LoginKeys.passwordField,
                                label: 'Password',
                                controller: controller.passwordController,
                                obscure: controller.isPasswordHidden.value,
                                textInputAction: TextInputAction.done,
                                prefixIcon: Icons.lock_outline_rounded,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => controller.submit(),
                                suffix: IconButton(
                                  key: LoginKeys.passwordToggle,
                                  onPressed: controller.togglePassword,
                                  icon: Icon(
                                    controller.isPasswordHidden.value
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  tooltip: controller.isPasswordHidden.value
                                      ? 'Show password'
                                      : 'Hide password',
                                  color: tertiaryLabelColor(context),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        Obx(
                          () => PrimaryBar(
                            key: LoginKeys.submit,
                            label: 'Sign in',
                            busy: controller.isSubmitting.value,
                            onPressed: controller.submit,
                          ),
                        ),

                        const SizedBox(height: 20),
                        Text(
                          'Accounts are issued by your administrator.',
                          textAlign: TextAlign.center,
                          style: isDark
                              ? AppTextStyles.darkFootnote()
                              : AppTextStyles.lightFootnote(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: brandFillColor(context),
            borderRadius: BorderRadius.circular(BentoRadius.hero),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimaryContainer
                  .withValues(alpha: 0.24),
            ),
            boxShadow: bentoShadow(context, hero: true),
          ),
          child: Icon(
            Icons.monitor_heart_rounded,
            size: 30,
            color: onBrandFillColor(context),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'MediHive',
          style: isDark
              ? AppTextStyles.darkTitle1()
              : AppTextStyles.lightTitle1(),
        ),
        const SizedBox(height: 4),
        Text(
          'Hospital operations',
          style: AppTextStyles.overline(Theme.of(context).brightness),
        ),
      ],
    );
  }
}
