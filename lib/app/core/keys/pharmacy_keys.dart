import 'package:flutter/widgets.dart';

/// Widget keys for the pharmacy: the counter hub, a prescription, the dispense
/// screen, the drug form and an over-the-counter sale.
///
/// One file for five screens because they are five views of two things — a
/// drug and a prescription — and a key that names a drug must mean the same
/// drug on the inventory row, in the dispense list and on the form that edits
/// it.
abstract final class PharmacyKeys {
  // ── The hub ───────────────────────────────────────────────────────────────
  static const screen = Key('pharmacy_screen');
  static const stats = Key('pharmacy_stats');
  static const error = Key('pharmacy_error');
  static const noAccess = Key('pharmacy_no_access');
  static const segmented = Key('pharmacy_segmented');

  /// One per segment, by its enum name, so a flow taps a counter view by name
  /// rather than by the words on it.
  static Key segment(String name) => Key('pharmacy_segment_$name');

  // ── To dispense ───────────────────────────────────────────────────────────
  static const prescriptionsList = Key('pharmacy_prescriptions_list');
  static const prescriptionsEmpty = Key('pharmacy_prescriptions_empty');
  static Key prescription(String id) => Key('pharmacy_prescription_$id');

  // ── Inventory ─────────────────────────────────────────────────────────────
  static const inventoryList = Key('pharmacy_inventory_list');
  static const inventoryEmpty = Key('pharmacy_inventory_empty');
  static const inventorySearch = Key('pharmacy_inventory_search');
  static const inventoryFilters = Key('pharmacy_inventory_filters');
  static const addDrug = Key('pharmacy_add_drug');

  /// A category chip. `all` is the chip that clears the filter.
  static Key category(String name) => Key('pharmacy_category_$name');

  static Key drug(String id) => Key('pharmacy_drug_$id');

  /// The stock reading on an inventory row. Keyed separately from the row
  /// because a flow asserting that low stock is amber has to reach the figure,
  /// not the thing that opens the drug.
  static Key drugStock(String id) => Key('pharmacy_drug_stock_$id');

  // ── Sales ─────────────────────────────────────────────────────────────────
  static const salesList = Key('pharmacy_sales_list');
  static const salesEmpty = Key('pharmacy_sales_empty');
  static const salesDate = Key('pharmacy_sales_date');
  static const newSale = Key('pharmacy_new_sale');
  static Key sale(String id) => Key('pharmacy_sale_$id');

  // ── One prescription ──────────────────────────────────────────────────────
  static const prescriptionScreen = Key('pharmacy_prescription_screen');
  static const prescriptionItems = Key('pharmacy_prescription_items');
  static const prescriptionMissing = Key('pharmacy_prescription_missing');
  static const dispenseAction = Key('pharmacy_dispense_action');
  static const cancelAction = Key('pharmacy_cancel_action');
  static const cancelConfirm = Key('pharmacy_cancel_confirm');

  // ── Dispensing ────────────────────────────────────────────────────────────
  static const dispenseScreen = Key('pharmacy_dispense_screen');
  static const dispenseLines = Key('pharmacy_dispense_lines');
  static const dispenseTotal = Key('pharmacy_dispense_total');
  static const dispensePaymentMethod = Key('pharmacy_dispense_payment_method');
  static const dispensePaymentStatus = Key('pharmacy_dispense_payment_status');
  static const dispenseConfirm = Key('pharmacy_dispense_confirm');
  static const dispenseError = Key('pharmacy_dispense_error');

  /// The quantity going out on one line, keyed by the drug rather than by the
  /// row's position: a prescription re-read after a refresh can reorder.
  static Key dispenseQuantity(String drugId) =>
      Key('pharmacy_dispense_quantity_$drugId');

  /// What that line comes to, so a flow can read the arithmetic it asserts on.
  static Key dispenseLineTotal(String drugId) =>
      Key('pharmacy_dispense_line_total_$drugId');

  // ── The drug form ─────────────────────────────────────────────────────────
  static const drugForm = Key('pharmacy_drug_form');
  static const drugNameField = Key('pharmacy_drug_name');
  static const drugGenericField = Key('pharmacy_drug_generic');
  static const drugBrandField = Key('pharmacy_drug_brand');
  static const drugCodeField = Key('pharmacy_drug_code');
  static const drugCategoryPicker = Key('pharmacy_drug_category');
  static const drugFormPicker = Key('pharmacy_drug_dosage_form');
  static const drugStrengthField = Key('pharmacy_drug_strength');
  static const drugStockField = Key('pharmacy_drug_stock_field');
  static const drugUnitField = Key('pharmacy_drug_unit');
  static const drugReorderField = Key('pharmacy_drug_reorder');
  static const drugCostField = Key('pharmacy_drug_cost');
  static const drugPriceField = Key('pharmacy_drug_price');
  static const drugLocationField = Key('pharmacy_drug_location');
  static const drugPrescriptionSwitch = Key('pharmacy_drug_requires_rx');
  static const drugActiveSwitch = Key('pharmacy_drug_active');
  static const drugSave = Key('pharmacy_drug_save');

  // ── Over the counter ──────────────────────────────────────────────────────
  static const saleForm = Key('pharmacy_sale_form');
  static const salePatientPicker = Key('pharmacy_sale_patient');
  static const saleAddLine = Key('pharmacy_sale_add_line');
  static const saleDrugPicker = Key('pharmacy_sale_drug_picker');
  static const salePaymentMethod = Key('pharmacy_sale_payment_method');
  static const salePaymentStatus = Key('pharmacy_sale_payment_status');
  static const saleTotal = Key('pharmacy_sale_total');
  static const saleSave = Key('pharmacy_sale_save');
  static const saleEmpty = Key('pharmacy_sale_empty');
  static Key saleQuantity(String drugId) => Key('pharmacy_sale_quantity_$drugId');
  static Key saleRemoveLine(String drugId) => Key('pharmacy_sale_remove_$drugId');
}
