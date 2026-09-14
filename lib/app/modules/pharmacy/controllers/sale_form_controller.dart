import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/drafts/pharmacy_drafts.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/patient_ref.dart';
import '../../../data/network/dio_client.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/pharmacy_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../theme/theme.dart';
import 'dispense_controller.dart';

/// One line of a walk-in sale.
class SaleLine {
  SaleLine({required this.drug, int quantity = 1})
      : quantity = quantity.obs,
        field = TextEditingController(text: '$quantity');

  final Drug drug;
  final RxInt quantity;
  final TextEditingController field;

  int get stock => drug.quantityInStock;

  double get unitPrice => drug.sellingPrice ?? 0;

  double get total => unitPrice * quantity.value;

  /// Clamped to what is on the shelf. The server refuses anything more, and a
  /// counter that lets somebody ring up eleven of a box of ten finds out at
  /// the moment the customer is holding their card.
  void setQuantity(int next) {
    final clamped = next < 1 ? 1 : (next > stock ? stock : next);
    quantity.value = clamped;
    if (field.text != '$clamped') {
      field.text = '$clamped';
      field.selection = TextSelection.collapsed(offset: field.text.length);
    }
  }

  void dispose() => field.dispose();
}

/// An over-the-counter sale: no prescription, and usually no patient record.
class SaleFormController extends GetxController {
  static SaleFormController get to => Get.find<SaleFormController>();

  final _service = PharmacyService.instance;

  final lines = <SaleLine>[].obs;

  /// Null for a walk-in. The DTO makes the patient optional for exactly that
  /// reason, and inventing one to satisfy a form is how a stranger's purchase
  /// lands on somebody's medical record.
  final patient = Rxn<PatientRef>();

  final paymentMethod = 'cash'.obs;
  final paymentStatus = 'paid'.obs;

  final submitting = false.obs;
  final errorMessage = RxnString();

  /// The running total, held as an observable rather than derived from [lines]
  /// in the widget tree: the alternative is `lines.refresh()` on every
  /// keystroke, which rebuilds every field on the form to move one figure.
  final totalDue = 0.0.obs;

  double get total => lines.fold<double>(0, (sum, line) => sum + line.total);

  String get totalLabel => SettingsService.to.money(totalDue.value);

  void _recompute() => totalDue.value = total;

  String moneyOf(num? amount) => SettingsService.to.money(amount);

  DioClient get _client => Get.find<DioClient>();

  // ── Lines ─────────────────────────────────────────────────────────────────

  /// The shelf, as picker options that say what is left and what it costs.
  ///
  /// A drug with nothing on the shelf is offered with its stock showing and
  /// cannot be added — see [addDrug]. Hiding it instead would leave a
  /// pharmacist searching for something they can see on the inventory screen.
  Future<List<PickerOption<Drug>>> searchDrugs(String query) async {
    final shelf = await _service.drugs(search: query);
    return [
      for (final drug in shelf)
        PickerOption<Drug>(
          value: drug,
          label: drug.displayName,
          sublabel: '${drug.quantityInStock} in stock · '
              '${drug.priceLabel(SettingsService.to.settings.money)}',
          // Amber, never red: an empty shelf is an administrative problem.
          color: drug.isOutOfStock || drug.isLowStock ? AppColors.warning : null,
        ),
    ];
  }

  void addDrug(Drug drug) {
    errorMessage.value = null;
    if (drug.isOutOfStock) {
      errorMessage.value = '${drug.displayName} is out of stock.';
      return;
    }
    final existing = lines.firstWhereOrNull((line) => line.drug.id == drug.id);
    if (existing != null) {
      existing.setQuantity(existing.quantity.value + 1);
    } else {
      lines.add(SaleLine(drug: drug));
    }
    _recompute();
  }

  void removeLine(SaleLine line) {
    lines.remove(line);
    line.dispose();
    _recompute();
  }

  void setQuantity(SaleLine line, String raw) {
    line.setQuantity(int.tryParse(raw.trim()) ?? 1);
    _recompute();
    errorMessage.value = null;
  }

  // ── The patient ───────────────────────────────────────────────────────────

  Future<List<PickerOption<PatientRef>>> searchPatients(String query) async {
    final response = await _client.get(
      Endpoints.patients.list,
      queryParameters: {
        if (query.trim().isNotEmpty) 'search': query.trim(),
        'limit': 20,
      },
    );
    final rows = ApiEnvelope.of(response).orThrow().listOf(PatientRef.fromJson);
    return [
      for (final row in rows)
        PickerOption<PatientRef>(
          value: row,
          label: row.displayName,
          sublabel: row.mrn.isEmpty ? null : 'MRN ${row.mrn}',
        ),
    ];
  }

  void setPatient(PatientRef? next) => patient.value = next;

  void setPaymentMethod(String method) => paymentMethod.value = method;

  void setPaymentStatus(String status) => paymentStatus.value = status;

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<void> save() async {
    if (submitting.value) return;
    if (lines.isEmpty) {
      errorMessage.value = 'Add at least one drug to the sale.';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    submitting.value = true;
    errorMessage.value = null;

    try {
      await _service.createSale(
        SaleDraft(
          patientId: patient.value?.id,
          items: [
            for (final line in lines)
              SaleItemDraft(
                drugId: line.drug.id,
                batchId: line.drug.nextBatch?.id,
                drugName: line.drug.drugName,
                quantity: line.quantity.value,
                unitPrice: line.unitPrice,
                total: line.total,
              ),
          ],
          paymentMethod: paymentMethod.value,
          paymentStatus: paymentStatus.value,
        ),
      );
      final takings = totalLabel;
      Get.back<void>();
      showBentoToast('Sale rung up — $takings.');
    } on ApiException catch (e) {
      // The server names the drug it could not cover, and that name is the
      // only part a pharmacist can act on.
      errorMessage.value = e.errorCode == PharmacyService.insufficientStock
          ? e.message
          : parseErrorMessage(e, "Couldn't ring up that sale.");
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't ring up that sale.");
    } finally {
      submitting.value = false;
    }
  }

  /// The same two vocabularies the dispense screen uses, so a sale rung up
  /// either way carries the same words.
  List<String> get paymentMethods => DispenseController.paymentMethods;

  List<String> get paymentStatuses => DispenseController.paymentStatuses;

  @override
  void onClose() {
    for (final line in lines) {
      line.dispose();
    }
    super.onClose();
  }
}
