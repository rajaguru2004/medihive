import 'package:flutter/widgets.dart';

/// Widget keys for recording a payment — `/billing/invoices/:id/pay`.
abstract final class PaymentFormKeys {
  static const Key screen = Key('payment_form_screen');
  static const Key form = Key('payment_form');

  /// What is still owed, shown above the amount field. The number the
  /// validator's ceiling is, so it has to be on screen beside it.
  static const Key outstanding = Key('payment_form_outstanding');

  static const Key amount = Key('payment_form_amount');

  /// Fills the field with the whole balance — the commonest case by a distance.
  static const Key payInFull = Key('payment_form_pay_in_full');

  static const Key method = Key('payment_form_method');

  // ── Conditional, by method ────────────────────────────────────────────────

  static const Key provider = Key('payment_form_provider');
  static const Key bankName = Key('payment_form_bank');
  static const Key chequeNumber = Key('payment_form_cheque_number');
  static const Key chequeDate = Key('payment_form_cheque_date');

  static const Key reference = Key('payment_form_reference');
  static const Key notes = Key('payment_form_notes');

  static const Key errors = Key('payment_form_errors');
  static const Key save = Key('payment_form_save');
}
