import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/app_log.dart';
import '../../../data/models/department.dart';
import '../../../data/models/role.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/network/dio_client.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../theme/theme.dart';
import '../../users/staff_directory.dart';

/// Adding somebody, or editing them.
///
/// One controller for both, because they are one form: the differences are the
/// title, the verb on the button, and the two fields a create carries that an
/// edit must not.
///
/// **Which write shape this form sends is decided by which route the directory
/// could read.** `/api/users` takes `firstName` + `lastName`;
/// `/api/settings/users` takes a single `fullName` and declares `role`
/// `@IsNotEmpty()`. Sending one route the other's keys is a 400 — the server
/// validates with `forbidNonWhitelisted` — so the form asks
/// [StaffDirectory.usesSettingsRoute] rather than guessing, and shows the
/// fields the answering route actually accepts.
class UserFormController extends GetxController {
  static UserFormController get to => Get.find<UserFormController>();

  static const StaffDirectory _directory = StaffDirectory();

  /// Roles whose holder practises on a patient, and whose licence number is
  /// therefore not optional.
  ///
  /// Matched against the normalised role token rather than the pretty label,
  /// because the column stores `LAB_TECHNICIAN` and a site may spell it
  /// `LAB TECHNICIAN` in its own custom role.
  static const Set<String> clinicalRoles = {
    'DOCTOR',
    'PHYSICIAN',
    'CONSULTANT',
    'NURSE',
    'LAB_TECHNICIAN',
    'LABORATORY_TECHNICIAN',
    'RADIOLOGIST',
  };

  final formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final employeeIdController = TextEditingController();
  final specializationController = TextEditingController();
  final licenceController = TextEditingController();

  final role = RxnString();
  final departmentId = RxnString();

  final roles = <Role>[].obs;
  final departments = <Department>[].obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// How many fields failed the last attempt, for `FieldErrorSummary`.
  final invalidCount = 0.obs;

  /// The account being edited, or null when adding.
  StaffUser? editing;

  bool get isEdit => editing != null;

  /// True when the settings route is the one answering, so the name is one
  /// field rather than two and a role is mandatory.
  bool get usesFullName => StaffDirectory.usesSettingsRoute;

  DioClient get _client => Get.find<DioClient>();

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final passed = argument is Map ? argument['user'] : argument;
    if (passed is StaffUser) _fill(passed);
  }

  @override
  void onReady() {
    super.onReady();
    _loadRoles();
    _loadDepartments();
  }

  void _fill(StaffUser user) {
    editing = user;
    fullNameController.text = user.displayName;

    // The split columns where the row carries them. A row created through the
    // settings route has only `fullName`, so the halves are taken at the first
    // space: that is wrong for "van der Berg" and it is still better than
    // sending `firstName: ''`, which `CreateUserDto` rejects outright and
    // `UpdateUserDto` would store as a blank name.
    final first = (user.firstName ?? '').trim();
    final last = (user.lastName ?? '').trim();
    if (first.isNotEmpty || last.isNotEmpty) {
      firstNameController.text = first;
      lastNameController.text = last;
    } else {
      final cut = user.displayName.trim().indexOf(' ');
      firstNameController.text =
          cut == -1 ? user.displayName.trim() : user.displayName.substring(0, cut);
      lastNameController.text =
          cut == -1 ? '' : user.displayName.substring(cut + 1).trim();
    }

    emailController.text = user.email;
    phoneController.text = user.phone ?? '';
    employeeIdController.text = user.employeeId ?? '';
    specializationController.text = user.specialization ?? '';
    licenceController.text = user.licenseNumber ?? '';
    role.value = (user.role ?? '').isEmpty ? null : user.role;
    departmentId.value =
        (user.departmentId ?? '').isEmpty ? null : user.departmentId;
  }

  // ── Options ───────────────────────────────────────────────────────────────

  /// The catalogue, plus whatever this record already holds.
  ///
  /// A role the catalogue does not carry still belongs in this record's own
  /// picker: an empty field on an edit form reads as "this was never set", and
  /// saving it back that way rewrites the account's role membership — the
  /// backend deletes every `userRole` row and rebuilds it from this string.
  List<PickerOption<String>> get roleOptions {
    final names = <String>{
      for (final entry in roles) entry.name,
      if ((role.value ?? '').isNotEmpty) role.value!,
    }..removeWhere((name) => name.isEmpty);

    final sorted = names.toList()..sort();
    return [
      for (final name in sorted)
        PickerOption<String>(value: name, label: _labelForRole(name)),
    ];
  }

  List<PickerOption<String>> get departmentOptions => [
        for (final department in departments)
          PickerOption<String>(
            value: department.id,
            label: department.name,
          ),
      ];

  String? get roleLabel =>
      (role.value ?? '').isEmpty ? null : _labelForRole(role.value!);

  String? get departmentLabel {
    final id = departmentId.value;
    if (id == null || id.isEmpty) return null;
    final match = departments.firstWhereOrNull((d) => d.id == id);
    return match?.name ?? editing?.departmentName;
  }

  String _labelForRole(String name) =>
      roles.firstWhereOrNull((r) => r.name == name)?.displayName ??
      Role(name: name).displayName;

  /// True when the chosen role is one that treats patients.
  bool get isClinicalRole => clinicalRoles.contains(_normalised(role.value));

  static String _normalised(String? raw) =>
      (raw ?? '').trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateEmail(String? value) {
    if (isEdit) return null;
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'An email address is how somebody signs in';
    // Deliberately loose. The server runs `@IsEmail()` and it is the authority;
    // this only catches the typo before a round trip.
    if (!text.contains('@') || !text.contains('.')) {
      return 'That does not look like an email address';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (isEdit) return null;
    final text = value ?? '';
    if (text.isEmpty) {
      // The settings route used to create accounts with no password at all,
      // and the person could then never sign in: login refuses a user with no
      // hash and points at an invitation flow that does not exist.
      return 'Set a first password — there is no invitation email';
    }
    if (text.length < 8) return 'At least 8 characters';
    return null;
  }

  String? validateFirstName(String? value) {
    if (usesFullName) return null;
    return (value ?? '').trim().isEmpty ? 'A first name is required' : null;
  }

  String? validateLastName(String? value) {
    if (usesFullName) return null;
    return (value ?? '').trim().isEmpty ? 'A last name is required' : null;
  }

  String? validateFullName(String? value) {
    if (!usesFullName) return null;
    return (value ?? '').trim().isEmpty ? 'A name is required' : null;
  }

  /// The settings route declares `role` `@IsNotEmpty()` on create; the paged
  /// route treats it as optional. Asked here rather than discovered as a 400.
  String? validateRole(String? value) {
    if (!usesFullName || isEdit) return null;
    return (value ?? '').trim().isEmpty
        ? 'Choose a role — this directory requires one'
        : null;
  }

  /// A licence number is not paperwork for these roles.
  ///
  /// A doctor, nurse, technician or radiologist signs results and prescriptions
  /// under a registration number, and an account that carries none puts an
  /// unattributable signature on a patient's record. Checked here so the
  /// message can say *why* rather than leaving the server to answer "licence
  /// number should not be empty".
  String? validateLicence(String? value) {
    if (!isClinicalRole) return null;
    if ((value ?? '').trim().isNotEmpty) return null;
    return 'A ${_labelForRole(role.value ?? '').toLowerCase()} signs results '
        'under a registration number — record it here';
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<void> save() async {
    if (isSubmitting.value) return;

    if (!(formKey.currentState?.validate() ?? false)) {
      invalidCount.value = _countProblems();
      return;
    }
    invalidCount.value = 0;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final values = StaffFormValues(
      // Create only, on both routes. `UpdateUserDto` is
      // `PartialType(OmitType(CreateUserDto, ['password', 'email']))` and
      // `UpdateSettingsUserDto` declares neither, so either key on a PUT is a
      // 400 — `StaffFormValues` carries them and the draft drops them.
      email: isEdit ? null : emailController.text.trim(),
      password: isEdit ? null : passwordController.text,
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      fullName: usesFullName
          ? fullNameController.text.trim()
          : [firstNameController.text.trim(), lastNameController.text.trim()]
              .where((part) => part.isNotEmpty)
              .join(' '),
      phone: phoneController.text.trim(),
      employeeId: employeeIdController.text.trim(),
      role: role.value,
      departmentId: departmentId.value,
      specialization: specializationController.text.trim(),
      licenseNumber: licenceController.text.trim(),
    );

    final name = usesFullName
        ? values.fullName ?? ''
        : [values.firstName, values.lastName]
            .whereType<String>()
            .where((part) => part.isNotEmpty)
            .join(' ');

    try {
      if (isEdit) {
        await _directory.updateAccount(editing!.id, values);
      } else {
        await _directory.createAccount(values);
      }
      Get.back<void>();
      showBentoToast(isEdit ? '$name updated.' : '$name can sign in now.');
    } on ApiForbiddenException catch (e) {
      errorMessage.value = e.message;
    } catch (e, stack) {
      AppLog.error('UserFormController', 'staff save failed', e, stack);
      errorMessage.value = parseErrorMessage(e, "Couldn't save that account.");
    } finally {
      isSubmitting.value = false;
    }
  }

  /// How many fields are currently wrong, for the summary above the save bar.
  int _countProblems() => [
        validateEmail(emailController.text),
        validatePassword(passwordController.text),
        validateFirstName(firstNameController.text),
        validateLastName(lastNameController.text),
        validateFullName(fullNameController.text),
        validateRole(role.value),
        validateLicence(licenceController.text),
      ].whereType<String>().length;

  // ── Lookups ───────────────────────────────────────────────────────────────

  Future<void> _loadRoles() async {
    try {
      final response = await _client.get(Endpoints.roles.list);
      roles.assignAll(
        ApiEnvelope.of(response).orThrow().listOf(Role.fromJson),
      );
    } on ApiForbiddenException catch (e) {
      // The picker then offers only the role this record already holds. Not a
      // banner: a user administrator without `ROLE_READ` is a shape the server
      // ships, and the form is still usable.
      AppLog.info('UserFormController', 'roles refused: ${e.message}');
    } catch (e, stack) {
      AppLog.error('UserFormController', 'role catalogue failed', e, stack);
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final response = await _client.get(Endpoints.departments.list);
      departments.assignAll(
        ApiEnvelope.of(response).orThrow().listOf(Department.fromJson),
      );
    } on ApiForbiddenException catch (e) {
      AppLog.info('UserFormController', 'departments refused: ${e.message}');
    } catch (e, stack) {
      AppLog.error('UserFormController', 'department list failed', e, stack);
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    employeeIdController.dispose();
    specializationController.dispose();
    licenceController.dispose();
    super.onClose();
  }
}
