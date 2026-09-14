import 'package:flutter/widgets.dart';

/// Widget keys for the invoice form — `/billing/invoices/new`.
///
/// The line keys are built from the line's **index**, because a line being
/// entered has no id yet and two custom lines can carry the same description.
abstract final class InvoiceFormKeys {
  static const Key screen = Key('invoice_form_screen');
  static const Key form = Key('invoice_form');

  static const Key patientPicker = Key('invoice_form_patient');

  /// Adds a line from the catalogue.
  static const Key addFromCatalogue = Key('invoice_form_add_service');

  /// Adds a line for something not in the catalogue.
  static const Key addCustomLine = Key('invoice_form_add_custom');

  static const Key linesEmpty = Key('invoice_form_lines_empty');

  static Key line(int index) => Key('invoice_form_line_$index');
  static Key lineDescription(int index) => Key('invoice_form_line_desc_$index');
  static Key lineQuantity(int index) => Key('invoice_form_line_qty_$index');
  static Key lineUnitPrice(int index) => Key('invoice_form_line_price_$index');
  static Key lineDiscount(int index) => Key('invoice_form_line_disc_$index');
  static Key lineTax(int index) => Key('invoice_form_line_tax_$index');
  static Key lineRemove(int index) => Key('invoice_form_line_remove_$index');

  /// The line's own total, so a flow can read back what the arithmetic did.
  static Key lineTotal(int index) => Key('invoice_form_line_total_$index');

  static const Key discountMode = Key('invoice_form_discount_mode');
  static const Key discountAmount = Key('invoice_form_discount_amount');
  static const Key discountPercentage = Key('invoice_form_discount_percent');

  static const Key dueDate = Key('invoice_form_due_date');
  static const Key notes = Key('invoice_form_notes');

  // ── The totals pane ───────────────────────────────────────────────────────
  //
  // Each figure keyed on its own: a flow that asserts the screen agrees with
  // `InvoiceMath` has to read four numbers, and three of them are formatted
  // money that also appears somewhere else on the screen.

  static const Key totals = Key('invoice_form_totals');
  static const Key subtotal = Key('invoice_form_subtotal');
  static const Key discountTotal = Key('invoice_form_discount_total');
  static const Key taxTotal = Key('invoice_form_tax_total');
  static const Key total = Key('invoice_form_total');

  static const Key errors = Key('invoice_form_errors');
  static const Key save = Key('invoice_form_save');
}
