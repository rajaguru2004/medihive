import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/ward_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../theme/theme.dart';

/// Add or edit a ward.
///
/// One controller for both, because they are one form: the only differences
/// are the title, the verb on the button, and which route the save goes to.
/// Two controllers would be two places to add the next field to.
class InpatientAddWardController extends GetxController {
  static InpatientAddWardController get to =>
      Get.find<InpatientAddWardController>();

  final _service = Get.find<InpatientService>();

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final capacityController = TextEditingController();

  final type = RxnString();
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// The ward being edited, or null when adding.
  WardModel? editing;

  bool get isEdit => editing != null;

  /// The ward types this product knows about.
  ///
  /// A fixed list rather than free text: the type drives which beds a ward may
  /// hold, and a site that types "Intensive Care" where the rest of the estate
  /// says "ICU" gets a ward nothing can filter on.
  static const types = [
    'General',
    'ICU',
    'Emergency',
    'Maternity',
    'Pediatric',
    'Surgical',
    'Isolation',
  ];

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final ward = argument is Map ? argument['ward'] : argument;
    if (ward is WardModel) {
      editing = ward;
      nameController.text = ward.name;
      codeController.text = ward.code;
      capacityController.text = '${ward.capacity}';
      // Matched case-insensitively: the API stores the type lowercased and the
      // picker offers it title-cased, so a direct comparison leaves the field
      // blank on every edit.
      type.value = types.firstWhereOrNull(
        (t) => t.toLowerCase() == ward.type.trim().toLowerCase(),
      );
    }
  }

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Give the ward a name' : null;

  String? validateCode(String? value) =>
      (value ?? '').trim().isEmpty ? 'Give the ward a short code' : null;

  String? validateCapacity(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'How many beds does it hold?';
    final capacity = int.tryParse(text);
    if (capacity == null) return 'Enter a number';
    if (capacity <= 0) return 'A ward needs at least one bed';
    // A guard rather than a rule: the largest real ward is around 60 beds, and
    // a typo of 300 for 30 silently breaks every occupancy figure on the
    // dashboard.
    if (capacity > 500) return 'That looks like a typo — 500 beds is the limit';
    return null;
  }

  Future<void> save() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (type.value == null) {
      errorMessage.value = 'Choose a ward type.';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final name = nameController.text.trim();

    try {
      final response = isEdit
          ? await _service.updateWard(
              id: editing!.id,
              name: name,
              code: codeController.text.trim(),
              type: type.value!.toLowerCase(),
              capacity: int.parse(capacityController.text.trim()),
            )
          : await _service.createWard(
              name: name,
              code: codeController.text.trim(),
              type: type.value!.toLowerCase(),
              capacity: int.parse(capacityController.text.trim()),
            );

      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        errorMessage.value =
            envelopeMessage(response.data) ?? "Couldn't save the ward.";
        return;
      }

      // The bus tells every screen showing a ward. No controller here reaches
      // into another one to refresh it.
      if (Get.isRegistered<DataBus>()) DataBus.to.changedBed();
      Get.back<void>();
      showBentoToast(isEdit ? '$name updated.' : '$name added.');
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't save the ward.");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    codeController.dispose();
    capacityController.dispose();
    super.onClose();
  }
}
