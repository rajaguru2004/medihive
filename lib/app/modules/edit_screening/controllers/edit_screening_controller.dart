import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/pre_triage_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/pre_triage_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../theme/theme.dart';
import '../../new_screening_step2/controllers/new_screening_step2_controller.dart';

/// Edit an existing screening.
///
/// The same fields as the two-step form, on one screen, because editing is not
/// two jobs — whoever is correcting a record has the whole record in front of
/// them. The validators and the route list are reused from step two rather
/// than restated, so a rule changed there changes here too.
class EditScreeningController extends GetxController {
  static EditScreeningController get to => Get.find<EditScreeningController>();

  final _service = PreTriageService.to;

  final formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();
  final phoneController = TextEditingController();
  final complaintController = TextEditingController();
  final historyController = TextEditingController();
  final temperatureController = TextEditingController();
  final pulseController = TextEditingController();
  final systolicController = TextEditingController();
  final diastolicController = TextEditingController();

  final sex = RxnString();
  final route = RxnString();
  final isSubmitting = false.obs;
  final errorMessage = RxnString();
  final vitalsRevision = 0.obs;

  late final PreTriageModel screening;

  /// What [screening] is when nothing was handed over. Never rendered as a
  /// record — [isMissingRecord] is what the screen reads — but it keeps the
  /// field non-null so every other line here stays plain.
  static final PreTriageModel _noRecord = PreTriageModel(
    id: '',
    screeningId: '',
    firstName: '',
    chiefComplaint: '',
    status: 'screening',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// True when this screen was opened without a record to edit.
  ///
  /// A deep link, a shortcut from a build that passed the record differently,
  /// or a push that forgot the argument. The old code ended the expression in
  /// `!`, so all three were `Null check operator used on a null value` — which
  /// is Flutter's **red screen**, on a ward, with no way back but the system
  /// button.
  bool get isMissingRecord => screening.screeningId.isEmpty;

  static List<String> get routes => NewScreeningStep2Controller.routes;
  static const sexes = ['Male', 'Female', 'Other'];

  double? get temperature =>
      double.tryParse(temperatureController.text.trim());
  int? get pulse => int.tryParse(pulseController.text.trim());
  int? get systolic => int.tryParse(systolicController.text.trim());
  int? get diastolic => int.tryParse(diastolicController.text.trim());

  Color? get worstFlag {
    final flags = [
      VitalRange.temperature(temperature),
      VitalRange.pulse(pulse),
      VitalRange.bloodPressure(systolic, diastolic),
    ].whereType<Color>();
    if (flags.isEmpty) return null;
    return flags.contains(AppColors.acuityCritical)
        ? AppColors.acuityCritical
        : AppColors.acuityUrgent;
  }

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final passed = argument is PreTriageModel
        ? argument
        : (argument is Map ? argument['screening'] : null);
    screening = passed is PreTriageModel ? passed : _noRecord;

    if (isMissingRecord) return;

    firstNameController.text = screening.firstName;
    lastNameController.text = screening.lastName ?? '';
    ageController.text = screening.age?.toString() ?? '';
    phoneController.text = screening.phone ?? '';
    complaintController.text = screening.chiefComplaint;
    historyController.text = screening.briefHistory ?? '';
    // `toStringAsFixed` rather than `toString`: a stored 37.0 renders as "37.0"
    // the way a chart writes it, not "37".
    temperatureController.text =
        screening.temperature?.toStringAsFixed(1) ?? '';
    pulseController.text = screening.pulse?.toString() ?? '';
    systolicController.text = screening.bpSystolic?.toString() ?? '';
    diastolicController.text = screening.bpDiastolic?.toString() ?? '';

    sex.value = sexes.firstWhereOrNull(
      (s) => s.toLowerCase() == (screening.gender ?? '').trim().toLowerCase(),
    );
    route.value = routes.firstWhereOrNull(
      (r) => r.toLowerCase() == (screening.route ?? '').trim().toLowerCase(),
    );
  }

  void onVitalChanged(String _) => vitalsRevision.value++;

  // The validators are step two's, so a rule lives in one place.
  String? validateFirstName(String? value) =>
      (value ?? '').trim().isEmpty ? 'A first name is needed' : null;

  String? validateComplaint(String? value) =>
      (value ?? '').trim().isEmpty ? 'What has brought them in?' : null;

  String? validateTemperature(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final celsius = double.tryParse(text);
    if (celsius == null) return 'Enter a number';
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
    final top = systolic;
    if (top != null && mmHg >= top) return 'Diastolic must be below systolic';
    return null;
  }

  Future<void> save() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      final response = await _service.updateScreening(
        screening.id,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim().isEmpty
            ? null
            : lastNameController.text.trim(),
        age: int.tryParse(ageController.text.trim()),
        gender: sex.value,
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
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
            envelopeMessage(response.data) ?? "Couldn't save the changes.";
        return;
      }

      if (Get.isRegistered<DataBus>()) {
        DataBus.to.changedRecord('pre-triage');
      }
      Get.back<void>();
      showBentoToast('Screening updated.');
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't save the changes.");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    complaintController.dispose();
    historyController.dispose();
    temperatureController.dispose();
    pulseController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    super.onClose();
  }
}
