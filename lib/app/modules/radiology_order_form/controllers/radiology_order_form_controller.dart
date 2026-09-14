import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../data/models/drafts/radiology_drafts.dart';
import '../../../data/models/patient_lookup.dart';
import '../../../data/models/radiology_exam.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/repositories/crud_repository.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/formatters.dart';
import '../../../data/utils/load_state.dart';

/// Raising an imaging request.
///
/// The fields are in the order the decision is made: who, what, how soon, and
/// why. The last is not optional here even though the DTO allows it — a
/// request with no clinical indication on it is one the radiologist cannot
/// protocol and, for anything ionising, one nobody can justify.
class RadiologyOrderFormController extends GetxController with LoadStateMixin {
  static RadiologyOrderFormController get to =>
      Get.find<RadiologyOrderFormController>();

  /// Patients come from the register, which is too big to hold, so the picker
  /// searches the server rather than filtering a list.
  static const _patients = CrudRepository<PatientLookup>(
    Endpoints.patients,
    PatientLookup.fromJson,
    'patients',
  );

  final formKey = GlobalKey<FormState>();

  final indicationController = TextEditingController();
  final diagnosisController = TextEditingController();
  final historyController = TextEditingController();
  final notesController = TextEditingController();

  /// The whole catalogue, held so the picker can group it. Small by nature —
  /// a department runs tens of exams, not thousands.
  final exams = <RadiologyExam>[].obs;

  final patient = Rxn<PatientLookup>();
  final exam = Rxn<RadiologyExam>();
  final urgency = RadiologyUrgency.routine.obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// Why the patient field is unhappy.
  ///
  /// Held here because `AsyncPicker` does not wrap a `FormField` — it opens a
  /// sheet and hands back a value — so `formKey.currentState!.validate()` does
  /// not reach it and a refused save would otherwise mark every field but the
  /// one that is actually missing.
  final patientError = RxnString();

  /// How many fields the last refused save complained about.
  final invalidFields = 0.obs;

  /// The consultation this request came out of, when it came out of one.
  String? consultationId;

  /// The catalogue, grouped the way a requester thinks about it.
  ///
  /// By category, and by modality where a site has not filled the category in
  /// — `CT` and `MRI` are how the list is read even when nobody has tidied the
  /// metadata. Categories in alphabetical order, exams alphabetical inside
  /// them, so the same exam is in the same place every time.
  Map<String, List<RadiologyExam>> get examsByGroup {
    final groups = <String, List<RadiologyExam>>{};
    for (final entry in exams) {
      final category = (entry.examCategory ?? '').trim();
      final modality = (entry.modality ?? '').trim();
      final key = category.isNotEmpty
          ? Formatters.label(category)
          : modality.isNotEmpty
              ? modality.toUpperCase()
              : 'Other';
      groups.putIfAbsent(key, () => []).add(entry);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.examName.compareTo(b.examName));
    }
    return {
      for (final key in groups.keys.toList()..sort()) key: groups[key]!,
    };
  }

  /// True when the chosen exam needs contrast, which changes how the patient
  /// is prepared — consent, cannula, renal function — so it is raised on the
  /// form rather than discovered at the machine.
  bool get needsContrast => exam.value?.contrastRequired ?? false;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          exams.assignAll(await RadiologyRepositories.exams.catalogue());

          // Ordering from a consultation arrives with the patient already
          // decided. Resolved rather than trusted blind, so the form shows the
          // record back and the requester can check it is the right one.
          final args = Get.arguments;
          if (args is Map) {
            final incoming = args['patientId'];
            final consultation = args['consultationId'];
            if (consultation is String && consultation.isNotEmpty) {
              consultationId = consultation;
            }
            if (incoming is String && incoming.isNotEmpty) {
              patient.value = await _patients.read(incoming);
            }
          }
        },
        fallback: "Couldn't load what this form needs.",
      );

  /// The patient picker's own search.
  ///
  /// Never throws back into the sheet: a failed lookup shows "nothing found",
  /// which is wrong but survivable, where an exception inside a sheet's
  /// builder takes the whole form down.
  Future<List<PatientLookup>> searchPatients(String query) async {
    try {
      return await _patients.search(query, limit: 20);
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'patient search failed', e, stack);
      return const [];
    }
  }

  void choosePatient(PatientLookup chosen) {
    patient.value = chosen;
    patientError.value = null;
  }

  String? validateIndication(String? value) => (value ?? '').trim().isEmpty
      ? 'Say why this study is being asked for.'
      : null;

  String? validateExam(String? _) =>
      exam.value == null ? 'Choose the exam.' : null;

  /// Raises the order and answers with its id, or null when it did not go
  /// through.
  Future<String?> submit() async {
    if (isSubmitting.value) return null;

    // The picker first, because `validate()` cannot see it.
    patientError.value = patient.value == null ? 'Choose the patient.' : null;
    final fieldsValid = formKey.currentState?.validate() ?? false;

    if (!fieldsValid || patientError.value != null) {
      // The field being complained about is usually several screens up, so the
      // count goes above the save bar, where the refusal happened.
      invalidFields.value = _missingCount();
      return null;
    }
    invalidFields.value = 0;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      final created = await RadiologyRepositories.orders.create(
        RadiologyOrderDraft(
          patientId: patient.value!.id,
          consultationId: consultationId,
          examId: exam.value!.id,
          clinicalIndication: indicationController.text,
          provisionalDiagnosis: diagnosisController.text,
          relevantHistory: historyController.text,
          urgency: urgency.value,
          notes: notesController.text,
        ).toCreateJson(),
      );
      return created.id;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'imaging order failed', e, stack);
      errorMessage.value =
          parseErrorMessage(e, "Couldn't raise this imaging request.");
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  int _missingCount() {
    var count = 0;
    if (patient.value == null) count++;
    if (exam.value == null) count++;
    if (indicationController.text.trim().isEmpty) count++;
    return count;
  }

  @override
  void onClose() {
    indicationController.dispose();
    diagnosisController.dispose();
    historyController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
