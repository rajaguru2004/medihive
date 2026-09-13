import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/appointment_model.dart';
import '../../../data/models/bed_model.dart';
import '../../../data/models/patient_lookup.dart';
import '../../../data/models/ward_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// Admit a patient into a bed.
///
/// Six choices, in the order somebody standing at a desk makes them: who,
/// where, why, and who is responsible. The form does not let a step be skipped
/// because each one narrows the next — a bed cannot be chosen before a ward,
/// and choosing one first is how a patient lands in the wrong bay.
class AdmitPatientController extends GetxController with LoadStateMixin {
  static AdmitPatientController get to => Get.find<AdmitPatientController>();

  final _service = Get.find<InpatientService>();

  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  final patients = <PatientLookup>[].obs;
  final wards = <WardModel>[].obs;
  final beds = <BedModel>[].obs;
  final doctors = <AppointmentDoctor>[].obs;

  final patient = Rxn<PatientLookup>();
  final ward = Rxn<WardModel>();
  final bed = Rxn<BedModel>();
  final admittingDoctor = Rxn<AppointmentDoctor>();
  final attendingDoctor = Rxn<AppointmentDoctor>();
  final admissionType = 'Routine admission'.obs;

  final isLoadingBeds = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  static const admissionTypeValues = <String, String>{
    'Routine admission': 'routine',
    'Emergency': 'emergency',
    'Ward transfer': 'transfer',
  };

  static List<String> get admissionTypes => admissionTypeValues.keys.toList();

  List<WardModel> get activeWards => wards.where((w) => w.isActive).toList();

  /// Only beds somebody can actually be put in.
  ///
  /// A picker that offers an occupied bed is a picker whose selection the
  /// server rejects, after the clinician has filled in everything else.
  List<BedModel> get vacantBeds => beds
      .where((b) => BedState.resolve(b.status) == BedState.vacant)
      .toList();

  bool get canSubmit =>
      patient.value != null &&
      bed.value != null &&
      reasonController.text.trim().isNotEmpty;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          final results = await Future.wait([
            _service.fetchPatients(query: '', limit: 100),
            _service.fetchWards(),
            _service.fetchDoctors(),
          ]);

          patients.assignAll(
            envelopeRows(results[0].data).map(PatientLookup.fromJson).toList(),
          );
          wards.assignAll(
            envelopeRows(results[1].data).map(WardModel.fromJson).toList(),
          );
          doctors.assignAll(
            envelopeRows(results[2].data)
                .map(AppointmentDoctor.fromJson)
                .toList(),
          );

          // A bed map can send somebody straight here with the bed already
          // chosen. Resolve it through its ward so the ward field is filled in
          // too, rather than showing a bed with no ward above it.
          final argument = Get.arguments;
          final incomingWard = argument is Map ? argument['wardId'] : null;
          if (incomingWard is String && incomingWard.isNotEmpty) {
            ward.value = wards.firstWhereOrNull((w) => w.id == incomingWard);
            await loadBeds();
            final incomingBed = argument is Map ? argument['bedId'] : null;
            if (incomingBed is String) {
              bed.value = beds.firstWhereOrNull((b) => b.id == incomingBed);
            }
          }
        },
        fallback: "Couldn't load what this form needs.",
      );

  Future<void> selectWard(WardModel? next) async {
    ward.value = next;
    // The old bed belonged to the old ward. Keeping it is how an admission
    // ends up pointing at a bed in a ward nobody selected.
    bed.value = null;
    await loadBeds();
  }

  Future<void> loadBeds() async {
    final wardId = ward.value?.id;
    if (wardId == null) {
      beds.clear();
      return;
    }
    isLoadingBeds.value = true;
    try {
      final response = await _service.fetchBeds(wardId: wardId);
      beds.assignAll(
        envelopeRows(response.data).map(BedModel.fromJson).toList(),
      );
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't load that ward's beds.");
    } finally {
      isLoadingBeds.value = false;
    }
  }

  String? validateReason(String? value) =>
      (value ?? '').trim().isEmpty ? 'Why is this patient being admitted?' : null;

  Future<void> submit() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (patient.value == null) {
      errorMessage.value = 'Choose the patient being admitted.';
      return;
    }
    if (bed.value == null) {
      errorMessage.value = 'Choose a ward and a bed.';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final name = patient.value!.fullName;

    try {
      final response = await _service.admitPatient(
        patientId: patient.value!.id,
        bedId: bed.value!.id,
        admissionType: admissionTypeValues[admissionType.value] ?? 'routine',
        admissionReason: reasonController.text.trim(),
        // The API requires both. Where only one clinician has been named they
        // are both — which is the truth on a routine admission anyway.
        admittingDoctorId:
            admittingDoctor.value?.id ?? attendingDoctor.value?.id ?? '',
        attendingDoctorId:
            attendingDoctor.value?.id ?? admittingDoctor.value?.id ?? '',
      );

      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        errorMessage.value =
            envelopeMessage(response.data) ?? "Couldn't admit $name.";
        return;
      }

      if (Get.isRegistered<DataBus>()) DataBus.to.changedBed();
      Get.back<void>();
      showBentoToast('$name admitted to bed ${bed.value!.bedNumber}.');
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't admit $name.");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    reasonController.dispose();
    super.onClose();
  }
}
