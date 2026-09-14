import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/billing_invoice_form_keys.dart';
import '../../../core/window_class.dart';
import '../../../data/models/billing_service.dart';
import '../../../data/models/patient_ref.dart';
import '../../../data/services/settings_service.dart';
import '../../../theme/theme.dart';
import '../controllers/invoice_form_controller.dart';

/// Raising a bill.
///
/// The totals pane is the point of the screen, and on a window wide enough it
/// stays beside the lines rather than under them: the number somebody is
/// working toward should not be scrolled off while they work toward it.
/// [SupportingPaneScaffold] does exactly that — beside on a tablet, beneath on
/// a phone.
class InvoiceFormView extends GetView<InvoiceFormController> {
  const InvoiceFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read the controller at the root of the build: a `GetView` whose build
    // never touches it never constructs its `lazyPut` controller, and the
    // catalogue never loads.
    final form = controller;

    return Scaffold(
      key: InvoiceFormKeys.screen,
      appBar: const DetailHeader(title: 'New invoice'),
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
                      maxWidth: 900,
                      child: SupportingPaneScaffold(
                        supportingWidth: 320,
                        primary: Column(
                          key: InvoiceFormKeys.form,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _error(form),
                            _who(form),
                            const SizedBox(height: BentoSpace.section),
                            _lines(context, form),
                            const SizedBox(height: BentoSpace.section),
                            _terms(form),
                          ],
                        ),
                        supporting: Padding(
                          // Room above only where the pane has stacked under
                          // the form; beside it the two tops already line up.
                          padding: EdgeInsets.only(
                            top: WindowClass.of(context).isTwoPane
                                ? 0
                                : BentoSpace.section,
                          ),
                          child: _TotalsPane(controller: form),
                        ),
                      ),
                    ),
                  ),
                ),
                _saveBar(form),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _error(InvoiceFormController form) => Obx(() {
        final error = form.errorMessage.value;
        if (error == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: NoticeBanner(
            message: error,
            icon: Icons.error_outline_rounded,
            tint: AppColors.error,
          ),
        );
      });

  Widget _who(InvoiceFormController form) => FormCard(
        title: 'Who it is for',
        children: [
          Obx(
            () => AsyncPicker<PatientRef>(
              fieldKey: InvoiceFormKeys.patientPicker,
              label: 'Patient',
              required: true,
              valueLabel: form.patient.value?.displayName,
              error: form.showErrors.value &&
                      (form.patient.value?.id ?? '').isEmpty
                  ? 'Choose the patient this bill is for'
                  : null,
              onSearch: form.searchPatients,
              onSelected: form.choosePatient,
            ),
          ),
        ],
      );

  Widget _lines(BuildContext context, InvoiceFormController form) => Obx(() {
        final lines = form.lines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormCard(
              title: 'What is being charged',
              children: [
                AsyncPicker<BillingService>(
                  fieldKey: InvoiceFormKeys.addFromCatalogue,
                  label: 'Add from the catalogue',
                  valueLabel: null,
                  placeholder: 'Search services',
                  searchHint: 'Search services',
                  options: form.catalogueOptions(),
                  emptyMessage: 'No services in the catalogue',
                  onSelected: form.addFromCatalogue,
                ),
                const SizedBox(height: BentoSpace.action),
                SecondaryBar(
                  key: InvoiceFormKeys.addCustomLine,
                  label: 'Add a custom line',
                  icon: Icons.add_rounded,
                  onPressed: form.addCustomLine,
                ),
              ],
            ),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: BentoSpace.section),
                child: EmptyState(
                  key: InvoiceFormKeys.linesEmpty,
                  icon: Icons.receipt_long_outlined,
                  title: 'Nothing on this invoice yet',
                  message: 'An invoice needs at least one line. Add a service '
                      'above, or a custom line for something the catalogue '
                      'does not carry.',
                  compact: true,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: BentoSpace.section),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i > 0) const SizedBox(height: BentoSpace.action),
                      _LineCard(
                        key: InvoiceFormKeys.line(i),
                        index: i,
                        controller: form,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      });

  Widget _terms(InvoiceFormController form) => FormCard(
        title: 'Terms',
        children: [
          Obx(
            () => BentoSegmented<DiscountMode>(
              key: InvoiceFormKeys.discountMode,
              options: DiscountMode.values,
              selected: form.discountMode.value,
              onSelected: form.setDiscountMode,
              labelOf: (mode) => mode == DiscountMode.amount
                  ? 'Discount amount'
                  : 'Discount %',
              keyOf: (mode) =>
                  InvoiceFormKeys.discountModeOption(mode.name),
            ),
          ),
          const SizedBox(height: BentoSpace.action),
          Obx(
            () => form.discountMode.value == DiscountMode.amount
                ? MoneyInput(
                    fieldKey: InvoiceFormKeys.discountAmount,
                    label: 'Discount off the whole invoice',
                    controller: form.discountController,
                    symbol: form.money.symbol,
                    decimalSeparator: form.money.decimalSeparator,
                    hint: 'Comes off the subtotal, before tax is added',
                    onChanged: form.onDiscountChanged,
                  )
                : BentoInput(
                    fieldKey: InvoiceFormKeys.discountPercentage,
                    label: 'Discount off the whole invoice',
                    controller: form.discountController,
                    placeholder: '0',
                    hint: 'A share of the subtotal. 100% at most.',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    suffix: const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Text('%'),
                    ),
                    onChanged: form.onDiscountChanged,
                  ),
          ),
          // One validator for both shapes: which ceiling applies is the
          // controller's business, not the field's.
          Obx(() {
            final message = form.validateDiscount(form.discountController.text);
            if (message == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: NoticeBanner(
                message: message,
                icon: Icons.percent_rounded,
                // Amber. A discount typed too large is a typo, not a fault.
                tint: AppColors.warning,
              ),
            );
          }),
          const SizedBox(height: BentoSpace.action),
          Obx(
            () => DateField(
              fieldKey: InvoiceFormKeys.dueDate,
              label: 'Due',
              value: form.dueDate.value,
              format: SettingsService.to.date,
              hint: 'Leave it empty and the bill never falls overdue',
              onChanged: form.setDueDate,
            ),
          ),
          BentoInput(
            fieldKey: InvoiceFormKeys.notes,
            label: 'Notes',
            controller: form.notesController,
            maxLines: 3,
            hint: 'Anything the patient should read on the bill',
          ),
        ],
      );

  Widget _saveBar(InvoiceFormController form) => Padding(
        padding: const EdgeInsets.fromLTRB(
          BentoSpace.page,
          0,
          BentoSpace.page,
          BentoSpace.page,
        ),
        child: MaxWidthBody(
          maxWidth: 900,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final missing = form.missingCount;
                if (missing == 0) return const SizedBox.shrink();
                return Padding(
                  key: InvoiceFormKeys.errors,
                  padding: const EdgeInsets.only(bottom: BentoSpace.action),
                  child: FieldErrorSummary(count: missing),
                );
              }),
              Obx(
                () => PrimaryBar(
                  key: InvoiceFormKeys.save,
                  label: 'Raise invoice',
                  icon: Icons.receipt_long_outlined,
                  busy: form.isSubmitting.value,
                  onPressed: form.submit,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── One line ────────────────────────────────────────────────────────────────

/// One charge: what it is, how many, at what price, less what, plus what tax.
///
/// The line's own total is shown on the card because it is the number somebody
/// checks against a quote. It comes from `InvoiceMath` like every other figure
/// on this screen — never recomputed here.
class _LineCard extends StatelessWidget {
  const _LineCard({super.key, required this.index, required this.controller});

  final int index;
  final InvoiceFormController controller;

  @override
  Widget build(BuildContext context) {
    final fields = controller.fieldsFor(index);
    final line = controller.lines[index];
    final totals = controller.lineTotals(index);
    final money = controller.money;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.serviceId == null ? 'Custom line' : 'Catalogue service',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.overline(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
              CircleIconButton(
                key: InvoiceFormKeys.lineRemove(index),
                icon: Icons.close_rounded,
                tooltip: 'Remove this line',
                size: 40,
                iconSize: 18,
                onTap: () => controller.removeLine(index),
              ),
            ],
          ),
          BentoInput(
            fieldKey: InvoiceFormKeys.lineDescription(index),
            label: 'What it is',
            controller: fields.description,
            required: true,
            validator: controller.validateDescription,
            enabled: line.serviceId == null,
            hint: line.serviceId == null
                ? null
                : 'Comes from the catalogue entry',
            onChanged: (value) =>
                controller.setLineDescription(index, value),
          ),
          TwoColumn(
            children: [
              QuantityField(
                fieldKey: InvoiceFormKeys.lineQuantity(index),
                label: 'Quantity',
                controller: fields.quantity,
                required: true,
                min: 1,
                error: controller.showErrors.value
                    ? controller.validateQuantity(fields.quantity.text)
                    : null,
                onChanged: (value) => controller.setLineQuantity(index, value),
              ),
              MoneyInput(
                fieldKey: InvoiceFormKeys.lineUnitPrice(index),
                label: 'Unit price',
                controller: fields.unitPrice,
                symbol: money.symbol,
                decimalSeparator: money.decimalSeparator,
                required: true,
                error: controller.showErrors.value
                    ? controller.validateUnitPrice(fields.unitPrice.text)
                    : null,
                onChanged: (value) => controller.setLineUnitPrice(index, value),
              ),
            ],
          ),
          const SizedBox(height: BentoSpace.action),
          TwoColumn(
            children: [
              MoneyInput(
                fieldKey: InvoiceFormKeys.lineDiscount(index),
                label: 'Discount',
                controller: fields.discount,
                symbol: money.symbol,
                decimalSeparator: money.decimalSeparator,
                hint: 'Comes off before tax',
                onChanged: (value) => controller.setLineDiscount(index, value),
              ),
              BentoInput(
                fieldKey: InvoiceFormKeys.lineTax(index),
                label: 'Tax',
                controller: fields.tax,
                placeholder: '0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Text('%'),
                ),
                onChanged: (value) => controller.setLineTax(index, value),
              ),
            ],
          ),
          const SizedBox(height: BentoSpace.action),
          const Hairline(),
          FactRow(
            key: InvoiceFormKeys.lineTotal(index),
            label: totals.tax > 0
                ? 'Line total, plus ${money(totals.tax)} tax'
                : 'Line total',
            // The **net** — what the server sums into the subtotal before it
            // adds the taxes. Showing the gross here would make this figure
            // and the subtotal below it disagree by the tax.
            value: money(totals.net),
            inset: false,
          ),
        ],
      ),
    );
  }
}

// ── Totals ──────────────────────────────────────────────────────────────────

/// Subtotal, discount, tax, total — in the server's own order.
///
/// Beside the lines on a tablet and beneath them on a phone, and in both cases
/// the same widget reading the same `InvoiceMath.totals` call the POST is built
/// from.
class _TotalsPane extends StatelessWidget {
  const _TotalsPane({required this.controller});

  final InvoiceFormController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Touch the lines so this rebuilds when one changes. The totals are
      // derived from them, and `Obx` tracks what is *read*.
      controller.lines.length;
      final totals = controller.totals;
      final money = controller.money;

      return BentoCard(
        key: InvoiceFormKeys.totals,
        hero: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Totals', inset: true),
            FactRow(
              key: InvoiceFormKeys.subtotal,
              label: 'Subtotal',
              value: money(totals.subtotal),
              inset: false,
            ),
            FactRow(
              key: InvoiceFormKeys.discountTotal,
              label: 'Discount',
              value: totals.discount > 0
                  ? '−${money(totals.discount)}'
                  : money(0),
              inset: false,
            ),
            FactRow(
              key: InvoiceFormKeys.taxTotal,
              label: 'Tax',
              value: money(totals.tax),
              inset: false,
            ),
            const Hairline(),
            const SizedBox(height: BentoSpace.action),
            MoneyFigure(
              key: InvoiceFormKeys.total,
              label: 'Total',
              amount: money(totals.total),
              // Ledger blue. Billing's colour, and never an acuity.
              color: semanticInk(context, AppColors.accent),
              size: 30,
            ),
            const SizedBox(height: 6),
            Text(
              'Discount comes off the subtotal; tax is added after it.',
              style: Theme.of(context).brightness == Brightness.dark
                  ? AppTextStyles.darkFootnote()
                  : AppTextStyles.lightFootnote(),
            ),
          ],
        ),
      );
    });
  }
}
