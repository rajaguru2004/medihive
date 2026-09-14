import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/unsaved_changes.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/consultation_model.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/drafts/consultation_draft.dart';
import '../../../data/models/drafts/lab_drafts.dart';
import '../../../data/models/drafts/radiology_drafts.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/json.dart';
import '../../../data/models/lab_test.dart';
import '../../../data/models/patient_ref.dart';
import '../../../data/models/radiology_exam.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/models/vitals_reading.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/repositories/clinical_repository.dart';
import '../../../data/repositories/crud_repository.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/laboratory_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/formatters.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../consultations/consultation_routes.dart';

/// The four faces of the write-up.
///
/// Four rather than the seven groups the document actually has, because
/// `BentoSegmented` holds two to four and a picker above a form is a control
/// nobody finds. Each tab carries its own `FormCard`s, so the seven groups all
/// survive — they are simply stacked two or three to a tab.
enum ConsultationTab { visit, vitals, notes, plan }

/// One drug on the script, while it is being written.
///
/// Its own object rather than a map because it owns six `TextEditingController`s
/// and something has to dispose them. A row removed from the list disposes its
/// own; the controller disposes whatever is left.
class PrescriptionRow {
  PrescriptionRow();

  final drug = Rxn<Drug>();
  final dosage = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final instructions = TextEditingController();

  int get quantityValue => int.tryParse(quantity.text.trim()) ?? 0;

  bool get isEmpty =>
      drug.value == null &&
      dosage.text.trim().isEmpty &&
      frequency.text.trim().isEmpty &&
      duration.text.trim().isEmpty &&
      instructions.text.trim().isEmpty;

  /// What is still missing before this line can be dispensed.
  ///
  /// The DTO requires all four; a script that reaches the counter without a
  /// frequency is a script the pharmacist has to telephone about.
  List<String> get problems => [
        if (drug.value == null) 'a drug',
        if (dosage.text.trim().isEmpty) 'a dose',
        if (frequency.text.trim().isEmpty) 'a frequency',
        if (duration.text.trim().isEmpty) 'a duration',
        if (quantityValue < 1) 'a quantity',
      ];

  bool get isComplete => problems.isEmpty;

  ConsultationPrescriptionItemDraft toDraft() =>
      ConsultationPrescriptionItemDraft(
        drugId: drug.value?.id,
        drugName: drug.value?.drugName,
        genericName: drug.value?.genericName,
        dosage: dosage.text,
        frequency: frequency.text,
        duration: duration.text,
        quantity: quantityValue,
        instructions: instructions.text,
      );

  void dispose() {
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
    quantity.dispose();
    instructions.dispose();
  }
}

/// Writing up what happened in the room.
///
/// The longest form in the app, and the one with the most to lose: a
/// consultation is twenty minutes of typing, and on Android that is one edge
/// swipe from gone. Everything about its shape follows from two facts — it must
/// not lose work, and it must warn about a reading in words rather than in
/// colour alone.
class ConsultationFormController extends GetxController
    with LoadStateMixin, UnsavedChanges {
  static ConsultationFormController get to =>
      Get.find<ConsultationFormController>();

  static const _consultations = ConsultationRepository();
  static const _laboratory = LaboratoryService();
  static const _imagingExams = RadiologyExamRepository();
  static const _imagingOrders = RadiologyOrderRepository();

  /// The pharmacy catalogue, searched rather than listed: a formulary is longer
  /// than any picker can hold, and `GET /pharmacy/drugs` takes a `search`.
  static const CrudRepository<Drug> _drugs =
      CrudRepository<Drug>(Endpoints.drugs, Drug.fromJson, 'drugs');

  final formKey = GlobalKey<FormState>();

  final tab = ConsultationTab.visit.obs;

  // ── Visit ─────────────────────────────────────────────────────────────────

  final patient = Rxn<PatientRef>();
  final doctor = Rxn<DoctorModel>();
  final visitDate = Rx<DateTime>(_today());
  final visitType = 'outpatient'.obs;
  final doctors = <DoctorModel>[].obs;

  /// A visit type is a category, not an acuity. `emergency` here means "came
  /// through the ED"; routed through the status ramp it would paint the record
  /// red, and red means a deteriorating patient.
  static const Map<String, String> visitTypes = {
    'outpatient': 'Outpatient',
    'follow_up': 'Follow-up',
    'emergency': 'Emergency',
    'inpatient': 'Inpatient',
  };

  // ── Vitals ────────────────────────────────────────────────────────────────

  final temperatureController = TextEditingController();
  final systolicController = TextEditingController();
  final diastolicController = TextEditingController();
  final pulseController = TextEditingController();
  final respiratoryController = TextEditingController();
  final saturationController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();

  /// Bumped on every keystroke in an observation field, so the units recolour
  /// and the banner reappears as the reading is typed rather than after it is
  /// saved.
  final vitalsRevision = 0.obs;

  // ── Notes, diagnosis, plan ────────────────────────────────────────────────

  final complaintController = TextEditingController();
  final historyController = TextEditingController();
  final examinationController = TextEditingController();
  final diagnosisController = TextEditingController();
  final icdController = TextEditingController();
  final planController = TextEditingController();
  final icdCodes = <String>[].obs;

  // ── Prescription ──────────────────────────────────────────────────────────

  final items = <PrescriptionRow>[].obs;

  // ── Orders ────────────────────────────────────────────────────────────────

  final labCatalogue = <LabTest>[].obs;
  final imagingCatalogue = <RadiologyExam>[].obs;
  final selectedTests = <LabTest>[].obs;
  final selectedExams = <RadiologyExam>[].obs;

  /// Which orders did not go through after the consultation itself saved.
  ///
  /// Named rather than counted: "one order failed" tells a clinician to check
  /// all of them, and the whole point of raising them from here is that they do
  /// not have to.
  final orderFailures = <String>[].obs;

  // ── Follow-up ─────────────────────────────────────────────────────────────

  final followUpDate = Rxn<DateTime>();
  final followUpController = TextEditingController();
  final referredToController = TextEditingController();
  final referralReasonController = TextEditingController();
  final notesController = TextEditingController();

  // ── Form state ────────────────────────────────────────────────────────────

  final isSubmitting = false.obs;
  final errorMessage = RxnString();
  final showErrors = false.obs;

  /// The id of the record once it exists. Set on a successful save, which is
  /// what lets a failed order be retried against the consultation it belongs to
  /// rather than by writing the consultation again.
  final savedId = RxnString();

  String _id = '';
  String _incomingPatientId = '';
  String? _appointmentId;

  bool get isEditing => _id.isNotEmpty;

  // ── Access ────────────────────────────────────────────────────────────────

  bool _can(String module, AccessVerb verb) =>
      !Get.isRegistered<AccessService>() ||
      AccessService.to.can(module, verb);

  bool get canSave => _can(
        Modules.consultations,
        isEditing ? AccessVerb.update : AccessVerb.create,
      );

  bool get canOrderLab => _can(Modules.laboratory, AccessVerb.create);
  bool get canOrderImaging => _can(Modules.radiology, AccessVerb.create);

  /// The orders card exists only for an account that can raise at least one
  /// kind of request. Absent, not disabled: a control that cannot be used is a
  /// control somebody presses twice before reading why.
  bool get canOrder => canOrderLab || canOrderImaging;

  // ── Site conventions ──────────────────────────────────────────────────────

  static SiteSettings get _site => Get.isRegistered<SettingsService>()
      ? SettingsService.to.settings
      : SiteSettings.empty;

  String formatDate(DateTime value) =>
      Formatters.date(value, pattern: _site.dateFormat);

  // ── Observations ──────────────────────────────────────────────────────────
  //
  // Every one of these guards `<= 0`, not just null. This backend stores an
  // unobserved numeric vital as `0`, and a half-typed field parses the same
  // way — so a zero temperature judged as a reading renders as hypothermia,
  // which is a red that is not a deteriorating patient.

  double? get temperature => _positiveDouble(temperatureController);
  double? get weight => _positiveDouble(weightController);
  double? get height => _positiveDouble(heightController);

  int? get systolic => _positiveInt(systolicController);
  int? get diastolic => _positiveInt(diastolicController);
  int? get pulse => _positiveInt(pulseController);
  int? get respiratoryRate => _positiveInt(respiratoryController);
  int? get oxygenSaturation => _positiveInt(saturationController);

  static double? _positiveDouble(TextEditingController field) {
    final value = double.tryParse(field.text.trim());
    return value == null || value <= 0 ? null : value;
  }

  static int? _positiveInt(TextEditingController field) {
    final value = int.tryParse(field.text.trim());
    return value == null || value <= 0 ? null : value;
  }

  /// The observations as one object, so the warning this form raises and the
  /// warning the record raises afterwards are the same sentence rather than two
  /// that drifted apart.
  VitalsReading get reading => VitalsReading(
        temperature: temperature,
        systolic: systolic,
        diastolic: diastolic,
        pulse: pulse,
        respiratoryRate: respiratoryRate,
        oxygenSaturation: oxygenSaturation,
        weight: weight,
        height: height,
      );

  Color? get vitalsFlag => reading.flag;

  /// The warning in words, naming the readings it is about.
  ///
  /// Colour alone fails three readers at once: somebody colour-blind, somebody
  /// holding a printout, and somebody reading the screen from across the room.
  String? get vitalsWarning => reading.warning;

  void onVitalChanged(String _) => vitalsRevision.value++;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    _id = ConsultationRoutes.idFrom(arguments, Get.parameters);

    final args = arguments is Map ? arguments : const {};
    final passed = args['patient'];
    if (passed is PatientRef) patient.value = passed;

    final incoming = args['patientId'];
    if (incoming is String) _incomingPatientId = incoming;

    final appointment = args['appointmentId'];
    if (appointment is String && appointment.isNotEmpty) {
      _appointmentId = appointment;
      // A consultation opened from a booking is a follow-through on it, so the
      // visit type starts where the booking left it rather than at the default.
      final type = args['appointmentType'];
      if (type is String && visitTypes.containsKey(type)) {
        visitType.value = type;
      }
    }

    final complaint = args['chiefComplaint'];
    if (complaint is String && complaint.trim().isNotEmpty) {
      complaintController.text = complaint.trim();
    }

    // One empty line to start on. A repeatable section that opens with nothing
    // in it reads as a section with nothing to add.
    items.add(PrescriptionRow());
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          doctors.assignAll(await ClinicLookups.doctors());

          if (isEditing) {
            _adopt(await _consultations.read(_id));
            savedId.value = _id;
          } else {
            await _resolveIncomingPatient();
          }

          await _loadCatalogues();
          markSaved();
        },
        fallback: "Couldn't open that consultation.",
      );

  /// The two catalogues the orders card picks from.
  ///
  /// Unguarded, and only fetched for an account that can raise an order: a
  /// catalogue that failed to load must not blank a consultation somebody is
  /// part-way through writing, and a clinician who cannot order anything should
  /// not pay two requests to find that out.
  Future<void> _loadCatalogues() async {
    if (!canOrder) return;
    if (canOrderLab) {
      try {
        final page = await _laboratory.tests.list(const PagedQuery(limit: 100));
        labCatalogue.assignAll(page.items.where((test) => test.isActive));
      } catch (_) {
        labCatalogue.clear();
      }
    }
    if (canOrderImaging) {
      try {
        final exams = await _imagingExams.catalogue();
        imagingCatalogue.assignAll(exams.where((exam) => exam.isActive));
      } catch (_) {
        imagingCatalogue.clear();
      }
    }
  }

  Future<void> _resolveIncomingPatient() async {
    if (patient.value != null || _incomingPatientId.isEmpty) return;
    try {
      patient.value = await ClinicLookups.patients.read(_incomingPatientId);
    } catch (_) {
      patient.value = PatientRef(id: _incomingPatientId);
    }
  }

  void _adopt(ConsultationModel record) {
    patient.value = PatientRef(
      id: record.patient.id,
      mrn: record.patient.mrn,
      firstName: record.patient.firstName,
      lastName: record.patient.lastName,
      phonePrimary: record.patient.phonePrimary,
      gender: record.patient.gender,
      dateOfBirth: record.patient.dateOfBirth,
    );
    doctor.value = doctors.firstWhereOrNull((d) => d.id == record.doctorId) ??
        (record.doctor.id.isEmpty ? null : record.doctor);
    visitDate.value = record.visitDate.toLocal();
    if (visitTypes.containsKey(record.visitType)) {
      visitType.value = record.visitType;
    }

    // `toStringAsFixed(1)` rather than `toString`: a stored 37.0 reads as
    // "37.0" the way a chart writes it, not "37". Zero is not written back at
    // all — the column's zero means "not observed", and putting it in the field
    // would turn an absence into a reading.
    temperatureController.text = _fixed(record.temperature);
    weightController.text = _fixed(record.weight);
    heightController.text = _fixed(record.height);
    systolicController.text = _whole(record.bloodPressureSystolic);
    diastolicController.text = _whole(record.bloodPressureDiastolic);
    pulseController.text = _whole(record.pulseRate);
    respiratoryController.text = _whole(record.respiratoryRate);
    saturationController.text = _whole(record.oxygenSaturation);

    complaintController.text = record.chiefComplaint;
    historyController.text = record.historyOfPresentIllness ?? '';
    examinationController.text = record.physicalExamination ?? '';
    diagnosisController.text = record.diagnosis ?? '';
    planController.text = record.treatmentPlan ?? '';
    // The column holds JSON text, so a read comes back as a string however it
    // was written.
    icdCodes.assignAll(asStringList(record.icd10Codes));

    followUpDate.value = record.followUpDate?.toLocal();
    followUpController.text = record.followUpInstructions ?? '';
    referredToController.text = record.referredTo ?? '';
    referralReasonController.text = record.referralReason ?? '';
    notesController.text = record.notes ?? '';
  }

  static String _fixed(double? value) =>
      value == null || value <= 0 ? '' : value.toStringAsFixed(1);

  static String _whole(int? value) =>
      value == null || value <= 0 ? '' : '$value';

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<List<PatientRef>> searchPatients(String query) =>
      ClinicLookups.patients.search(query);

  Future<List<Drug>> searchDrugs(String query) => _drugs.search(query);

  void choosePatient(PatientRef value) => patient.value = value;
  void chooseDoctor(DoctorModel value) => doctor.value = value;
  void chooseVisitDate(DateTime? value) {
    if (value != null) visitDate.value = value;
  }

  void setVisitType(String value) => visitType.value = value;
  void showTab(ConsultationTab next) => tab.value = next;
  void chooseFollowUpDate(DateTime? value) => followUpDate.value = value;

  // ── ICD-10 ────────────────────────────────────────────────────────────────

  /// Adds whatever is in the box as a code.
  ///
  /// Upper-cased and de-duplicated, because `j20.9` and `J20.9` are the same
  /// diagnosis and a record carrying both reads as two.
  void addIcdCode([String? raw]) {
    final code = (raw ?? icdController.text).trim().toUpperCase();
    if (code.isEmpty) return;
    if (!icdCodes.contains(code)) icdCodes.add(code);
    icdController.clear();
  }

  void removeIcdCode(String code) => icdCodes.remove(code);

  // ── Prescription ──────────────────────────────────────────────────────────

  void addPrescriptionRow() => items.add(PrescriptionRow());

  void removePrescriptionRow(int index) {
    if (index < 0 || index >= items.length) return;
    items.removeAt(index).dispose();
    // Never leave the section with nothing in it: an empty repeatable reads as
    // a section that cannot be added to.
    if (items.isEmpty) items.add(PrescriptionRow());
  }

  void chooseDrug(int index, Drug drug) {
    if (index < 0 || index >= items.length) return;
    final row = items[index];
    row.drug.value = drug;
    // The strength the catalogue already knows, so the commonest dose is one
    // fewer thing to type. Only when the field is untouched.
    if (row.dosage.text.trim().isEmpty && (drug.strength ?? '').isNotEmpty) {
      row.dosage.text = drug.strength!;
    }
    items.refresh();
  }

  /// The lines a clinician actually filled in. A row left blank is not an
  /// error — it is the empty line the section always keeps at the bottom.
  List<PrescriptionRow> get writtenItems =>
      items.where((row) => !row.isEmpty).toList();

  // ── Orders ────────────────────────────────────────────────────────────────

  bool isTestSelected(String id) => selectedTests.any((t) => t.id == id);
  bool isExamSelected(String id) => selectedExams.any((e) => e.id == id);

  void toggleTest(LabTest test) {
    if (isTestSelected(test.id)) {
      selectedTests.removeWhere((t) => t.id == test.id);
    } else {
      selectedTests.add(test);
    }
  }

  void toggleExam(RadiologyExam exam) {
    if (isExamSelected(exam.id)) {
      selectedExams.removeWhere((e) => e.id == exam.id);
    } else {
      selectedExams.add(exam);
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateComplaint(String? value) =>
      (value ?? '').trim().isEmpty ? 'What brought them in?' : null;

  String? get patientError =>
      showErrors.value && (patient.value?.id.isEmpty ?? true)
          ? 'Choose the patient this consultation is about'
          : null;

  String? get doctorError => showErrors.value && doctor.value == null
      ? 'Choose the clinician who saw them'
      : null;

  /// What is wrong with each written prescription line, by index.
  Map<int, String> get prescriptionErrors {
    if (!showErrors.value) return const {};
    final errors = <int, String>{};
    for (var i = 0; i < items.length; i++) {
      final row = items[i];
      if (row.isEmpty || row.isComplete) continue;
      errors[i] = 'This line still needs ${_join(row.problems)}.';
    }
    return errors;
  }

  static String _join(List<String> parts) => parts.length == 1
      ? parts.single
      : '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';

  int get missingCount {
    if (!showErrors.value) return 0;
    var count = 0;
    if (patientError != null) count++;
    if (doctorError != null) count++;
    if (validateComplaint(complaintController.text) != null) count++;
    count += prescriptionErrors.length;
    return count;
  }

  /// The tab holding the first thing that is wrong.
  ///
  /// A form four tabs deep that refuses to save and marks a field the reader
  /// cannot see is a form that appears to do nothing. Saving takes them to it.
  ConsultationTab? get firstProblemTab {
    if (patientError != null || doctorError != null) {
      return ConsultationTab.visit;
    }
    if (validateComplaint(complaintController.text) != null) {
      return ConsultationTab.notes;
    }
    if (prescriptionErrors.isNotEmpty) return ConsultationTab.plan;
    return null;
  }

  // ── The payload ───────────────────────────────────────────────────────────

  ConsultationDraft get draft => ConsultationDraft(
        patientId: patient.value?.id,
        doctorId: doctor.value?.id,
        appointmentId: _appointmentId,
        visitType: visitType.value,
        temperature: temperature,
        bloodPressureSystolic: systolic,
        bloodPressureDiastolic: diastolic,
        pulseRate: pulse,
        respiratoryRate: respiratoryRate,
        weight: weight,
        height: height,
        oxygenSaturation: oxygenSaturation,
        chiefComplaint: complaintController.text,
        historyOfPresentIllness: historyController.text,
        physicalExamination: examinationController.text,
        diagnosis: diagnosisController.text,
        icd10Codes: icdCodes.toList(),
        treatmentPlan: planController.text,
        followUpInstructions: followUpController.text,
        followUpDate: followUpDate.value,
        referredTo: referredToController.text,
        referralReason: referralReasonController.text,
        notes: notesController.text,
        // Create only: the update DTO drops `prescriptionItems`, and a script
        // added after the fact goes to the pharmacy route instead.
        prescriptionItems: isEditing
            ? null
            : [for (final row in writtenItems) row.toDraft()],
      );

  /// What this form holds that the server does not.
  ///
  /// The chosen orders are folded in even though they are not part of the
  /// consultation's own body: a clinician who picked three tests and swiped
  /// back has lost three tests, and a guard that cannot see them would let
  /// them go without asking.
  @override
  Map<String, dynamic> unsavedPayload() => {
        ...isEditing ? draft.toUpdateJson() : draft.toCreateJson(),
        'labTests': [for (final test in selectedTests) test.id],
        'imagingExams': [for (final exam in selectedExams) exam.id],
      };

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (isSubmitting.value) return;
    showErrors.value = true;

    // The record may already exist: a save whose orders failed leaves the
    // consultation written and the requests outstanding, and pressing the bar
    // again must retry those rather than write the encounter twice.
    if (savedId.value != null && orderFailures.isNotEmpty) {
      await retryOrders();
      return;
    }

    final problem = firstProblemTab;
    if (problem != null) {
      tab.value = problem;
      // Painted after the tab switch, so the field being complained about is
      // the one on screen.
      formKey.currentState?.validate();
      errorMessage.value = null;
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;
    orderFailures.clear();

    final name = patient.value?.displayName ?? 'the patient';

    try {
      final saved = isEditing
          ? await _consultations.update(_id, draft.toUpdateJson())
          : await _consultations.create(draft.toCreateJson());

      final id = saved.id.isEmpty ? _id : saved.id;
      savedId.value = id;
      // Snapshotted the moment the record is safe, so nothing that happens to
      // the orders afterwards can make the guard ask about work already saved.
      markSaved();

      await _raiseOrders(id);

      if (orderFailures.isEmpty) {
        Get.back<void>();
        showBentoToast(
          isEditing
              ? "$name's consultation is updated."
              : "$name's consultation is saved.",
        );
      }
    } on ApiForbiddenException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value =
          parseErrorMessage(e, "Couldn't save that consultation.");
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Raises the lab and imaging requests the write-up asked for.
  ///
  /// After the consultation, and against its id — which is the whole reason
  /// they are separate calls. Each failure is named and the choice is kept, so
  /// a retry sends only what did not go through and the consultation itself is
  /// never at risk.
  Future<void> _raiseOrders(String consultationId) async {
    final patientId = patient.value?.id ?? '';
    if (patientId.isEmpty) return;

    final indication = diagnosisController.text.trim().isNotEmpty
        ? diagnosisController.text.trim()
        : complaintController.text.trim();

    final failures = <String>[];

    if (canOrderLab && selectedTests.isNotEmpty) {
      try {
        await _laboratory.orders.create(
          LabOrderDraft(
            patientId: patientId,
            consultationId: consultationId,
            tests: [
              for (final test in selectedTests)
                LabOrderTestDraft(testId: test.id, testName: test.testName),
            ],
            clinicalIndication: indication,
            provisionalDiagnosis: diagnosisController.text,
          ).toCreateJson(),
        );
        selectedTests.clear();
      } catch (e) {
        failures.add('The laboratory order could not be raised — '
            '${parseErrorMessage(e, 'the request was refused')}.');
      }
    }

    if (canOrderImaging) {
      final sent = <String>[];
      for (final exam in selectedExams) {
        try {
          await _imagingOrders.create(
            RadiologyOrderDraft(
              patientId: patientId,
              consultationId: consultationId,
              examId: exam.id,
              clinicalIndication: indication,
              provisionalDiagnosis: diagnosisController.text,
            ).toCreateJson(),
          );
          sent.add(exam.id);
        } catch (e) {
          failures.add('The imaging request for ${exam.displayName} could not '
              'be raised — ${parseErrorMessage(e, 'the request was refused')}.');
        }
      }
      selectedExams.removeWhere((exam) => sent.contains(exam.id));
    }

    orderFailures.assignAll(failures);
  }

  /// Tries the orders that failed again, against the consultation that is
  /// already saved.
  Future<void> retryOrders() async {
    final id = savedId.value;
    if (id == null || isSubmitting.value) return;
    isSubmitting.value = true;
    try {
      await _raiseOrders(id);
      if (orderFailures.isEmpty) {
        Get.back<void>();
        showBentoToast('The orders are raised.');
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Leaves the screen with the consultation saved and the failed orders still
  /// outstanding — deliberately, and with the reader having read why.
  void finish() {
    markSaved();
    Get.back<void>();
    showBentoToast(
      'The consultation is saved. Raise the outstanding orders from it.',
      tone: ToastTone.info,
    );
  }

  @override
  void onClose() {
    for (final row in items) {
      row.dispose();
    }
    temperatureController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    pulseController.dispose();
    respiratoryController.dispose();
    saturationController.dispose();
    weightController.dispose();
    heightController.dispose();
    complaintController.dispose();
    historyController.dispose();
    examinationController.dispose();
    diagnosisController.dispose();
    icdController.dispose();
    planController.dispose();
    followUpController.dispose();
    referredToController.dispose();
    referralReasonController.dispose();
    notesController.dispose();
    super.onClose();
  }

  static DateTime _today() {
    final now = AppClock.now();
    return DateTime(now.year, now.month, now.day);
  }
}
