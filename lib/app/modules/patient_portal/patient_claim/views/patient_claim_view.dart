import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/app_clock.dart';
import '../../../../core/keys/app_keys.dart';
import '../../../../data/services/settings_service.dart';
import '../../../../theme/theme.dart';
import '../controllers/patient_claim_controller.dart';

/// "I have a hospital card and no account."
///
/// The first screen of the portal for everybody who has ever been treated
/// here, and the one most likely to be read by somebody who is anxious and has
/// never used the app. So: one thing asked at a time, the question set larger
/// than the label above it, and a sentence under each field saying where on
/// the card to look.
class PatientClaimView extends GetView<PatientClaimController> {
  const PatientClaimView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the top so the controller is built. See the trap in CLAUDE.md.
    final c = controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = AppClock.now();

    return Scaffold(
      key: PatientPortalKeys.claim,
      appBar: const DetailHeader(title: 'Get into your record'),
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
                          Text(
                            'What is on your hospital card?',
                            style: isDark
                                ? AppTextStyles.darkTitle2()
                                : AppTextStyles.lightTitle2(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We will use these to find your record and set up a '
                            'password for you.',
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
                                      key: PatientPortalKeys.claimError,
                                      icon: Icons.info_outline_rounded,
                                      // Amber, not red. Nobody is
                                      // deteriorating; a card that did not
                                      // work is an administrative problem, and
                                      // `.agents/RULES.md` §0 keeps red for
                                      // the other kind.
                                      tint: AppColors.warning,
                                      message: c.errorMessage.value!,
                                    ),
                                  ),
                          ),

                          FormCard(
                            children: [
                              BentoInput(
                                fieldKey: PatientPortalKeys.claimMrn,
                                label: 'Hospital number',
                                controller: c.mrnController,
                                validator: c.validateMrn,
                                required: true,
                                autofocus: true,
                                hint: 'Printed on your card, next to your name',
                                textInputAction: TextInputAction.done,
                                textCapitalization:
                                    TextCapitalization.characters,
                                // Whitespace only. The number is matched
                                // exactly by the server, so stripping the
                                // hyphens out of a correct card is how a
                                // correct card stops working.
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                  LengthLimitingTextInputFormatter(64),
                                ],
                              ),
                              Obx(
                                () => DateField(
                                  fieldKey: PatientPortalKeys.claimDateOfBirth,
                                  label: 'Date of birth',
                                  value: c.dateOfBirth.value,
                                  required: true,
                                  error: c.dateOfBirthError.value,
                                  // "Today" and "In a week" are answers to a
                                  // due date. A date of birth is always a day
                                  // on a calendar.
                                  quickPicks: false,
                                  firstDate: DateTime(now.year - 120),
                                  lastDate: now,
                                  format: SettingsService.to.date,
                                  onChanged: (value) {
                                    c.dateOfBirth.value = value;
                                    c.dateOfBirthError.value = null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: BentoSpace.section),
                          Text(
                            'No card? Ask at reception and they can set this up '
                            'for you.',
                            style: (isDark
                                    ? AppTextStyles.darkSubheadline()
                                    : AppTextStyles.lightSubheadline())
                                .copyWith(
                              color: secondaryLabelColor(context),
                              height: 1.4,
                            ),
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
                      child: Obx(
                        () => PrimaryBar(
                          key: PatientPortalKeys.claimSubmit,
                          label: 'Continue',
                          icon: Icons.arrow_forward_rounded,
                          busy: c.isSubmitting.value,
                          onPressed: c.submit,
                        ),
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
