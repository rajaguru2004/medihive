import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/patient_text.dart';
import '../../../../core/keys/app_keys.dart';
import '../../../../theme/theme.dart';
import '../../patient_entry.dart';
import '../controllers/patient_language_controller.dart';

/// "Choose your language."
///
/// Drawn with the conversation kit rather than as a settings form, because that
/// is what it is: the first turn of the interview, in the register the rest of
/// it is in. A patient who answers this as a dropdown on a settings screen and
/// is then dropped into a conversation has met two apps.
///
/// **The native name is the row and the English name is the footnote**, not the
/// other way round and not a bracket after it. The person this screen is for is
/// the one who cannot read the heading above it: for them the screen is twelve
/// shapes, one of which they recognise, and every point of type spent on
/// "Tamil" instead of on "தமிழ்" is spent on somebody who was not going to
/// struggle either way.
///
/// **What is chosen here is the language the patient will speak, and nothing
/// else.** The questions are asked in English on every row of this list, and
/// the sentence under the heading says so — because a patient who picks Tamil
/// and then meets an English question has been told wrong by the app, and a
/// screen that lies in its first sentence has spent the trust the rest of the
/// interview needs.
///
/// **Nothing here is offered and then refused.** One of the twelve cannot be
/// spoken back — the transcriber has no Odia model — and the screen says so
/// under the row the moment it is chosen, rather than letting the patient find
/// out when the microphone is missing from a question six screens later.
class PatientLanguageView extends GetView<PatientLanguageController> {
  const PatientLanguageView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Scaffold(
      key: PatientPortalKeys.language,
      appBar: DetailHeader(title: PatientText.beforeWeStart),
      body: BentoGround(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: PatientPortalKeys.languageList,
                  padding: const EdgeInsets.all(BentoSpace.page),
                  child: MaxWidthBody(
                    maxWidth: 520,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Not wrapped in a `ConversationTurn` — the bubble is
                        // one already. Wrapping it takes 88% of 88% and pays
                        // the turn's bottom padding twice, which on a heading
                        // this long is a line break the design did not ask for.
                        AssistantBubble(
                          live: true,
                          text: PatientText.chooseYourLanguage,
                          detail: PatientText.chooseYourLanguageDetail,
                        ),
                        const SizedBox(height: BentoSpace.section),
                        Obx(
                          () => AnswerChoiceRow<PatientLanguageOffer>(
                            choices: c.rxLanguages,
                            selected: c.selectedOffer,
                            // One per row. Two columns would halve the width a
                            // native name has, and these are scripts whose
                            // marks sit above and below the line — a Malayalam
                            // name wrapped mid-word is a name nobody
                            // recognises.
                            columns: 1,
                            labelOf: (offer) => offer.nativeName,
                            detailOf: (offer) => offer.englishName,
                            keyOf: (offer) =>
                                PatientPortalKeys.languageOption(offer.code),
                            onSelected: c.choose,
                          ),
                        ),
                        Obx(() {
                          final offer = c.selectedOffer;
                          if (offer == null || offer.canSpeak) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding:
                                const EdgeInsets.only(top: BentoSpace.section),
                            child: NoticeBanner(
                              key: PatientPortalKeys.languageVoiceNotice,
                              message: PatientText.cannotAnswerOutLoudIn(
                                offer.nativeName,
                              ),
                              icon: Icons.mic_off_rounded,
                              // Amber, never red. `.agents/RULES.md` §0 keeps
                              // red for a deteriorating patient, and a
                              // transcriber with one model missing is not
                              // that — it is a route that is longer, not one
                              // that is closed.
                              tint: AppColors.warning,
                            ),
                          );
                        }),
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
                      label: PatientText.languageContinue,
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
