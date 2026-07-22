import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../models/ward_model.dart';
import '../../../services/inpatient_service.dart';
import '../../inpatient/controllers/inpatient_controller.dart';

class InpatientWardsController extends GetxController {
  final _service = Get.find<InpatientService>();

  // State fields
  bool isLoading = false;
  String errorMessage = '';
  List<WardModel> wards = [];

  @override
  void onInit() {
    super.onInit();
    refreshAllData();
  }

  // Fetch wards data
  Future<void> refreshAllData() async {
    isLoading = true;
    errorMessage = '';
    update();

    try {
      final res = await _service.fetchWards();
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> wardsList = res.data['data'] ?? [];
        final List<WardModel> parsedWards = [];
        for (final item in wardsList) {
          if (item is Map<String, dynamic>) {
            parsedWards.add(WardModel.fromJson(item));
          }
        }
        wards = parsedWards;
      }
    } on DioException catch (e) {
      errorMessage = e.message ?? 'Network error. Please try again.';
      debugPrint('[InpatientWardsController] DioException: ${e.message}');
    } catch (e) {
      errorMessage = 'Failed to load inpatient details. Please try again.';
      debugPrint('[InpatientWardsController] Error: $e');
    } finally {
      isLoading = false;
      update();
    }
  }

  // Deactivate ward
  Future<void> deactivateWard(String wardId) async {
    isLoading = true;
    update();

    try {
      final res = await _service.updateWardStatus(wardId, false);
      if (res.data != null && res.data['success'] == true) {
        Get.snackbar(
          'Success',
          'Ward deactivated successfully.',
          snackPosition: SnackPosition.BOTTOM,
        );
        // Refresh local data
        await refreshAllData();
        // Also refresh inpatient stats if registered
        if (Get.isRegistered<InpatientController>()) {
          Get.find<InpatientController>().refreshAllData();
        }
      } else {
        final msg = res.data != null ? res.data['message'] as String? : null;
        Get.snackbar(
          'Error',
          msg ?? 'Failed to deactivate ward.',
          snackPosition: SnackPosition.BOTTOM,
        );
        isLoading = false;
        update();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      isLoading = false;
      update();
    }
  }

  // Get active wards only
  List<WardModel> get activeWards {
    final List<WardModel> result = [];
    for (final w in wards) {
      if (w.isActive) {
        result.add(w);
      }
    }
    return result;
  }
}
