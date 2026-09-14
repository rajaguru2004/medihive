import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/drafts/lab_drafts.dart';
import '../../../data/models/lab_test.dart';
import '../../../data/services/laboratory_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../theme/theme.dart';

/// Adding or editing one catalogue entry.
///
/// One controller for both, because they are one form: the differences are the
/// title, the verb on the button and which route the save goes to.
class LabTestFormController extends GetxController {
  static LabTestFormController get to => Get.find<LabTestFormController>();

  static const LaboratoryService _lab = LaboratoryService();

  /// The vocabularies the backend's own examples use. Offered rather than
  /// enforced — the DTO takes free text, and a site with a histopathology
  /// bench should not be told it has none.
  static const List<String> categories = [
    'hematology',
    'chemistry',
    'microbiology',
    'serology',
    'immunology',
    'histopathology',
    'molecular',
  ];

  static const List<String> types = ['quantitative', 'qualitative'];

  static const List<String> specimens = [
    'blood',
    'serum',
    'plasma',
    'urine',
    'stool',
    'swab',
    'csf',
    'sputum',
    'tissue',
  ];

  /// What shape the result-entry field takes when somebody types this test's
  /// result. See `LabResultFormView`.
  static const List<String> resultTypes = [
    'numeric',
    'text',
    'positive_negative',
    'select',
  ];

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final unitController = TextEditingController();
  final rangesController = TextEditingController();
  final priceController = TextEditingController();
  final turnaroundController = TextEditingController();
  final preparationController = TextEditingController();

  final category = RxnString();
  final type = RxnString();
  final specimen = RxnString();
  final resultType = RxnString();
  final isActive = true.obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// The entry being edited, or null when adding.
  LabTest? editing;

  bool get isEdit => editing != null;

  /// The site's currency symbol, for the money field.
  String get currencySymbol => SettingsService.to.settings.money.symbol;

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final passed = argument is Map ? argument['test'] : argument;
    if (passed is! LabTest) return;

    editing = passed;
    nameController.text = passed.testName;
    codeController.text = passed.testCode ?? '';
    unitController.text = passed.unit ?? '';
    // The **raw** string, not the parsed list re-encoded. The DTO types this
    // field as a string while the column holds JSON, so round-tripping the
    // stored text is what keeps a site's own shape intact — re-encoding a
    // sex-keyed map as a flat array rewrites every range it has.
    rangesController.text = passed.referenceRangesRaw ?? '';
    priceController.text = passed.price == null ? '' : '${passed.price}';
    turnaroundController.text =
        passed.turnaroundTime == null ? '' : '${passed.turnaroundTime}';
    preparationController.text = passed.preparationInstructions ?? '';

    category.value = _match(categories, passed.testCategory);
    type.value = _match(types, passed.testType);
    specimen.value = _match(specimens, passed.specimenType);
    resultType.value = _match(resultTypes, passed.resultType);
    isActive.value = passed.isActive;
  }

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Give the test a name' : null;

  String? validatePrice(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final price = double.tryParse(text.replaceAll(',', ''));
    if (price == null) return 'Enter a number';
    if (price < 0) return 'A price cannot be negative';
    return null;
  }

  String? validateTurnaround(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final hours = int.tryParse(text);
    if (hours == null) return 'Enter a whole number of hours';
    if (hours < 0) return 'A turnaround cannot be negative';
    return null;
  }

  /// Reference ranges are stored as JSON in a text column, so junk typed here
  /// is junk every future reader has to cope with. Checked before it is sent
  /// rather than after somebody has relied on it.
  String? validateRanges(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    try {
      jsonDecode(text);
      return null;
    } on FormatException {
      return 'That is not valid JSON — try {"male": {"min": 13.5, "max": 17.5}}';
    }
  }

  Future<void> save() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final name = nameController.text.trim();
    final draft = LabTestDraft(
      testName: name,
      testCode: codeController.text,
      testCategory: category.value,
      testType: type.value,
      specimenType: specimen.value,
      resultType: resultType.value,
      unit: unitController.text,
      referenceRanges: rangesController.text,
      price: double.tryParse(priceController.text.trim().replaceAll(',', '')),
      turnaroundTime: int.tryParse(turnaroundController.text.trim()),
      preparationInstructions: preparationController.text,
      // Create only ever makes an active entry; the switch is an edit-time
      // control, and `toCreateJson` does not carry it.
      isActive: isActive.value,
    );

    try {
      if (isEdit) {
        await _lab.tests.update(editing!.id, draft.toUpdateJson());
      } else {
        await _lab.tests.create(draft.toCreateJson());
      }
      Get.back<void>();
      showBentoToast(isEdit ? '$name updated.' : '$name added.');
    } on ApiForbiddenException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't save that test.");
    } finally {
      isSubmitting.value = false;
    }
  }

  /// The offered list, plus whatever this record already holds.
  ///
  /// A site that stores `virology` gets `virology` in its own picker rather
  /// than an empty field — and an empty field on an edit form reads as "this
  /// was never set" and is saved back that way, quietly erasing a category the
  /// whole catalogue is grouped by.
  static List<String> optionsFor(List<String> base, String? current) {
    final value = (current ?? '').trim();
    if (value.isEmpty ||
        base.any((option) => option.toLowerCase() == value.toLowerCase())) {
      return base;
    }
    return [value, ...base];
  }

  /// Matches a stored value against the offered list case-insensitively,
  /// keeping the stored spelling when it is not one of them.
  static String? _match(List<String> options, String? stored) {
    final value = (stored ?? '').trim();
    if (value.isEmpty) return null;
    return options.firstWhereOrNull(
          (option) => option.toLowerCase() == value.toLowerCase(),
        ) ??
        value;
  }

  @override
  void onClose() {
    nameController.dispose();
    codeController.dispose();
    unitController.dispose();
    rangesController.dispose();
    priceController.dispose();
    turnaroundController.dispose();
    preparationController.dispose();
    super.onClose();
  }
}
