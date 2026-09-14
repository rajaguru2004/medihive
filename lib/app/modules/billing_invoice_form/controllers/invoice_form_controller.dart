import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/billing_service.dart';
import '../../../data/models/drafts/billing_drafts.dart';
import '../../../data/models/patient_ref.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/repositories/crud_repository.dart';
import '../../../data/services/billing_api.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/invoice_math.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// How the invoice-level discount was entered.
enum DiscountMode {
  /// A flat amount off the subtotal.
  amount,

  /// A share of the subtotal, capped at a hundred percent.
  percentage,
}

/// Raising a bill: who it is for, what is on it, and what it comes to.
///
/// **No arithmetic lives here.** Every figure comes from [InvoiceMath], which
/// is where the server's order of operations is written down and unit-tested.
/// A controller that did its own sums would be a second definition of the
/// total, and the two would disagree the first time somebody changed one.
class InvoiceFormController extends GetxController with LoadStateMixin {
  static InvoiceFormController get to => Get.find<InvoiceFormController>();

  static const BillingApi _billing = BillingApi();

  /// Patients are searched, never listed: a hospital has more of them than any
  /// picker can hold.
  static const _patients = CrudRepository<PatientRef>(
    Endpoints.patients,
    PatientRef.fromJson,
    'patients',
  );

  final formKey = GlobalKey<FormState>();

  final notesController = TextEditingController();
  final discountController = TextEditingController();

  final patient = Rxn<PatientRef>();
  final lines = <InvoiceLine>[].obs;
  final dueDate = Rxn<DateTime>();
  final discountMode = DiscountMode.amount.obs;

  /// The catalogue, for the picker sheet.
  final catalogue = <BillingService>[].obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// True once somebody has tried to save. Until then a missing patient is not
  /// an error — it is a form nobody has filled in yet.
  final showErrors = false.obs;

  /// Set when the invoice is raised from a consultation, so the charge links
  /// back to the encounter that caused it.
  String? consultationId;

  /// Per-line editing controllers, keyed by the line's position.
  ///
  /// Held rather than rebuilt because a `TextEditingController` created inside
  /// `build` loses the cursor on every keystroke — the field then reads as
  /// typing backwards.
  final _lineFields = <int, InvoiceLineFields>{};

  MoneyFormat get money => SettingsService.to.settings.money;

  /// The site's minor-unit count. Two nearly everywhere, zero in the currencies
  /// that have no minor unit at all.
  int get precision => money.precision;

  bool get hasLines => lines.isNotEmpty;

  /// What the pane shows, and what the POST will be built from. One call, so
  /// the two can never be computed differently.
  InvoiceTotals get totals => InvoiceMath.totals(
        lines,
        discountAmount: discountMode.value == DiscountMode.amount
            ? _discountInput
            : 0,
        discountPercentage: discountMode.value == DiscountMode.percentage
            ? _discountInput
            : null,
        precision: precision,
      );

  /// The discount field's value, read in the site's own convention — a site
  /// whose decimal separator is a comma has staff typing `1.234,56`, and
  /// `double.parse` reads that as `1.234`.
  double get _discountInput =>
      money.parse(discountController.text)?.clamp(0, double.maxFinite) ?? 0;

  LineTotals lineTotals(int index) =>
      InvoiceMath.line(lines[index], precision: precision);

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final args = argument is Map ? argument : const {};

    final passed = args['patient'];
    if (passed is PatientRef) {
      patient.value = passed;
    } else if (passed is Map) {
      patient.value = PatientRef.of(passed);
    }

    final patientId = args['patientId'];
    if (patient.value == null && patientId is String && patientId.isNotEmpty) {
      // Only an id reached us — enough to send, not enough to name. The picker
      // shows the id rather than an empty field, so nobody raises a bill
      // against a patient the screen never confirmed.
      patient.value = PatientRef(id: patientId, mrn: patientId);
    }

    final consultation = args['consultationId'];
    if (consultation is String && consultation.isNotEmpty) {
      consultationId = consultation;
    }
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(loadCatalogue());
  }

  @override
  void onClose() {
    notesController.dispose();
    discountController.dispose();
    for (final fields in _lineFields.values) {
      fields.dispose();
    }
    super.onClose();
  }

  /// The whole active catalogue, in one request: `GET /billing/services` has no
  /// pagination DTO, so there is no second page to follow and nothing to search
  /// server-side — the picker filters what it has.
  Future<void> loadCatalogue() => runGuarded(
        () async => catalogue.assignAll(await _billing.catalogue.entries()),
        fallback: "Couldn't load the service catalogue.",
      );

  /// Patients, as the picker asks for them.
  Future<List<PickerOption<PatientRef>>> searchPatients(String query) async {
    final rows = await _patients.search(query);
    return [
      for (final row in rows)
        PickerOption<PatientRef>(
          value: row,
          label: row.displayName,
          sublabel: 'MRN ${row.mrn}',
        ),
    ];
  }

  /// The catalogue, as the picker asks for it. Filtered in memory — see
  /// [loadCatalogue].
  List<PickerOption<BillingService>> catalogueOptions() => [
        for (final service in catalogue)
          PickerOption<BillingService>(
            value: service,
            label: service.serviceName,
            // The price is on the option because it is what decides which of
            // two similarly named services is the right one.
            sublabel: [
              money(service.unitPrice),
              if ((service.serviceCategory ?? '').trim().isNotEmpty)
                service.serviceCategory!,
            ].join(' · '),
          ),
      ];

  void choosePatient(PatientRef value) => patient.value = value;

  /// Adds a catalogue entry as a line.
  ///
  /// The price and the tax rate are **copied onto the line**, not looked up at
  /// send time: a catalogue price can change between the line being added and
  /// the invoice being raised, and the bill has to be the one the patient was
  /// quoted.
  void addFromCatalogue(BillingService service) {
    _appendLine(
      InvoiceLine(
        serviceId: service.id,
        description: service.serviceName,
        unitPrice: service.unitPrice,
        taxPercentage: service.isTaxable ? service.taxPercentage : 0,
      ),
    );
  }

  /// Adds an empty line for something the catalogue does not carry.
  void addCustomLine() => _appendLine(const InvoiceLine(description: ''));

  void _appendLine(InvoiceLine line) {
    lines.add(line);
    fieldsFor(lines.length - 1).fill(line, money);
  }

  void removeLine(int index) {
    if (index < 0 || index >= lines.length) return;
    lines.removeAt(index);
    // The fields are keyed by position, so everything after the removed line
    // has shifted under them. Refilling is cheaper than remapping and cannot
    // leave a field showing the previous neighbour's price.
    _refillFields();
  }

  void setLineDescription(int index, String value) =>
      _replace(index, (line) => line.copyWith(description: value));

  void setLineQuantity(int index, String value) {
    final quantity = int.tryParse(value.trim());
    _replace(index, (line) => line.copyWith(quantity: quantity ?? 0));
  }

  void setLineUnitPrice(int index, String value) =>
      _replace(index, (line) => line.copyWith(unitPrice: money.parse(value) ?? 0));

  void setLineDiscount(int index, String value) =>
      _replace(index, (line) => line.copyWith(discount: money.parse(value) ?? 0));

  void setLineTax(int index, String value) => _replace(
        index,
        (line) => line.copyWith(
          taxPercentage: double.tryParse(value.trim().replaceAll(',', '.')) ?? 0,
        ),
      );

  void _replace(int index, InvoiceLine Function(InvoiceLine) change) {
    if (index < 0 || index >= lines.length) return;
    lines[index] = change(lines[index]);
    // `lines[i] = …` notifies on its own; this is the discount pane, which
    // reads the field controllers rather than the list.
    lines.refresh();
  }

  void setDiscountMode(DiscountMode mode) {
    if (discountMode.value == mode) return;
    discountMode.value = mode;
    // The number means something different now — 10 as an amount is not 10 as
    // a percentage — so the field is cleared rather than reinterpreted.
    discountController.clear();
    lines.refresh();
  }

  void onDiscountChanged(String _) => lines.refresh();

  void setDueDate(DateTime? value) => dueDate.value = value;

  /// The text controllers for one line, created the first time it is drawn.
  InvoiceLineFields fieldsFor(int index) =>
      _lineFields.putIfAbsent(index, InvoiceLineFields.new);

  void _refillFields() {
    for (var i = 0; i < lines.length; i++) {
      fieldsFor(i).fill(lines[i], money);
    }
    for (final index in _lineFields.keys.toList()) {
      if (index >= lines.length) _lineFields.remove(index)?.dispose();
    }
    lines.refresh();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateDescription(String? value) =>
      (value ?? '').trim().isEmpty ? 'Say what this line is for' : null;

  String? validateQuantity(String? value) {
    final quantity = int.tryParse((value ?? '').trim());
    // `@Min(1)` on the DTO. Zero is a 400, not a free line.
    if (quantity == null || quantity < 1) return 'At least one';
    return null;
  }

  String? validateUnitPrice(String? value) {
    final price = money.parse(value);
    if (price == null) return 'Enter a price';
    // Zero is a value: a service given free still belongs on the bill, because
    // the record of what was done is the point.
    if (price < 0) return 'A price cannot be negative';
    return null;
  }

  /// The invoice-level discount, checked against what there is to discount.
  ///
  /// The message names the ceiling rather than just refusing: "too big" tells
  /// somebody their number is wrong and not what would be right.
  String? validateDiscount(String? value) {
    final entered = money.parse(value);
    if (entered == null || entered <= 0) return null;

    if (discountMode.value == DiscountMode.percentage) {
      return entered > InvoiceMath.maxDiscountPercentage
          ? 'A discount cannot be more than 100%'
          : null;
    }

    final subtotal = InvoiceMath.totals(lines, precision: precision).subtotal;
    if (entered > subtotal) {
      return 'That is more than the subtotal of ${money(subtotal)}';
    }
    return null;
  }

  /// How many required things are still missing, for the line above the save
  /// bar. Zero until somebody has actually tried to save.
  int get missingCount {
    if (!showErrors.value) return 0;
    var count = 0;
    final chosen = patient.value;
    if (chosen == null || chosen.id.isEmpty) count++;
    if (!hasLines) count++;
    for (final line in lines) {
      if (line.description.trim().isEmpty || line.quantity < 1) count++;
    }
    return count;
  }

  /// The first thing wrong with a number on this form, or null.
  ///
  /// One sentence rather than a list: the banner is above the save bar and the
  /// field itself is already marked, so the message's job is to say which line
  /// to scroll to.
  String? _firstNumericError() {
    for (var i = 0; i < lines.length; i++) {
      final fields = fieldsFor(i);
      final quantity = validateQuantity(fields.quantity.text);
      if (quantity != null) return 'Line ${i + 1}: $quantity.';
      final price = validateUnitPrice(fields.unitPrice.text);
      if (price != null) return 'Line ${i + 1}: $price.';
    }
    return validateDiscount(discountController.text);
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> submit() async {
    showErrors.value = true;
    if (isSubmitting.value) return;

    final chosen = patient.value;
    if (chosen == null || chosen.id.isEmpty) {
      errorMessage.value = 'Choose the patient this bill is for.';
      return;
    }
    if (!hasLines) {
      errorMessage.value = 'An invoice needs at least one line.';
      return;
    }

    // The numeric fields are checked by hand, because the form cannot see them.
    //
    // `QuantityField` and `MoneyInput` wrap `BentoInput` and pass only
    // `error:` — neither forwards a `validator:` — so `formKey.validate()`
    // covers the descriptions and nothing else. Without this, a line whose
    // quantity field was cleared posts `quantity: 0` and the DTO's `@Min(1)`
    // turns the whole invoice into a 400 somebody has to read a stack trace to
    // understand.
    final numberError = _firstNumericError();
    if (numberError != null) {
      errorMessage.value = numberError;
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    // Computed once, from the same call the pane renders, so the figure on
    // screen and the figure posted cannot drift.
    final computed = totals;
    final percentage = discountMode.value == DiscountMode.percentage
        ? _discountInput.clamp(0, InvoiceMath.maxDiscountPercentage).toDouble()
        : 0.0;

    final draft = InvoiceDraft(
      patientId: chosen.id,
      consultationId: consultationId,
      items: [
        for (final line in lines)
          InvoiceMath.itemDraft(line, precision: precision),
      ],
      // The amount is what the server actually reads; the percentage is stored
      // beside it and never used in `createInvoice`, so both are sent — the
      // amount so the total is right, the percentage so the document records
      // what was agreed.
      discountAmount: computed.discount,
      discountPercentage: percentage,
      dueDate: dueDate.value,
      notes: notesController.text,
    );

    try {
      final invoice = await _billing.invoices.create(draft.toCreateJson());
      Get.back<void>();
      showBentoToast('Invoice ${invoice.invoiceNumber} raised.');
    } on ApiForbiddenException catch (e) {
      // The access map is a hint and can be a minute older than the role it
      // describes, so the button being there is never proof the write is
      // allowed.
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't raise that invoice.");
    } finally {
      isSubmitting.value = false;
    }
  }
}

/// The five text fields one line owns.
///
/// A class rather than five maps: they are created and disposed together, and
/// five parallel maps keyed by index is five chances to leak one.
class InvoiceLineFields {
  InvoiceLineFields();

  final description = TextEditingController();
  final quantity = TextEditingController();
  final unitPrice = TextEditingController();
  final discount = TextEditingController();
  final tax = TextEditingController();

  /// Writes [line] into the fields without moving the caret unnecessarily.
  ///
  /// The guard matters: assigning `.text` rebuilds the value and drops the
  /// selection, so refilling on every rebuild would send the cursor to the end
  /// of the field between keystrokes.
  void fill(InvoiceLine line, MoneyFormat money) {
    _set(description, line.description);
    _set(quantity, '${line.quantity}');
    _set(unitPrice, money.editable(line.unitPrice));
    _set(discount, line.discount > 0 ? money.editable(line.discount) : '');
    _set(tax, line.taxPercentage > 0 ? _percent(line.taxPercentage) : '');
  }

  static void _set(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.text = value;
  }

  static String _percent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    discount.dispose();
    tax.dispose();
  }
}
