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

  /// The list itself.
  ///
  /// Spelled `invoices` rather than `invoice` because [invoice] keys a row as
  /// `billing_invoice_<id>` — and a robot that reads ids back by stripping
  /// that prefix would otherwise find an invoice whose id is the word "list",
  /// first in every ordering assertion and one extra in every count.
  static const Key invoiceList = Key('billing_invoices_list');

  /// One invoice row, by id.
  ///
  /// A row carries exactly one `StatusPill`, so a flow reaches the pill as the
  /// row's only descendant of that type. Keyed as the row rather than as the
  /// pill on purpose: the assertion that matters is the pill's **colour**, and
  /// a test that read the word "Overdue" off a key would pass just as happily
  /// if somebody painted it `acuityCritical`.
  static Key invoice(String id) => Key('billing_invoice_$id');

  static const Key invoicesEmpty = Key('billing_invoices_empty');

  static const Key newInvoice = Key('billing_new_invoice');

  /// One catalogue row on the **ledger's** Services tab.
  ///
  /// Deliberately not `BillingServicesKeys.service` — the catalogue screen is
  /// pushed *over* this tab, so both rows for one service are mounted at once
  /// and a shared key would make every finder for either of them ambiguous.
  static Key ledgerService(String id) => Key('billing_ledger_service_$id');

  /// The link through to the service catalogue.
  static const Key openServices = Key('billing_open_services');

  /// The locked panel a role without billing gets.
  static const Key noAccess = Key('billing_no_access');

  /// The detail pane on a tablet, beside the list.
  static const Key detailPane = Key('billing_detail_pane');
  static const Key listPane = Key('billing_list_pane');
}
