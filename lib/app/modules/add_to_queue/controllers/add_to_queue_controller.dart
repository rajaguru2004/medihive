import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import 'package:medihive/app/theme/theme.dart';

import '../../../data/models/patient_lookup.dart';
import '../../../data/services/queue_service.dart';
import '../../queue/controllers/queue_controller.dart';

class AddToQueueController extends GetxController {
  final _queueService = Get.find<QueueService>();

  final searchController = TextEditingController();
  final serviceTypeController = TextEditingController();
  final assignedRoomController = TextEditingController();

  // State fields (Plain variables, no Rx / Obx)
  List<PatientLookup> patientsList = [];
  PatientLookup? selectedPatient;
  String selectedServiceArea = '';
  String selectedPriority = 'Normal'; // default selected priority

  bool isLoadingPatients = false;
  bool isSaving = false;
  String? errorMessage;

  final List<String> serviceAreas = [
    'OPD',
    'Emergency',
    'MCH',
    'Psychiatric',
    'Laboratory',
    'Pharmacy',
    'Radiology',
  ];

  final List<String> priorities = [
    'Urgent',
    'Normal',
    'Low',
    'Routine',
  ];

  @override
  void onInit() {
    super.onInit();
    // Default select first service area
    selectedServiceArea = serviceAreas.first;
    // Initial fetch of patients list
    fetchPatients('');
  }

  /// Fetches patient list for search matching
  Future<void> fetchPatients(String query) async {
    isLoadingPatients = true;
    errorMessage = null;
    update();

    try {
      final res = await _queueService.fetchPatients(query: query);
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> rawList = res.data['data']['data'] ?? [];
        patientsList = rawList
            .map((e) => PatientLookup.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      errorMessage = 'Failed to load patients list.';
    } finally {
      isLoadingPatients = false;
      update();
    }
  }

  /// Handles patient search field changes
  void onPatientSearchChanged(String val) {
    fetchPatients(val);
  }

  /// Sets selected patient
  void selectPatient(PatientLookup patient) {
    selectedPatient = patient;
    searchController.text = patient.fullName;
    patientsList = []; // Clear list to dismiss search results
    update();
  }

  /// Clears selected patient
  void clearSelectedPatient() {
    selectedPatient = null;
    searchController.clear();
    fetchPatients('');
    update();
  }

  /// Sets service area dropdown selection
  void selectServiceArea(String area) {
    selectedServiceArea = area;
    update();
  }

  /// Sets priority dropdown selection
  void selectPriority(String priority) {
    selectedPriority = priority;
    update();
  }

  /// Validates and submits patient registration to queue
  Future<void> submit(FormState? formState, BuildContext context) async {
    // 1. Patient Validation
    if (selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a patient.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 2. Service Area Validation
    if (selectedServiceArea.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a service area.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 3. Priority Validation
    if (selectedPriority.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a priority.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!(formState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields correctly.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    isSaving = true;
    update();

    try {
      final serviceAreaKey = _mapServiceAreaToKey(selectedServiceArea);
      final priorityKey = selectedPriority.toLowerCase();

      final res = await _queueService.addToQueue(
        patientId: selectedPatient!.id,
        serviceArea: serviceAreaKey,
        serviceType: serviceTypeController.text.trim().isNotEmpty
            ? serviceTypeController.text.trim()
            : null,
        priority: priorityKey,
        assignedRoom: assignedRoomController.text.trim().isNotEmpty
            ? assignedRoomController.text.trim()
            : null,
      );

      if (!context.mounted) return;

      if (res.data != null && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Patient added to queue successfully.'),
            backgroundColor: AppColors.success,
          ),
        );

        // Refresh Queue Controller and automatically select the added patient's department tab
        if (Get.isRegistered<QueueController>()) {
          final queueCtrl = Get.find<QueueController>();
          queueCtrl.selectedServiceArea.value = selectedServiceArea;
          await queueCtrl.fetchQueueData();
        }

        // Navigate back to Queue Management
        Get.back();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(res.data['message'] ?? 'Could not add patient to queue.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      final msg = e.response?.data?['message'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg ?? 'Network error occurred.'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      isSaving = false;
      update();
    }
  }

  String _mapServiceAreaToKey(String name) {
    switch (name) {
      case 'OPD':
        return 'opd';
      case 'Emergency':
        return 'emergency';
      case 'MCH':
        return 'mch';
      case 'Psychiatric':
        return 'psychiatric';
      case 'Laboratory':
        return 'laboratory';
      case 'Pharmacy':
        return 'pharmacy';
      case 'Radiology':
        return 'radiology';
      default:
        return name.toLowerCase();
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    serviceTypeController.dispose();
    assignedRoomController.dispose();
    super.onClose();
  }
}
