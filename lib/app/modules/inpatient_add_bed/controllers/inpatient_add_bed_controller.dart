import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/ward_model.dart';
import '../../../data/services/inpatient_service.dart';
import '../../inpatient/controllers/inpatient_controller.dart';
import '../../inpatient_beds_grid/controllers/inpatient_beds_grid_controller.dart';
import '../../inpatient_wards/controllers/inpatient_wards_controller.dart';

class InpatientAddBedController extends GetxController {
  final _service = Get.find<InpatientService>();

  // Form Field Controllers
  final bedNumberController = TextEditingController();

  // Selections
  String? selectedWardId;
  String? selectedType;

  // Option Lists
  List<WardModel> activeWards = [];
  final List<String> typeOptions = [
    'Standard',
    'ICU Spec',
    'Electric Adjustable',
    'Pediatric Crib',
  ];

  // Mapping from UI Display type to API value
  final Map<String, String> typeApiValues = {
    'Standard': 'standard',
    'ICU Spec': 'icu',
    'Electric Adjustable': 'electric',
    'Pediatric Crib': 'pediatric',
  };

  // State Variables
  bool isInitialized = false;
  bool isLoadingWards = false;
  bool isSubmitting = false;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  @override
  void onClose() {
    bedNumberController.dispose();
    super.onClose();
  }

  Future<void> initialize() async {
    if (isInitialized) return;

    // Get ward ID from arguments if passed
    final args = Get.arguments;
    if (args is Map && args.containsKey('wardId')) {
      selectedWardId = args['wardId'] as String?;
    }

    selectedType = 'Standard';

    await _loadWards();

    // If no ward ID was passed, pre-select the first active ward
    if (selectedWardId == null && activeWards.isNotEmpty) {
      selectedWardId = activeWards.first.id;
    }

    isInitialized = true;
    update();
  }

  Future<void> _loadWards() async {
    isLoadingWards = true;
    update();

    try {
      // 1. Try to read from existing controllers to save network call
      if (Get.isRegistered<InpatientBedsGridController>()) {
        final gridCtrl = Get.find<InpatientBedsGridController>();
        final wardsList = gridCtrl.activeWards;
        if (wardsList.isNotEmpty) {
          activeWards = wardsList;
          isLoadingWards = false;
          update();
          return;
        }
      }

      if (Get.isRegistered<InpatientWardsController>()) {
        final wardsCtrl = Get.find<InpatientWardsController>();
        final wardsList = wardsCtrl.activeWards;
        if (wardsList.isNotEmpty) {
          activeWards = wardsList;
          isLoadingWards = false;
          update();
          return;
        }
      }

      // 2. Fetch from service if not cached
      final res = await _service.fetchWards();
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> rawWards = res.data['data'] ?? [];
        final List<WardModel> parsedWards = [];
        for (final item in rawWards) {
          if (item is Map<String, dynamic>) {
            final w = WardModel.fromJson(item);
            if (w.isActive) {
              parsedWards.add(w);
            }
          }
        }
        activeWards = parsedWards;
      }
    } catch (e) {
      debugPrint('[InpatientAddBedController] Error loading wards: $e');
    } finally {
      isLoadingWards = false;
      update();
    }
  }

  void setWardId(String? val) {
    selectedWardId = val;
    update();
  }

  void setSelectedType(String? val) {
    selectedType = val;
    update();
  }

  Future<void> saveBed() async {
    if (isSubmitting) return;

    final bedNumber = bedNumberController.text.trim();
    final wardId = selectedWardId;
    final displayType = selectedType;

    if (bedNumber.isEmpty || wardId == null || displayType == null) {
      Get.snackbar(
        'Validation Error',
        'All fields are mandatory',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFF9F0A).withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    final apiType = typeApiValues[displayType] ?? 'standard';

    isSubmitting = true;
    update();

    try {
      final response = await _service.createBed(
        wardId: wardId,
        bedNumber: bedNumber,
        type: apiType,
        status: 'available',
      );

      if (response.data != null && response.data['success'] == true) {
        Get.back();
        Get.snackbar(
          'Success',
          'Bed created successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF30D158).withValues(alpha: 0.9),
          colorText: Colors.white,
        );

        // Refresh inpatient tabs to keep everything in sync
        if (Get.isRegistered<InpatientBedsGridController>()) {
          final gridCtrl = Get.find<InpatientBedsGridController>();
          // If the added bed is for the currently selected ward in grid, reload
          if (gridCtrl.selectedWardId == wardId) {
            gridCtrl.refreshAllData();
          } else {
            // Otherwise, we can change the selection to this ward and load
            gridCtrl.changeSelectedWard(wardId);
          }
        }

        if (Get.isRegistered<InpatientController>()) {
          Get.find<InpatientController>().refreshAllData();
        }
      } else {
        final msg = response.data != null ? response.data['message'] as String? : null;
        Get.snackbar(
          'Error',
          msg ?? 'Failed to save bed details.',
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
