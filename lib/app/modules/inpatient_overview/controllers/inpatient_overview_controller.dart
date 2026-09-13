import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/admission_model.dart';
import '../../../data/services/inpatient_service.dart';

class InpatientOverviewController extends GetxController {
  final _service = Get.find<InpatientService>();

  // State fields
  bool isLoading = false;
  String errorMessage = '';
  List<AdmissionModel> admissions = [];
  String overviewSearchQuery = '';

  @override
  void onInit() {
    super.onInit();
    refreshData();
  }

  // Fetch only active admissions data
  Future<void> refreshData() async {
    isLoading = true;
    errorMessage = '';
    update();

    try {
      final res = await _service.fetchAdmissions();
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> admissionsList = res.data['data'] ?? [];
        final List<AdmissionModel> parsedAdmissions = [];
        for (final item in admissionsList) {
          if (item is Map<String, dynamic>) {
            parsedAdmissions.add(AdmissionModel.fromJson(item));
          }
        }
        admissions = parsedAdmissions;
      }
    } on DioException catch (e) {
      errorMessage = e.message ?? 'Network error. Please try again.';
      debugPrint('[InpatientOverviewController] DioException: ${e.message}');
    } catch (e) {
      errorMessage = 'Failed to load inpatient details. Please try again.';
      debugPrint('[InpatientOverviewController] Error: $e');
    } finally {
      isLoading = false;
      update();
    }
  }

  // Update Search Query
  void updateOverviewSearch(String query) {
    overviewSearchQuery = query;
    update();
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
}
