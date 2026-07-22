import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../models/ward_model.dart';
import '../../../services/inpatient_service.dart';
import '../../inpatient/controllers/inpatient_controller.dart';
import '../../inpatient_wards/controllers/inpatient_wards_controller.dart';

class InpatientAddWardController extends GetxController {
  final _service = Get.find<InpatientService>();

  // Form Field Controllers
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final capacityController = TextEditingController();

  // Selected Type
  String? selectedType;

  // Type Options
  final List<String> typeOptions = [
    'General',
    'ICU',
    'Emergency',
    'Maternity',
    'Pediatric',
    'Surgical',
    'Isolation',
  ];

  // State Variables
  bool isInitialized = false;
  bool isSubmitting = false;
  bool isEdit = false;
  WardModel? ward;

  void initialize(WardModel? wardModel, bool isEditMode) {
    if (isInitialized) return;

    ward = wardModel;
    isEdit = isEditMode;

    if (isEdit && wardModel != null) {
      nameController.text = wardModel.name;
      codeController.text = wardModel.code;
      capacityController.text = wardModel.capacity.toString();

      // Resolve selected type by comparing lowercase
      selectedType = typeOptions.firstWhere(
        (t) => t.toLowerCase() == wardModel.type.toLowerCase(),
        orElse: () => typeOptions.first,
      );
    } else {
      nameController.clear();
      codeController.clear();
      capacityController.clear();
      selectedType = 'General';
    }

    isInitialized = true;
    update();
  }

  @override
  void onClose() {
    nameController.dispose();
    codeController.dispose();
    capacityController.dispose();
    super.onClose();
  }

  void setSelectedType(String? value) {
    selectedType = value;
    update();
  }

  Future<void> saveWard() async {
    if (isSubmitting) return;

    final name = nameController.text.trim();
    final code = codeController.text.trim();
    final capacityStr = capacityController.text.trim();
    final type = selectedType;

    // Field-level validation safeguard
    if (name.isEmpty || code.isEmpty || capacityStr.isEmpty || type == null) {
      Get.snackbar(
        'Validation Error',
        'All fields are mandatory',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF9F0A).withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    final capacity = int.tryParse(capacityStr);
    if (capacity == null || capacity <= 0) {
      Get.snackbar(
        'Validation Error',
        'Capacity must be greater than 0',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF9F0A).withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    isSubmitting = true;
    update();

    try {
      final Response response;
      if (isEdit && ward != null) {
        response = await _service.updateWard(
          id: ward!.id,
          name: name,
          code: code,
          type: type.toLowerCase(),
          capacity: capacity,
        );
      } else {
        response = await _service.createWard(
          name: name,
          code: code,
          type: type.toLowerCase(),
          capacity: capacity,
        );
      }

      if (response.data != null && response.data['success'] == true) {
        Get.back();
        Get.snackbar(
          'Success',
          isEdit ? 'Ward updated successfully' : 'Ward created successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF30D158).withValues(alpha: 0.9),
          colorText: Colors.white,
        );

        // Refresh the inpatient ward list automatically
        if (Get.isRegistered<InpatientController>()) {
          Get.find<InpatientController>().refreshAllData();
        }
        if (Get.isRegistered<InpatientWardsController>()) {
          Get.find<InpatientWardsController>().refreshAllData();
        }
      } else {
        final msg =
            response.data != null ? response.data['message'] as String? : null;
        Get.snackbar(
          'Error',
          msg ?? 'Failed to save ward details.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFF453A).withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Network error. Please try again.';
      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF453A).withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF453A).withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } finally {
      isSubmitting = false;
      update();
    }
  }
}
