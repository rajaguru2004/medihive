import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../models/admission_model.dart';
import '../../../services/inpatient_service.dart';

class InpatientAdmissionsController extends GetxController {
  final _service = Get.find<InpatientService>();

  // State fields
  bool isLoading = false;
  String errorMessage = '';
  List<AdmissionModel> admissions = [];

  // Filters / Search
  String admissionsSearchQuery = '';
  String selectedAdmissionStatusFilter =
      'Active'; // 'All', 'Active', 'Discharged'

  @override
  void onInit() {
    super.onInit();
    refreshAllData();
  }

  // Fetch admissions data
  Future<void> refreshAllData() async {
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
      debugPrint('[InpatientAdmissionsController] DioException: ${e.message}');
    } catch (e) {
      errorMessage = 'Failed to load inpatient details. Please try again.';
      debugPrint('[InpatientAdmissionsController] Error: $e');
    } finally {
      isLoading = false;
      update();
    }
  }

  // Change Admission Status Filter
  void changeAdmissionStatusFilter(String filter) {
    selectedAdmissionStatusFilter = filter;
    update();
  }

  // Set Search Queries
  void updateAdmissionsSearch(String query) {
    admissionsSearchQuery = query;
    update();
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
}
