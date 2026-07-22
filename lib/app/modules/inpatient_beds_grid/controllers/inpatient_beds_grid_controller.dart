import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../models/admission_model.dart';
import '../../../models/bed_model.dart';
import '../../../models/ward_model.dart';
import '../../../services/inpatient_service.dart';

class InpatientBedsGridController extends GetxController {
  final _service = Get.find<InpatientService>();

  // State fields
  bool isLoading = false;
  String errorMessage = '';
  List<WardModel> wards = [];
  List<BedModel> beds = []; // Beds for the currently selected ward
  Map<String, AdmissionPatient> bedOccupants = {}; // Map bed ID to current occupant patient info

  String? selectedWardId;
  String selectedBedStatusFilter =
      'All Beds'; // 'All Beds', 'Available', 'Occupied', 'Maintenance'

  @override
  void onInit() {
    super.onInit();
    refreshAllData();
  }

  // Fetch wards and beds
  Future<void> refreshAllData() async {
    isLoading = true;
    errorMessage = '';
    update();

    try {
      final wardsRes = await _service.fetchWards();

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

      // Check selected ward
      _syncSelectedWard();

      // Fetch active admissions to map current occupants
      bedOccupants.clear();
      try {
        final admissionsRes = await _service.fetchAdmissions();
        if (admissionsRes.data != null && admissionsRes.data['success'] == true) {
          final List<dynamic> admissionsList = admissionsRes.data['data'] ?? [];
          for (final item in admissionsList) {
            if (item is Map<String, dynamic>) {
              final adm = AdmissionModel.fromJson(item);
              if (adm.status.toLowerCase() == 'admitted') {
                bedOccupants[adm.bedId] = adm.patient;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[InpatientBedsGridController] Error loading admissions: $e');
      }

      if (selectedWardId != null) {
        await _fetchBedsForSelectedWardQuietly();
      } else {
        beds = [];
      }
    } on DioException catch (e) {
      errorMessage = e.message ?? 'Network error. Please try again.';
      debugPrint('[InpatientBedsGridController] DioException: ${e.message}');
    } catch (e) {
      errorMessage = 'Failed to load inpatient details. Please try again.';
      debugPrint('[InpatientBedsGridController] Error: $e');
    } finally {
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
        debugPrint('[InpatientBedsGridController] Error changing ward: $e');
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
    final res =
        await _service.fetchBeds(wardId: selectedWardId!, status: 'all');
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

  // Get filtered bed list for Beds Grid
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
