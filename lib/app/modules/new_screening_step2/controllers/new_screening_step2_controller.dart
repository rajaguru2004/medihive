import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/services/data_bus.dart';
import '../../../data/services/pre_triage_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../theme/theme.dart';

/// Screening, step two: what is wrong, and the observations.
class NewScreeningStep2Controller extends GetxController {
  static NewScreeningStep2Controller get to =>
      Get.find<NewScreeningStep2Controller>();

  final _service = PreTriageService.to;

  final formKey = GlobalKey<FormState>();

  final complaintController = TextEditingController();
  final historyController = TextEditingController();
  final temperatureController = TextEditingController();
  final pulseController = TextEditingController();
  final systolicController = TextEditingController();
  final diastolicController = TextEditingController();

  final route = RxnString();
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// Set as the observations are typed, so the form can flag a reading the
  /// moment it is entered rather than after it is saved.
  final vitalsRevision = 0.obs;

  static const routes = [
    'OPD',
    'Emergency',
    'Radiology',
    'Laboratory',
    'Pharmacy',
    'General Medicine',
    'Orthopedics',
    'Pediatrics',
  ];

  // Carried from step one.
  String firstName = '';
  String lastName = '';
  int? age;
  String? sex;
  String phone = '';

  String get fullName => '$firstName $lastName'.trim();

  double? get temperature =>
      double.tryParse(temperatureController.text.trim());
  int? get pulse => int.tryParse(pulseController.text.trim());
  int? get systolic => int.tryParse(systolicController.text.trim());
  int? get diastolic => int.tryParse(diastolicController.text.trim());

  /// The worst flag across the observations entered so far.
  ///
  /// Drives the banner at the top of the form: a nurse who has just typed a
  /// temperature of 39.8 should be told before they tap save, not after.
  Color? get worstFlag => VitalRange.worst([
        VitalRange.temperature(temperature),
        VitalRange.pulse(pulse),
        VitalRange.bloodPressure(systolic, diastolic),
      ]);

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments is Map) {
      firstName = (arguments['firstName'] ?? '').toString();
      lastName = (arguments['lastName'] ?? '').toString();
      age = arguments['age'] is int ? arguments['age'] as int : null;
      sex = arguments['gender'] as String?;
      phone = (arguments['phone'] ?? '').toString();
    }
  }

  void onVitalChanged(String _) => vitalsRevision.value++;

  String? validateComplaint(String? value) => (value ?? '').trim().isEmpty
      ? 'What has brought them in?'
      : null;

  String? validateTemperature(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final celsius = double.tryParse(text);
    if (celsius == null) return 'Enter a number';
    // A plausibility guard, not a clinical one: 25–45 covers every survivable
    // reading, and catches a decimal point typed in the wrong place.
    if (celsius < 25 || celsius > 45) return 'Between 25 and 45 °C';
    return null;
  }

  String? validatePulse(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final bpm = int.tryParse(text);
    if (bpm == null) return 'Enter a number';
    if (bpm < 20 || bpm > 250) return 'Between 20 and 250 bpm';
    return null;
  }

  String? validateSystolic(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final mmHg = int.tryParse(text);
    if (mmHg == null) return 'Enter a number';
    if (mmHg < 40 || mmHg > 300) return 'Between 40 and 300';
    return null;
  }

  String? validateDiastolic(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final mmHg = int.tryParse(text);
    if (mmHg == null) return 'Enter a number';
    if (mmHg < 20 || mmHg > 200) return 'Between 20 and 200';
    // Caught here because the pair is meaningless the wrong way round, and a
    // server that stores it produces a chart nobody can read.
    final top = systolic;
    if (top != null && mmHg >= top) {
      return 'Diastolic must be below systolic';
    }
    return null;
  }

  Future<void> save() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      final response = await _service.createScreening(
        firstName: firstName,
        lastName: lastName.isEmpty ? null : lastName,
        age: age,
        gender: sex,
        phone: phone.isEmpty ? null : phone,
        chiefComplaint: complaintController.text.trim(),
        briefHistory: historyController.text.trim().isEmpty
            ? null
            : historyController.text.trim(),
        temperature: temperature,
        pulse: pulse,
        bpSystolic: systolic,
        bpDiastolic: diastolic,
        routedTo: route.value,
      );

      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        errorMessage.value =
            envelopeMessage(response.data) ?? "Couldn't save the screening.";
        return;
      }

      if (Get.isRegistered<DataBus>()) {
        DataBus.to.changedRecord('pre-triage');
      }
      // Back past step one as well: the two screens are one task, and leaving
      // step one on the stack means Back from the board reopens a half-filled
      // form for a patient already screened.
      Get.close(2);
      showBentoToast('Screening saved for $fullName.');
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't save the screening.");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    complaintController.dispose();
    historyController.dispose();
    temperatureController.dispose();
    pulseController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    super.onClose();
  }
}
