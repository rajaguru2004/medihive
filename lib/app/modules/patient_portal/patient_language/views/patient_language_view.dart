import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/keys/app_keys.dart';
import '../../../../theme/theme.dart';
import '../../patient_entry.dart';
import '../controllers/patient_language_controller.dart';

/// "Which language would you like to use?"
///
/// Drawn with the conversation kit rather than as a settings form, because
/// that is what it is: the first turn of the interview, in the register the
/// rest of it is in. A patient who answers this as a dropdown on a settings
/// screen and is then dropped into a conversation has met two apps.
///
/// **Nothing here shows a language that does not work.** A list with Tamil and
/// Hindi greyed out tells a patient this app is for somebody else; a sentence
/// saying they are coming tells them the same fact without the refusal. The
/// speech models for both still have to be benchmarked before the app can
/// promise an interview in either — a misheard symptom is worse than an
/// untranslated one — and that is the phase that will add them.
class PatientLanguageView extends GetView<PatientLanguageController> {
  const PatientLanguageView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: PatientPortalKeys.language,
      appBar: const DetailHeader(title: 'Before we start'),
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
                        const ConversationTurn(
                          speaker: ConversationSpeaker.assistant,
                          child: AssistantBubble(
                            live: true,
                            text: 'Which language would you like to use?',
                            detail: 'You can change it later.',
                          ),
                        ),
                        const SizedBox(height: BentoSpace.section),
                        Obx(
                          () => AnswerChoiceRow<PatientLanguage>(
                            choices: c.languages,
                            selected: c.selected.value,
                            // One per row. A single option laid out in a
                            // two-column grid is a tile that stops halfway
                            // across the screen, which reads as a second
                            // option that failed to load.
                            columns: 1,
                            labelOf: (language) => language.nativeName,
                            keyOf: (language) =>
                                PatientPortalKeys.languageOption(language.code),
                            onSelected: c.choose,
                          ),
                        ),
                        if (c.isSingleLanguage) ...[
                          const SizedBox(height: BentoSpace.section),
                          Text(
                            'More languages are coming. Today the questions are '
                            'in English only — if that is difficult, tell the '
                            'desk and somebody can go through them with you.',
                            key: PatientPortalKeys.languageMore,
                            style: (isDark
                                    ? AppTextStyles.darkBody()
                                    : AppTextStyles.lightBody())
                                .copyWith(
                              color: secondaryLabelColor(context),
                              height: 1.45,
                            ),
                          ),
                        ],
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
                    child: PrimaryBar(
                      key: PatientPortalKeys.languageContinue,
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: c.continueToConsent,
                    ),
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
