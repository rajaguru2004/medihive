import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/billing_service.dart';
import '../../../data/models/drafts/billing_drafts.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/billing_api.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../theme/theme.dart';

/// Adding or editing one catalogue entry.
///
/// One controller for both, because they are one form: the only differences are
/// the title, the verb on the button, and whether the write is a POST or a
/// PATCH. Two controllers would be two places to add the next field to.
class BillingServiceFormController extends GetxController {
  static BillingServiceFormController get to =>
      Get.find<BillingServiceFormController>();

  static const BillingApi _billing = BillingApi();

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final departmentController = TextEditingController();
  final priceController = TextEditingController();
  final taxController = TextEditingController();
  final copayController = TextEditingController();

  final category = RxnString();
  final isTaxable = false.obs;
  final isCoveredByInsurance = true.obs;
  final isActive = true.obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// The entry being edited, or null when adding.
  BillingService? editing;

  bool get isEdit => editing != null;

  MoneyFormat get money => SettingsService.to.settings.money;

  /// The categories the seeded catalogue groups by.
  ///
  /// A picker rather than free text: the category is what the ledger groups a
  /// price list by, and a site that types "Consultations" where the rest says
  /// "consultation" gets a group of one that nothing can filter on. The field
  /// is still optional — the DTO lets it be.
  static const List<String> categories = [
    'consultation',
    'procedure',
    'laboratory',
    'radiology',
    'pharmacy',
    'accommodation',
    'other',
  ];

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final service = argument is Map ? argument['service'] : argument;
    if (service is! BillingService) return;

    editing = service;
    nameController.text = service.serviceName;
    codeController.text = service.serviceCode ?? '';
    departmentController.text = service.department ?? '';
    priceController.text = money.editable(service.unitPrice);
    taxController.text =
        service.taxPercentage > 0 ? _percent(service.taxPercentage) : '';
    copayController.text = service.insuranceCopayPercentage == null
        ? ''
        : _percent(service.insuranceCopayPercentage!);
    // Matched case-insensitively: the API stores the category lowercased and a
    // site's own entry may not be, so a direct comparison leaves the field
    // blank on every edit.
    category.value = categories.firstWhereOrNull(
      (c) => c == (service.serviceCategory ?? '').trim().toLowerCase(),
    );
    isTaxable.value = service.isTaxable;
    isCoveredByInsurance.value = service.isCoveredByInsurance;
    isActive.value = service.isActive;
  }

  @override
  void onClose() {
    nameController.dispose();
    codeController.dispose();
    departmentController.dispose();
    priceController.dispose();
    taxController.dispose();
    copayController.dispose();
    super.onClose();
  }

  void setCategory(String value) => category.value = value;

  void setTaxable(bool value) {
    isTaxable.value = value;
    // A rate left behind on an untaxed service would be stored and then read
    // back by the invoice form as a rate to charge.
    if (!value) taxController.clear();
  }

  void setCovered(bool value) {
    isCoveredByInsurance.value = value;
    if (!value) copayController.clear();
  }

  void setActive(bool value) => isActive.value = value;

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Give the service a name' : null;

  String? validatePrice(String? value) {
    final price = money.parse(value);
    if (price == null) return 'What does it cost?';
    // Zero is a value: a free service is a real entry in a catalogue, and the
    // record of what was done is the point.
    if (price < 0) return 'A price cannot be negative';
    return null;
  }

  String? validateTax(String? value) {
    if (!isTaxable.value) return null;
    final rate = _rate(value);
    if (rate == null) return 'What rate is charged?';
    if (rate < 0 || rate > 100) return 'A tax rate is between 0 and 100%';
    return null;
  }

  String? validateCopay(String? value) {
    if (!isCoveredByInsurance.value) return null;
    final text = (value ?? '').trim();
    // Optional: plenty of policies have no copay at all.
    if (text.isEmpty) return null;
    final rate = _rate(text);
    if (rate == null) return 'Enter a percentage, or leave it empty';
    if (rate < 0 || rate > 100) return 'A copay is between 0 and 100%';
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> save() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final name = nameController.text.trim();
    final draft = BillingServiceDraft(
      serviceName: name,
      serviceCode: codeController.text,
      serviceCategory: category.value,
      department: departmentController.text,
      unitPrice: money.parse(priceController.text) ?? 0,
      isTaxable: isTaxable.value,
      // Zero rather than null when tax is off: `false` and `0` are values, and
      // a service switched from taxable to not has to have its old rate
      // overwritten rather than left standing.
      taxPercentage: isTaxable.value ? (_rate(taxController.text) ?? 0) : 0,
      isCoveredByInsurance: isCoveredByInsurance.value,
      insuranceCopayPercentage:
          isCoveredByInsurance.value ? _rate(copayController.text) : null,
      // Create only sends what `CreateBillingServiceDto` declares, and it has
      // no `isActive` — the column defaults to true. `toUpdateJson` adds it.
      isActive: isActive.value,
    );

    try {
      if (isEdit) {
        await _billing.catalogue.update(editing!.id, draft.toUpdateJson());
      } else {
        await _billing.catalogue.create(draft.toCreateJson());
      }
      Get.back<void>();
      showBentoToast(isEdit ? '$name updated.' : '$name added.');
    } on ApiForbiddenException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't save that service.");
    } finally {
      isSubmitting.value = false;
    }
  }

  /// A percentage typed by hand. Read with both separators, because the
  /// keyboard offers whichever the device's locale prefers.
  static double? _rate(String? value) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  static String _percent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
