import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/pharmacy_drafts.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/prescription.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/pharmacy_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// One line of a dispense: what was prescribed, what is on the shelf, and what
/// is actually going over the counter.
///
/// The drug is observable because the shelf can move underneath this screen —
/// somebody else dispensing the same box between the load and the tap — and
/// the only honest answer to that is to re-read the stock and lower the line.
class DispenseLine {
  DispenseLine({
    required this.item,
    required Drug drug,
    required int quantity,
  })  : drug = drug.obs,
        quantity = quantity.obs,
        field = TextEditingController(text: '$quantity');

  final PrescriptionItem item;
  final Rx<Drug> drug;

  /// What is going out on this line. Never above [cap].
  final RxInt quantity;

  final TextEditingController field;

  /// What the prescriber wrote.
  int get prescribed => item.quantity;

  int get stock => drug.value.quantityInStock;

  /// The most this line can hand over: never more than was prescribed, never
  /// more than is on the shelf.
  int get cap => prescribed < stock ? prescribed : stock;

  /// Zero when the catalogue carries no price. Sent as it stands rather than
  /// guessed — a counter that invents a price prints a receipt nobody can
  /// reconcile.
  double get unitPrice => drug.value.sellingPrice ?? 0;

  double get total => unitPrice * quantity.value;

  /// True when the prescription is not going out in full on this line.
  bool get isShort => quantity.value < prescribed;

  /// The prescribed drug is not in the catalogue at all — withdrawn, or never
  /// stocked here. Nothing can go out against it, and saying so beats a line
  /// that silently reads "0 in stock".
  bool get isUnstocked => drug.value.isEmpty;

  /// Clamps [next] into range and keeps the field in step.
  ///
  /// Only written back when it actually differs: assigning the same text moves
  /// the cursor to the end under somebody's thumb.
  void setQuantity(int next) {
    final limit = cap;
    final clamped = next < 0 ? 0 : (next > limit ? limit : next);
    quantity.value = clamped;
    if (field.text != '$clamped') {
      field.text = '$clamped';
      field.selection = TextSelection.collapsed(offset: field.text.length);
    }
  }

  /// Takes on a freshly read stock figure. True when it forced this line down.
  bool adoptStock(Drug fresh) {
    drug.value = fresh;
    if (quantity.value <= cap) return false;
    setQuantity(cap);
    return true;
  }

  void dispose() => field.dispose();
}

/// Handing a prescription over the counter.
///
/// The one screen in this module that writes something irreversible: a sale
/// decrements stock on the server, and the same POST moves the prescription.
class DispenseController extends GetxController with LoadStateMixin {
  static DispenseController get to => Get.find<DispenseController>();

  final _service = PharmacyService.instance;

  final prescription = Prescription.empty.obs;
  final lines = <DispenseLine>[].obs;

  /// `cash`, `credit_card`, `debit_card`, `mobile_money`, `insurance`,
  /// `bank_transfer`, `cheque` — the server's own list, and nothing else
  /// passes its validator.
  static const List<String> paymentMethods = [
    'cash',
    'credit_card',
    'debit_card',
    'mobile_money',
    'insurance',
    'bank_transfer',
    'cheque',
  ];

  /// Narrower than an invoice's: a counter sale is never refunded in place.
  static const List<String> paymentStatuses = ['paid', 'partially_paid', 'pending'];

  final paymentMethod = 'cash'.obs;
  final paymentStatus = 'paid'.obs;

  final submitting = false.obs;

  /// Why the last attempt did not go through, shown inline above the bar.
  ///
  /// Inline rather than a toast because the fix is on this screen: a refused
  /// dispense has already lowered the quantity it refused, and a message that
  /// disappears in three seconds takes the explanation for that with it.
  final failure = RxnString();

  late final String id = _resolveId();

  bool get canDispense =>
      AccessService.to.can(Modules.pharmacy, AccessVerb.create);

  /// The running total, and the two counts read off the same pass.
  ///
  /// Held as observables rather than derived from [lines] in the widget tree,
  /// because the alternative is calling `lines.refresh()` on every keystroke —
  /// which rebuilds the whole screen, every field on it included, to move one
  /// figure at the bottom.
  final totalDue = 0.0.obs;

  /// How many lines are going out short of what was prescribed.
  final shortLines = 0.obs;

  /// How many lines have anything on them at all.
  final goingOut = 0.obs;

  /// Every line going out in full — what decides which status the prescription
  /// ends in.
  bool get isFullDispense => lines.isNotEmpty && shortLines.value == 0;

  /// Nothing at all is going out, so there is no sale to write.
  bool get isEmptyDispense => goingOut.value <= 0;

  double get total =>
      lines.fold<double>(0, (sum, line) => sum + line.total);

  /// The running total, in the site's own currency. Never a symbol written
  /// into a screen.
  String get totalLabel => SettingsService.to.money(totalDue.value);

  /// Re-reads the lines into the three figures the summary shows.
  void _recompute() {
    var due = 0.0;
    var short = 0;
    var going = 0;
    for (final line in lines) {
      due += line.total;
      if (line.isShort) short++;
      if (line.quantity.value > 0) going++;
    }
    totalDue.value = due;
    shortLines.value = short;
    goingOut.value = going;
  }

  String moneyOf(num? amount) => SettingsService.to.money(amount);

  @override
  void onInit() {
    super.onInit();
    final handed = _handedOver();
    if (handed != null) prescription.value = handed;
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  /// The prescription and the shelf it is coming off.
  ///
  /// The shelf is always re-read, even when the prescription was handed over:
  /// the stock figures are the whole point of this screen, and the hub's copy
  /// of them is as old as the last time somebody looked at it.
  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          if (prescription.value.isEmpty && id.isNotEmpty) {
            final rows = await _service.prescriptions();
            prescription.value = rows.firstWhere(
              (row) => row.id == id,
              orElse: () => Prescription.empty,
            );
          }
          _buildLines(await _service.drugs());
        },
        fallback: "Couldn't open the dispense.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  void setQuantity(DispenseLine line, String raw) {
    line.setQuantity(int.tryParse(raw.trim()) ?? 0);
    _recompute();
    failure.value = null;
  }

  void setPaymentMethod(String method) => paymentMethod.value = method;

  void setPaymentStatus(String status) => paymentStatus.value = status;

  /// Writes the sale, then corrects the prescription's status if it has to.
  ///
  /// `POST /pharmacy/sales` does three things in one transaction: it writes
  /// the sale, decrements every line's stock, and — because a `prescriptionId`
  /// goes with it — sets that prescription to **`fully_dispensed`** and stamps
  /// who dispensed it. So a full dispense is already correct when the POST
  /// returns and **must not be PATCHed again**; only a partial one needs the
  /// follow-up, to walk the status back to `partially_dispensed`.
  Future<void> confirm() async {
    if (submitting.value) return;

    final record = prescription.value;
    if (record.isEmpty) return;

    final going = lines.where((line) => line.quantity.value > 0).toList();
    if (going.isEmpty) {
      failure.value = 'Nothing is going out yet. Set a quantity on at least '
          'one drug.';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    submitting.value = true;
    failure.value = null;

    final full = isFullDispense;

    try {
      await _service.createSale(
        SaleDraft(
          // Null for a prescription written against no patient record, which
          // the DTO allows and the sale route reads as a walk-in.
          patientId: record.patientId.isEmpty ? null : record.patientId,
          prescriptionId: record.id,
          items: [
            for (final line in going)
              SaleItemDraft(
                drugId: line.drug.value.id,
                batchId: line.drug.value.nextBatch?.id,
                drugName: line.item.drugName,
                quantity: line.quantity.value,
                unitPrice: line.unitPrice,
                total: line.total,
              ),
          ],
          paymentMethod: paymentMethod.value,
          paymentStatus: paymentStatus.value,
        ),
      );

      if (!full) {
        await _service.updatePrescription(
          record.id,
          const PrescriptionDraft(status: partiallyDispensed),
        );
      }

      showBentoToast(
        full
            ? 'Dispensed in full.'
            : 'Dispensed what was in stock. The rest is still owed.',
      );
      Get.back<void>();
    } on ApiException catch (e) {
      if (e.errorCode == PharmacyService.insufficientStock) {
        failure.value = await _handleShortStock(e.message);
        return;
      }
      failure.value = parseErrorMessage(e, "Couldn't complete the dispense.");
    } catch (e) {
      failure.value = parseErrorMessage(e, "Couldn't complete the dispense.");
    } finally {
      submitting.value = false;
    }
  }

  /// The shelf moved between this screen loading and the tap.
  ///
  /// Re-reads stock, lowers whichever lines no longer fit, and answers with a
  /// message that **names the drug** — "that request was rejected" over a
  /// counter queue tells a pharmacist nothing they can act on, and the one
  /// thing they need to know is which box to go and count.
  Future<String> _handleShortStock(String serverMessage) async {
    final cut = <DispenseLine>[];
    try {
      final shelf = await _service.drugs();
      for (final line in lines) {
        final fresh = shelf.firstWhere(
          (drug) => drug.id == line.drug.value.id,
          orElse: () => line.drug.value,
        );
        if (line.adoptStock(fresh)) cut.add(line);
      }
      _recompute();
    } catch (e, stack) {
      // The re-read is a courtesy; the refusal is the thing being reported, so
      // this failure is logged and then swallowed rather than replacing it.
      AppLog.error('$runtimeType', 'stock re-read failed', e, stack);
    }

    final named = serverMessage.trim();
    final mentionsADrug = named.isNotEmpty &&
        lines.any(
          (line) =>
              line.item.drugName.isNotEmpty && named.contains(line.item.drugName),
        );
    if (mentionsADrug) return named;

    if (cut.isNotEmpty) {
      final parts = cut.map(
        (line) => '${line.item.drugName} — ${line.stock} left',
      );
      return 'The shelf moved while this was open: ${parts.join(', ')}. '
          'The quantities have been lowered to match.';
    }

    return named.isEmpty
        ? "There isn't enough stock for one of these drugs. Check the shelf "
            'and try again.'
        : named;
  }

  void _buildLines(List<Drug> shelf) {
    for (final line in lines) {
      line.dispose();
    }

    final byId = {for (final drug in shelf) drug.id: drug};
    lines.assignAll([
      for (final item in prescription.value.items)
        DispenseLine(
          item: item,
          drug: byId[item.drugId] ?? Drug.empty,
          // Opens at everything that will fit, because handing over the whole
          // prescription is what happens nearly every time. The pharmacist
          // lowers the exception rather than typing the rule.
          quantity: _openingQuantity(item, byId[item.drugId] ?? Drug.empty),
        ),
    ]);
    _recompute();
  }

  static int _openingQuantity(PrescriptionItem item, Drug drug) {
    final stock = drug.quantityInStock;
    return item.quantity < stock ? item.quantity : (stock < 0 ? 0 : stock);
  }

  Prescription? _handedOver() {
    final args = Get.arguments;
    if (args is Prescription) return args;
    if (args is Map && args['prescription'] is Prescription) {
      return args['prescription'] as Prescription;
    }
    return null;
  }

  String _resolveId() {
    final handed = _handedOver();
    if (handed != null && handed.id.isNotEmpty) return handed.id;
    final fromPath = Get.parameters['id'];
    if (fromPath != null && fromPath.isNotEmpty) return fromPath;
    final args = Get.arguments;
    if (args is Map && args['id'] is String) return args['id'] as String;
    return '';
  }

  /// The status a dispense that could not cover everything leaves behind.
  static const String partiallyDispensed = 'partially_dispensed';

  @override
  void onClose() {
    for (final line in lines) {
      line.dispose();
    }
    super.onClose();
  }
}
