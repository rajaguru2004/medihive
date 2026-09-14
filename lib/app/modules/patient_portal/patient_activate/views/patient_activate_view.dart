import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/keys/app_keys.dart';
import '../../../../theme/theme.dart';
import '../../patient_portal_navigation.dart';
import '../controllers/patient_activate_controller.dart';

/// Setting a password, and the end of the claim.
///
/// The rule is written above the field rather than revealed by a refusal. A
/// password form that only says what is wrong after the fact makes somebody
/// guess twice, and this one is being filled in by a person who has already
/// typed a hospital number they were not sure they read correctly.
class PatientActivateView extends GetView<PatientActivateController> {
  const PatientActivateView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: PatientPortalKeys.activate,
      appBar: const DetailHeader(title: 'Choose a password'),
      body: BentoGround(
        child: SafeArea(
          child: Form(
            key: c.formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(BentoSpace.page),
                    child: MaxWidthBody(
                      maxWidth: 520,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!c.hasClaim) ...[
                            const NoticeBanner(
                              key: PatientPortalKeys.activateNoClaim,
                              icon: Icons.schedule_rounded,
                              tint: AppColors.warning,
                              message: 'This step has to start from your '
                                  'hospital card, and it only stays open for a '
                                  'few minutes. Start again.',
                            ),
                            const SizedBox(height: BentoSpace.section),
                          ],

                          Text(
                            'Choose a password',
                            style: isDark
                                ? AppTextStyles.darkTitle2()
                                : AppTextStyles.lightTitle2(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You will use it every time you sign in, so pick '
                            'something you will remember. At least 8 '
                            'characters, and no more than 72.',
                            style: (isDark
                                    ? AppTextStyles.darkBody()
                                    : AppTextStyles.lightBody())
                                .copyWith(
                              color: secondaryLabelColor(context),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: BentoSpace.section),

                          Obx(
                            () => c.errorMessage.value == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: BentoSpace.section,
                                    ),
                                    child: NoticeBanner(
                                      key: PatientPortalKeys.activateError,
                                      icon: Icons.info_outline_rounded,
                                      tint: AppColors.warning,
                                      message: c.errorMessage.value!,
                                    ),
                                  ),
                          ),

                          FormCard(
                            children: [
                              Obx(
                                () => BentoInput(
                                  fieldKey: PatientPortalKeys.activatePassword,
                                  label: 'Password',
                                  controller: c.passwordController,
                                  validator: c.validatePassword,
                                  required: true,
                                  obscure: c.isPasswordHidden.value,
                                  enabled: c.hasClaim,
                                  autofocus: c.hasClaim,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(72),
                                  ],
                                  suffix: IconButton(
                                    key: PatientPortalKeys.activateReveal,
                                    onPressed: c.togglePassword,
                                    tooltip: c.isPasswordHidden.value
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      c.isPasswordHidden.value
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              Obx(
                                () => BentoInput(
                                  fieldKey: PatientPortalKeys.activateConfirm,
                                  label: 'Type it again',
                                  controller: c.confirmController,
                                  validator: c.validateConfirm,
                                  required: true,
                                  obscure: c.isPasswordHidden.value,
                                  enabled: c.hasClaim,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(72),
                                  ],
                                ),
                              ),
                              Obx(
                                () => BentoInput(
                                  fieldKey: PatientPortalKeys.activateEmail,
                                  label: 'Email address',
                                  controller: c.emailController,
                                  validator: c.validateEmail,
                                  required: c.emailRequired.value,
                                  enabled: c.hasClaim,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.email],
                                  // The app cannot know whether the record
                                  // already carries one — the claim response
                                  // tells it nothing about the record on
                                  // purpose — so the field is offered rather
                                  // than demanded, and becomes required only
                                  // when the server says it is.
                                  hint: c.emailRequired.value
                                      ? 'This is how you will sign in'
                                      : 'Only needed if we do not already have '
                                          'one for you',
                                  onSubmitted: (_) => c.submit(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BentoSpace.page,
                    0,
                    BentoSpace.page,
                    BentoSpace.page,
                  ),
                  child: MaxWidthBody(
                    maxWidth: 520,
                    child: SizedBox(
                      height: 56,
                      // Branched outside the `Obx`, deliberately. `hasClaim`
                      // is a plain field read once from the route arguments,
                      // and an `Obx` whose body reads no observable throws
                      // rather than rendering.
                      child: c.hasClaim
                          ? Obx(
                              () => PrimaryBar(
                                key: PatientPortalKeys.activateSubmit,
                                label: 'Set my password',
                                icon: Icons.check_rounded,
                                busy: c.isSubmitting.value,
                                onPressed: c.submit,
                              ),
                            )
                          : const PrimaryBar(
                              key: PatientPortalKeys.activateSubmit,
                              label: 'Start again',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: PatientPortalNavigation.toClaim,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
