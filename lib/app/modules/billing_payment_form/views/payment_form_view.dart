import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/billing_payment_form_keys.dart';
import '../../../data/services/settings_service.dart';
import '../../../theme/theme.dart';
import '../../billing/billing_status.dart';
import '../controllers/payment_form_controller.dart';

/// Recording a payment against one bill.
///
/// The fields below the method change with it: mobile money needs a network,
/// a transfer needs a bank and a reference, a cheque needs a number and the
/// date on its face. They are **absent** rather than greyed out — a field that
/// does not apply is not a field somebody should be reading past.
class PaymentFormView extends GetView<PaymentFormController> {
  const PaymentFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read the controller at the root: a `GetView` whose build never touches it
    // never builds it, and the invoice never loads.
    final form = controller;

    return Scaffold(
      key: PaymentFormKeys.screen,
      appBar: const DetailHeader(title: 'Record payment'),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (form.isLoading && form.rxFirstLoad.value) {
              return const BentoScreen(
                bottomClearance: false,
                ground: false,
                slivers: [
                  BentoSection(
                    top: BentoSpace.page,
                    child: BentoSkeleton(rows: 4),
                  ),
                ],
              );
            }

            return Form(
              key: form.formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(BentoSpace.page),
                      child: MaxWidthBody(
                        maxWidth: 560,
                        child: Column(
                          key: PaymentFormKeys.form,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (form.hasLoadError)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: ErrorRetryBanner(
                                  message: form.rxLoadError.value!,
                                  onRetry: form.load,
                                ),
                              ),
                            _error(form),
                            _balance(context, form),
                            const SizedBox(height: BentoSpace.section),
                            _amount(form),
                            const SizedBox(height: BentoSpace.section),
                            _method(form),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _saveBar(form),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _error(PaymentFormController form) => Obx(() {
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

  /// What is owed, above the field whose ceiling it is.
  ///
  /// On screen rather than only in the validator: a rule a person finds out
  /// about by breaking it is a rule that wastes their time twice.
  Widget _balance(BuildContext context, PaymentFormController form) => Obx(() {
        final invoice = form.invoice.value;
        final money = form.money;

        return BentoCard(
          key: PaymentFormKeys.outstanding,
          hero: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyFigure(
                label: 'Outstanding on ${invoice.invoiceNumber}',
                amount: money(form.outstanding),
                caption: invoice.amountPaid > 0
                    ? '${money(invoice.amountPaid)} already received of '
                        '${money(invoice.totalAmount)}'
                    : 'Nothing received yet',
                // Amber while money is owed — an administrative state, never
                // the red that means a patient is in trouble.
                color: form.outstanding > 0
                    ? semanticInk(context, AppColors.warning)
                    : semanticInk(context, AppColors.acuityStable),
              ),
              const SizedBox(height: BentoSpace.action),
              RatioBar(
                fraction: invoice.totalAmount <= 0
                    ? 0
                    : (invoice.amountPaid / invoice.totalAmount)
                        .clamp(0.0, 1.0),
                filledLabel: '${money(invoice.amountPaid)} paid',
                remainderLabel: '${money(form.outstanding)} owed',
                remainderColor: AppColors.warning,
              ),
            ],
          ),
        );
      });

  Widget _amount(PaymentFormController form) => FormCard(
        title: 'How much',
        children: [
          Obx(
            () => MoneyInput(
              fieldKey: PaymentFormKeys.amount,
              label: 'Amount received',
              controller: form.amountController,
              symbol: form.money.symbol,
              decimalSeparator: form.money.decimalSeparator,
              required: true,
              // The kit shows this as a hint on the field itself, so the
              // ceiling is visible before it is hit as well as after.
              max: form.outstanding,
              error: form.showErrors.value
                  ? form.validateAmount(form.amountController.text)
                  : null,
            ),
          ),
          const SizedBox(height: BentoSpace.action),
          SecondaryBar(
            key: PaymentFormKeys.payInFull,
            label: 'Settle the balance',
            icon: Icons.done_all_rounded,
            onPressed: form.payInFull,
          ),
        ],
      );

  Widget _method(PaymentFormController form) => FormCard(
        title: 'How it was paid',
        children: [
          Obx(
            () => AsyncPicker<String>(
              fieldKey: PaymentFormKeys.method,
              label: 'Method',
              required: true,
              valueLabel: PaymentMethod.labelOf(form.method.value),
              options: [
                for (final method in PaymentMethod.all)
                  PickerOption<String>(
                    value: method,
                    label: PaymentMethod.labelOf(method),
                  ),
              ],
              onSelected: form.setMethod,
            ),
          ),

          // ── Conditional, and absent rather than disabled ─────────────────

          Obx(
            () => !form.needsProvider
                ? const SizedBox.shrink()
                : BentoInput(
                    fieldKey: PaymentFormKeys.provider,
                    label: 'Mobile money provider',
                    controller: form.providerController,
                    required: true,
                    validator: form.validateProvider,
                    hint: 'The network the transfer came through',
                  ),
          ),
          Obx(
            () => !form.needsBank
                ? const SizedBox.shrink()
                : BentoInput(
                    fieldKey: PaymentFormKeys.bankName,
                    label: 'Bank',
                    controller: form.bankController,
                    required: true,
                    validator: form.validateBank,
                    hint: form.needsCheque
                        ? 'The bank the cheque is drawn on'
                        : 'The bank the transfer came from',
                  ),
          ),
          Obx(
            () => !form.needsCheque
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BentoInput(
                        fieldKey: PaymentFormKeys.chequeNumber,
                        label: 'Cheque number',
                        controller: form.chequeNumberController,
                        required: true,
                        validator: form.validateChequeNumber,
                      ),
                      DateField(
                        fieldKey: PaymentFormKeys.chequeDate,
                        label: 'Date on the cheque',
                        required: true,
                        value: form.chequeDate.value,
                        format: SettingsService.to.date,
                        error: form.showErrors.value &&
                                form.chequeDate.value == null
                            ? 'The date printed on the cheque'
                            : null,
                        hint: 'Kept in the notes — the payment API has no '
                            'field of its own for it',
                        onChanged: form.setChequeDate,
                      ),
                    ],
                  ),
          ),

          Obx(
            () => BentoInput(
              fieldKey: PaymentFormKeys.reference,
              label: 'Reference',
              controller: form.referenceController,
              required: form.needsReference,
              validator: form.validateReference,
              hint: 'The number this payment can be traced by',
            ),
          ),
          BentoInput(
            fieldKey: PaymentFormKeys.notes,
            label: 'Notes',
            controller: form.notesController,
            maxLines: 3,
          ),
        ],
      );

  Widget _saveBar(PaymentFormController form) => Padding(
        padding: const EdgeInsets.fromLTRB(
          BentoSpace.page,
          0,
          BentoSpace.page,
          BentoSpace.page,
        ),
        child: MaxWidthBody(
          maxWidth: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final missing = form.missingCount;
                if (missing == 0) return const SizedBox.shrink();
                return Padding(
                  key: PaymentFormKeys.errors,
                  padding: const EdgeInsets.only(bottom: BentoSpace.action),
                  child: FieldErrorSummary(count: missing),
                );
              }),
              Obx(
                () => PrimaryBar(
                  key: PaymentFormKeys.save,
                  label: 'Record payment',
                  icon: Icons.payments_outlined,
                  busy: form.isSubmitting.value,
                  onPressed: form.submit,
                ),
              ),
            ],
          ),
        ),
      );
}
