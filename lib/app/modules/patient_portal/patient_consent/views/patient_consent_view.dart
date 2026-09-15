import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/patient_text.dart';
import '../../../../core/keys/app_keys.dart';
import '../../../../theme/theme.dart';
import '../controllers/patient_consent_controller.dart';

/// What happens to what you say, and then the question.
///
/// **Not a checkbox under a wall of text.** A consent nobody read is not
/// consent, and a tick box beside three hundred words of terms is a control
/// designed to be got past. So the four things a patient has a right to know
/// are four separate statements, each one sentence long, each with the heading
/// a person would use to describe it — and the ask comes *after* them, as a
/// question with two equally real answers.
///
/// The four are not arbitrary. They are the ones where a patient's assumption
/// is most likely to be wrong:
///
///  * what is collected — people expect a form and get a conversation;
///  * who reads it — people assume a machine files it and nobody looks;
///  * that it is **not a diagnosis** — the one that matters clinically, and
///    the one the spec is most insistent about (§30, §43): a patient who
///    believes the app has told them what is wrong may not go in at all;
///  * that they can stop — because somebody who believes they cannot will
///    answer a question they would rather not, and an answer given under that
///    belief is worse evidence than no answer.
class PatientConsentView extends GetView<PatientConsentController> {
  const PatientConsentView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: PatientPortalKeys.consent,
      // The same header as the language screen, and read from the same key:
      // the two are one sequence, and a title translated on one of them and
      // not the other is the drift `patient_text.dart` exists to stop.
      appBar: DetailHeader(title: PatientText.beforeWeStart),
      body: BentoGround(
        child: SafeArea(
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
                          'What happens to what you tell us',
                          style: isDark
                              ? AppTextStyles.darkTitle2()
                              : AppTextStyles.lightTitle2(),
                        ),
                        const SizedBox(height: BentoSpace.section),

                        const BentoCard(
                          key: PatientPortalKeys.consentPoints,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ConsentPoint(
                                icon: Icons.chat_bubble_outline_rounded,
                                heading: 'We write down what you say',
                                body: 'Your answers about your symptoms, your '
                                    'health and any medicines you take. If you '
                                    'photograph a prescription or a report, we '
                                    'keep that too.',
                              ),
                              _ConsentPoint(
                                icon: Icons.local_hospital_outlined,
                                heading: 'A doctor reads it',
                                body: 'It goes onto your hospital record, and '
                                    'the doctor you are about to see reads it '
                                    'before your appointment.',
                              ),
                              _ConsentPoint(
                                icon: Icons.info_outline_rounded,
                                heading: 'It is not a diagnosis',
                                body: 'MediHive does not decide what is wrong '
                                    'with you and will not tell you. It writes '
                                    'your story down so the doctor already has '
                                    'it when you go in.',
                              ),
                              _ConsentPoint(
                                icon: Icons.pan_tool_outlined,
                                heading: 'You can stop at any time',
                                body: 'You can skip a question or leave '
                                    'altogether. Nothing is sent to the doctor '
                                    'until you have read it back and said it '
                                    'is right.',
                                last: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: BentoSpace.section),
                        const ConversationTurn(
                          speaker: ConversationSpeaker.assistant,
                          child: AssistantBubble(
                            live: true,
                            text: 'Shall we start?',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 56,
                        child: PrimaryBar(
                          key: PatientPortalKeys.consentAgree,
                          label: 'Yes, start',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: c.agree,
                        ),
                      ),
                      const SizedBox(height: BentoSpace.action),
                      // A real second answer, not a link in the corner.
                      // "Not now" is not destructive and is not styled as if
                      // it were — `.agents/RULES.md` §0 keeps red for a
                      // deteriorating patient, and declining to answer some
                      // questions is not that.
                      SizedBox(
                        height: 52,
                        child: SecondaryBar(
                          key: PatientPortalKeys.consentDecline,
                          label: 'Not now',
                          onPressed: c.decline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One thing the patient is being told.
///
/// Heading at `headline`, body at `body` — nothing on this surface goes below
/// 17, which is the patient register `app_bento_conversation.dart` sets out and
/// the reason this screen does not reuse `FactRow`: a label-and-value row is
/// for a figure, and this is a sentence somebody has to actually read.
class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({
    required this.icon,
    required this.heading,
    required this.body,
    this.last = false,
  });

  final IconData icon;
  final String heading;
  final String body;

  /// Suppresses the rule under the final point, so the card does not end on a
  /// line with nothing below it.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: brandInkColor(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: isDark
                        ? AppTextStyles.darkHeadline()
                        : AppTextStyles.lightHeadline(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: (isDark
                            ? AppTextStyles.darkBody()
                            : AppTextStyles.lightBody())
                        .copyWith(
                      color: secondaryLabelColor(context),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!last) ...[
          const SizedBox(height: BentoSpace.section),
          const Hairline(),
          const SizedBox(height: BentoSpace.section),
        ],
      ],
    );
  }
}
