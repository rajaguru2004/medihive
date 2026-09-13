import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/admit_patient_controller.dart';

/// Admit a patient.
///
/// The fields are in the order the decision is made — who, where, why, who is
/// responsible — and the bed picker stays shut until a ward is chosen, because
/// a bed list with no ward above it is a list somebody picks the wrong row
/// from.
class AdmitPatientView extends GetView<AdmitPatientController> {
  const AdmitPatientView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Admit patient'),
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
                          key: AdmitPatientKeys.screen,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // A load that failed and a save that bounced are
                            // not the same news. The first leaves every picker
                            // on this form empty, so it is the one that needs
                            // a way back; folded into the same notice it had
                            // none, and the screen could then neither be
                            // filled in nor asked for its data again.
                            Obx(() {
                              final loadError = controller.rxLoadError.value;
                              if (loadError == null) {
                                return const SizedBox.shrink();
                              }
                              return ErrorRetryBanner(
                                key: AdmitPatientKeys.loadError,
                                message: loadError,
                                onRetry: controller.load,
                              );
                            }),
                            Obx(() {
                              final submitError = controller.errorMessage.value;
                              if (submitError == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: NoticeBanner(
                                  key: AdmitPatientKeys.error,
                                  message: submitError,
                                  icon: Icons.error_outline_rounded,
                                  tint: AppColors.error,
                                ),
                              );
                            }),

                            // ── Who ─────────────────────────────────────
                            FormCard(
                              title: 'Patient',
                              children: [
                                Obx(
                                  () => BentoPicker(
                                    key: AdmitPatientKeys.patientPicker,
                                    label: 'Patient',
                                    required: true,
                                    value: controller.patient.value?.fullName,
                                    placeholder: 'Search by name or MRN',
                                    onTap: () =>
                                        _openPatientPicker(context, controller),
                                  ),
                                ),
                                Obx(() {
                                  final patient = controller.patient.value;
                                  if (patient == null) {
                                    return const SizedBox.shrink();
                                  }
                                  // Shown back, so the person filling the form
                                  // can check they picked the right record
                                  // before committing a bed to it.
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: InsetSurface(
                                      padding: const EdgeInsets.all(14),
                                      child: PatientIdentityBand(
                                        name: patient.fullName,
                                        mrn: patient.mrn,
                                        age: Formatters.age(
                                          patient.dateOfBirth,
                                        ),
                                        sex: patient.gender,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            // ── Where ───────────────────────────────────
                            FormCard(
                              title: 'Bed',
                              children: [
                                Obx(
                                  () => BentoPicker(
                                    key: AdmitPatientKeys.wardPicker,
                                    label: 'Ward',
                                    required: true,
                                    value: controller.ward.value?.name,
                                    placeholder: 'Choose a ward',
                                    onTap: () =>
                                        _openWardPicker(controller),
                                  ),
                                ),
                                Obx(
                                  () => BentoPicker(
                                    key: AdmitPatientKeys.bedPicker,
                                    label: 'Bed',
                                    required: true,
                                    value: controller.bed.value == null
                                        ? null
                                        : 'Bed ${controller.bed.value!.bedNumber}',
                                    placeholder: controller.ward.value == null
                                        ? 'Choose a ward first'
                                        : controller.isLoadingBeds.value
                                            ? 'Loading beds…'
                                            : controller.vacantBeds.isEmpty
                                                ? 'No free beds in this ward'
                                                : 'Choose a free bed',
                                    onTap: () {
                                      if (controller.ward.value == null) return;
                                      if (controller.isLoadingBeds.value) return;
                                      _openBedPicker(controller);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: BentoSpace.section),

                            // ── Why and who ─────────────────────────────
                            FormCard(
                              title: 'Admission',
                              children: [
                                Obx(
                                  () => BentoPicker(
                                    key: AdmitPatientKeys.acuityPicker,
                                    label: 'Type',
                                    value: controller.admissionType.value,
                                    onTap: () => _openTypePicker(controller),
                                  ),
                                ),
                                BentoInput(
                                  fieldKey: AdmitPatientKeys.reasonField,
                                  label: 'Reason',
                                  controller: controller.reasonController,
                                  validator: controller.validateReason,
                                  required: true,
                                  maxLines: 3,
                                  hint: 'The presenting problem, in a line',
                                ),
                                Obx(
                                  () => BentoPicker(
                                    key: AdmitPatientKeys.consultantPicker,
                                    label: 'Consultant',
                                    value: controller
                                        .attendingDoctor.value?.fullName,
                                    placeholder: 'Who is responsible',
                                    onTap: () => _openDoctorPicker(controller),
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
                      child: Obx(
                        () => PrimaryBar(
                          key: AdmitPatientKeys.submit,
                          label: 'Admit patient',
                          busy: controller.isSubmitting.value,
                          onPressed: controller.submit,
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

// ── Pickers ─────────────────────────────────────────────────────────────────

Future<void> _openPatientPicker(
  BuildContext context,
  AdmitPatientController controller,
) {
  final query = ''.obs;

  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Patient',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            hint: 'Name or MRN',
            onChanged: (value) => query.value = value,
          ),
          const SizedBox(height: 12),
          // Bounded, so a site with four thousand patients does not build four
          // thousand rows into a sheet.
          Flexible(
            child: Obx(() {
              final text = query.value.trim().toLowerCase();
              final rows = controller.patients
                  .where(
                    (p) => text.isEmpty ||
                        '${p.fullName} ${p.mrn}'.toLowerCase().contains(text),
                  )
                  .take(40)
                  .toList();

              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    compact: true,
                    icon: Icons.person_search_outlined,
                    title: 'No patient matches that',
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Hairline(),
                itemBuilder: (context, i) => SheetRow(
                  icon: Icons.person_outline_rounded,
                  label: rows[i].fullName,
                  sublabel: [
                    if (rows[i].mrn.isNotEmpty) 'MRN ${rows[i].mrn}',
                    Formatters.age(rows[i].dateOfBirth),
                    if (rows[i].gender?.isNotEmpty ?? false) rows[i].gender!,
                  ].where((s) => s != '—').join(' · '),
                  selected: controller.patient.value?.id == rows[i].id,
                  onTap: () {
                    controller.patient.value = rows[i];
                    Get.back<void>();
                  },
                ),
              );
            }),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openWardPicker(AdmitPatientController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Ward',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ward in controller.activeWards)
            SheetRow(
              icon: Icons.meeting_room_outlined,
              label: ward.name,
              sublabel: ward.availableBeds > 0
                  ? '${ward.availableBeds} free of ${ward.capacity}'
                  : 'Full',
              selected: controller.ward.value?.id == ward.id,
              onTap: () {
                Get.back<void>();
                controller.selectWard(ward);
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openBedPicker(AdmitPatientController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Bed',
      scrollable: true,
      child: Obx(
        () => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.vacantBeds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  compact: true,
                  icon: Icons.bed_outlined,
                  title: 'No free beds in this ward',
                  message: 'Try another ward, or free a bed by discharging '
                      'or transferring.',
                ),
              )
            else
              for (final bed in controller.vacantBeds)
                SheetRow(
                  icon: BedState.vacant.icon,
                  label: 'Bed ${bed.bedNumber}',
                  sublabel: bed.type.isEmpty ? null : bed.type,
                  selected: controller.bed.value?.id == bed.id,
                  onTap: () {
                    controller.bed.value = bed;
                    Get.back<void>();
                  },
                ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openTypePicker(AdmitPatientController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Admission type',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in AdmitPatientController.admissionTypes)
            SheetRow(
              icon: Icons.assignment_outlined,
              label: type,
              selected: controller.admissionType.value == type,
              onTap: () {
                controller.admissionType.value = type;
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openDoctorPicker(AdmitPatientController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Consultant',
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
              selected: controller.attendingDoctor.value?.id == doctor.id,
              onTap: () {
                controller.attendingDoctor.value = doctor;
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
