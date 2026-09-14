import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/laboratory_keys.dart';
import '../../../data/models/lab_test.dart';
import '../../../data/models/patient_ref.dart';
import '../../../theme/theme.dart';
import '../../laboratory/lab_status.dart';
import '../controllers/lab_order_form_controller.dart';

/// A new laboratory order.
class LabOrderFormView extends GetView<LabOrderFormController> {
  const LabOrderFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root: a `GetView` that never touches `controller` never
    // builds it, and the catalogue is never fetched.
    final form = controller;

    return Scaffold(
      key: LaboratoryKeys.orderFormScreen,
      appBar: const DetailHeader(
        title: 'New lab order',
        subtitle: 'What to run, and how fast',
      ),
      body: BentoGround(
        child: SafeArea(
          child: Form(
            key: form.formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(BentoSpace.page),
                    child: MaxWidthBody(
                      maxWidth: 560,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(() {
                            final message = form.errorMessage.value;
                            if (message == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: BentoSpace.action,
                              ),
                              child: NoticeBanner(
                                message: message,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),
                          Obx(
                            () => FormCard(
                              title: 'Patient',
                              children: [
                                AsyncPicker<PatientRef>(
                                  fieldKey: LaboratoryKeys.orderPatient,
                                  label: 'Patient',
                                  required: true,
                                  valueLabel: form.patient.value?.displayName,
                                  placeholder: 'Search by name or MRN',
                                  searchHint: 'Search patients',
                                  emptyMessage: 'Nobody matches that',
                                  onSearch: form.searchPatients,
                                  onSelected: form.choosePatient,
                                  error: form.showErrors.value &&
                                          (form.patient.value?.id ?? '').isEmpty
                                      ? 'Choose the patient this order is for'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: BentoSpace.section),
                          Obx(() => _tests(context, form)),
                          const SizedBox(height: BentoSpace.section),
                          Obx(
                            () => FormCard(
                              title: 'Priority',
                              children: [
                                const SizedBox(height: 10),
                                BentoSegmented<String>(
                                  options: LabPriority.all,
                                  selected: form.priority.value,
                                  labelOf: LabPriority.labelOf,
                                  keyOf: LaboratoryKeys.orderPriority,
                                  onSelected: form.setPriority,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                          const SizedBox(height: BentoSpace.section),
                          FormCard(
                            title: 'Clinical detail',
                            children: [
                              BentoInput(
                                fieldKey: LaboratoryKeys.orderIndication,
                                label: 'Clinical indication',
                                controller: form.indicationController,
                                validator: form.validateIndication,
                                required: true,
                                maxLines: 2,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                hint: 'Why the lab is being asked — the bench '
                                    'reads this to interpret the result',
                              ),
                              BentoInput(
                                fieldKey: LaboratoryKeys.orderDiagnosis,
                                label: 'Provisional diagnosis',
                                controller: form.diagnosisController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                              BentoInput(
                                fieldKey: LaboratoryKeys.orderNotes,
                                label: 'Notes for the laboratory',
                                controller: form.notesController,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
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
                    child: Obx(
                      () => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FieldErrorSummary(count: form.missingCount),
                          if (form.missingCount > 0)
                            const SizedBox(height: BentoSpace.action),
                          PrimaryBar(
                            key: LaboratoryKeys.orderSubmit,
                            label: 'Raise order',
                            icon: Icons.science_outlined,
                            busy: form.isSubmitting.value,
                            onPressed: form.submit,
                          ),
                        ],
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

  Widget _tests(BuildContext context, LabOrderFormController form) {
    return FormCard(
      title: 'Tests',
      children: [
        const SizedBox(height: 6),
        if (!form.hasTests)
          const EmptyState(
            compact: true,
            icon: Icons.checklist_rounded,
            title: 'No tests yet',
            message: 'Pick them from the catalogue.',
          )
        else
          for (final test in form.selected) ...[
            _testRow(context, form, test),
            const Hairline(),
          ],
        const SizedBox(height: 10),
        SecondaryBar(
          key: LaboratoryKeys.orderAddTests,
          label: form.hasTests ? 'Add more tests' : 'Add tests',
          icon: Icons.add_rounded,
          onPressed: () => openCataloguePicker(context, form),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _testRow(
    BuildContext context,
    LabOrderFormController form,
    LabTest test,
  ) {
    return Padding(
      key: LaboratoryKeys.orderTest(test.id),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      test.testName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).brightness == Brightness.dark
                          ? AppTextStyles.darkCallout()
                          : AppTextStyles.lightCallout(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        test.displayCode,
                        if ((test.specimenType ?? '').isNotEmpty)
                          test.specimenType!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.text(
                        fontSize: 12,
                        color: tertiaryLabelColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              CircleIconButton(
                key: LaboratoryKeys.orderRemoveTest(test.id),
                icon: Icons.close_rounded,
                tooltip: 'Remove ${test.testName}',
                iconSize: 17,
                onTap: () => form.removeTest(test.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BentoSegmented<String>(
            options: LabPriority.all,
            selected: form.urgencyOf(test.id),
            labelOf: LabPriority.labelOf,
            keyOf: (urgency) =>
                LaboratoryKeys.orderTestUrgency(test.id, urgency),
            onSelected: (urgency) => form.setUrgency(test.id, urgency),
          ),
        ],
      ),
    );
  }
}

/// The catalogue, grouped the way a paper request form groups it.
///
/// Multi-select and live: the sheet stays open while tests are ticked, because
/// an order is usually three or four of them and closing after each one turns
/// one job into four.
Future<void> openCataloguePicker(
  BuildContext context,
  LabOrderFormController form,
) {
  return Get.bottomSheet<void>(
    Obx(() {
      final groups = form.catalogueByCategory;
      final categories = groups.keys.toList()..sort();

      return SheetShell(
        title: 'Add tests',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (form.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(BentoSpace.page),
                        child: BentoSkeleton(rows: 4),
                      )
                    else if (categories.isEmpty)
                      const EmptyState(
                        compact: true,
                        icon: Icons.menu_book_outlined,
                        title: 'The catalogue is empty',
                        message: 'Nothing has been set up to order yet.',
                      )
                    else
                      for (final category in categories) ...[
                        SheetSection(
                          child: SectionHeader(
                            key: LaboratoryKeys.catalogPickCategory(category),
                            title: _categoryLabel(category),
                          ),
                        ),
                        for (final test in groups[category]!)
                          SheetRow(
                            key: LaboratoryKeys.catalogPick(test.id),
                            icon: form.isSelected(test.id)
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            label: test.testName,
                            sublabel: test.displayCode,
                            selected: form.isSelected(test.id),
                            onTap: () => form.toggleTest(test),
                          ),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SheetSection(
              bottom: 8,
              child: PrimaryBar(
                key: LaboratoryKeys.catalogPickDone,
                label: form.hasTests
                    ? 'Done — ${form.selected.length} selected'
                    : 'Done',
                onPressed: () => Get.back<void>(),
              ),
            ),
          ],
        ),
      );
    }),
    isScrollControlled: true,
  );
}

String _categoryLabel(String category) =>
    category.isEmpty ? 'Other' : category[0].toUpperCase() + category.substring(1);
