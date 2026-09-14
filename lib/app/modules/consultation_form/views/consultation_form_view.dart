import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/consultation_form_keys.dart';
import '../../../core/unsaved_changes.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/patient_ref.dart';
import '../../../theme/theme.dart';
import '../controllers/consultation_form_controller.dart';

/// Writing up a consultation.
///
/// Four tabs over one `Form`. The tabs are only ever hidden, never unbuilt, so
/// `validate()` covers the whole document however little of it is on screen —
/// and a save refused by a field three tabs away takes the reader to it rather
/// than appearing to do nothing.
class ConsultationFormView extends GetView<ConsultationFormController> {
  const ConsultationFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of build: a `GetView` whose build never touches
    // `controller` never constructs its `lazyPut` controller, and `onReady`
    // never runs.
    final isEditing = controller.isEditing;

    return UnsavedChangesGuard(
      isDirty: () => controller.isDirty,
      title: 'Leave this consultation unsaved?',
      message: 'The examination, the diagnosis and anything prescribed here '
          'will be lost. This cannot be undone.',
      discardKey: ConsultationFormKeys.discard,
      keepKey: ConsultationFormKeys.keepEditing,
      child: Scaffold(
        appBar: DetailHeader(
          title: isEditing ? 'Edit consultation' : 'New consultation',
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

              if (controller.hasNoAccess) {
                return const Padding(
                  padding: EdgeInsets.all(BentoSpace.page),
                  child: EmptyState(
                    key: ConsultationFormKeys.noAccess,
                    icon: Icons.lock_outline_rounded,
                    title: 'Not your record to write',
                    message: 'This account can read consultations but not '
                        'write them.',
                  ),
                );
              }

              return _Body(controller: controller, isEditing: isEditing);
            }),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.isEditing});

  final ConsultationFormController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BentoSpace.page,
              BentoSpace.page,
              BentoSpace.page,
              0,
            ),
            child: MaxWidthBody(
              maxWidth: 640,
              child: Obx(
                () => BentoSegmented<ConsultationTab>(
                  options: ConsultationTab.values,
                  selected: controller.tab.value,
                  labelOf: _tabLabel,
                  keyOf: (tab) => ConsultationFormKeys.tab(tab.name),
                  onSelected: controller.showTab,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BentoSpace.page),
              child: MaxWidthBody(
                maxWidth: 640,
                child: Column(
                  key: ConsultationFormKeys.screen,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.hasLoadError)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: BentoSpace.action),
                        child: ErrorRetryBanner(
                          message: controller.rxLoadError.value!,
                          onRetry: controller.load,
                        ),
                      ),
                    Obx(() {
                      final message = controller.errorMessage.value;
                      if (message == null) return const SizedBox.shrink();
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: BentoSpace.action),
                        child: NoticeBanner(
                          key: ConsultationFormKeys.error,
                          message: message,
                          icon: Icons.error_outline_rounded,
                          tint: AppColors.error,
                        ),
                      );
                    }),

                    // Every tab stays in the tree. `Offstage` skips layout and
                    // paint but keeps the elements — which is what registers
                    // each field with the `Form` whether or not its tab is
                    // showing. An `IndexedStack` would lay all four out at the
                    // height of the tallest; a lazy one would leave an unvisited
                    // tab's required fields out of `validate()` entirely.
                    Obx(() {
                      final tab = controller.tab.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Offstage(
                            offstage: tab != ConsultationTab.visit,
                            child: _VisitTab(
                              controller: controller,
                              isEditing: isEditing,
                            ),
                          ),
                          Offstage(
                            offstage: tab != ConsultationTab.vitals,
                            child: _VitalsTab(controller: controller),
                          ),
                          Offstage(
                            offstage: tab != ConsultationTab.notes,
                            child: _NotesTab(controller: controller),
                          ),
                          Offstage(
                            offstage: tab != ConsultationTab.plan,
                            child: _PlanTab(
                              controller: controller,
                              isEditing: isEditing,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          _SaveBar(controller: controller, isEditing: isEditing),
        ],
      ),
    );
  }

  static String _tabLabel(ConsultationTab tab) => switch (tab) {
        ConsultationTab.visit => 'Visit',
        ConsultationTab.vitals => 'Vitals',
        ConsultationTab.notes => 'Notes',
        ConsultationTab.plan => 'Plan',
      };
}

// ── Visit ───────────────────────────────────────────────────────────────────

class _VisitTab extends StatelessWidget {
  const _VisitTab({required this.controller, required this.isEditing});

  final ConsultationFormController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Visit',
      children: [
        Obx(() {
          final chosen = controller.patient.value;
          return AsyncPicker<PatientRef>(
            fieldKey: ConsultationFormKeys.patient,
            label: 'Patient',
            required: true,
            // A consultation cannot be re-pointed at another patient — the
            // update DTO has no `patientId` — so an edit states the fact
            // rather than offering a choice the server would refuse.
            enabled: !isEditing,
            valueLabel: chosen == null || chosen.isEmpty
                ? null
                : '${chosen.displayName} · MRN ${chosen.mrn}',
            error: controller.patientError,
            searchHint: 'Search by name or MRN',
            onSearch: (query) async {
              final rows = await controller.searchPatients(query);
              return [
                for (final row in rows)
                  PickerOption<PatientRef>(
                    value: row,
                    label: row.displayName,
                    sublabel: 'MRN ${row.mrn} · ${row.age}',
                  ),
              ];
            },
            onSelected: controller.choosePatient,
          );
        }),
        Obx(
          () => AsyncPicker<DoctorModel>(
            fieldKey: ConsultationFormKeys.doctor,
            label: 'Clinician',
            required: true,
            valueLabel: controller.doctor.value?.fullName,
            error: controller.doctorError,
            emptyMessage: 'No clinicians are listed for this site',
            options: [
              for (final doctor in controller.doctors)
                PickerOption<DoctorModel>(
                  value: doctor,
                  label: doctor.fullName,
                  sublabel: doctor.specialization,
                ),
            ],
            onSelected: controller.chooseDoctor,
          ),
        ),
        Obx(
          () => DateField(
            fieldKey: ConsultationFormKeys.visitDate,
            label: 'Visit date',
            required: true,
            value: controller.visitDate.value,
            format: controller.formatDate,
            onChanged: controller.chooseVisitDate,
          ),
        ),
        Obx(
          () => BentoField(
            label: 'Visit type',
            child: BentoSegmented<String>(
              options: ConsultationFormController.visitTypes.keys.toList(),
              selected: controller.visitType.value,
              labelOf: (value) =>
                  ConsultationFormController.visitTypes[value] ?? value,
              keyOf: ConsultationFormKeys.visitType,
              onSelected: controller.setVisitType,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Vitals ──────────────────────────────────────────────────────────────────

/// The observations, and the sentence about them.
///
/// `VitalInput` colours its **unit** when a reading is out of range — never its
/// border, because a red border in a form means "this entry is invalid" and
/// 39.8 °C is a perfectly valid entry describing a patient with a fever. The
/// banner above says the same thing in words, which is what survives a
/// colour-blind reader and a printed record.
class _VitalsTab extends StatelessWidget {
  const _VitalsTab({required this.controller});

  final ConsultationFormController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() {
          controller.vitalsRevision.value;
          final warning = controller.vitalsWarning;
          if (warning == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: BentoSpace.action),
            child: NoticeBanner(
              key: ConsultationFormKeys.vitalsFlag,
              message: warning,
              icon: Icons.monitor_heart_outlined,
              tint: controller.vitalsFlag!,
            ),
          );
        }),
        FormCard(
          title: 'Observations',
          children: [
            Obx(() {
              controller.vitalsRevision.value;
              return VitalInput(
                fieldKey: ConsultationFormKeys.temperature,
                label: 'Temperature',
                unit: '°C',
                decimal: true,
                controller: controller.temperatureController,
                onChanged: controller.onVitalChanged,
                hint: VitalRange.captions['temperature'],
                tone: VitalRange.temperature(controller.temperature),
              );
            }),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Obx(() {
                    controller.vitalsRevision.value;
                    return VitalInput(
                      fieldKey: ConsultationFormKeys.systolic,
                      label: 'BP systolic',
                      unit: 'mmHg',
                      controller: controller.systolicController,
                      onChanged: controller.onVitalChanged,
                      tone: VitalRange.bloodPressure(
                        controller.systolic,
                        controller.diastolic,
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() {
                    controller.vitalsRevision.value;
                    return VitalInput(
                      fieldKey: ConsultationFormKeys.diastolic,
                      label: 'BP diastolic',
                      unit: 'mmHg',
                      controller: controller.diastolicController,
                      onChanged: controller.onVitalChanged,
                    );
                  }),
                ),
              ],
            ),
            Obx(() {
              controller.vitalsRevision.value;
              return VitalInput(
                fieldKey: ConsultationFormKeys.pulse,
                label: 'Pulse',
                unit: 'bpm',
                controller: controller.pulseController,
                onChanged: controller.onVitalChanged,
                hint: VitalRange.captions['pulse'],
                tone: VitalRange.pulse(controller.pulse),
              );
            }),
            Obx(() {
              controller.vitalsRevision.value;
              return VitalInput(
                fieldKey: ConsultationFormKeys.respiratoryRate,
                label: 'Respiratory rate',
                unit: '/min',
                controller: controller.respiratoryController,
                onChanged: controller.onVitalChanged,
                hint: VitalRange.captions['respiratoryRate'],
                tone: VitalRange.respiratoryRate(controller.respiratoryRate),
              );
            }),
            Obx(() {
              controller.vitalsRevision.value;
              return VitalInput(
                fieldKey: ConsultationFormKeys.oxygenSaturation,
                label: 'Oxygen saturation',
                unit: '%',
                controller: controller.saturationController,
                onChanged: controller.onVitalChanged,
                hint: VitalRange.captions['oxygenSaturation'],
                tone: VitalRange.oxygenSaturation(controller.oxygenSaturation),
              );
            }),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: VitalInput(
                    fieldKey: ConsultationFormKeys.weight,
                    label: 'Weight',
                    unit: 'kg',
                    decimal: true,
                    controller: controller.weightController,
                    onChanged: controller.onVitalChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VitalInput(
                    fieldKey: ConsultationFormKeys.height,
                    label: 'Height',
                    unit: 'cm',
                    decimal: true,
                    controller: controller.heightController,
                    onChanged: controller.onVitalChanged,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ── Notes, diagnosis and plan ───────────────────────────────────────────────

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.controller});

  final ConsultationFormController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormCard(
          title: 'Notes',
          children: [
            BentoInput(
              fieldKey: ConsultationFormKeys.complaint,
              label: 'Chief complaint',
              controller: controller.complaintController,
              validator: controller.validateComplaint,
              required: true,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            BentoInput(
              fieldKey: ConsultationFormKeys.history,
              label: 'History of present illness',
              controller: controller.historyController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
            BentoInput(
              fieldKey: ConsultationFormKeys.examination,
              label: 'Physical examination',
              controller: controller.examinationController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        const SizedBox(height: BentoSpace.section),
        FormCard(
          title: 'Diagnosis and plan',
          children: [
            BentoInput(
              fieldKey: ConsultationFormKeys.diagnosis,
              label: 'Diagnosis',
              controller: controller.diagnosisController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            _IcdCodes(controller: controller),
            BentoInput(
              fieldKey: ConsultationFormKeys.treatmentPlan,
              label: 'Treatment plan',
              controller: controller.planController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ],
    );
  }
}

/// The coded diagnosis, as chips.
///
/// Chips rather than a comma-separated field because the column behind them is
/// a list: a reader has to be able to see where one code ends and the next
/// begins, and a typo in the middle of a string is a code nobody can look up.
class _IcdCodes extends StatelessWidget {
  const _IcdCodes({required this.controller});

  final ConsultationFormController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BentoInput(
          fieldKey: ConsultationFormKeys.icdInput,
          label: 'ICD-10 codes',
          hint: 'One at a time — J20.9, I10',
          controller: controller.icdController,
          placeholder: 'Add a code',
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.addIcdCode(),
          // Inside the field rather than beside it: `BentoInput` gives a suffix
          // a 48-point box and centres it on the control, which is the only
          // way a button next to a labelled field lines up with the field
          // rather than with the label above it.
          suffix: CircleIconButton(
            key: ConsultationFormKeys.icdAdd,
            icon: Icons.add_rounded,
            tooltip: 'Add this code',
            size: 44,
            onTap: controller.addIcdCode,
          ),
        ),
        Obx(() {
          if (controller.icdCodes.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in controller.icdCodes)
                  ActiveFilterChip(
                    chipKey: ConsultationFormKeys.icdChip(code),
                    label: code,
                    icon: Icons.local_offer_outlined,
                    onClear: () => controller.removeIcdCode(code),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Prescription, orders and follow-up ──────────────────────────────────────

class _PlanTab extends StatelessWidget {
  const _PlanTab({required this.controller, required this.isEditing});

  final ConsultationFormController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prescription(controller: controller, isEditing: isEditing),
        if (controller.canOrder) ...[
          const SizedBox(height: BentoSpace.section),
          _Orders(controller: controller),
        ],
        const SizedBox(height: BentoSpace.section),
        _FollowUp(controller: controller),
      ],
    );
  }
}

class _Prescription extends StatelessWidget {
  const _Prescription({required this.controller, required this.isEditing});

  final ConsultationFormController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return const FormCard(
        title: 'Prescription',
        children: [
          NoticeBanner(
            message: 'A script is written with the consultation, not after it. '
                'Add or change one in Pharmacy.',
            icon: Icons.medication_outlined,
          ),
        ],
      );
    }

    return Obx(() {
      final errors = controller.prescriptionErrors;

      return FormCard(
        title: 'Prescription',
        children: [
          for (var i = 0; i < controller.items.length; i++) ...[
            if (i > 0) const SizedBox(height: BentoSpace.action),
            _PrescriptionRow(
              controller: controller,
              index: i,
              error: errors[i],
            ),
          ],
          const SizedBox(height: BentoSpace.action),
          SecondaryBar(
            key: ConsultationFormKeys.prescriptionAdd,
            label: 'Add another drug',
            icon: Icons.add_rounded,
            onPressed: controller.addPrescriptionRow,
          ),
        ],
      );
    });
  }
}

class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow({
    required this.controller,
    required this.index,
    this.error,
  });

  final ConsultationFormController controller;
  final int index;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final row = controller.items[index];

    return InsetSurface(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The line's own heading, with the way off it. A remove control
          // beside a labelled picker lines up with the label rather than with
          // the control, and a numbered line is how a reader tells the third
          // drug from the first.
          Row(
            children: [
              Expanded(
                child: Text(
                  'DRUG ${index + 1}',
                  style: AppTextStyles.overline(Theme.of(context).brightness),
                ),
              ),
              CircleIconButton(
                key: ConsultationFormKeys.prescriptionRemove(index),
                icon: Icons.close_rounded,
                tooltip: 'Remove this drug',
                onTap: () => controller.removePrescriptionRow(index),
              ),
            ],
          ),
          Obx(
            () => AsyncPicker<Drug>(
              fieldKey: ConsultationFormKeys.prescriptionDrug(index),
              label: 'Drug',
              required: true,
              valueLabel: row.drug.value?.displayName,
              searchHint: 'Search the formulary',
              emptyMessage: 'No drug matches that',
              onSearch: (query) async {
                final drugs = await controller.searchDrugs(query);
                return [
                  for (final drug in drugs)
                    PickerOption<Drug>(
                      value: drug,
                      label: drug.displayName,
                      sublabel: drug.genericName,
                    ),
                ];
              },
              onSelected: (drug) => controller.chooseDrug(index, drug),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BentoInput(
                  fieldKey: ConsultationFormKeys.prescriptionDosage(index),
                  label: 'Dose',
                  controller: row.dosage,
                  required: true,
                  placeholder: '500 mg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoInput(
                  fieldKey: ConsultationFormKeys.prescriptionFrequency(index),
                  label: 'Frequency',
                  controller: row.frequency,
                  required: true,
                  placeholder: 'Three times daily',
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BentoInput(
                  fieldKey: ConsultationFormKeys.prescriptionDuration(index),
                  label: 'Duration',
                  controller: row.duration,
                  required: true,
                  placeholder: '7 days',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QuantityField(
                  fieldKey: ConsultationFormKeys.prescriptionQuantity(index),
                  label: 'Quantity',
                  controller: row.quantity,
                  required: true,
                  min: 1,
                ),
              ),
            ],
          ),
          BentoInput(
            fieldKey: ConsultationFormKeys.prescriptionInstructions(index),
            label: 'Instructions',
            controller: row.instructions,
            placeholder: 'After meals',
            textCapitalization: TextCapitalization.sentences,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: AppFonts.text(
                  fontSize: 12.5,
                  color: semanticInk(context, AppColors.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Orders ──────────────────────────────────────────────────────────────────

/// Tests and studies, chosen here and raised after the consultation is saved.
///
/// They are separate requests carrying the consultation's id, so they cannot be
/// sent until it has one. That is why a failure here never costs the write-up:
/// the record is already safe by the time these are attempted.
class _Orders extends StatelessWidget {
  const _Orders({required this.controller});

  final ConsultationFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Orders',
      children: [
        Column(
          key: ConsultationFormKeys.orders,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.canOrderLab) ...[
              Obx(
                () => _ChosenChips(
                  label: 'Laboratory',
                  empty: 'No tests requested',
                  chips: [
                    for (final test in controller.selectedTests)
                      (
                        key: ConsultationFormKeys.labTest(test.id),
                        label: test.testName,
                        onClear: () => controller.toggleTest(test),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: BentoSpace.action),
              SecondaryBar(
                key: ConsultationFormKeys.labAdd,
                label: 'Request tests',
                icon: Icons.biotech_outlined,
                onPressed: () => _openTests(context, controller),
              ),
            ],
            if (controller.canOrderLab && controller.canOrderImaging)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: BentoSpace.header),
                child: Hairline(),
              ),
            if (controller.canOrderImaging) ...[
              Obx(
                () => _ChosenChips(
                  label: 'Imaging',
                  empty: 'No studies requested',
                  chips: [
                    for (final exam in controller.selectedExams)
                      (
                        key: ConsultationFormKeys.imagingExam(exam.id),
                        label: exam.displayName,
                        onClear: () => controller.toggleExam(exam),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: BentoSpace.action),
              SecondaryBar(
                key: ConsultationFormKeys.imagingAdd,
                label: 'Request imaging',
                icon: Icons.monitor_heart_outlined,
                onPressed: () => _openExams(context, controller),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

typedef _Chip = ({Key key, String label, VoidCallback onClear});

class _ChosenChips extends StatelessWidget {
  const _ChosenChips({
    required this.label,
    required this.empty,
    required this.chips,
  });

  final String label;
  final String empty;
  final List<_Chip> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline(Theme.of(context).brightness),
        ),
        const SizedBox(height: 8),
        if (chips.isEmpty)
          Text(
            empty,
            style: Theme.of(context).brightness == Brightness.dark
                ? AppTextStyles.darkFootnote()
                : AppTextStyles.lightFootnote(),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                ActiveFilterChip(
                  chipKey: chip.key,
                  label: chip.label,
                  icon: Icons.check_rounded,
                  onClear: chip.onClear,
                ),
            ],
          ),
      ],
    );
  }
}

Future<void> _openTests(
  BuildContext context,
  ConsultationFormController controller,
) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Request tests',
      scrollable: true,
      child: Obx(
        () => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.labCatalogue.isEmpty)
              const SheetSection(
                child: NoticeBanner(
                  message: 'The test catalogue is empty or could not be read. '
                      'Raise the order from Laboratory instead.',
                  icon: Icons.biotech_outlined,
                  tint: AppColors.warning,
                ),
              )
            else
              for (final test in controller.labCatalogue)
                SheetRow(
                  icon: Icons.biotech_outlined,
                  label: test.testName,
                  sublabel: test.testCategory,
                  selected: controller.isTestSelected(test.id),
                  onTap: () => controller.toggleTest(test),
                ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openExams(
  BuildContext context,
  ConsultationFormController controller,
) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Request imaging',
      scrollable: true,
      child: Obx(
        () => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.imagingCatalogue.isEmpty)
              const SheetSection(
                child: NoticeBanner(
                  message: 'The imaging catalogue is empty or could not be '
                      'read. Raise the request from Imaging instead.',
                  icon: Icons.monitor_heart_outlined,
                  tint: AppColors.warning,
                ),
              )
            else
              for (final exam in controller.imagingCatalogue)
                SheetRow(
                  icon: Icons.monitor_heart_outlined,
                  label: exam.displayName,
                  sublabel: exam.modality,
                  selected: controller.isExamSelected(exam.id),
                  onTap: () => controller.toggleExam(exam),
                ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

// ── Follow-up ───────────────────────────────────────────────────────────────

class _FollowUp extends StatelessWidget {
  const _FollowUp({required this.controller});

  final ConsultationFormController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormCard(
          title: 'Follow-up',
          children: [
            Obx(
              () => DateField(
                fieldKey: ConsultationFormKeys.followUpDate,
                label: 'Come back on',
                value: controller.followUpDate.value,
                format: controller.formatDate,
                onChanged: controller.chooseFollowUpDate,
              ),
            ),
            BentoInput(
              fieldKey: ConsultationFormKeys.followUpInstructions,
              label: 'Follow-up instructions',
              controller: controller.followUpController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        const SizedBox(height: BentoSpace.section),
        FormCard(
          title: 'Referral',
          children: [
            BentoInput(
              fieldKey: ConsultationFormKeys.referredTo,
              label: 'Referred to',
              controller: controller.referredToController,
              placeholder: 'A specialty, or a named clinician',
              textCapitalization: TextCapitalization.sentences,
            ),
            BentoInput(
              fieldKey: ConsultationFormKeys.referralReason,
              label: 'Reason for referral',
              controller: controller.referralReasonController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            BentoInput(
              fieldKey: ConsultationFormKeys.notes,
              label: 'Other notes',
              controller: controller.notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ],
    );
  }
}

// ── The bar ─────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller, required this.isEditing});

  final ConsultationFormController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        0,
        BentoSpace.page,
        BentoSpace.page,
      ),
      child: MaxWidthBody(
        maxWidth: 640,
        child: Obx(() {
          if (!controller.canSave) {
            return const NoticeBanner(
              key: ConsultationFormKeys.noAccess,
              message: 'This account can read consultations but not write '
                  'them. Ask an administrator if that is wrong.',
              icon: Icons.lock_outline_rounded,
            );
          }

          final failures = controller.orderFailures;
          if (failures.isNotEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NoticeBanner(
                  key: ConsultationFormKeys.ordersFailed,
                  // Amber, not red. The consultation is written and the patient
                  // is fine; what failed is paperwork, and red here would cost
                  // the next real red its meaning.
                  tint: AppColors.warning,
                  icon: Icons.pending_actions_outlined,
                  message: 'The consultation is saved. '
                      '${failures.join(' ')}',
                ),
                const SizedBox(height: BentoSpace.action),
                SecondaryBar(
                  key: ConsultationFormKeys.ordersRetry,
                  label: 'Try those orders again',
                  icon: Icons.refresh_rounded,
                  onPressed: controller.retryOrders,
                ),
                const SizedBox(height: BentoSpace.action),
                PrimaryBar(
                  key: ConsultationFormKeys.save,
                  label: 'Done',
                  busy: controller.isSubmitting.value,
                  onPressed: controller.finish,
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldErrorSummary(count: controller.missingCount),
              if (controller.missingCount > 0)
                const SizedBox(height: BentoSpace.header),
              PrimaryBar(
                key: ConsultationFormKeys.save,
                label: isEditing ? 'Save changes' : 'Save consultation',
                busy: controller.isSubmitting.value,
                onPressed: controller.submit,
              ),
            ],
          );
        }),
      ),
    );
  }
}
