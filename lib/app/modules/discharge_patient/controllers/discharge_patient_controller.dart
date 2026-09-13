import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/app_clock.dart';
import '../../../data/models/admission_model.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// Discharge a patient.
///
/// The one screen in this app that ends a record rather than starting one, and
/// the only one that asks for confirmation before it writes: a discharge frees
/// a bed, closes an admission and cannot be undone from the app.
class DischargePatientController extends GetxController with LoadStateMixin {
  static DischargePatientController get to =>
      Get.find<DischargePatientController>();

  final _service = Get.find<InpatientService>();

  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  final summaryController = TextEditingController();
  final followUpNotesController = TextEditingController();

  final admission = Rxn<AdmissionModel>();
  final doctors = <AppointmentDoctor>[].obs;
  final dischargingDoctor = Rxn<AppointmentDoctor>();
  final followUpDate = Rxn<DateTime>();
  final outcome = 'Recovered'.obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// Discharge outcomes, and what the API stores.
  ///
  /// "Died" is on the list because it is a real outcome and an app that omits
  /// it forces somebody to record a death as "other". It is deliberately last.
  static const outcomeValues = <String, String>{
    'Recovered': 'recovered',
    'Improved': 'improved',
    'Referred on': 'referred',
    'Transferred': 'transferred',
    'Self-discharge': 'self_discharge',
    'Died': 'died',
  };

  static List<String> get outcomes => outcomeValues.keys.toList();

  /// Whether a follow-up makes sense for the chosen outcome.
  bool get wantsFollowUp =>
      outcome.value != 'Died' && outcome.value != 'Transferred';

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          final argument = Get.arguments;
          final admissionId = argument is Map ? argument['admissionId'] : null;

          final results = await Future.wait([
            _service.fetchAdmissions(),
            _service.fetchDoctors(),
          ]);

          final rows = envelopeRows(results[0].data)
              .map(AdmissionModel.fromJson)
              .toList();
          admission.value = admissionId is String
              ? rows.firstWhereOrNull((a) => a.id == admissionId)
              : null;

          doctors.assignAll(
            envelopeRows(results[1].data)
                .map(AppointmentDoctor.fromJson)
                .toList(),
          );

          if (admission.value == null) {
            throw const FormatException(
              'That admission could not be found. It may already be closed.',
            );
          }
        },
        fallback: "Couldn't load the admission.",
      );

  String? validateReason(String? value) =>
      (value ?? '').trim().isEmpty ? 'Why is this patient going home?' : null;

  Future<void> pickFollowUpDate(BuildContext context) async {
    final now = AppClock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: followUpDate.value ?? now.add(const Duration(days: 7)),
      // No past dates: a follow-up already in the past is a typo, and the
      // picker is the cheapest place to catch it.
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) followUpDate.value = picked;
  }

  void clearFollowUp() => followUpDate.value = null;

  Future<void> submit() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    final record = admission.value;
    if (record == null) {
      errorMessage.value = 'No admission loaded.';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final name = record.patient.fullName;

    try {
      final response = await _service.dischargePatient(
        admissionId: record.id,
        dischargeReason: outcomeValues[outcome.value] ?? 'recovered',
        dischargeSummary: summaryController.text.trim().isEmpty
            ? reasonController.text.trim()
            : summaryController.text.trim(),
        dischargeDoctorId: dischargingDoctor.value?.id ?? '',
        followUpDate: wantsFollowUp ? followUpDate.value : null,
        followUpNotes:
            wantsFollowUp ? followUpNotesController.text.trim() : null,
      );

      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        errorMessage.value =
            envelopeMessage(response.data) ?? "Couldn't discharge $name.";
        return;
      }

      if (Get.isRegistered<DataBus>()) DataBus.to.changedBed();
      Get.back<void>();
      showBentoToast(
        '$name discharged. Bed ${record.bed.bedNumber} is free.',
      );
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't discharge $name.");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    reasonController.dispose();
    summaryController.dispose();
    followUpNotesController.dispose();
    super.onClose();
  }
}
