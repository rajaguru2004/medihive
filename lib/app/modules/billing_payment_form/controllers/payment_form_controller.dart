import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/drafts/billing_drafts.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/billing_api.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/invoice_math.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../billing/billing_status.dart';

/// Taking money against one invoice.
///
/// The screen fetches the invoice rather than trusting what it was handed: the
/// ceiling on the amount is the balance, and a balance that is thirty seconds
/// stale is how an invoice gets overpaid by somebody at a counter.
class PaymentFormController extends GetxController with LoadStateMixin {
  static PaymentFormController get to => Get.find<PaymentFormController>();

  static const BillingApi _billing = BillingApi();

  final formKey = GlobalKey<FormState>();

  final amountController = TextEditingController();
  final referenceController = TextEditingController();
  final providerController = TextEditingController();
  final bankController = TextEditingController();
  final chequeNumberController = TextEditingController();
  final notesController = TextEditingController();

  final invoice = Invoice.empty.obs;
  final method = PaymentMethod.cash.obs;
  final chequeDate = Rxn<DateTime>();

  final isSubmitting = false.obs;
  final errorMessage = RxnString();
  final showErrors = false.obs;

  late final String invoiceId = _routeInvoiceId();

  MoneyFormat get money => SettingsService.to.settings.money;

  int get precision => money.precision;

  /// What is still owed, and the ceiling every validation below is measured
  /// against.
  double get outstanding => invoice.value.outstanding;

  bool get needsProvider => PaymentMethod.needsProvider(method.value);
  bool get needsBank => PaymentMethod.needsBank(method.value);
  bool get needsCheque => PaymentMethod.needsCheque(method.value);
  bool get needsReference => PaymentMethod.needsReference(method.value);

  static String _routeInvoiceId() {
    final args = Get.arguments;
    if (args is Map && args['invoiceId'] is String) {
      return args['invoiceId'] as String;
    }
    return Get.parameters['id'] ?? '';
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(load());
  }

  @override
  void onClose() {
    amountController.dispose();
    referenceController.dispose();
    providerController.dispose();
    bankController.dispose();
    chequeNumberController.dispose();
    notesController.dispose();
    super.onClose();
  }

  Future<void> load() => runGuarded(
        () async {
          final record = await _billing.invoices.read(invoiceId);
          invoice.value = record;
          // Pre-filled with the whole balance, because that is what happens at
          // a counter nine times out of ten. Editable, because the tenth is a
          // part payment and refusing it sends somebody back to the desk.
          if (amountController.text.trim().isEmpty) {
            amountController.text = money.editable(record.outstanding);
          }
        },
        fallback: "Couldn't load that invoice.",
      );

  void setMethod(String value) {
    if (method.value == value) return;
    method.value = value;
    // The fields that no longer apply are cleared rather than hidden with
    // their values intact: a cheque number left behind after the method was
    // switched to cash is a key the DTO would happily store against a payment
    // nobody wrote a cheque for.
    if (!needsProvider) providerController.clear();
    if (!needsBank) bankController.clear();
    if (!needsCheque) {
      chequeNumberController.clear();
      chequeDate.value = null;
    }
  }

  void payInFull() {
    amountController.text = money.editable(outstanding);
    update();
  }

  void setChequeDate(DateTime? value) => chequeDate.value = value;

  // ── Validation ────────────────────────────────────────────────────────────

  /// The amount, capped at the balance.
  ///
  /// The message **names the balance** rather than just refusing: "too much"
  /// tells somebody their number is wrong and not what would be right, and the
  /// person typing it is standing at a counter with a patient in front of them.
  String? validateAmount(String? value) {
    final amount = money.parse(value);
    if (amount == null) return 'Enter the amount received';
    // `@Min(0.01)` on the DTO. A zero payment is not a way to mark an invoice
    // seen.
    if (amount <= 0) return 'Enter an amount above zero';

    final ceiling = InvoiceMath.round(outstanding, precision: precision);
    if (InvoiceMath.round(amount, precision: precision) > ceiling) {
      return 'That is more than the ${money(ceiling)} still owed on this '
          'invoice. Take ${money(ceiling)} or less.';
    }
    return null;
  }

  String? validateProvider(String? value) => needsProvider &&
          (value ?? '').trim().isEmpty
      ? 'Which mobile money network it came through'
      : null;

  String? validateBank(String? value) =>
      needsBank && (value ?? '').trim().isEmpty
          ? 'Which bank it was drawn on'
          : null;

  String? validateChequeNumber(String? value) =>
      needsCheque && (value ?? '').trim().isEmpty
          ? 'The number printed on the cheque'
          : null;

  String? validateReference(String? value) =>
      needsReference && (value ?? '').trim().isEmpty
          ? 'The transaction reference, so this can be matched to a statement'
          : null;

  /// How many required things are still missing, for the line above the save
  /// bar.
  int get missingCount {
    if (!showErrors.value) return 0;
    var count = 0;
    if (validateAmount(amountController.text) != null) count++;
    if (validateProvider(providerController.text) != null) count++;
    if (validateBank(bankController.text) != null) count++;
    if (validateChequeNumber(chequeNumberController.text) != null) count++;
    if (validateReference(referenceController.text) != null) count++;
    if (needsCheque && chequeDate.value == null) count++;
    return count;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> submit() async {
    showErrors.value = true;
    if (isSubmitting.value) return;

    if (needsCheque && chequeDate.value == null) {
      errorMessage.value = 'Enter the date on the face of the cheque.';
      return;
    }

    // The amount is checked by hand rather than by the form.
    //
    // `MoneyInput` has no `validator:` hook — it wraps `BentoInput` and passes
    // only `error:` — so `formKey.validate()` does not see this field at all.
    // Leaving it to the form would let an overpayment through to a POST the
    // server has no ceiling on either: `CreatePaymentDto` checks `@Min(0.01)`
    // and nothing else, so the only thing standing between a mistyped digit
    // and a credited balance is this line.
    final amountError = validateAmount(amountController.text);
    if (amountError != null) {
      errorMessage.value = amountError;
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) return;

    final amount = money.parse(amountController.text);
    if (amount == null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final draft = PaymentDraft(
      invoiceId: invoiceId,
      patientId: invoice.value.patientId.isEmpty
          ? null
          : invoice.value.patientId,
      amount: InvoiceMath.round(amount, precision: precision),
      paymentMethod: method.value,
      paymentReference: referenceController.text,
      mobileMoneyProvider: needsProvider ? providerController.text : null,
      bankName: needsBank ? bankController.text : null,
      chequeNumber: needsCheque ? chequeNumberController.text : null,
      notes: _notes(),
    );

    try {
      final payment = await _billing.payments.create(draft.toCreateJson());
      // The bus tells the invoice behind this screen and the ledger behind
      // that. No controller here reaches into a sibling to refresh it.
      Get.back<void>();
      showBentoToast(
        'Receipt ${payment.receiptNumber} — ${money(payment.amount)} '
        'received.',
      );
    } on ApiForbiddenException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value =
          parseErrorMessage(e, "Couldn't record that payment.");
    } finally {
      isSubmitting.value = false;
    }
  }

  /// The notes, with the cheque's date folded in.
  ///
  /// `Payment.chequeDate` is a real column and **`CreatePaymentDto` has no key
  /// for it** — a client that sent one would get a 400 from
  /// `forbidNonWhitelisted` rather than a stored value. The date is still the
  /// thing that decides when a cheque can be banked, so it goes where the
  /// server will actually keep it, prefixed so it reads as a fact rather than
  /// as somebody's sentence.
  String _notes() {
    final typed = notesController.text.trim();
    if (!needsCheque || chequeDate.value == null) return typed;
    final dated = 'Cheque dated ${SettingsService.to.date(chequeDate.value)}.';
    return typed.isEmpty ? dated : '$dated $typed';
  }
}
