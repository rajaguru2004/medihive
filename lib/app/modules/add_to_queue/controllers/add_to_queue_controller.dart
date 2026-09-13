import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/patient_lookup.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/queue_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../theme/theme.dart';

/// Put somebody on the queue.
class AddToQueueController extends GetxController {
  static AddToQueueController get to => Get.find<AddToQueueController>();

  final _queueService = Get.find<QueueService>();

  final formKey = GlobalKey<FormState>();
  final serviceTypeController = TextEditingController();
  final roomController = TextEditingController();

  final patients = <PatientLookup>[].obs;
  final patient = Rxn<PatientLookup>();
  final serviceArea = RxnString();
  final acuity = 'P4'.obs;

  final isSearching = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// Debounces the patient search.
  ///
  /// Without it a seven-letter surname is seven requests, and on hospital wifi
  /// the answers arrive out of order — so the list settles on the results for
  /// "Steve" while the field reads "Stevenson".
  Timer? _searchDebounce;

  static const serviceAreas = <String, String>{
    'OPD': 'opd',
    'Emergency': 'emergency',
    'MCH': 'mch',
    'Psychiatric': 'psychiatric',
    'Laboratory': 'laboratory',
    'Pharmacy': 'pharmacy',
    'Radiology': 'radiology',
  };

  /// The triage levels offered here, in urgency order.
  ///
  /// Codes rather than words, so what this screen writes is what the queue
  /// board sorts on. `CaseStatus` turns them back into words.
  static const acuityCodes = ['P1', 'P2', 'P3', 'P4', 'P5'];

  bool get canSubmit => patient.value != null && serviceArea.value != null;

  @override
  void onReady() {
    super.onReady();
    searchPatients('');
  }

  void onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => searchPatients(query),
    );
  }

  Future<void> searchPatients(String query) async {
    isSearching.value = true;
    try {
      final response = await _queueService.fetchPatients(query: query.trim());
      patients.assignAll(
        envelopeRows(response.data).map(PatientLookup.fromJson).toList(),
      );
    } catch (e) {
      errorMessage.value =
          parseErrorMessage(e, "Couldn't search for patients.");
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (patient.value == null) {
      errorMessage.value = 'Choose the patient to add.';
      return;
    }
    if (serviceArea.value == null) {
      errorMessage.value = 'Choose which service they are waiting for.';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final name = patient.value!.fullName;

    try {
      final response = await _queueService.addToQueue(
        patientId: patient.value!.id,
        serviceArea: serviceAreas[serviceArea.value] ?? 'opd',
        serviceType: serviceTypeController.text.trim().isEmpty
            ? null
            : serviceTypeController.text.trim(),
        priority: acuity.value.toLowerCase(),
        assignedRoom: roomController.text.trim().isEmpty
            ? null
            : roomController.text.trim(),
      );

      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        errorMessage.value =
            envelopeMessage(response.data) ?? "Couldn't add $name to the queue.";
        return;
      }

      if (Get.isRegistered<DataBus>()) DataBus.to.changedRecord('queue');
      Get.back<void>();
      showBentoToast('$name added to the ${serviceArea.value} queue.');
    } catch (e) {
      errorMessage.value =
          parseErrorMessage(e, "Couldn't add $name to the queue.");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    serviceTypeController.dispose();
    roomController.dispose();
    super.onClose();
  }
}
