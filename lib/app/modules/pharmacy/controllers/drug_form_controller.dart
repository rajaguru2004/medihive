import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/drafts/pharmacy_drafts.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/pharmacy_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../theme/theme.dart';

/// Add or edit a catalogue entry.
///
/// One controller for both, because they are one form: the title, the verb on
/// the button and which route the save goes to are the only differences, and
/// two controllers would be two places to add the next column to.
///
/// The drug being edited arrives in `Get.arguments`. It has to — there is no
/// `GET /api/pharmacy/drugs/:id` to fetch it back from.
class DrugFormController extends GetxController {
  static DrugFormController get to => Get.find<DrugFormController>();

  final _service = PharmacyService.instance;

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final genericController = TextEditingController();
  final brandController = TextEditingController();
  final codeController = TextEditingController();
  final strengthController = TextEditingController();
  final stockController = TextEditingController();
  final unitController = TextEditingController();
  final reorderController = TextEditingController();
  final costController = TextEditingController();
  final priceController = TextEditingController();
  final locationController = TextEditingController();

  final category = RxnString();
  final dosageForm = RxnString();
  final requiresPrescription = false.obs;
  final isActive = true.obs;

  final submitting = false.obs;
  final errorMessage = RxnString();

  /// How many fields the last attempted save was refused over, for the line
  /// above the button. A refusal that only marks the fields is a refusal
  /// nobody can see — on a form this long the field it means is usually
  /// several screens up.
  final invalidCount = 0.obs;

  /// The entry being edited, or null when adding.
  Drug? editing;

  bool get isEdit => editing != null;

  /// The site's money convention. The form never writes a symbol of its own —
  /// `MoneyInput` is handed this one.
  MoneyFormat get money => SettingsService.to.settings.money;

  /// The shapes a drug comes in. A fixed list rather than free text: the form
  /// drives how a dose is read at the counter, and "tabs" beside "tablet" is
  /// two things to anything that groups by it.
  static const List<String> dosageForms = [
    'tablet',
    'capsule',
    'syrup',
    'suspension',
    'injection',
    'infusion',
    'cream',
    'ointment',
    'drops',
    'inhaler',
    'suppository',
    'patch',
  ];

  /// The categories the catalogue is organised by. Offered rather than
  /// enforced — [categoryOptions] adds whatever this site already uses.
  static const List<String> baseCategories = [
    'analgesic',
    'antibiotic',
    'antiviral',
    'antifungal',
    'antihypertensive',
    'antidiabetic',
    'antihistamine',
    'cardiovascular',
    'gastrointestinal',
    'respiratory',
    'supplement',
    'vaccine',
  ];

  /// The categories on offer, with anything this site already uses folded in.
  ///
  /// A site whose catalogue says `cytotoxic` would otherwise have to retype it
  /// — or, worse, pick the nearest thing on the list.
  List<String> get categoryOptions {
    final extra = <String>{};
    final current = category.value;
    if (current != null && current.trim().isNotEmpty) extra.add(current.trim());
    return [...baseCategories, ...extra.where((c) => !baseCategories.contains(c))];
  }

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final drug = argument is Map ? argument['drug'] : argument;
    if (drug is! Drug || drug.isEmpty) return;

    editing = drug;
    nameController.text = drug.drugName;
    genericController.text = drug.genericName ?? '';
    brandController.text = drug.brandName ?? '';
    codeController.text = drug.drugCode ?? '';
    strengthController.text = drug.strength ?? '';
    stockController.text = '${drug.quantityInStock}';
    unitController.text = drug.unitOfMeasure ?? '';
    reorderController.text = '${drug.reorderLevel}';
    costController.text = money.editable(drug.costPrice);
    priceController.text = money.editable(drug.sellingPrice);
    locationController.text = drug.storageLocation ?? '';
    category.value = drug.drugCategory;
    // Matched case-insensitively: the API stores the form lowercased and a
    // site that typed "Tablet" once would otherwise open a blank picker.
    dosageForm.value = dosageForms.firstWhereOrNull(
      (form) => form == (drug.dosageForm ?? '').trim().toLowerCase(),
    );
    requiresPrescription.value = drug.requiresPrescription;
    isActive.value = drug.isActive;
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Give the drug a name' : null;

  /// Zero is a value, not an absence: a drug that has run out has to be able
  /// to say so.
  String? validateStock(String? value) => _wholeNumber(value, 'stock');

  String? validateReorder(String? value) =>
      _wholeNumber(value, 'reorder level');

  String? validatePrice(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    return money.parse(text) == null ? 'Enter an amount' : null;
  }

  /// The same validators the fields ran, counted.
  ///
  /// Re-run rather than collected from the `Form`: Flutter's `FormState` marks
  /// its fields and reports one boolean, so the count the line above the
  /// button needs has to be worked out here.
  int _countInvalid() => [
        validateName(nameController.text),
        validateStock(stockController.text),
        validateReorder(reorderController.text),
        validatePrice(costController.text),
        validatePrice(priceController.text),
      ].nonNulls.length;

  String? _wholeNumber(String? value, String what) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Enter a whole number';
    if (parsed < 0) return "A $what can't be negative";
    return null;
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<void> save() async {
    if (submitting.value) return;

    if (!(formKey.currentState?.validate() ?? false)) {
      invalidCount.value = _countInvalid();
      return;
    }

    invalidCount.value = 0;
    FocusManager.instance.primaryFocus?.unfocus();
    submitting.value = true;
    errorMessage.value = null;

    final name = nameController.text.trim();
    final draft = DrugDraft(
      drugName: name,
      genericName: genericController.text,
      brandName: brandController.text,
      drugCode: codeController.text,
      drugCategory: category.value,
      dosageForm: dosageForm.value,
      strength: strengthController.text,
      quantityInStock: int.tryParse(stockController.text.trim()),
      unitOfMeasure: unitController.text,
      reorderLevel: int.tryParse(reorderController.text.trim()),
      costPrice: money.parse(costController.text),
      sellingPrice: money.parse(priceController.text),
      requiresPrescription: requiresPrescription.value,
      storageLocation: locationController.text,
      // Create-only on the DTO side, so it is only ever sent on an edit —
      // `toCreateJson` leaves it out whatever is set here.
      isActive: isActive.value,
    );

    try {
      if (isEdit) {
        await _service.updateDrug(editing!.id, draft);
      } else {
        await _service.createDrug(draft);
      }
      Get.back<void>();
      showBentoToast(isEdit ? '$name updated.' : '$name added to the shelf.');
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't save $name.");
    } finally {
      submitting.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    genericController.dispose();
    brandController.dispose();
    codeController.dispose();
    strengthController.dispose();
    stockController.dispose();
    unitController.dispose();
    reorderController.dispose();
    costController.dispose();
    priceController.dispose();
    locationController.dispose();
    super.onClose();
  }
}
