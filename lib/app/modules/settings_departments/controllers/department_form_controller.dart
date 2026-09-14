import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/department.dart';
import '../../../data/models/drafts/drafts.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/network/dio_client.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../theme/theme.dart';
import 'settings_departments_controller.dart';

/// Adding or editing one department.
///
/// One controller for both, because they are one form: the only differences are
/// the title, the verb on the button, and whether the write is a POST or a PUT.
/// Two controllers would be two places to add the next field to.
///
/// The asymmetry the draft documents is followed rather than smoothed over:
/// `organizationId` is **required** on create and **absent** from update.
/// Sending it on a PUT is a 400, and omitting it on a POST is a 400 the other
/// way.
class DepartmentFormController extends GetxController {
  static DepartmentFormController get to =>
      Get.find<DepartmentFormController>();

  DioClient get client => Get.find<DioClient>();

  final formKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final code = TextEditingController();
  final description = TextEditingController();

  final rxHeadId = RxnString();
  final rxHeadName = RxnString();
  final rxActive = true.obs;

  final rxSubmitting = false.obs;
  final rxDeleting = false.obs;
  final rxError = RxnString();
  final rxSubmitted = false.obs;

  /// The department being edited, or null when adding one.
  Department? editing;

  bool get isEdit => editing != null;

  bool get canWrite => AccessService.to.can(Modules.settings, AccessVerb.update);

  /// How many people are assigned to this department, where the list route
  /// counted them. Null means nobody counted, not that it is empty.
  int? get staffCount => editing?.staffCount;

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final department = argument is Map ? argument['department'] : argument;
    if (department is! Department) return;

    editing = department;
    name.text = department.name;
    code.text = department.code ?? '';
    description.text = department.description ?? '';
    rxHeadId.value = department.headId;
    rxHeadName.value = department.headName;
    rxActive.value = department.isActive;
  }

  @override
  void onClose() {
    name.dispose();
    code.dispose();
    description.dispose();
    super.onClose();
  }

  void setActive(bool value) => rxActive.value = value;

  void setHead(StaffUser staff) {
    rxHeadId.value = staff.id;
    rxHeadName.value = staff.displayName;
  }

  void clearHead() {
    rxHeadId.value = null;
    rxHeadName.value = null;
  }

  // ── The head-of-department picker ─────────────────────────────────────────

  /// Everyone the directory lists, for the picker that names a head.
  ///
  /// `GET /api/users/staff` answers a **bare array** with no `meta` and has no
  /// pagination DTO at all, so `role` is the only parameter it will read — and
  /// a head of department is not always a doctor, so none is sent.
  Future<List<StaffUser>> staff(String query) async {
    try {
      final response = await client.get(Endpoints.staff);
      final rows =
          ApiEnvelope.of(response).orThrow().listOf(StaffUser.fromJson);
      final needle = query.trim().toLowerCase();
      if (needle.isEmpty) return rows;
      return rows
          .where(
            (s) =>
                s.displayName.toLowerCase().contains(needle) ||
                (s.role ?? '').toLowerCase().contains(needle),
          )
          .toList();
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'staff lookup failed', e, stack);
      // An empty list rather than a throw: the picker's own empty state says
      // "nobody found", which is a screen somebody can back out of. An
      // exception inside a sheet is not.
      return const [];
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'What is this department called?' : null;

  int get invalidFieldCount =>
      validateName(name.text) == null ? 0 : 1;

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> save() async {
    if (rxSubmitting.value || rxDeleting.value) return;
    rxSubmitted.value = true;
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    rxSubmitting.value = true;
    rxError.value = null;

    final label = name.text.trim();
    final draft = DepartmentDraft(
      // Create only. `UpdateDepartmentDto` does not declare it, and
      // `forbidNonWhitelisted` turns an extra key into a 400.
      organizationId:
          isEdit ? null : AuthService.to.currentUser?.organizationId,
      name: label,
      // Upper-cased on the way out. The server stores whatever it is sent, so
      // `physio` beside `PHYSIO` is two departments to anything that groups by
      // code — which is every report that does.
      code: code.text.trim().toUpperCase(),
      description: description.text,
      headId: rxHeadId.value,
      isActive: rxActive.value,
    );

    try {
      if (isEdit) {
        await SettingsDepartmentsController.repository
            .update(editing!.id, draft.toUpdateJson());
      } else {
        await SettingsDepartmentsController.repository
            .create(draft.toCreateJson());
      }
      Get.back<void>();
      showBentoToast(isEdit ? '$label updated.' : '$label added.');
    } on ApiForbiddenException catch (e) {
      rxError.value = e.message;
    } catch (e) {
      rxError.value = parseErrorMessage(e, "Couldn't save that department.");
    } finally {
      rxSubmitting.value = false;
    }
  }

  /// Removes the department. The caller confirms first.
  ///
  /// The server unassigns every user in it — `departmentId` goes to null — and
  /// then soft-deletes the row. Nobody's account is touched and nothing else
  /// moves, which is exactly what the confirm has to say: the fear here is
  /// "will this delete my staff", and the honest answer is no.
  Future<void> delete() async {
    final department = editing;
    if (department == null || rxDeleting.value || rxSubmitting.value) return;

    rxDeleting.value = true;
    rxError.value = null;
    try {
      await SettingsDepartmentsController.repository.delete(department.id);
      Get.back<void>();
      showBentoToast('${department.name} removed.');
    } on ApiForbiddenException catch (e) {
      rxError.value = e.message;
    } catch (e) {
      rxError.value = parseErrorMessage(e, "Couldn't remove that department.");
    } finally {
      rxDeleting.value = false;
    }
  }

  /// What the delete confirm says becomes true.
  String get deleteConsequence {
    final count = staffCount;
    final people = switch (count) {
      null => 'Anyone assigned to it',
      0 => null,
      1 => 'The one person assigned to it',
      _ => 'The $count people assigned to it',
    };

    return [
      if (people != null)
        '$people ${count == 1 ? 'keeps their account' : 'keep their accounts'} '
            'and ${count == 1 ? 'stops' : 'stop'} being in any department. '
            'Nobody is deleted and nobody is signed out.'
      else
        'Nobody is assigned to it, so no account changes.',
      'Wards, rotas and records that name this department keep the name; it '
          'simply stops being offered on new ones.',
    ].join('\n\n');
  }
}
