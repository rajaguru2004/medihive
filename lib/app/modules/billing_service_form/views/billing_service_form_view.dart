import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/billing_service_form_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/billing_service_form_controller.dart';

/// One catalogue entry: what it is called, what it costs, and the two things a
/// site needs to know about it — whether tax is charged, and whether insurance
/// covers it.
class BillingServiceFormView extends GetView<BillingServiceFormController> {
  const BillingServiceFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read the controller at the root of the build, or the `lazyPut` never
    // happens and the edit form opens empty.
    final form = controller;

    return Scaffold(
      key: BillingServiceFormKeys.screen,
      appBar: DetailHeader(title: form.isEdit ? 'Edit service' : 'Add service'),
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
                        key: BillingServiceFormKeys.form,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(() {
                            final error = form.errorMessage.value;
                            if (error == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                key: BillingServiceFormKeys.errors,
                                message: error,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),
                          _what(form),
                          const SizedBox(height: BentoSpace.section),
                          _price(form),
                          const SizedBox(height: BentoSpace.section),
                          _insurance(form),
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
                        key: BillingServiceFormKeys.save,
                        label: form.isEdit ? 'Save changes' : 'Add service',
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

  Widget _what(BillingServiceFormController form) => FormCard(
    title: 'What it is',
    children: [
      BentoInput(
        fieldKey: BillingServiceFormKeys.name,
        label: 'Service name',
        controller: form.nameController,
        required: true,
        validator: form.validateName,
        textInputAction: TextInputAction.next,
        hint: 'What appears on the patient’s bill',
      ),
      BentoInput(
        fieldKey: BillingServiceFormKeys.code,
        label: 'Code',
        controller: form.codeController,
        textInputAction: TextInputAction.next,
        hint: 'The site’s own reference for it',
        inputFormatters: [
          // Upper-cased as typed: a code is an identifier, and "srv-001"
          // beside "SRV-001" is two services to anything that groups by it.
          TextInputFormatter.withFunction(
            (_, next) => next.copyWith(text: next.text.toUpperCase()),
          ),
        ],
      ),
      Obx(
        () => AsyncPicker<String>(
          fieldKey: BillingServiceFormKeys.category,
          label: 'Category',
          valueLabel: form.category.value == null
              ? null
              : Formatters.label(form.category.value),
          placeholder: 'Choose a category',
          hint: 'How the price list groups it',
          options: [
            for (final category in BillingServiceFormController.categories)
              PickerOption<String>(
                value: category,
                label: Formatters.label(category),
              ),
          ],
          onSelected: form.setCategory,
        ),
      ),
      BentoInput(
        fieldKey: BillingServiceFormKeys.department,
        label: 'Department',
        controller: form.departmentController,
        textInputAction: TextInputAction.next,
        hint: 'Who performs it',
      ),
    ],
  );

  Widget _price(BillingServiceFormController form) => FormCard(
    title: 'What it costs',
    children: [
      MoneyInput(
        fieldKey: BillingServiceFormKeys.unitPrice,
        label: 'Unit price',
        controller: form.priceController,
        symbol: form.money.symbol,
        decimalSeparator: form.money.decimalSeparator,
        required: true,
        hint: 'Before tax and before any discount',
      ),
      Obx(
        () => BentoSwitchRow(
          switchKey: BillingServiceFormKeys.taxable,
          label: 'Tax is charged on this',
          sublabel: 'Added on top of the line, after any discount',
          value: form.isTaxable.value,
          onChanged: form.setTaxable,
        ),
      ),
      Obx(
        () => !form.isTaxable.value
            ? const SizedBox.shrink()
            : BentoInput(
                fieldKey: BillingServiceFormKeys.taxPercentage,
                label: 'Tax rate',
                controller: form.taxController,
                required: true,
                validator: form.validateTax,
                placeholder: '0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Text('%'),
                ),
              ),
      ),
    ],
  );

  Widget _insurance(BillingServiceFormController form) => FormCard(
    title: 'Insurance',
    children: [
      Obx(
        () => BentoSwitchRow(
          switchKey: BillingServiceFormKeys.insured,
          label: 'Covered by insurance',
          // The column defaults to true, and a service that silently reads
          // as uncovered quotes a patient the full price.
          sublabel: 'Off means the patient pays the whole price',
          value: form.isCoveredByInsurance.value,
          onChanged: form.setCovered,
        ),
      ),
      Obx(
        () => !form.isCoveredByInsurance.value
            ? const SizedBox.shrink()
            : BentoInput(
                fieldKey: BillingServiceFormKeys.copayPercentage,
                label: 'Patient copay',
                controller: form.copayController,
                validator: form.validateCopay,
                placeholder: '0',
                hint:
                    'The share the patient pays. Leave it empty if there '
                    'is none.',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Text('%'),
                ),
              ),
      ),
      // Outside the `Obx`, not inside it. Whether this is an edit is fixed
      // for the screen's lifetime, and an `Obx` whose builder returns
      // before reading an observable **throws** rather than rendering
      // nothing — so on a new service the early return took the whole form
      // down with it.
      if (form.isEdit)
        Obx(
          () => BentoSwitchRow(
            switchKey: BillingServiceFormKeys.active,
            label: 'Active',
            // Retired rather than deleted: the service is still on
            // every invoice that used it, and deleting it would make
            // those documents reference something nobody can find.
            sublabel:
                'Off takes it out of the catalogue. Invoices '
                'that already use it keep it.',
            value: form.isActive.value,
            onChanged: form.setActive,
          ),
        ),
    ],
  );
}
