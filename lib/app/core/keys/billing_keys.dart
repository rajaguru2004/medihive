import 'package:flutter/widgets.dart';

/// Widget keys for the ledger — the `/billing` screen.
///
/// Production API, because the widgets reference them. `find.text` is ambiguous
/// here by construction: an invoice number appears on its row and again on the
/// detail it opens, "Paid" is a pill, a filter chip and a segment label, and
/// a formatted amount appears on the row, in the stats block and in the totals
/// pane of the form that created it.
abstract final class BillingKeys {
  static const Key screen = Key('billing_screen');

  /// The stats block. Keyed as a whole so a flow can assert the figures are
  /// present without naming each one.
  static const Key stats = Key('billing_stats');

  /// Invoices ↔ Services.
  static const Key tabs = Key('billing_tabs');
  static Key tab(String id) => Key('billing_tab_$id');

  static const Key statusFilter = Key('billing_status_filter');

  /// One status chip, by its stored value — `draft`, `overdue`.
  static Key statusChip(String status) => Key('billing_status_$status');

  static const Key search = Key('billing_search');

  static const Key invoiceList = Key('billing_invoice_list');

  /// One invoice row, by id.
  static Key invoice(String id) => Key('billing_invoice_$id');

  /// The status pill on one invoice row.
  ///
  /// Keyed separately from the row because the assertion that matters about it
  /// is its **colour**, not its label: an overdue bill is amber, and a test
  /// that reads the word "Overdue" would pass just as happily if somebody
  /// painted it `acuityCritical`.
  static Key invoiceStatusPill(String id) => Key('billing_invoice_pill_$id');

  static const Key invoicesEmpty = Key('billing_invoices_empty');

  static const Key newInvoice = Key('billing_new_invoice');

  /// The link through to the service catalogue.
  static const Key openServices = Key('billing_open_services');

  /// The locked panel a role without billing gets.
  static const Key noAccess = Key('billing_no_access');

  /// The detail pane on a tablet, beside the list.
  static const Key detailPane = Key('billing_detail_pane');
  static const Key listPane = Key('billing_list_pane');
}
