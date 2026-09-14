import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/radiology_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/radiology_exam_form_controller.dart';

/// Add or edit one entry in the imaging catalogue.
class RadiologyExamFormView extends GetView<RadiologyExamFormController> {
  const RadiologyExamFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: controller.isEditing ? 'Edit exam' : 'New exam',
      ),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoading && controller.rxFirstLoad.value) {
              return const Padding(
                padding: EdgeInsets.all(BentoSpace.page),
                child: BentoSkeleton(rows: 5),
              );
            }

            return Form(
              key: controller.formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(BentoSpace.page),
                      child: MaxWidthBody(
                        maxWidth: 520,
                        child: Column(
                          key: RadiologyKeys.examForm,
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
                                  key: RadiologyKeys.examFormError,
                                  message: saveError,
                                  icon: Icons.error_outline_rounded,
                                  tint: AppColors.error,
                                ),
                              );
                            }),

                            FormCard(
                              title: 'What it is',
                              children: [
                                BentoInput(
                                  fieldKey: RadiologyKeys.examName,
                                  label: 'Exam name',
                                  required: true,
                                  controller: controller.nameController,
                                  validator: controller.validateName,
                                  textCapitalization: TextCapitalization.words,
                                ),
                                BentoInput(
                                  fieldKey: RadiologyKeys.examCode,
                                  label: 'Code',
                                  controller: controller.codeController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  hint: 'What the request card and the PACS '
                                      'call it.',
                                ),
                                Obx(
                                  () => BentoPicker(
                                    fieldKey: RadiologyKeys.examCategory,
                                    label: 'Category',
                                    value: Formatters.label(
                                      controller.category.value,
                                    ),
                                    placeholder: 'Choose a category',
                                    hint: 'The order form groups the catalogue '
                                        'by this.',
                                    onTap: () => _openChoiceSheet(
                                      title: 'Category',
                                      options:
                                          RadiologyExamFormController.categories,
                                      labelOf: Formatters.label,
                                      selected: controller.category.value,
                                      onSelected: (value) =>
                                          controller.category.value = value,
                                    ),
                                  ),
                                ),
                                BentoInput(
                                  fieldKey: RadiologyKeys.examBodyPart,
                                  label: 'Body part',
                                  controller: controller.bodyPartController,
                                  textCapitalization: TextCapitalization.words,
                                ),
                                Obx(
                                  () => BentoPicker(
                                    fieldKey: RadiologyKeys.examModality,
                                    label: 'Modality',
                                    value: controller.modality.value,
                                    placeholder: 'DICOM code',
                                    onTap: () => _openChoiceSheet(
                                      title: 'Modality',
                                      options:
                                          RadiologyExamFormController.modalities,
                                      labelOf: (value) => value,
                                      selected: controller.modality.value,
                                      onSelected: (value) =>
                                          controller.modality.value = value,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            FormCard(
                              title: 'What it costs, and how long it takes',
                              children: [
                                MoneyInput(
                                  fieldKey: RadiologyKeys.examPrice,
                                  label: 'Price',
                                  symbol: controller.currencySymbol,
                                  controller: controller.priceController,
                                ),
                                QuantityField(
                                  fieldKey: RadiologyKeys.examDuration,
                                  label: 'Minutes on the machine',
                                  controller: controller.durationController,
                                ),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            FormCard(
                              title: 'Preparing the patient',
                              children: [
                                Obx(
                                  () => BentoSwitchRow(
                                    switchKey: RadiologyKeys.examContrast,
                                    label: 'Contrast required',
                                    sublabel: 'Raises a notice on the order '
                                        'form, where consent and renal '
                                        'function are checked.',
                                    value: controller.contrastRequired.value,
                                    onChanged: (value) =>
                                        controller.contrastRequired.value =
                                            value,
                                  ),
                                ),
                                BentoInput(
                                  fieldKey: RadiologyKeys.examPreparation,
                                  label: 'Preparation instructions',
                                  maxLines: 3,
                                  controller: controller.preparationController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  hint: 'Fasting, metal, bladder, cannula.',
                                ),
                                // Only when editing: a catalogue entry is
                                // created live, and the switch on a create
                                // form would send a key the create DTO does
                                // not declare.
                                if (controller.isEditing)
                                  Obx(
                                    () => BentoSwitchRow(
                                      label: 'Offered',
                                      sublabel: 'An exam switched off stays on '
                                          'every order that used it, and stops '
                                          'appearing on new ones.',
                                      value: controller.isActive.value,
                                      onChanged: (value) =>
                                          controller.isActive.value = value,
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
                              key: RadiologyKeys.examSave,
                              label: controller.isEditing
                                  ? 'Save changes'
                                  : 'Add the exam',
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

Future<void> _save(RadiologyExamFormController controller) async {
  if (!await controller.submit()) return;
  Get.back<void>();
  showBentoToast(
    controller.isEditing ? 'Exam updated.' : 'Exam added to the catalogue.',
  );
}

/// A short fixed vocabulary, as a sheet of rows.
Future<void> _openChoiceSheet({
  required String title,
  required List<String> options,
  required String Function(String) labelOf,
  required String? selected,
  required ValueChanged<String> onSelected,
}) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: title,
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            SheetRow(
              icon: Icons.label_outline_rounded,
              label: labelOf(option),
              selected: selected == option,
              onTap: () {
                onSelected(option);
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
