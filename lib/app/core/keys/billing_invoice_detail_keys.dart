import 'package:flutter/widgets.dart';

/// Widget keys for one invoice — `/billing/invoices/:id`.
abstract final class InvoiceDetailKeys {
  static const Key screen = Key('invoice_detail_screen');
  static const Key header = Key('invoice_detail_header');

  /// Paid against total. The bar a collector reads before deciding whether to
  /// chase.
  static const Key paidBar = Key('invoice_detail_paid_bar');

  static const Key items = Key('invoice_detail_items');
  static Key item(int index) => Key('invoice_detail_item_$index');

  static const Key totals = Key('invoice_detail_totals');
  static const Key outstanding = Key('invoice_detail_outstanding');

  static const Key payments = Key('invoice_detail_payments');
  static Key payment(String id) => Key('invoice_detail_payment_$id');
  static const Key paymentsEmpty = Key('invoice_detail_payments_empty');

  /// The notice that says why a cancelled invoice was cancelled.
  static const Key cancelledNotice = Key('invoice_detail_cancelled');

  // ── Actions, each absent rather than disabled when it is not permitted ────

  static const Key recordPayment = Key('invoice_detail_record_payment');
  static const Key markSent = Key('invoice_detail_mark_sent');
  static const Key cancel = Key('invoice_detail_cancel');

  /// The reason field inside the cancel sheet, and its confirm.
  static const Key cancelReason = Key('invoice_detail_cancel_reason');
  static const Key cancelConfirm = Key('invoice_detail_cancel_confirm');

  static const Key noAccess = Key('invoice_detail_no_access');
}
