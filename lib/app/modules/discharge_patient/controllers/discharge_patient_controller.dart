import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/admission_model.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/services/inpatient_service.dart';
import '../../inpatient/controllers/inpatient_controller.dart';
import '../../inpatient_admissions/controllers/inpatient_admissions_controller.dart';
import '../../inpatient_beds_grid/controllers/inpatient_beds_grid_controller.dart';
import '../../inpatient_overview/controllers/inpatient_overview_controller.dart';
import '../../inpatient_wards/controllers/inpatient_wards_controller.dart';
import '../../../data/models/discharge_patient_model.dart';

class DischargePatientController extends GetxController {
  final _service = Get.find<InpatientService>();

  late final AdmissionModel admission;

  // Controllers
  final reasonController = TextEditingController();
  final summaryController = TextEditingController();
  final directivesController = TextEditingController();

  // Selected values
  AppointmentDoctor? selectedDoctor;
  DateTime? selectedFollowUpDate;

  // State flags
  bool isLoadingDoctors = false;
  bool isSubmitting = false;

  List<AppointmentDoctor> doctors = [];

  @override
  void onInit() {
    super.onInit();
    // Retrieve argument passed
    if (Get.arguments is AdmissionModel) {
      admission = Get.arguments as AdmissionModel;
    } else {
      // Fallback/Safety (should not happen if args passed properly)
      debugPrint(
          '[DischargePatientController] Warning: No admission argument provided.');
    }
    _loadDoctors();
  }

  @override
  void onClose() {
    reasonController.dispose();
    summaryController.dispose();
    directivesController.dispose();
    super.onClose();
  }

  Future<void> _loadDoctors() async {
    isLoadingDoctors = true;
    update();

    try {
      final res = await _service.fetchDoctors();
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> rawList = res.data['data'] ?? [];
        doctors = rawList
            .map((e) => AppointmentDoctor.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[DischargePatientController] Error loading doctors: $e');
    } finally {
      isLoadingDoctors = false;
      update();
    }
  }

  void selectDoctor(AppointmentDoctor? doc) {
    selectedDoctor = doc;
    update();
  }

  Future<void> selectFollowUpDate(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = now;
    final lastDate = now.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedFollowUpDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF30D158),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1C1C1E),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF30D158),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      selectedFollowUpDate = picked;
      update();
    }
  }

  Future<void> submitDischarge() async {
    if (isSubmitting) return;

    final reason = reasonController.text.trim();
    final summary = summaryController.text.trim();
    final directives = directivesController.text.trim();

    // Validation
    if (reason.isEmpty) {
      _showValidationError('Discharge reason is required');
      return;
    }
    if (selectedDoctor == null) {
      _showValidationError('Please select a discharging doctor');
      return;
    }
    if (summary.isEmpty) {
      _showValidationError('Discharge summary is required');
      return;
    }

    isSubmitting = true;
    update();

    // Instantiate separate model for patient discharge data
    final dischargeData = DischargePatientModel(
      admissionId: admission.id,
      dischargeReason: reason,
      dischargeSummary: summary,
      dischargeDoctorId: selectedDoctor!.id,
      followUpDate: selectedFollowUpDate,
      followUpNotes: directives,
    );

    try {
      final res = await _service.dischargePatient(
        admissionId: dischargeData.admissionId,
        dischargeReason: dischargeData.dischargeReason,
        dischargeSummary: dischargeData.dischargeSummary,
        dischargeDoctorId: dischargeData.dischargeDoctorId,
        followUpDate: dischargeData.followUpDate,
        followUpNotes: dischargeData.followUpNotes,
      );

      if (res.data != null && res.data['success'] == true) {
        // Navigate back first
        Get.back();

        Get.snackbar(
          'Success',
          res.data['message'] ?? 'Patient discharged successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF30D158).withValues(alpha: 0.9),
          colorText: Colors.white,
        );

        // Refresh all data
        if (Get.isRegistered<InpatientController>()) {
          Get.find<InpatientController>().refreshAllData();
        }
        if (Get.isRegistered<InpatientWardsController>()) {
          Get.find<InpatientWardsController>().refreshAllData();
        }
        if (Get.isRegistered<InpatientOverviewController>()) {
          Get.find<InpatientOverviewController>().refreshData();
        }
        if (Get.isRegistered<InpatientAdmissionsController>()) {
          Get.find<InpatientAdmissionsController>().refreshAllData();
        }
        if (Get.isRegistered<InpatientBedsGridController>()) {
          Get.find<InpatientBedsGridController>().refreshAllData();
        }
      } else {
        final msg = res.data != null ? res.data['message'] as String? : null;
        Get.snackbar(
          'Error',
          msg ?? 'Failed to discharge patient.',
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

  void _showValidationError(String message) {
    Get.snackbar(
      'Validation Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFF9F0A).withValues(alpha: 0.9),
      colorText: Colors.white,
    );
  }
}
