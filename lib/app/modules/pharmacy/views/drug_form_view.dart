import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/pharmacy_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/drug_form_controller.dart';

/// A catalogue entry, new or edited.
///
/// Grouped the way somebody holding the box reads it: what the drug is, then
/// how much of it there is, then what it costs and where it lives. The supplier
/// columns the record carries are absent on purpose — neither write DTO
/// accepts them, so a field for one would collect a value the server rejects.
class DrugFormView extends GetView<DrugFormController> {
  const DrugFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: controller.isEdit ? 'Edit drug' : 'Add a drug',
      ),
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
                      maxWidth: 560,
                      child: Column(
                        key: PharmacyKeys.drugForm,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(() {
                            final error = controller.errorMessage.value;
                            if (error == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                message: error,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),
                          _identity(),
                          const SizedBox(height: BentoSpace.section),
                          _stock(),
                          const SizedBox(height: BentoSpace.section),
                          _money(context),
                          const SizedBox(height: BentoSpace.section),
                          _handling(),
                        ],
                      ),
                    ),
                  ),
                ),
                _saveBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── What it is ────────────────────────────────────────────────────────────

  Widget _identity() => FormCard(
        title: 'The drug',
        children: [
          BentoInput(
            fieldKey: PharmacyKeys.drugNameField,
            label: 'Name',
            controller: controller.nameController,
            validator: controller.validateName,
            required: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            hint: 'What the counter calls it',
          ),
          BentoInput(
            fieldKey: PharmacyKeys.drugGenericField,
            label: 'Generic name',
            controller: controller.genericController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            hint: 'Searched as well as the name, so a prescriber finds it '
                'either way',
          ),
          BentoInput(
            fieldKey: PharmacyKeys.drugBrandField,
            label: 'Brand',
            controller: controller.brandController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          BentoInput(
            fieldKey: PharmacyKeys.drugCodeField,
            label: 'Code',
            controller: controller.codeController,
            textInputAction: TextInputAction.next,
            hint: 'The site\'s own reference for it',
            inputFormatters: [
              // Upper-cased as typed: a code is an identifier, and "drg001"
              // beside "DRG001" is two drugs to anything that groups by it.
              TextInputFormatter.withFunction(
                (_, next) => next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
          ),
          Obx(
            () => AsyncPicker<String>(
              fieldKey: PharmacyKeys.drugCategoryPicker,
              label: 'Category',
              valueLabel: controller.category.value == null
                  ? null
                  : Formatters.label(controller.category.value),
              placeholder: 'Choose a category',
              options: [
                for (final category in controller.categoryOptions)
                  PickerOption<String>(
                    value: category,
                    label: Formatters.label(category),
                  ),
              ],
              onSelected: (value) => controller.category.value = value,
            ),
          ),
          Obx(
            () => AsyncPicker<String>(
              fieldKey: PharmacyKeys.drugFormPicker,
              label: 'Form',
              valueLabel: controller.dosageForm.value == null
                  ? null
                  : Formatters.label(controller.dosageForm.value),
              placeholder: 'Tablet, syrup, injection…',
              options: [
                for (final form in DrugFormController.dosageForms)
                  PickerOption<String>(
                    value: form,
                    label: Formatters.label(form),
                  ),
              ],
              onSelected: (value) => controller.dosageForm.value = value,
            ),
          ),
          BentoInput(
            fieldKey: PharmacyKeys.drugStrengthField,
            label: 'Strength',
            controller: controller.strengthController,
            textInputAction: TextInputAction.next,
            hint: '500mg, 10mg/ml',
          ),
        ],
      );

  // ── How much of it there is ───────────────────────────────────────────────

  Widget _stock() => FormCard(
        title: 'Stock',
        children: [
          BentoInput(
            fieldKey: PharmacyKeys.drugStockField,
            label: 'In stock',
            controller: controller.stockController,
            validator: controller.validateStock,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            hint: 'Zero is a value: a drug that has run out has to say so',
          ),
          BentoInput(
            fieldKey: PharmacyKeys.drugUnitField,
            label: 'Unit',
            controller: controller.unitController,
            textInputAction: TextInputAction.next,
            hint: 'What one of it is — tablet, ml, vial',
          ),
          BentoInput(
            fieldKey: PharmacyKeys.drugReorderField,
            label: 'Reorder level',
            controller: controller.reorderController,
            validator: controller.validateReorder,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            hint: 'The count the counter reorders at. Left at zero, nothing '
                'is ever flagged low.',
          ),
        ],
      );

  // ── What it costs ─────────────────────────────────────────────────────────

  Widget _money(BuildContext context) {
    final money = controller.money;
    return FormCard(
      title: 'Price',
      children: [
        MoneyInput(
          fieldKey: PharmacyKeys.drugCostField,
          label: 'Cost price',
          controller: controller.costController,
          // The site's own symbol and separators. A field that assumes a dot
          // for decimals reads 1.234,56 as one and a bit.
          symbol: money.symbol,
          decimalSeparator: money.decimalSeparator,
          hint: 'What the pharmacy pays for one',
        ),
        MoneyInput(
          fieldKey: PharmacyKeys.drugPriceField,
          label: 'Selling price',
          controller: controller.priceController,
          symbol: money.symbol,
          decimalSeparator: money.decimalSeparator,
          hint: 'What a dispense charges for one',
        ),
      ],
    );
  }

  // ── How it is handled ─────────────────────────────────────────────────────

  Widget _handling() => FormCard(
        title: 'Handling',
        children: [
          BentoInput(
            fieldKey: PharmacyKeys.drugLocationField,
            label: 'Storage location',
            controller: controller.locationController,
            textInputAction: TextInputAction.done,
            hint: 'Shelf A1, fridge 2',
            onSubmitted: (_) => controller.save(),
          ),
          Obx(
            () => BentoSwitchRow(
              switchKey: PharmacyKeys.drugPrescriptionSwitch,
              label: 'Prescription only',
              sublabel: 'Cannot be sold over the counter without a script',
              value: controller.requiresPrescription.value,
              onChanged: (value) =>
                  controller.requiresPrescription.value = value,
            ),
          ),
          if (controller.isEdit)
            Obx(
              () => BentoSwitchRow(
                switchKey: PharmacyKeys.drugActiveSwitch,
                label: 'Stocked',
                sublabel: 'Turn this off to retire the drug without losing '
                    'what it was dispensed against',
                value: controller.isActive.value,
                onChanged: (value) => controller.isActive.value = value,
              ),
            ),
        ],
      );

  Widget _saveBar() => Padding(
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
                FieldErrorSummary(count: controller.invalidCount.value),
                if (controller.invalidCount.value > 0)
                  const SizedBox(height: BentoSpace.action),
                PrimaryBar(
                  key: PharmacyKeys.drugSave,
                  label: controller.isEdit ? 'Save changes' : 'Add to the shelf',
                  busy: controller.submitting.value,
                  onPressed: controller.save,
                ),
              ],
            ),
          ),
        ),
      );
}
