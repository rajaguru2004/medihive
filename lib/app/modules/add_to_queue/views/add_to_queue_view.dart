import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/add_to_queue_controller.dart';

/// Add somebody to the queue.
///
/// Acuity is a segmented control rather than a picker, because it is the one
/// field on this form that changes where the patient lands in the order — and
/// a choice with a consequence should be visible without opening anything.
class AddToQueueView extends GetView<AddToQueueController> {
  const AddToQueueView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Add to queue'),
      body: BentoGround(
        child: SafeArea(
          child: Form(
            key: controller.formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(BentoSpace.page),
                    child: MaxWidthBody(
                      maxWidth: 520,
                      child: Column(
                        key: AddToQueueKeys.screen,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(() {
                            final error = controller.errorMessage.value;
                            if (error == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                key: AddToQueueKeys.error,
                                message: error,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),

                          FormCard(
                            title: 'Patient',
                            children: [
                              Obx(
                                () => BentoPicker(
                                  key: AddToQueueKeys.patientPicker,
                                  label: 'Patient',
                                  required: true,
                                  value: controller.patient.value?.fullName,
                                  placeholder: 'Search by name or MRN',
                                  onTap: () => _openPatientPicker(controller),
                                ),
                              ),
                              Obx(() {
                                final patient = controller.patient.value;
                                if (patient == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: InsetSurface(
                                    padding: const EdgeInsets.all(14),
                                    child: PatientIdentityBand(
                                      name: patient.fullName,
                                      mrn: patient.mrn,
                                      age: Formatters.age(patient.dateOfBirth),
                                      sex: patient.gender,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),

                          const SizedBox(height: BentoSpace.section),

                          // ── Acuity ──────────────────────────────────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(title: 'Triage'),
                              BentoCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Obx(
                                      () => Row(
                                        children: [
                                          for (var i = 0;
                                              i <
                                                  AddToQueueController
                                                      .acuityCodes.length;
                                              i++) ...[
                                            if (i > 0)
                                              const SizedBox(width: 6),
                                            Expanded(
                                              child: _AcuityButton(
                                                code: AddToQueueController
                                                    .acuityCodes[i],
                                                selected: controller
                                                        .acuity.value ==
                                                    AddToQueueController
                                                        .acuityCodes[i],
                                                onTap: () => controller.acuity
                                                        .value =
                                                    AddToQueueController
                                                        .acuityCodes[i],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Obx(
                                      () => Text(
                                        CaseStatus.labelOfCode(
                                          controller.acuity.value,
                                        ),
                                        style: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppTextStyles.darkSubheadline(
                                                weight: FontWeight.w600,
                                              )
                                            : AppTextStyles.lightSubheadline(
                                                weight: FontWeight.w600,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: BentoSpace.section),

                          FormCard(
                            title: 'Where',
                            children: [
                              Obx(
                                () => BentoPicker(
                                  key: AddToQueueKeys.departmentPicker,
                                  label: 'Service',
                                  required: true,
                                  value: controller.serviceArea.value,
                                  placeholder: 'Which desk are they waiting '
                                      'for?',
                                  onTap: () => _openServicePicker(controller),
                                ),
                              ),
                              BentoInput(
                                fieldKey: AddToQueueKeys.reasonField,
                                label: 'Reason',
                                controller: controller.serviceTypeController,
                                hint: 'Optional — what they are here for',
                              ),
                              BentoInput(
                                label: 'Room',
                                controller: controller.roomController,
                                hint: 'Optional — if a room is already '
                                    'assigned',
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => controller.submit(),
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
                        key: AddToQueueKeys.submit,
                        label: 'Add to queue',
                        busy: controller.isSubmitting.value,
                        onPressed: controller.submit,
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

/// One triage level, as a button carrying its own colour.
class _AcuityButton extends StatelessWidget {
  const _AcuityButton({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = CaseStatus.colorOfCode(code);
    final ink = semanticInk(context, tint);

    return Semantics(
      selected: selected,
      button: true,
      label: CaseStatus.labelOfCode(code),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BentoRadius.control),
        child: AnimatedContainer(
          duration: motionDuration(context),
          curve: Curves.easeOutCubic,
          height: AppTheme.minTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: selected ? 0.22 : 0.08),
            borderRadius: BorderRadius.circular(BentoRadius.control),
            border: Border.all(
              color: tint.withValues(alpha: selected ? 0.8 : 0.22),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            code,
            style: AppFonts.numeric(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: ink,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openPatientPicker(AddToQueueController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Patient',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            hint: 'Name or MRN',
            onChanged: controller.onSearchChanged,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Obx(() {
              final error = controller.errorMessage.value;
              final searching = controller.isSearching.value;
              final rows = controller.patients.take(40).toList();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The search's own failure, said inside the sheet rather
                  // than only on the form behind it. A search that never
                  // reached the server fell through to "No patient matches
                  // that", which is the one wrong answer this sheet can give:
                  // it sends somebody off to register a patient who is already
                  // on file, and the queue then holds two of them.
                  if (error != null)
                    ErrorRetryBanner(
                      message: error,
                      onRetry: () => controller.searchPatients(''),
                    ),
                  if (searching && rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: BentoSkeleton(rows: 3),
                    )
                  // Only once the search has actually come back. Under a
                  // failure banner this is a second answer contradicting the
                  // first.
                  else if (rows.isEmpty && error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: EmptyState(
                        compact: true,
                        icon: Icons.person_search_outlined,
                        title: 'No patient matches that',
                      ),
                    )
                  else if (rows.isNotEmpty)
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Hairline(),
                        itemBuilder: (context, i) => SheetRow(
                          icon: Icons.person_outline_rounded,
                          label: rows[i].fullName,
                          sublabel: [
                            if (rows[i].mrn.isNotEmpty) 'MRN ${rows[i].mrn}',
                            Formatters.age(rows[i].dateOfBirth),
                            if (rows[i].gender?.isNotEmpty ?? false)
                              rows[i].gender!,
                          ].where((s) => s != '—').join(' · '),
                          selected: controller.patient.value?.id == rows[i].id,
                          onTap: () {
                            controller.patient.value = rows[i];
                            Get.back<void>();
                          },
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openServicePicker(AddToQueueController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Service',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final area in AddToQueueController.serviceAreas.keys)
            SheetRow(
              icon: switch (area) {
                'Emergency' => Icons.emergency_outlined,
                'Laboratory' => Icons.science_outlined,
                'Pharmacy' => Icons.medication_outlined,
                'Radiology' => Icons.monitor_heart_outlined,
                'MCH' => Icons.pregnant_woman_outlined,
                'Psychiatric' => Icons.psychology_outlined,
                _ => Icons.meeting_room_outlined,
              },
              label: area,
              selected: controller.serviceArea.value == area,
              onTap: () {
                controller.serviceArea.value = area;
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
