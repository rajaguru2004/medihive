import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../models/appointment_model.dart';
import '../../../models/bed_model.dart';
import '../../../models/patient_lookup.dart';
import '../../../models/ward_model.dart';
import '../../../services/inpatient_service.dart';
import '../../inpatient/controllers/inpatient_controller.dart';

class AdmitPatientController extends GetxController {
  final _service = Get.find<InpatientService>();

  // Loading flags
  bool isLoadingPatients = false;
  bool isLoadingWards = false;
  bool isLoadingDoctors = false;
  bool isLoadingBeds = false;
  bool isSubmitting = false;

  String? errorMessage;

  // Data lists
  List<PatientLookup> patients = [];
  List<WardModel> wards = [];
  List<BedModel> beds = [];
  List<AppointmentDoctor> doctors = [];

  // Dropdown options for admission type
  final List<String> admissionTypes = [
    'Routine Admission',
    'Emergency',
    'Ward Transfer',
  ];

  // Mapping from display string to API value
  final Map<String, String> admissionTypeValues = {
    'Routine Admission': 'routine',
    'Emergency': 'emergency',
    'Ward Transfer': 'transfer',
  };

  // Form selections
  PatientLookup? selectedPatient;
  WardModel? selectedWard;
  BedModel? selectedBed;
  String? selectedAdmissionType;
  AppointmentDoctor? selectedAdmittingDoctor;
  AppointmentDoctor? selectedAttendingDoctor;

  // Admission Reason controller
  final reasonController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  @override
  void onClose() {
    reasonController.dispose();
    super.onClose();
  }

  // Load patients, wards, and doctors
  Future<void> loadInitialData() async {
    errorMessage = null;
    update();

    await Future.wait([_loadPatients(), _loadWards(), _loadDoctors()]);

    update();
  }

  Future<void> _loadPatients() async {
    isLoadingPatients = true;
    update();

    try {
      final res = await _service.fetchPatients(query: '', limit: 100);
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> rawList = res.data['data']['data'] ?? [];
        patients = rawList
            .map((e) => PatientLookup.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[AdmitPatientController] Error loading patients: $e');
    } finally {
      isLoadingPatients = false;
      update();
    }
  }

  Future<void> _loadWards() async {
    isLoadingWards = true;
    update();

    try {
      // Use existing InpatientController wards if already loaded to ensure consistency
      if (Get.isRegistered<InpatientController>()) {
        final inpatientCtrl = Get.find<InpatientController>();
        if (inpatientCtrl.wards.isNotEmpty) {
          // Filter active wards
          wards = inpatientCtrl.activeWards;
          isLoadingWards = false;
          return;
        }
      }

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
        wards = parsedWards;
      }
    } catch (e) {
      debugPrint('[AdmitPatientController] Error loading wards: $e');
    } finally {
      isLoadingWards = false;
      update();
    }
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
      debugPrint('[AdmitPatientController] Error loading doctors: $e');
    } finally {
      isLoadingDoctors = false;
      update();
    }
  }

  // Handle Ward selection
  void selectWard(WardModel? ward) {
    if (selectedWard?.id == ward?.id) return;

    selectedWard = ward;
    selectedBed = null; // Clear previously selected bed
    beds = []; // Reset beds list

    if (ward != null) {
      _loadBedsForWard(ward.id);
    } else {
      update();
    }
  }

  Future<void> _loadBedsForWard(String wardId) async {
    isLoadingBeds = true;
    update();

    try {
      final res = await _service.fetchBeds(wardId: wardId, status: 'available');
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> rawBeds = res.data['data'] ?? [];
        final List<BedModel> parsedBeds = [];
        for (final item in rawBeds) {
          if (item is Map<String, dynamic>) {
            final bed = BedModel.fromJson(item);
            if (bed.status.toLowerCase() == 'available') {
              parsedBeds.add(bed);
            }
          }
        }
        beds = parsedBeds;
      }
    } catch (e) {
      debugPrint('[AdmitPatientController] Error loading beds: $e');
    } finally {
      isLoadingBeds = false;
      update();
    }
  }

  // Select patient, bed, doctor, type
  void selectPatient(PatientLookup? patient) {
    selectedPatient = patient;
    update();
  }

  void selectBed(BedModel? bed) {
    selectedBed = bed;
    update();
  }

  void selectAdmissionType(String? type) {
    selectedAdmissionType = type;
    update();
  }

  void selectAdmittingDoctor(AppointmentDoctor? doc) {
    selectedAdmittingDoctor = doc;
    update();
  }

  void selectAttendingDoctor(AppointmentDoctor? doc) {
    selectedAttendingDoctor = doc;
    update();
  }

  // Admission Submit Logic
  Future<void> submitAdmission() async {
    if (isSubmitting) return;

    // Validate fields manually for custom snackbars as requested
    if (selectedPatient == null) {
      _showValidationError('Please select a patient');
      return;
    }
    if (selectedWard == null) {
      _showValidationError('Please select a ward');
      return;
    }
    if (selectedBed == null) {
      _showValidationError('Please select an available bed');
      return;
    }
    if (selectedAdmissionType == null) {
      _showValidationError('Please select an admission type');
      return;
    }
    if (selectedAdmittingDoctor == null) {
      _showValidationError('Please select an admitting doctor');
      return;
    }
    if (selectedAttendingDoctor == null) {
      _showValidationError('Please select an attending doctor');
      return;
    }
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      _showValidationError('Please enter the admission reason');
      return;
    }

    isSubmitting = true;
    errorMessage = null;
    update();

    try {
      final apiType = admissionTypeValues[selectedAdmissionType] ?? 'routine';
      final res = await _service.admitPatient(
        patientId: selectedPatient!.id,
        bedId: selectedBed!.id,
        admissionType: apiType,
        admissionReason: reason,
        admittingDoctorId: selectedAdmittingDoctor!.id,
        attendingDoctorId: selectedAttendingDoctor!.id,
      );

      if (res.data != null && res.data['success'] == true) {
        Get.snackbar(
          'Success',
          res.data['message'] ?? 'Patient admitted successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF30D158).withValues(alpha: 0.9),
          colorText: Colors.white,
        );

        // Refresh inpatient data
        if (Get.isRegistered<InpatientController>()) {
          Get.find<InpatientController>().refreshAllData();
        }

        // Navigate back to Inpatient View
        Get.back();
      } else {
        final msg = res.data != null ? res.data['message'] as String? : null;
        Get.snackbar(
          'Error',
          msg ?? 'Failed to admit patient.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFF453A).withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ??
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
