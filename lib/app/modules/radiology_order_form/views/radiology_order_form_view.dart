import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/radiology_keys.dart';
import '../../../data/models/patient_lookup.dart';
import '../../../data/models/radiology_exam.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../radiology/radiology_routes.dart';
import '../../radiology/views/radiology_shared.dart';
import '../controllers/radiology_order_form_controller.dart';

/// Raise an imaging request.
class RadiologyOrderFormView extends GetView<RadiologyOrderFormController> {
  const RadiologyOrderFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'New imaging order'),
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
                        maxWidth: 560,
                        child: Column(
                          key: RadiologyKeys.orderForm,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // A load that failed and a save that bounced are
                            // not the same news: the first leaves every picker
                            // on this form empty, so it is the one that needs
                            // a way back.
                            Obx(() {
                              final loadError = controller.rxLoadError.value;
                              if (loadError == null) {
                                return const SizedBox.shrink();
                              }
                              return ErrorRetryBanner(
                                key: RadiologyKeys.orderFormLoadError,
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
                                  key: RadiologyKeys.orderFormError,
                                  message: saveError,
                                  icon: Icons.error_outline_rounded,
                                  tint: AppColors.error,
                                ),
                              );
                            }),

                            // ── Who ───────────────────────────────────────
                            FormCard(
                              title: 'Patient',
                              children: [
                                Obx(
                                  () => AsyncPicker<PatientLookup>(
                                    fieldKey: RadiologyKeys.orderPatient,
                                    label: 'Patient',
                                    required: true,
                                    placeholder: 'Search by name or MRN',
                                    searchHint: 'Name or MRN',
                                    valueLabel:
                                        controller.patient.value?.fullName,
                                    // `AsyncPicker` does not join the enclosing
                                    // `Form`, so a patient nobody chose is
                                    // caught by the controller rather than by
                                    // `validate()` — see
                                    // `RadiologyOrderFormController.submit`.
                                    error: controller.patientError.value,
                                    onSearch: (query) async => [
                                      for (final p in await controller
                                          .searchPatients(query))
                                        PickerOption<PatientLookup>(
                                          value: p,
                                          label: p.fullName,
                                          sublabel: [
                                            if (p.mrn.isNotEmpty)
                                              'MRN ${p.mrn}',
                                            Formatters.age(p.dateOfBirth),
                                            if ((p.gender ?? '').isNotEmpty)
                                              p.gender!,
                                          ]
                                              .where((part) => part != '—')
                                              .join(' · '),
                                        ),
                                    ],
                                    onSelected: (chosen) =>
                                        controller.choosePatient(chosen),
                                  ),
                                ),
                                Obx(() {
                                  final chosen = controller.patient.value;
                                  if (chosen == null) {
                                    return const SizedBox.shrink();
                                  }
                                  // Shown back, so whoever is filling the form
                                  // can check the record before a study is
                                  // committed to it.
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: InsetSurface(
                                      padding: const EdgeInsets.all(14),
                                      child: PatientIdentityBand(
                                        name: chosen.fullName,
                                        mrn: chosen.mrn,
                                        age: Formatters.age(chosen.dateOfBirth),
                                        sex: chosen.gender,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            // ── What ──────────────────────────────────────
                            FormCard(
                              title: 'Study',
                              children: [
                                Obx(
                                  () => BentoPicker(
                                    fieldKey: RadiologyKeys.orderExam,
                                    label: 'Exam',
                                    required: true,
                                    value: controller.exam.value?.displayName,
                                    placeholder: 'Choose an exam',
                                    validator: controller.validateExam,
                                    onTap: () => _openExamSheet(controller),
                                  ),
                                ),
                                Obx(() {
                                  if (!controller.needsContrast) {
                                    return const SizedBox.shrink();
                                  }
                                  // Amber, not red: contrast changes how the
                                  // patient is prepared, it is not a patient
                                  // deteriorating.
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: NoticeBanner(
                                      key: RadiologyKeys.orderContrast,
                                      message: _contrastMessage(
                                        controller.exam.value!,
                                      ),
                                      icon: Icons.opacity_rounded,
                                      tint: AppColors.warning,
                                    ),
                                  );
                                }),
                                BentoField(
                                  label: 'How soon',
                                  required: true,
                                  hint: 'Stat means the patient is waiting at '
                                      'the machine.',
                                  child: Obx(
                                    () => BentoSegmented<String>(
                                      key: RadiologyKeys.orderUrgency,
                                      options: RadiologyUrgency.all,
                                      selected: controller.urgency.value,
                                      labelOf: radiologyUrgencyLabel,
                                      keyOf: RadiologyKeys.orderUrgencyOption,
                                      onSelected: (value) =>
                                          controller.urgency.value = value,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            // ── Why ───────────────────────────────────────
                            FormCard(
                              title: 'Request',
                              children: [
                                BentoInput(
                                  fieldKey: RadiologyKeys.orderIndication,
                                  label: 'Clinical indication',
                                  required: true,
                                  maxLines: 3,
                                  controller: controller.indicationController,
                                  validator: controller.validateIndication,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  hint: 'What question is the study meant to '
                                      'answer?',
                                ),
                                BentoInput(
                                  fieldKey: RadiologyKeys.orderDiagnosis,
                                  label: 'Provisional diagnosis',
                                  maxLines: 2,
                                  controller: controller.diagnosisController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                ),
                                BentoInput(
                                  fieldKey: RadiologyKeys.orderHistory,
                                  label: 'Relevant history',
                                  maxLines: 3,
                                  controller: controller.historyController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  hint: 'Previous imaging, implants, pregnancy, '
                                      'allergies.',
                                ),
                                BentoInput(
                                  fieldKey: RadiologyKeys.orderNotes,
                                  label: 'Notes for the department',
                                  maxLines: 2,
                                  controller: controller.notesController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  hint: 'Wheelchair, interpreter, ward porter.',
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
                              key: RadiologyKeys.orderSubmit,
                              label: 'Raise the request',
                              busy: controller.isSubmitting.value,
                              onPressed: () => _submit(controller),
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

String _contrastMessage(RadiologyExam exam) {
  final prep = (exam.preparationInstructions ?? '').trim();
  const head = 'This exam needs contrast. Check consent, renal function and '
      'allergies before the patient is sent.';
  return prep.isEmpty ? head : '$head $prep';
}

Future<void> _submit(RadiologyOrderFormController controller) async {
  final id = await controller.submit();
  if (id == null) return;
  showBentoToast('Imaging request raised.');
  // Straight to the order, not back to the worklist: the next thing anybody
  // does with a new request is schedule it.
  //
  // **Not awaited.** `Get.offNamed` completes when the route it opens is
  // *popped*, so awaiting it here would hold this function open for as long as
  // the clinician stays on the detail screen — the same trap as
  // `await Get.toNamed(...)`.
  unawaited(Get.offNamed<void>(RadiologyRoutes.orderFor(id)));
}

/// The catalogue, grouped the way a requester thinks about it.
///
/// A sheet of its own rather than a flat picker: "CT" and "Ultrasound" is how
/// somebody narrows sixty exams to four, and an alphabetical list of sixty
/// makes them read all sixty.
Future<void> _openExamSheet(RadiologyOrderFormController controller) {
  final groups = controller.examsByGroup;
  final money = SettingsService.to.settings.money;

  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Exam',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (groups.isEmpty)
            const SheetSection(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  compact: true,
                  icon: Icons.list_alt_outlined,
                  title: 'The catalogue is empty',
                  message: 'Add an exam to the catalogue before ordering one.',
                ),
              ),
            )
          else
            for (final group in groups.entries) ...[
              SheetSection(
                child: SectionHeader(title: group.key, inset: true),
              ),
              for (final exam in group.value)
                SheetRow(
                  icon: exam.contrastRequired
                      ? Icons.opacity_rounded
                      : Icons.monitor_heart_outlined,
                  label: exam.displayName,
                  sublabel: [
                    if ((exam.modality ?? '').trim().isNotEmpty) exam.modality!,
                    if (exam.estimatedDuration != null)
                      '${exam.estimatedDuration} min',
                    if (exam.price != null) exam.priceLabel(money),
                    if (exam.contrastRequired) 'Contrast',
                  ].join(' · '),
                  selected: controller.exam.value?.id == exam.id,
                  onTap: () {
                    controller.exam.value = exam;
                    Get.back<void>();
                  },
                ),
            ],
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
