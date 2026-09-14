import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/laboratory_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/lab_test_form_controller.dart';

/// One catalogue entry: what it is called, what it needs and what it costs.
class LabTestFormView extends GetView<LabTestFormController> {
  const LabTestFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`, or the lazyPut controller is never built
    // and an edit opens on an empty form.
    final form = controller;

    return Scaffold(
      key: LaboratoryKeys.testFormScreen,
      appBar: DetailHeader(
        title: form.isEdit ? 'Edit test' : 'Add a test',
        subtitle: 'Laboratory catalogue',
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
                          FormCard(
                            title: 'What it is',
                            children: [
                              BentoInput(
                                fieldKey: LaboratoryKeys.testName,
                                label: 'Test name',
                                controller: form.nameController,
                                validator: form.validateName,
                                required: true,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                              ),
                              BentoInput(
                                fieldKey: LaboratoryKeys.testCode,
                                label: 'Code',
                                controller: form.codeController,
                                hint: 'What the bench and the request form '
                                    'call it — CBC, U&E',
                                inputFormatters: [
                                  // Upper-cased as typed: a code is an
                                  // identifier, and "cbc" beside "CBC" is two
                                  // tests to anything that groups by it.
                                  TextInputFormatter.withFunction(
                                    (_, next) => next.copyWith(
                                      text: next.text.toUpperCase(),
                                    ),
                                  ),
                                ],
                              ),
                              Obx(
                                () => AsyncPicker<String>(
                                  fieldKey: LaboratoryKeys.testCategory,
                                  label: 'Category',
                                  valueLabel:
                                      Formatters.label(form.category.value),
                                  placeholder: 'Choose a category',
                                  options: _options(
                                    LabTestFormController.optionsFor(
                                      LabTestFormController.categories,
                                      form.category.value,
                                    ),
                                  ),
                                  onSelected: (value) =>
                                      form.category.value = value,
                                ),
                              ),
                              Obx(
                                () => AsyncPicker<String>(
                                  fieldKey: LaboratoryKeys.testType,
                                  label: 'Type',
                                  valueLabel: Formatters.label(form.type.value),
                                  placeholder: 'Quantitative or qualitative',
                                  options: _options(
                                    LabTestFormController.optionsFor(
                                      LabTestFormController.types,
                                      form.type.value,
                                    ),
                                  ),
                                  onSelected: (value) => form.type.value = value,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: BentoSpace.section),
                          FormCard(
                            title: 'What it needs, and what it answers with',
                            children: [
                              Obx(
                                () => AsyncPicker<String>(
                                  fieldKey: LaboratoryKeys.testSpecimen,
                                  label: 'Specimen',
                                  valueLabel:
                                      Formatters.label(form.specimen.value),
                                  placeholder: 'Blood, urine, swab',
                                  options: _options(
                                    LabTestFormController.optionsFor(
                                      LabTestFormController.specimens,
                                      form.specimen.value,
                                    ),
                                  ),
                                  onSelected: (value) =>
                                      form.specimen.value = value,
                                ),
                              ),
                              Obx(
                                () => AsyncPicker<String>(
                                  fieldKey: LaboratoryKeys.testResultType,
                                  label: 'Result type',
                                  valueLabel:
                                      Formatters.label(form.resultType.value),
                                  placeholder: 'How a result is entered',
                                  hint: 'Decides the shape of the field '
                                      'somebody types the result into',
                                  options: _options(
                                    LabTestFormController.optionsFor(
                                      LabTestFormController.resultTypes,
                                      form.resultType.value,
                                    ),
                                  ),
                                  onSelected: (value) =>
                                      form.resultType.value = value,
                                ),
                              ),
                              BentoInput(
                                fieldKey: LaboratoryKeys.testUnit,
                                label: 'Unit',
                                controller: form.unitController,
                                hint: 'g/dL, mmol/L — blank for a test that '
                                    'answers in words',
                              ),
                              BentoInput(
                                fieldKey: LaboratoryKeys.testRanges,
                                label: 'Reference ranges',
                                controller: form.rangesController,
                                validator: form.validateRanges,
                                maxLines: 3,
                                hint: 'JSON, as this site already stores it — '
                                    r'{"male": {"min": 13.5, "max": 17.5}}',
                              ),
                            ],
                          ),
                          const SizedBox(height: BentoSpace.section),
                          FormCard(
                            title: 'Ordering',
                            children: [
                              MoneyInput(
                                fieldKey: LaboratoryKeys.testPrice,
                                label: 'Price',
                                controller: form.priceController,
                                symbol: form.currencySymbol,
                              ),
                              BentoInput(
                                fieldKey: LaboratoryKeys.testTurnaround,
                                label: 'Turnaround',
                                controller: form.turnaroundController,
                                validator: form.validateTurnaround,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                hint: 'Hours, not minutes',
                              ),
                              BentoInput(
                                fieldKey: LaboratoryKeys.testPreparation,
                                label: 'Preparation',
                                controller: form.preparationController,
                                maxLines: 2,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                hint: 'What the patient has to do first — '
                                    'fasting, timing',
                              ),
                              Obx(
                                () => BentoSwitchRow(
                                  switchKey: LaboratoryKeys.testActive,
                                  label: 'Orderable',
                                  sublabel: 'Off takes it off the request '
                                      'form. Orders that already name it keep '
                                      'it.',
                                  value: form.isActive.value,
                                  onChanged: (value) =>
                                      form.isActive.value = value,
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
                    maxWidth: 560,
                    child: Obx(
                      () => PrimaryBar(
                        key: LaboratoryKeys.testSave,
                        label: form.isEdit ? 'Save changes' : 'Add test',
                        busy: form.isSubmitting.value,
                        onPressed: form.save,
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

  List<PickerOption<String>> _options(List<String> values) => [
        for (final value in values)
          PickerOption<String>(value: value, label: Formatters.label(value)),
      ];
}
