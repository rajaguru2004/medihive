import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/radiology_keys.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/radiology_report_form_controller.dart';

/// The radiologist's read.
class RadiologyReportFormView extends GetView<RadiologyReportFormController> {
  const RadiologyReportFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: controller.isEditing ? 'Edit report' : 'Write report',
      ),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoading && controller.rxFirstLoad.value) {
              return const Padding(
                padding: EdgeInsets.all(BentoSpace.page),
                child: BentoSkeleton(rows: 6),
              );
            }

            final order = controller.order.value;

            return Form(
              key: controller.formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(BentoSpace.page),
                      child: MaxWidthBody(
                        maxWidth: 560,
                        child: Column(
                          key: RadiologyKeys.reportForm,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Obx(() {
                              final loadError = controller.rxLoadError.value;
                              if (loadError == null) {
                                return const SizedBox.shrink();
                              }
                              return ErrorRetryBanner(
                                message: loadError,
                                onRetry: controller.load,
                              );
                            }),
                            Obx(() {
                              final saveError = controller.errorMessage.value;
                              if (saveError == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: NoticeBanner(
                                  key: RadiologyKeys.reportFormError,
                                  message: saveError,
                                  icon: Icons.error_outline_rounded,
                                  tint: AppColors.error,
                                ),
                              );
                            }),

                            // Who and what, so a read written from a worklist
                            // is checked against the right study before a word
                            // of it is typed.
                            if (!order.isEmpty) ...[
                              InsetSurface(
                                padding: const EdgeInsets.all(14),
                                child: PatientIdentityBand(
                                  name: order.patient.displayName,
                                  mrn: order.patient.mrn,
                                  age: order.patient.age,
                                  sex: order.patient.gender,
                                  extra: order.examName,
                                ),
                              ),
                              const SizedBox(height: BentoSpace.section),
                            ],

                            // ── The read ──────────────────────────────────
                            FormCard(
                              title: 'The read',
                              children: [
                                BentoInput(
                                  fieldKey: RadiologyKeys.reportTechnique,
                                  label: 'Technique',
                                  required: true,
                                  maxLines: 2,
                                  controller: controller.techniqueController,
                                  validator: controller.validateTechnique,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  hint: 'How the study was acquired.',
                                ),
                                // A validated field rather than a numbered one:
                                // findings are required, and
                                // `NumberedTextInput` does not join the
                                // enclosing `Form`.
                                BentoInput(
                                  fieldKey: RadiologyKeys.reportFindings,
                                  label: 'Findings',
                                  required: true,
                                  maxLines: 6,
                                  controller: controller.findingsController,
                                  validator: controller.validateFindings,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                ),
                                BentoInput(
                                  fieldKey: RadiologyKeys.reportImpression,
                                  label: 'Impression',
                                  required: true,
                                  maxLines: 4,
                                  controller: controller.impressionController,
                                  validator: controller.validateImpression,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  hint: 'The one paragraph the referring '
                                      'clinician reads.',
                                ),
                                // Numbered, because recommendations are a list
                                // somebody works through and typing "1. " on a
                                // phone keyboard is how a field ends up empty.
                                NumberedTextInput(
                                  fieldKey:
                                      RadiologyKeys.reportRecommendations,
                                  label: 'Recommendations',
                                  controller:
                                      controller.recommendationsController,
                                  hint: 'Follow-up imaging, referral, '
                                      'interval.',
                                ),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            // ── Critical findings ─────────────────────────
                            FormCard(
                              title: 'Critical findings',
                              children: [
                                Obx(
                                  () => BentoSwitchRow(
                                    switchKey: RadiologyKeys.reportCritical,
                                    label: 'This read found something critical',
                                    sublabel: 'The ward has to be told, and '
                                        'this record is how that is proved.',
                                    value: controller.hasCriticalFindings.value,
                                    onChanged: (value) => controller
                                        .hasCriticalFindings.value = value,
                                  ),
                                ),
                                Obx(() {
                                  if (!controller.hasCriticalFindings.value) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      BentoInput(
                                        fieldKey:
                                            RadiologyKeys.reportCriticalText,
                                        label: 'What the finding is',
                                        required: true,
                                        maxLines: 3,
                                        controller: controller
                                            .criticalFindingsController,
                                        validator: controller
                                            .validateCriticalFindings,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                      ),
                                      BentoInput(
                                        fieldKey:
                                            RadiologyKeys.reportNotifiedTo,
                                        label: 'Notified to',
                                        required: true,
                                        controller:
                                            controller.notifiedToController,
                                        validator:
                                            controller.validateNotifiedTo,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        hint: _notifiedHint(controller),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            // ── Comparison ────────────────────────────────
                            FormCard(
                              title: 'Comparison',
                              children: [
                                Obx(
                                  () => BentoSwitchRow(
                                    switchKey: RadiologyKeys.reportComparison,
                                    label: 'Compared with a previous study',
                                    value:
                                        controller.comparedWithPrevious.value,
                                    onChanged: (value) => controller
                                        .comparedWithPrevious.value = value,
                                  ),
                                ),
                                Obx(
                                  () => controller.comparedWithPrevious.value
                                      ? BentoInput(
                                          fieldKey: RadiologyKeys
                                              .reportComparisonNotes,
                                          label: 'What changed',
                                          maxLines: 3,
                                          controller: controller
                                              .comparisonNotesController,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          hint: 'Which study, and how this one '
                                              'differs.',
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            // ── Status ────────────────────────────────────
                            FormCard(
                              title: 'Status',
                              children: [_StatusSection(controller: controller)],
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
                      maxWidth: 560,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(
                            () => controller.invalidFields.value == 0
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: FieldErrorSummary(
                                      count: controller.invalidFields.value,
                                    ),
                                  ),
                          ),
                          Obx(
                            () => PrimaryBar(
                              key: RadiologyKeys.reportSave,
                              label: controller.isAmending
                                  ? 'Save the amendment'
                                  : 'Save report',
                              busy: controller.isSubmitting.value,
                              onPressed: () => _save(controller),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Draft or final while the read is being written; an amendment once it has
/// been signed.
///
/// A signed report is not offered a way back to "draft": the ward has already
/// acted on it, and a record that can quietly become a draft again is a record
/// nobody can rely on. What it is offered is the reason it is changing.
class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.controller});

  final RadiologyReportFormController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isAmending) {
        return BentoField(
          label: 'Report status',
          required: true,
          hint: 'A final report is the one the ward acts on.',
          child: BentoSegmented<String>(
            key: RadiologyKeys.reportStatus,
            options: const [
              RadiologyReportStatus.draft,
              RadiologyReportStatus.isFinal,
            ],
            selected: controller.status.value,
            labelOf: Formatters.label,
            keyOf: RadiologyKeys.reportStatusOption,
            onSelected: (value) => controller.status.value = value,
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoticeBanner(
            message: 'This report has been signed. Saving records an '
                'amendment against it, with the reason below.',
            icon: Icons.history_edu_outlined,
            tint: AppColors.acuityReview,
          ),
          const SizedBox(height: BentoSpace.action),
          BentoInput(
            fieldKey: RadiologyKeys.reportAmendment,
            label: 'Why this is being amended',
            required: true,
            maxLines: 3,
            controller: controller.amendmentController,
            validator: controller.validateAmendment,
            textCapitalization: TextCapitalization.sentences,
            hint: 'Goes on the record beside the change.',
          ),
        ],
      );
    });
  }
}

/// When the notification will be stamped, said plainly.
String _notifiedHint(RadiologyReportFormController controller) {
  final already = controller.stored.value?.criticalNotifiedAt;
  return already == null
      ? 'The time is recorded when this is saved.'
      : 'Told at ${Formatters.dateTime(already)}.';
}

Future<void> _save(RadiologyReportFormController controller) async {
  if (!await controller.submit()) return;
  Get.back<void>();
  showBentoToast(
    controller.isAmending ? 'Amendment saved.' : 'Report saved.',
  );
}
