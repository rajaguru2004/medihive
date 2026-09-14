import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/drafts/lab_drafts.dart';
import '../../../data/models/lab_test.dart';
import '../../../data/models/patient_ref.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/repositories/crud_repository.dart';
import '../../../data/services/laboratory_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../laboratory/lab_status.dart';

/// Raising a lab order: who it is for, what to run, and how fast.
class LabOrderFormController extends GetxController with LoadStateMixin {
  static LabOrderFormController get to => Get.find<LabOrderFormController>();

  static const LaboratoryService _lab = LaboratoryService();

  /// Patients are searched, never listed: a hospital has more of them than any
  /// picker can hold.
  static const _patients =
      CrudRepository<PatientRef>(Endpoints.patients, PatientRef.fromJson, 'patients');

  final formKey = GlobalKey<FormState>();

  final indicationController = TextEditingController();
  final diagnosisController = TextEditingController();
  final notesController = TextEditingController();

  final patient = Rxn<PatientRef>();
  final priority = LabPriority.routine.obs;

  /// The catalogue, for the picker sheet. Grouped by category when it renders.
  final catalogue = <LabTest>[].obs;

  /// The tests on this order, in the order they were added.
  final selected = <LabTest>[].obs;

  /// Per-test urgency, above the order's own priority. Keyed by test id.
  final urgencies = <String, String>{}.obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// Set when the order is being raised from a consultation, so the record
  /// links back to the encounter that asked for it.
  String? consultationId;

  /// True once the person has tried to save. Until then a missing patient is
  /// not an error — it is a form nobody has filled in yet.
  final showErrors = false.obs;

  bool get hasTests => selected.isNotEmpty;

  /// The catalogue grouped the way a request form is laid out.
  Map<String, List<LabTest>> get catalogueByCategory {
    final groups = <String, List<LabTest>>{};
    for (final test in catalogue) {
      final category = (test.testCategory ?? '').trim();
      groups
          .putIfAbsent(category.isEmpty ? 'Other' : category, () => [])
          .add(test);
    }
    return groups;
  }

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final args = argument is Map ? argument : const {};

    final passed = args['patient'];
    if (passed is PatientRef) {
      patient.value = passed;
    } else if (passed is Map) {
      patient.value = PatientRef.of(passed);
    }

    final patientId = args['patientId'];
    if (patient.value == null && patientId is String && patientId.isNotEmpty) {
      // Only an id reached us — enough to send, not enough to name. The picker
      // shows the id rather than an empty field, so nobody submits an order
      // against a patient the screen never confirmed.
      patient.value = PatientRef(id: patientId, mrn: patientId);
    }

    final consultation = args['consultationId'];
    if (consultation is String && consultation.isNotEmpty) {
      consultationId = consultation;
    }
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(loadCatalogue());
  }

  /// Reads the whole active catalogue.
  ///
  /// One request: `GET /laboratory/tests` is a bare array with no paging, so
  /// there is no second page to follow and nothing to search server-side —
  /// the picker filters what it has.
  Future<void> loadCatalogue() => runGuarded(
        () async {
          final page = await _lab.tests.list(const PagedQuery(limit: 100));
          catalogue.assignAll(page.items.where((t) => t.isActive));
        },
        fallback: "Couldn't load the test catalogue.",
      );

  /// Patients, as the picker asks for them.
  Future<List<PickerOption<PatientRef>>> searchPatients(String query) async {
    final rows = await _patients.search(query);
    return [
      for (final row in rows)
        PickerOption<PatientRef>(
          value: row,
          label: row.displayName,
          sublabel: 'MRN ${row.mrn}',
        ),
    ];
  }

  void choosePatient(PatientRef value) => patient.value = value;

  bool isSelected(String testId) =>
      selected.any((test) => test.id == testId);

  void toggleTest(LabTest test) {
    if (isSelected(test.id)) {
      removeTest(test.id);
      return;
    }
    selected.add(test);
    // A test inherits the order's priority until somebody says otherwise: a
    // STAT order whose tests all say "routine" is an order the bench works in
    // the wrong sequence.
    urgencies[test.id] = priority.value;
  }

  void removeTest(String testId) {
    selected.removeWhere((test) => test.id == testId);
    urgencies.remove(testId);
  }

  void setUrgency(String testId, String urgency) =>
      urgencies[testId] = urgency;

  String urgencyOf(String testId) =>
      urgencies[testId] ?? priority.value;

  /// Changing the order's priority carries the tests that were following it.
  void setPriority(String value) {
    final previous = priority.value;
    priority.value = value;
    for (final test in selected) {
      if (urgencies[test.id] == previous) urgencies[test.id] = value;
    }
  }

  /// How many required fields are still empty, for the line above the save
  /// bar. Zero until somebody has actually tried to save: a form that opens
  /// complaining is a form that has told nobody anything.
  int get missingCount {
    if (!showErrors.value) return 0;
    var count = 0;
    final chosen = patient.value;
    if (chosen == null || chosen.id.isEmpty) count++;
    if (!hasTests) count++;
    if (indicationController.text.trim().isEmpty) count++;
    return count;
  }

  String? validateIndication(String? value) =>
      (value ?? '').trim().isEmpty ? 'Say why the lab is being asked' : null;

  Future<void> submit() async {
    showErrors.value = true;
    if (isSubmitting.value) return;

    final chosen = patient.value;
    if (chosen == null || chosen.id.isEmpty) {
      errorMessage.value = 'Choose the patient this order is for.';
      return;
    }
    if (!hasTests) {
      errorMessage.value = 'Add at least one test.';
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final draft = LabOrderDraft(
      patientId: chosen.id,
      consultationId: consultationId,
      tests: [
        for (final test in selected)
          LabOrderTestDraft(
            testId: test.id,
            testName: test.testName,
            urgency: urgencyOf(test.id),
          ),
      ],
      clinicalIndication: indicationController.text,
      provisionalDiagnosis: diagnosisController.text,
      priority: priority.value,
      notes: notesController.text,
    );

    try {
      final order = await _lab.orders.create(draft.toCreateJson());
      Get.back<void>();
      showBentoToast('Order ${order.orderNumber} raised.');
    } on ApiForbiddenException catch (e) {
      // The access map is a hint and can be a minute older than the role it
      // describes, so the button being there is never proof the write is
      // allowed.
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't raise that order.");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    indicationController.dispose();
    diagnosisController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
