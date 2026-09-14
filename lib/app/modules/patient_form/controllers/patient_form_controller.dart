import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../core/unsaved_changes.dart';
import '../../../data/models/drafts/patient_draft.dart';
import '../../../data/models/patient.dart';
import '../../../data/repositories/patient_repository.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../patients/patient_routes.dart';

/// Registering a patient, and editing one.
///
/// One controller for both, because they are one form: the differences are the
/// title, the verb on the button, the route the save goes to, and one switch
/// that only an edit has. Two controllers would be two places to add the next
/// field to, and a field added to one of them is a field the other silently
/// stops collecting.
///
/// Every rule below is copied from `hms_v2/src/modules/patients/dto/
/// create-patient.dto.ts`. Validating here is not a substitute for the
/// server's validation — it is what turns a round trip and a red banner into a
/// message under the field somebody is looking at.
class PatientFormController extends GetxController
    with LoadStateMixin, UnsavedChanges {
  static PatientFormController get to => Get.find<PatientFormController>();

  final PatientRepository _repository = patientRepository;

  final formKey = GlobalKey<FormState>();

  // ── Identity ──────────────────────────────────────────────────────────────
  final firstName = TextEditingController();
  final middleName = TextEditingController();
  final lastName = TextEditingController();
  final dateOfBirth = Rxn<DateTime>();
  final sex = RxnString();
  final bloodGroup = RxnString();

  // ── Contact ───────────────────────────────────────────────────────────────
  final phonePrimary = TextEditingController();
  final phoneSecondary = TextEditingController();
  final email = TextEditingController();
  final region = TextEditingController();
  final zone = TextEditingController();
  final woreda = TextEditingController();
  final kebele = TextEditingController();
  final houseNumber = TextEditingController();
  final addressDescription = TextEditingController();

  // ── Emergency contact ─────────────────────────────────────────────────────
  final emergencyName = TextEditingController();
  final emergencyPhone = TextEditingController();
  final emergencyRelationship = TextEditingController();

  // ── Insurance ─────────────────────────────────────────────────────────────
  final hasInsurance = false.obs;
  final insuranceProvider = TextEditingController();
  final insuranceId = TextEditingController();
  final insuranceExpiry = Rxn<DateTime>();

  // ── Clinical ──────────────────────────────────────────────────────────────
  final allergies = <String>[].obs;
  final chronicConditions = <String>[].obs;
  final currentMedications = <String>[].obs;
  final notes = TextEditingController();

  /// Update only. Deactivating a patient is not deleting one, and the create
  /// route has no such key — `PatientDraft.toCreateJson` leaves it out.
  final isActive = true.obs;

  // ── Submission ────────────────────────────────────────────────────────────
  final isSubmitting = false.obs;
  final submitError = RxnString();

  /// Fields the last attempted save was refused over, for the line above the
  /// button. A refusal that only marks the fields is a refusal nobody can
  /// see — the field it means is usually several screens up.
  final invalidCount = 0.obs;

  /// Set by [save] rather than by a `FormField`: neither the segmented control
  /// nor the date picker is one, and a required choice nobody made must fail
  /// louder than by staying empty.
  final sexError = RxnString();
  final dateOfBirthError = RxnString();

  /// The id being edited, or empty when registering.
  String _id = '';
  Patient _loaded = Patient.empty;

  String get id => _id;
  bool get isEdit => _id.isNotEmpty;
  Patient get loaded => _loaded;

  /// The three sexes the DTO's `@IsEnum` accepts. Anything else is a 400.
  static const List<String> sexes = ['male', 'female', 'other'];

  /// The groups a site actually records. Free text here would give one
  /// hospital `O+`, `O positive` and `o+` for one patient population.
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void onInit() {
    super.onInit();
    _id = PatientRoutes.idFrom(Get.arguments);

    // A registration has nothing to fetch, so its baseline is the empty form.
    // Taken here rather than in `onReady` because the guard is asked at the
    // moment of the back gesture, which can be before the first frame.
    if (!isEdit) markSaved();
  }

  @override
  void onReady() {
    super.onReady();
    if (isEdit) load();
  }

  Future<void> load() => runGuarded(
        () async {
          final patient = await _repository.read(_id);
          _loaded = patient;
          _fill(patient);
          // The baseline the unsaved-changes guard compares against. Taken
          // once the record is on screen, so a form that merely finished
          // loading is not "dirty".
          markSaved();
        },
        fallback: "Couldn't load that patient.",
      );

  void _fill(Patient patient) {
    firstName.text = patient.firstName;
    middleName.text = patient.middleName ?? '';
    lastName.text = patient.lastName;
    dateOfBirth.value = patient.dateOfBirth;
    // Matched case-insensitively: the column holds whatever a console wrote,
    // and `Male` compared directly against `male` leaves the control blank on
    // every edit — which then saves a null over a perfectly good value.
    sex.value = sexes.firstWhereOrNull(
      (value) => value == (patient.gender ?? '').trim().toLowerCase(),
    );
    bloodGroup.value = (patient.bloodGroup ?? '').trim().isEmpty
        ? null
        : patient.bloodGroup!.trim().toUpperCase();

    phonePrimary.text = patient.phonePrimary ?? '';
    phoneSecondary.text = patient.phoneSecondary ?? '';
    email.text = patient.email ?? '';
    region.text = patient.region ?? '';
    zone.text = patient.zone ?? '';
    woreda.text = patient.woreda ?? '';
    kebele.text = patient.kebele ?? '';
    houseNumber.text = patient.houseNumber ?? '';
    addressDescription.text = patient.addressDescription ?? '';

    emergencyName.text = patient.emergencyContactName ?? '';
    emergencyPhone.text = patient.emergencyContactPhone ?? '';
    emergencyRelationship.text = patient.emergencyContactRelationship ?? '';

    hasInsurance.value = patient.hasInsurance;
    insuranceProvider.text = patient.insuranceProvider ?? '';
    insuranceId.text = patient.insuranceId ?? '';
    insuranceExpiry.value = patient.insuranceExpiryDate;

    allergies.assignAll(patient.allergies);
    chronicConditions.assignAll(patient.chronicConditions);
    currentMedications.assignAll(patient.currentMedications);
    notes.text = patient.notes ?? '';

    isActive.value = patient.isActive;
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// `@IsString() @MinLength(2) @MaxLength(100)` on both name fields.
  String? validateGivenName(String? value) => _name(value, 'first name');

  String? validateFamilyName(String? value) => _name(value, 'last name');

  String? _name(String? value, String what) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the patient’s $what';
    if (text.length < 2) return 'A $what needs at least two letters';
    if (text.length > 100) return 'That $what is too long for the record';
    return null;
  }

  /// Optional, but capped at 100 like the rest.
  String? validateMiddleName(String? value) {
    final text = (value ?? '').trim();
    if (text.length > 100) return 'That middle name is too long for the record';
    return null;
  }

  /// `@IsEmail()`, and only when something was typed.
  ///
  /// Deliberately loose: the server is the authority, and a client regex that
  /// is stricter than the server's rejects addresses that would have worked.
  String? validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final looksLikeAnAddress =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return looksLikeAnAddress ? null : 'That does not look like an email address';
  }

  /// An insurance block with no provider on it is a record nobody can claim
  /// against, so the two fields under the switch are required once it is on.
  String? validateInsuranceProvider(String? value) {
    if (!hasInsurance.value) return null;
    return (value ?? '').trim().isEmpty ? 'Who is the cover with?' : null;
  }

  // ── Chip lists ────────────────────────────────────────────────────────────

  /// Adds one entry, deduplicated case-insensitively.
  ///
  /// "Penicillin" twice on an allergy list is a list a prescriber reads twice,
  /// and the second reading is the one that wastes the seconds.
  bool addTo(RxList<String> list, String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    final already = list.any(
      (existing) => existing.toLowerCase() == text.toLowerCase(),
    );
    if (already) return false;
    list.add(text);
    return true;
  }

  void removeFrom(RxList<String> list, String value) => list.remove(value);

  // ── Saving ────────────────────────────────────────────────────────────────

  PatientDraft draft() => PatientDraft(
        firstName: firstName.text,
        middleName: middleName.text,
        lastName: lastName.text,
        dateOfBirth: dateOfBirth.value,
        gender: sex.value,
        bloodGroup: bloodGroup.value,
        phonePrimary: phonePrimary.text,
        phoneSecondary: phoneSecondary.text,
        email: email.text,
        region: region.text,
        zone: zone.text,
        woreda: woreda.text,
        kebele: kebele.text,
        houseNumber: houseNumber.text,
        addressDescription: addressDescription.text,
        emergencyContactName: emergencyName.text,
        emergencyContactPhone: emergencyPhone.text,
        emergencyContactRelationship: emergencyRelationship.text,
        allergies: allergies.toList(),
        chronicConditions: chronicConditions.toList(),
        currentMedications: currentMedications.toList(),
        hasInsurance: hasInsurance.value,
        insuranceProvider: hasInsurance.value ? insuranceProvider.text : null,
        insuranceId: hasInsurance.value ? insuranceId.text : null,
        insuranceExpiryDate: hasInsurance.value ? insuranceExpiry.value : null,
        notes: notes.text,
        isActive: isActive.value,
      );

  /// What the guard compares against. The payload rather than a hand-kept
  /// flag, so a field added to this form is covered the day it is added.
  @override
  Map<String, dynamic> unsavedPayload() => draft().toUpdateJson();

  Future<void> save() async {
    if (isSubmitting.value) return;

    final formIsValid = formKey.currentState?.validate() ?? false;
    // Both checked every time, not short-circuited: somebody who has missed
    // the date *and* the sex should be told about both on one attempt.
    sexError.value = sex.value == null ? 'Choose one' : null;
    dateOfBirthError.value =
        dateOfBirth.value == null ? 'A date of birth is required' : null;

    final missing = [sexError.value, dateOfBirthError.value].nonNulls.length;
    if (!formIsValid || missing > 0) {
      // A count rather than a list: the fields are already marked, and the
      // line above the button exists to say that the marks are up there.
      invalidCount.value = (formIsValid ? 0 : 1) + missing;
      return;
    }

    invalidCount.value = 0;
    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    submitError.value = null;

    final body = draft();
    final name = '${firstName.text.trim()} ${lastName.text.trim()}'.trim();

    try {
      // The draft emits only the keys the DTO declares. Spreading a model's
      // `toJson` here would be a 400: the server runs `forbidNonWhitelisted`,
      // and `mrn`, `createdAt` and `organizationId` are all on the record and
      // on none of the write routes.
      final saved = isEdit
          ? await _repository.update(_id, body.toUpdateJson())
          : await _repository.create(body.toCreateJson());

      _loaded = saved;
      // Before leaving, so the guard does not ask about work that is now on
      // the server.
      markSaved();
      Get.back<Patient>(result: saved);
      showBentoToast(
        isEdit ? '$name updated.' : '$name registered as ${saved.mrn}.',
      );
    } catch (e, stack) {
      // Never logged with the name in it: an identifier in a log line is an
      // identifier on a device that holds patient data.
      AppLog.error('PatientFormController', 'patient save failed', e, stack);
      submitError.value = parseErrorMessage(
        e,
        isEdit ? "Couldn't save those changes." : "Couldn't register them.",
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    for (final field in [
      firstName,
      middleName,
      lastName,
      phonePrimary,
      phoneSecondary,
      email,
      region,
      zone,
      woreda,
      kebele,
      houseNumber,
      addressDescription,
      emergencyName,
      emergencyPhone,
      emergencyRelationship,
      insuranceProvider,
      insuranceId,
      notes,
    ]) {
      field.dispose();
    }
    super.onClose();
  }
}
