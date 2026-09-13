import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/discharge_patient_controller.dart';

/// Discharge a patient.
///
/// The patient's identity sits at the top and stays there, because this is the
/// one screen where acting on the wrong record has a consequence that cannot
/// be taken back from the app. The confirm dialog names them again.
class DischargePatientView extends GetView<DischargePatientController> {
  const DischargePatientView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Discharge'),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoading && controller.rxFirstLoad.value) {
              return const Padding(
                padding: EdgeInsets.all(BentoSpace.page),
                child: BentoSkeleton(rows: 4),
              );
            }

            final admission = controller.admission.value;
            if (admission == null) {
              return Padding(
                padding: const EdgeInsets.all(BentoSpace.page),
                child: EmptyState(
                  key: DischargePatientKeys.error,
                  icon: Icons.search_off_rounded,
                  title: 'Admission not found',
                  message: controller.rxLoadError.value ??
                      'It may already have been closed by somebody else.',
                  actionLabel: 'Go back',
                  onAction: Get.back,
                ),
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
                          key: DischargePatientKeys.screen,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Obx(() {
                              final error = controller.errorMessage.value;
                              if (error == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: NoticeBanner(
                                  message: error,
                                  icon: Icons.error_outline_rounded,
                                  tint: AppColors.error,
                                ),
                              );
                            }),

                            BentoCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PatientIdentityBand(
                                    name: admission.patient.fullName,
                                    mrn: admission.patient.mrn,
                                    age: Formatters.age(
                                      admission.patient.dateOfBirth,
                                    ),
                                    sex: admission.patient.gender,
                                  ),
                                  const SizedBox(height: 14),
                                  const Hairline(),
                                  const SizedBox(height: 6),
                                  // Two facts rather than one joined string: a
                                  // FactRow gives its value about half the
                                  // width, and "Acute Medical · bed 01"
                                  // truncates to "Acute Medical · be…".
                                  if (admission.bed.ward?.name.isNotEmpty ??
                                      false)
                                    FactRow(
                                      label: 'Ward',
                                      value: admission.bed.ward!.name,
                                    ),
                                  FactRow(
                                    label: 'Bed',
                                    value: admission.bed.bedNumber,
                                  ),
                                  FactRow(
                                    label: 'Admitted',
                                    value: Formatters.dateMedium(
                                      admission.admissionDate,
                                    ),
                                  ),
                                  FactRow(
                                    label: 'Length of stay',
                                    value: () {
                                      final days =
                                          Formatters.lengthOfStayDays(
                                        admission.admissionDate,
                                      );
                                      return days == 0
                                          ? 'Same day'
                                          : days == 1
                                              ? '1 day'
                                              : '$days days';
                                    }(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: BentoSpace.section),

                            FormCard(
                              title: 'Discharge',
                              children: [
                                Obx(
                                  () => BentoPicker(
                                    key: DischargePatientKeys.outcomePicker,
                                    label: 'Outcome',
                                    required: true,
                                    value: controller.outcome.value,
                                    onTap: () => _openOutcomePicker(controller),
                                  ),
                                ),
                                BentoInput(
                                  label: 'Reason',
                                  controller: controller.reasonController,
                                  validator: controller.validateReason,
                                  required: true,
                                  maxLines: 2,
                                  hint: 'In a line, for the record',
                                ),
                                BentoInput(
                                  fieldKey: DischargePatientKeys.summaryField,
                                  label: 'Discharge summary',
                                  controller: controller.summaryController,
                                  maxLines: 5,
                                  hint: 'What happened during the stay, and '
                                      'what happens next. Leave blank to use '
                                      'the reason above.',
                                ),
                                Obx(
                                  () => BentoPicker(
                                    label: 'Discharging clinician',
                                    value: controller
                                        .dischargingDoctor.value?.fullName,
                                    placeholder: 'Who signed this off',
                                    onTap: () => _openDoctorPicker(controller),
                                  ),
                                ),
                              ],
                            ),

                            // Follow-up, only where it applies. Asking for a
                            // follow-up appointment after a death is the kind
                            // of thing software does that people do not.
                            Obx(() {
                              if (!controller.wantsFollowUp) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: BentoSpace.section,
                                ),
                                child: FormCard(
                                  title: 'Follow-up',
                                  children: [
                                    Obx(
                                      () => BentoPicker(
                                        key: DischargePatientKeys.dateField,
                                        label: 'Date',
                                        value: controller.followUpDate.value ==
                                                null
                                            ? null
                                            : Formatters.dateMedium(
                                                controller.followUpDate.value,
                                              ),
                                        placeholder: 'None booked',
                                        onTap: () => controller
                                            .pickFollowUpDate(context),
                                      ),
                                    ),
                                    BentoInput(
                                      fieldKey:
                                          DischargePatientKeys.followUpField,
                                      label: 'Notes',
                                      controller:
                                          controller.followUpNotesController,
                                      maxLines: 3,
                                      hint: 'What the follow-up is for',
                                    ),
                                  ],
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
                      child: Obx(
                        () => PrimaryBar(
                          key: DischargePatientKeys.submit,
                          label: 'Discharge patient',
                          busy: controller.isSubmitting.value,
                          onPressed: () async {
                            if (!(controller.formKey.currentState
                                    ?.validate() ??
                                false)) {
                              return;
                            }
                            final confirmed = await ConfirmDialog.show(
                              context,
                              confirmKey: DischargePatientKeys.confirm,
                              title:
                                  'Discharge ${admission.patient.fullName}?',
                              message:
                                  'Bed ${admission.bed.bedNumber} is freed and '
                                  'the admission is closed. This cannot be '
                                  'undone from the app.',
                              confirmLabel: 'Discharge',
                              cancelLabel: 'Not yet',
                              destructive: true,
                            );
                            if (confirmed) await controller.submit();
                          },
                        ),
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

Future<void> _openOutcomePicker(DischargePatientController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Outcome',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final outcome in DischargePatientController.outcomes)
            SheetRow(
              icon: switch (outcome) {
                'Recovered' => Icons.check_circle_outline_rounded,
                'Improved' => Icons.trending_up_rounded,
                'Referred on' => Icons.call_made_rounded,
                'Transferred' => Icons.swap_horiz_rounded,
                'Self-discharge' => Icons.directions_walk_rounded,
                _ => Icons.remove_circle_outline_rounded,
              },
              label: outcome,
              selected: controller.outcome.value == outcome,
              onTap: () {
                controller.outcome.value = outcome;
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openDoctorPicker(DischargePatientController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Discharging clinician',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final doctor in controller.doctors)
            SheetRow(
              icon: Icons.badge_outlined,
              label: doctor.fullName,
              sublabel: doctor.specialization,
              selected: controller.dischargingDoctor.value?.id == doctor.id,
              onTap: () {
                controller.dischargingDoctor.value = doctor;
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
