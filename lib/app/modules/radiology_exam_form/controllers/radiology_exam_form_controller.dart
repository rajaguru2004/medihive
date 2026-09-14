import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../data/models/drafts/radiology_drafts.dart';
import '../../../data/models/radiology_exam.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';

/// One entry in the imaging catalogue, being added or edited.
class RadiologyExamFormController extends GetxController with LoadStateMixin {
  static RadiologyExamFormController get to =>
      Get.find<RadiologyExamFormController>();

  /// The categories this backend's seed uses. A picker rather than free text,
  /// because the order form groups by this value and two spellings of "x-ray"
  /// are two groups.
  static const List<String> categories = [
    'x-ray',
    'ct',
    'mri',
    'ultrasound',
    'mammography',
    'fluoroscopy',
    'nuclear medicine',
  ];

  /// DICOM modality codes. Also a fixed set: a PACS matches on them exactly.
  static const List<String> modalities = [
    'CR',
    'DR',
    'CT',
    'MRI',
    'US',
    'MG',
    'XA',
    'NM',
  ];

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final bodyPartController = TextEditingController();
  final priceController = TextEditingController();
  final durationController = TextEditingController(text: '15');
  final preparationController = TextEditingController();

  final category = RxnString();
  final modality = RxnString();
  final contrastRequired = false.obs;
  final isActive = true.obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();
  final invalidFields = 0.obs;

  String examId = '';

  bool get isEditing => examId.isNotEmpty;

  String get currencySymbol => SettingsService.to.settings.money.symbol;

  @override
  void onInit() {
    super.onInit();
    // The arguments, not the network — see `RadiologyReportFormController`:
    // `isEditing` titles the header, which is painted outside the screen's
    // `Obx` and never rebuilt.
    final args = Get.arguments;
    if (args is Map && args['examId'] is String) {
      examId = args['examId'] as String;
    }
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          if (!isEditing) return;
          _fill(await RadiologyRepositories.exams.read(examId));
        },
        fallback: "Couldn't load this exam.",
      );

  void _fill(RadiologyExam exam) {
    nameController.text = exam.examName;
    codeController.text = exam.examCode ?? '';
    bodyPartController.text = exam.bodyPart ?? '';
    // `editable`, not `toString`: a price field pre-filled with the site's
    // grouping marks is one `MoneyInput` cannot read back.
    priceController.text = SettingsService.to.settings.money.editable(
      exam.price,
    );
    durationController.text =
        exam.estimatedDuration == null ? '' : '${exam.estimatedDuration}';
    preparationController.text = exam.preparationInstructions ?? '';
    category.value = exam.examCategory;
    modality.value = exam.modality;
    contrastRequired.value = exam.contrastRequired;
    isActive.value = exam.isActive;
  }

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Give the exam a name.' : null;

  Future<bool> submit() async {
    if (isSubmitting.value) return false;
    if (!(formKey.currentState?.validate() ?? false)) {
      invalidFields.value = 1;
      return false;
    }
    invalidFields.value = 0;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final draft = RadiologyExamDraft(
      examName: nameController.text,
      examCode: codeController.text,
      examCategory: category.value,
      bodyPart: bodyPartController.text,
      modality: modality.value,
      price: _money(priceController.text),
      estimatedDuration: int.tryParse(durationController.text.trim()),
      preparationInstructions: preparationController.text,
      contrastRequired: contrastRequired.value,
      // Update only. Sending it on a create is a 400 — `CreateRadiologyExamDto`
      // does not declare it, and the server runs `forbidNonWhitelisted`.
      isActive: isEditing ? isActive.value : null,
    );

    try {
      if (isEditing) {
        await RadiologyRepositories.exams.update(examId, draft.toUpdateJson());
      } else {
        await RadiologyRepositories.exams.create(draft.toCreateJson());
      }
      return true;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'exam save failed', e, stack);
      errorMessage.value = parseErrorMessage(e, "Couldn't save this exam.");
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Reads what `MoneyInput` left in the field back into a number.
  ///
  /// Through the site's own format rather than `double.parse`: a site writing
  /// `1.250,00` parses to 1.25 otherwise, which is a two-thousand-rupee scan
  /// billed at one and a quarter.
  double? _money(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return SettingsService.to.settings.money.parse(text);
  }

  @override
  void onClose() {
    nameController.dispose();
    codeController.dispose();
    bodyPartController.dispose();
    priceController.dispose();
    durationController.dispose();
    preparationController.dispose();
    super.onClose();
  }
}
