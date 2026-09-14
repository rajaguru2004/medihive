import 'package:flutter/widgets.dart';

/// Widget keys for the staff directory, one account, and the role editor.
///
/// One namespace across four modules rather than four, because they are four
/// views of one object: a person's name is on the directory row, again on the
/// record it opens, and again in the member list of every role they hold. A
/// parallel set of keys per screen is how two views of one person drift until a
/// test passes against a screen nobody sees.
abstract final class StaffKeys {
  // ── The directory ─────────────────────────────────────────────────────────

  static const Key screen = Key('staff_screen');
  static const Key search = Key('staff_search');
  static const Key sortButton = Key('staff_sort');
  static const Key filterButton = Key('staff_filter');
  static const Key list = Key('staff_list');
  static const Key empty = Key('staff_empty');
  static const Key noAccess = Key('staff_no_access');
  static const Key add = Key('staff_add');
  static const Key addFromEmpty = Key('staff_add_from_empty');
  static const Key clearFilters = Key('staff_clear_filters');

  /// One person's row.
  static Key row(String id) => Key('staff_row_$id');

  /// One option in the role filter sheet, keyed by the role's stored name.
  static Key roleOption(String role) => Key('staff_filter_role_$role');

  static const Key filterApply = Key('staff_filter_apply');
  static const Key filterReset = Key('staff_filter_reset');

  static Key sortOption(String field, {required bool descending}) =>
      Key('staff_sort_${field}_${descending ? 'desc' : 'asc'}');

  // ── The form ──────────────────────────────────────────────────────────────

  static const Key formScreen = Key('staff_form_screen');

  /// Create only on both routes — `UpdateUserDto` omits it, and sending it on
  /// the PUT is a 400.
  static const Key formEmail = Key('staff_form_email');
  static const Key formPassword = Key('staff_form_password');

  /// `/api/users` splits the name; `/api/settings/users` takes one string. The
  /// form shows whichever pair the answering route accepts, so the keys are
  /// not interchangeable.
  static const Key formFirstName = Key('staff_form_first_name');
  static const Key formLastName = Key('staff_form_last_name');
  static const Key formFullName = Key('staff_form_full_name');

  static const Key formPhone = Key('staff_form_phone');
  static const Key formEmployeeId = Key('staff_form_employee_id');
  static const Key formRole = Key('staff_form_role');
  static const Key formDepartment = Key('staff_form_department');
  static const Key formSpecialization = Key('staff_form_specialization');
  static const Key formLicence = Key('staff_form_licence');
  static const Key formSave = Key('staff_form_save');

  // ── One account ───────────────────────────────────────────────────────────

  static const Key detailScreen = Key('staff_detail_screen');
  static const Key detailEdit = Key('staff_detail_edit');
  static const Key detailRoles = Key('staff_detail_roles');
  static const Key detailAddRole = Key('staff_detail_add_role');
  static const Key detailActivate = Key('staff_detail_activate');
  static const Key detailDelete = Key('staff_detail_delete');
  static const Key detailConfirm = Key('staff_detail_confirm');
  static const Key detailCancel = Key('staff_detail_cancel');

  static Key detailRole(String roleId) => Key('staff_detail_role_$roleId');
  static Key detailRemoveRole(String roleId) =>
      Key('staff_detail_remove_role_$roleId');

  /// A row in the sheet that offers a role this account does not hold.
  ///
  /// Its own key rather than [detailRole]: the two sets are disjoint today
  /// only because the sheet lists what the record does not have, and a key
  /// that is unique by coincidence is a key that stops being unique.
  static Key detailAssignOption(String roleId) =>
      Key('staff_detail_assign_$roleId');

  // ── The role editor ───────────────────────────────────────────────────────

  static const Key editorScreen = Key('role_editor_screen');
  static const Key editorTabs = Key('role_editor_tabs');
  static const Key editorName = Key('role_editor_name');
  static const Key editorDescription = Key('role_editor_description');

  /// The pill that says the server will refuse every edit to this role.
  static const Key editorSystemNotice = Key('role_editor_system_notice');

  static const Key editorSave = Key('role_editor_save');
  static const Key editorConfirm = Key('role_editor_confirm');
  static const Key editorCancel = Key('role_editor_cancel');
  static const Key editorGrid = Key('role_editor_grid');
  static const Key editorMembers = Key('role_editor_members');
  static const Key editorAddMember = Key('role_editor_add_member');

  static Key editorTab(String name) => Key('role_editor_tab_$name');

  static Key editorModuleCard(String module) =>
      Key('role_editor_module_$module');

  /// One switch, keyed by module *and* verb — a test asserting "a nurse may
  /// create a screening" has to name the exact control, and four switches per
  /// module share every other attribute.
  static Key editorVerb(String module, String verb) =>
      Key('role_editor_${module}_$verb');

  static Key editorMember(String userId) => Key('role_editor_member_$userId');
  static Key editorRemoveMember(String userId) =>
      Key('role_editor_remove_member_$userId');
}
