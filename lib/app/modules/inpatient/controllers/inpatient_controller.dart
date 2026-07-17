import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;

import '../../../models/admission_model.dart';
import '../../../models/bed_model.dart';
import '../../../models/ward_model.dart';
import '../../../services/inpatient_service.dart';

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
  List<AdmissionModel> admissions = [];
  List<BedModel> beds = []; // Beds for the currently selected ward

  // Navigation / Tabs
  int activeTabIndex = 0; // 0: Overview, 1: Wards, 2: Beds Grid, 3: Admissions

  // Filters / Search
  String overviewSearchQuery = '';
  String admissionsSearchQuery = '';
  String selectedAdmissionStatusFilter = 'Active'; // 'All', 'Active', 'Discharged'
  
  String? selectedWardId;
  String selectedBedStatusFilter = 'All Beds'; // 'All Beds', 'Available', 'Occupied', 'Maintenance'

  @override
  void onInit() {
    super.onInit();
    refreshAllData();
  }

  // Fetch all inpatient data from endpoints
  Future<void> refreshAllData() async {
    isLoading = true;
    errorMessage = '';
    update();

    try {
      // Parallel fetch stats, wards, and admissions
      final results = await Future.wait([
        _service.fetchStats(),
        _service.fetchWards(),
        _service.fetchAdmissions(),
      ]);

      final statsRes = results[0];
      final wardsRes = results[1];
      final admissionsRes = results[2];

      if (statsRes.data != null && statsRes.data['success'] == true) {
        stats = InpatientStats.fromJson(statsRes.data['data'] as Map<String, dynamic>);
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

      if (admissionsRes.data != null && admissionsRes.data['success'] == true) {
        final List<dynamic> admissionsList = admissionsRes.data['data'] ?? [];
        final List<AdmissionModel> parsedAdmissions = [];
        for (final item in admissionsList) {
          if (item is Map<String, dynamic>) {
            parsedAdmissions.add(AdmissionModel.fromJson(item));
          }
        }
        admissions = parsedAdmissions;
      }

      // Check selected ward
      _syncSelectedWard();

      if (selectedWardId != null) {
        await _fetchBedsForSelectedWardQuietly();
      } else {
        beds = [];
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

  // Update Bed Status
  Future<void> updateBedStatus(String bedId, String status) async {
    isLoading = true;
    update();

    try {
      final res = await _service.updateBedStatus(bedId, status);
      if (res.data != null && res.data['success'] == true) {
        Get.snackbar(
          'Success',
          'Bed status updated to $status.',
          snackPosition: SnackPosition.BOTTOM,
        );
        // Refresh all data to sync state
        await refreshAllData();
      } else {
        final msg = res.data != null ? res.data['message'] as String? : null;
        Get.snackbar(
          'Error',
          msg ?? 'Failed to update bed status.',
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

  // Select Ward & load beds
  Future<void> changeSelectedWard(String? wardId) async {
    selectedWardId = wardId;
    if (wardId != null) {
      isLoading = true;
      update();
      try {
        await _fetchBedsForSelectedWardQuietly();
      } catch (e) {
        debugPrint('[InpatientController] Error changing ward: $e');
      } finally {
        isLoading = false;
        update();
      }
    } else {
      beds = [];
      update();
    }
  }

  // Change Bed Status Filter
  void changeBedStatusFilter(String filter) {
    selectedBedStatusFilter = filter;
    update();
  }

  // Change Admission Status Filter
  void changeAdmissionStatusFilter(String filter) {
    selectedAdmissionStatusFilter = filter;
    update();
  }

  // Set Search Queries
  void updateOverviewSearch(String query) {
    overviewSearchQuery = query;
    update();
  }

  void updateAdmissionsSearch(String query) {
    admissionsSearchQuery = query;
    update();
  }

  // Set active tab
  void changeTab(int index) {
    activeTabIndex = index;
    update();
  }

  // Helper: Synchronize selected ward ID based on available active wards list
  void _syncSelectedWard() {
    final activeWardsList = activeWards;
    if (activeWardsList.isEmpty) {
      selectedWardId = null;
      return;
    }

    // Check if current selection is still active
    bool stillActive = false;
    for (final w in activeWardsList) {
      if (w.id == selectedWardId) {
        stillActive = true;
        break;
      }
    }

    if (!stillActive) {
      // Default to the first active ward
      selectedWardId = activeWardsList[0].id;
    }
  }

  // Fetch beds quietly (does not handle loader state itself)
  Future<void> _fetchBedsForSelectedWardQuietly() async {
    if (selectedWardId == null) return;
    final res = await _service.fetchBeds(wardId: selectedWardId!, status: 'all');
    if (res.data != null && res.data['success'] == true) {
      final List<dynamic> bedsList = res.data['data'] ?? [];
      final List<BedModel> parsedBeds = [];
      for (final item in bedsList) {
        if (item is Map<String, dynamic>) {
          parsedBeds.add(BedModel.fromJson(item));
        }
      }
      beds = parsedBeds;
    }
  }

  // ─── Filtered Getters (strict loop pattern, no .where/.firstWhere/.indexWhere) ───

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

  // Get selected ward details if available
  WardModel? get selectedWardDetails {
    if (selectedWardId == null) return null;
    for (final w in wards) {
      if (w.id == selectedWardId) {
        return w;
      }
    }
    return null;
  }

  // Get filtered patient list for Overview tab (admitted status only + query filter)
  List<AdmissionModel> get filteredActiveAdmissions {
    final query = overviewSearchQuery.trim().toLowerCase();
    final List<AdmissionModel> result = [];
    for (final admission in admissions) {
      if (admission.status.toLowerCase() == 'admitted') {
        if (query.isEmpty) {
          result.add(admission);
        } else {
          final name = admission.patient.fullName.toLowerCase();
          final mrn = admission.patient.mrn.toLowerCase();
          if (name.contains(query) || mrn.contains(query)) {
            result.add(admission);
          }
        }
      }
    }
    return result;
  }

  // Get filtered admission list for Admissions tab (status filter + query filter)
  List<AdmissionModel> get filteredAllAdmissions {
    final query = admissionsSearchQuery.trim().toLowerCase();
    final filter = selectedAdmissionStatusFilter;
    final List<AdmissionModel> result = [];
    for (final admission in admissions) {
      bool matchesStatus = true;
      if (filter == 'Active') {
        matchesStatus = admission.status.toLowerCase() == 'admitted';
      } else if (filter == 'Discharged') {
        matchesStatus = admission.status.toLowerCase() == 'discharged';
      }

      if (matchesStatus) {
        if (query.isEmpty) {
          result.add(admission);
        } else {
          final name = admission.patient.fullName.toLowerCase();
          final mrn = admission.patient.mrn.toLowerCase();
          if (name.contains(query) || mrn.contains(query)) {
            result.add(admission);
          }
        }
      }
    }
    return result;
  }

  // Get filtered bed list for Beds Grid tab
  List<BedModel> get filteredBeds {
    final List<BedModel> result = [];
    final filter = selectedBedStatusFilter;
    for (final bed in beds) {
      bool matchesStatus = true;
      if (filter != 'All Beds') {
        matchesStatus = bed.status.toLowerCase() == filter.toLowerCase();
      }
      if (matchesStatus) {
        result.add(bed);
      }
    }
    return result;
  }
}
