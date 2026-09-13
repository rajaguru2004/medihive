import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/ward_model.dart';
import '../../../data/services/inpatient_service.dart';
import '../../inpatient_admissions/controllers/inpatient_admissions_controller.dart';
import '../../inpatient_beds_grid/controllers/inpatient_beds_grid_controller.dart';
import '../../inpatient_overview/controllers/inpatient_overview_controller.dart';
import '../../inpatient_wards/controllers/inpatient_wards_controller.dart';

class InpatientStats {
  final int totalBeds;
  final int occupiedBeds;
  final int availableBeds;
  final int todayAdmissions;
  final int todayDischarges;
  final double occupancyRate;

  InpatientStats({
    required this.totalBeds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.todayAdmissions,
    required this.todayDischarges,
    required this.occupancyRate,
  });

  factory InpatientStats.fromJson(Map<String, dynamic> json) => InpatientStats(
        totalBeds: json['totalBeds'] as int? ?? 0,
        occupiedBeds: json['occupiedBeds'] as int? ?? 0,
        availableBeds: json['availableBeds'] as int? ?? 0,
        todayAdmissions: json['todayAdmissions'] as int? ?? 0,
        todayDischarges: json['todayDischarges'] as int? ?? 0,
        occupancyRate: (json['occupancyRate'] as num?)?.toDouble() ?? 0.0,
      );
}

class InpatientController extends GetxController {
  final _service = Get.find<InpatientService>();

  // State fields
  bool isLoading = false;
  String errorMessage = '';
  InpatientStats? stats;
  List<WardModel> wards = [];

  // Active Tab state: 0: Overview, 1: Wards, 2: Beds Grid, 3: Admissions
  int activeTab = 0;

  void changeTab(int index) {
    activeTab = index;
    update();
  }

  @override
  void onInit() {
    super.onInit();
    refreshActiveTabData();
  }

  // Refresh active tab's specific data alongside main stats
  Future<void> refreshActiveTabData() async {
    await refreshAllData();

    switch (activeTab) {
      case 0:
        if (Get.isRegistered<InpatientOverviewController>()) {
          await Get.find<InpatientOverviewController>().refreshData();
        }
        break;
      case 1:
        if (Get.isRegistered<InpatientWardsController>()) {
          await Get.find<InpatientWardsController>().refreshAllData();
        }
        break;
      case 2:
        if (Get.isRegistered<InpatientBedsGridController>()) {
          await Get.find<InpatientBedsGridController>().refreshAllData();
        }
        break;
      case 3:
        if (Get.isRegistered<InpatientAdmissionsController>()) {
          await Get.find<InpatientAdmissionsController>().refreshAllData();
        }
        break;
    }
  }

  // Fetch stats and wards data
  Future<void> refreshAllData() async {
    isLoading = true;
    errorMessage = '';
    update();

    try {
      // Parallel fetch stats and wards
      final results = await Future.wait([
        _service.fetchStats(),
        _service.fetchWards(),
      ]);

      final statsRes = results[0];
      final wardsRes = results[1];

      if (statsRes.data != null && statsRes.data['success'] == true) {
        stats = InpatientStats.fromJson(
            statsRes.data['data'] as Map<String, dynamic>);
      }

      if (wardsRes.data != null && wardsRes.data['success'] == true) {
        final List<dynamic> wardsList = wardsRes.data['data'] ?? [];
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
      debugPrint('[InpatientController] DioException: ${e.message}');
    } catch (e) {
      errorMessage = 'Failed to load inpatient details. Please try again.';
      debugPrint('[InpatientController] Error: $e');
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
        // Refresh all data to sync state
        await refreshAllData();
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

  // ─── Filtered Getters ───

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
