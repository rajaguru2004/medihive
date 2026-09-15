import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../../patient_portal/patient_portal_navigation.dart';
import '../controllers/login_controller.dart';
import '../demo_accounts.dart';

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
                              validator: controller.validateEmail,
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
                                validator: controller.validatePassword,
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

                        if (DemoAccounts.enabled) ...[
                          const SizedBox(height: BentoSpace.section),
                          _DemoSignIn(controller),
                        ],

                        // ── The other person who opens this app ──────────
                        //
                        // A patient with a hospital card and no password has
                        // nowhere else to start: the claim screen is public
                        // and reachable from nothing but here. Below the rule
                        // and below the staff form, because the heaviest user
                        // of this screen is still a clinician at the start of
                        // a shift — but a real control rather than a link, so
                        // somebody holding a card can actually hit it.
                        const SizedBox(height: 24),
                        const Hairline(),
                        const SizedBox(height: 20),
                        Text(
                          'Are you a patient?',
                          textAlign: TextAlign.center,
                          style: isDark
                              ? AppTextStyles.darkHeadline()
                              : AppTextStyles.lightHeadline(),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'If you have a hospital card and no password yet, '
                          'you can set one up.',
                          textAlign: TextAlign.center,
                          style: (isDark
                                  ? AppTextStyles.darkSubheadline()
                                  : AppTextStyles.lightSubheadline())
                              .copyWith(color: secondaryLabelColor(context)),
                        ),
                        const SizedBox(height: 14),
                        const SecondaryBar(
                          key: PatientPortalKeys.claimFromSignIn,
                          label: 'Use my hospital card',
                          icon: Icons.badge_outlined,
                          onPressed: PatientPortalNavigation.toClaim,
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

/// One tap per seeded account, on debug builds only.
///
/// Compiled out of release entirely — `DemoAccounts.enabled` is `kDebugMode`,
/// and a shipped app that lists working hospital logins on its first screen has
/// no authentication at all.
///
/// It signs in the ordinary way: the form is filled and `submit()` runs, so the
/// request, the access map and the shell decision are the same ones a typed
/// password produces. What it removes is the typing, which is the part that
/// goes wrong on a phone in front of an audience.
class _DemoSignIn extends StatelessWidget {
  const _DemoSignIn(this.controller);

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      key: LoginKeys.demoPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Demo sign-in',
            style: AppTextStyles.overline(Theme.of(context).brightness),
          ),
          const SizedBox(height: 4),
          Text(
            'Debug builds only. Signs in normally with the seeded password.',
            style: Theme.of(context).brightness == Brightness.dark
                ? AppTextStyles.darkFootnote()
                : AppTextStyles.lightFootnote(),
          ),
          const SizedBox(height: BentoSpace.action),
          Obx(() {
            final busy = controller.isSubmitting.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final account in DemoAccounts.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BentoRow(
                      key: LoginKeys.demoAccount(account.email),
                      title: account.label,
                      subtitle: account.shows,
                      subtitleMaxLines: 2,
                      icon: Icons.login_rounded,
                      onTap: busy
                          ? null
                          : () => controller.signInAsDemo(account),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
