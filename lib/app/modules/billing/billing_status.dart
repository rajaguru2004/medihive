import 'package:flutter/material.dart';

import '../../data/utils/formatters.dart';
import '../../theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the ledger's own vocabulary
///
/// `CaseStatus` resolves *clinical* states, and none of these are one. Routed
/// through it the words land wrong or land nowhere: `paid` is in none of its
/// sets and falls to the grey default, `overdue` likewise, and `draft` resolves
/// through the triage ramp for no reason anybody chose. A whole invoice list in
/// one colour is a list nobody scans.
///
/// So the five document states, the five money states and the seven payment
/// methods are mapped here, once. Each carries **colour and rank and word**,
/// never colour alone.
///
/// Two rules this file exists to hold, and the first outranks everything:
///
///   * **An overdue invoice is amber. Never red.** `.agents/RULES.md` §0 rule
///     1: red is `acuityCritical` or `error` — a deteriorating patient, or a
///     fault. A clinician scans a ward board for red, and a bill that borrows
///     it costs that scan its meaning. An unpaid bill is an administrative
///     problem, the same as a missed appointment, and takes the same amber.
///   * **Teal never appears here.** Billing's colour is `AppColors.accent`,
///     the ledger blue, and it marks a document in flight — sent, part paid.
///     Never a clinical state, never the brand.
/// ─────────────────────────────────────────────────────────────────────────────

/// `Invoice.status` — the document's own state.
///
/// Spelled exactly as the column stores them. `INVOICE_STATUSES` in
/// `hms_v2/src/common/enums/clinical-status.enum.ts` is the `@IsIn` list, so
/// any other spelling is a 400 on the PATCH that moves the invoice along.
abstract final class InvoiceStatus {
  static const String draft = 'draft';
  static const String sent = 'sent';
  static const String overdue = 'overdue';
  static const String paid = 'paid';
  static const String cancelled = 'cancelled';

  /// Every state, in the order a bill moves through them — which is also the
  /// order a filter should offer them in.
  static const List<String> all = [draft, sent, overdue, paid, cancelled];

  static String _key(String? status) => (status ?? '').trim().toLowerCase();

  static Color colorOf(String? status) => switch (_key(status)) {
        draft => AppColors.acuityRoutine,
        // Ledger blue: raised and out with the patient, nothing wrong with it.
        sent => AppColors.accent,
        // Amber, and this is the rule. Never `acuityCritical`.
        overdue => AppColors.warning,
        paid => AppColors.acuityStable,
        cancelled => AppColors.acuityDischarged,
        _ => AppColors.acuityRoutine,
      };

  static String labelOf(String? status) => switch (_key(status)) {
        draft => 'Draft',
        sent => 'Sent',
        overdue => 'Overdue',
        paid => 'Paid',
        cancelled => 'Cancelled',
        _ => Formatters.label(status),
      };

  static IconData iconOf(String? status) => switch (_key(status)) {
        draft => Icons.edit_note_rounded,
        sent => Icons.outgoing_mail,
        overdue => Icons.schedule_rounded,
        paid => Icons.check_circle_rounded,
        cancelled => Icons.block_rounded,
        _ => Icons.receipt_long_outlined,
      };

  /// Whether money can still be taken against it. A cancelled or settled
  /// invoice offers no payment action — the server would refuse the write, and
  /// an app that offers it collects a receipt number and then loses it to a
  /// 400.
  static bool acceptsPayment(String? status) => switch (_key(status)) {
        paid || cancelled => false,
        _ => true,
      };
}

/// `Invoice.paymentStatus` — where the money has got to.
///
/// Separate from [InvoiceStatus] on purpose, and the server keeps them
/// separate too: an invoice is `sent` while its money is `partially_paid`.
abstract final class InvoicePaymentStatus {
  static const String unpaid = 'unpaid';
  static const String partiallyPaid = 'partially_paid';
  static const String paid = 'paid';
  static const String cancelled = 'cancelled';
  static const String refunded = 'refunded';

  static const List<String> all = [
    unpaid,
    partiallyPaid,
    paid,
    cancelled,
    refunded,
  ];

  static String _key(String? status) => (status ?? '').trim().toLowerCase();

  static Color colorOf(String? status) => switch (_key(status)) {
        // Neutral, deliberately. An invoice raised this morning is unpaid and
        // that is not a problem — `overdue` is where the amber belongs.
        unpaid => AppColors.acuityRoutine,
        partiallyPaid => AppColors.accent,
        paid => AppColors.acuityStable,
        cancelled || refunded => AppColors.acuityDischarged,
        _ => AppColors.acuityRoutine,
      };

  /// `partially_paid` → `Part paid`. Never the stored spelling: an underscore
  /// on a pill has leaked a database convention onto a screen somebody reads
  /// to a patient.
  static String labelOf(String? status) => switch (_key(status)) {
        unpaid => 'Unpaid',
        partiallyPaid => 'Part paid',
        paid => 'Paid',
        cancelled => 'Cancelled',
        refunded => 'Refunded',
        _ => Formatters.label(status),
      };
}

/// `Payment.paymentMethod` — how the money arrived.
///
/// A category, not a state: `PAYMENT_METHODS` gets one neutral tint and the
/// word carries it. Painting cash green and a cheque amber would say something
/// about the payment that nobody meant.
abstract final class PaymentMethod {
  static const String cash = 'cash';
  static const String creditCard = 'credit_card';
  static const String debitCard = 'debit_card';
  static const String mobileMoney = 'mobile_money';
  static const String insurance = 'insurance';
  static const String bankTransfer = 'bank_transfer';
  static const String cheque = 'cheque';

  /// The `@IsIn` list from `CreatePaymentDto`, commonest first — which is the
  /// order a picker should offer them in.
  static const List<String> all = [
    cash,
    creditCard,
    debitCard,
    mobileMoney,
    bankTransfer,
    insurance,
    cheque,
  ];

  static String _key(String? method) => (method ?? '').trim().toLowerCase();

  static String labelOf(String? method) => switch (_key(method)) {
        cash => 'Cash',
        creditCard => 'Credit card',
        debitCard => 'Debit card',
        mobileMoney => 'Mobile money',
        insurance => 'Insurance',
        bankTransfer => 'Bank transfer',
        cheque => 'Cheque',
        _ => Formatters.label(method),
      };

  static IconData iconOf(String? method) => switch (_key(method)) {
        cash => Icons.payments_outlined,
        creditCard || debitCard => Icons.credit_card_rounded,
        mobileMoney => Icons.smartphone_rounded,
        insurance => Icons.health_and_safety_outlined,
        bankTransfer => Icons.account_balance_outlined,
        cheque => Icons.description_outlined,
        _ => Icons.payments_outlined,
      };

  // ── Conditional fields ────────────────────────────────────────────────────
  //
  // `CreatePaymentDto` marks every one of these `@IsOptional()`, so the server
  // will happily store a mobile-money payment with no provider on it — and a
  // reconciliation nobody can complete six weeks later. The rules below are
  // the console's (`frontend/src/features/billing/schemas/payment.schema.ts`),
  // mirrored so the two clients ask for the same things.

  /// Which network took it. `mobile_money` only.
  static bool needsProvider(String? method) => _key(method) == mobileMoney;

  /// Which bank. Both transfers and cheques, as the console's schema has it —
  /// a cheque with no drawee bank is not traceable.
  static bool needsBank(String? method) =>
      _key(method) == bankTransfer || _key(method) == cheque;

  /// The cheque's number, and the date on its face.
  static bool needsCheque(String? method) => _key(method) == cheque;

  /// The transaction reference. Required on a bank transfer beyond what the
  /// console asks: a transfer with no reference cannot be matched against a
  /// statement, which is the only reason to record one.
  static bool needsReference(String? method) => _key(method) == bankTransfer;
}
