import 'package:flutter/widgets.dart';

/// Widget keys for departments — the list at `/settings/departments` and the
/// form at `/settings/departments/edit`.
///
/// One file for both screens because they are one thing to a reader: a list
/// whose rows open an editor. Splitting them would put `add` and `name` in
/// different files with nothing to say which list the form belongs to.
abstract final class SettingsDepartmentsKeys {
  // ── The list ──────────────────────────────────────────────────────────────
  static const Key screen = Key('settings_departments_screen');
  static const Key search = Key('settings_departments_search');
  static const Key empty = Key('settings_departments_empty');
  static const Key add = Key('settings_departments_add');

  static Key department(String id) => Key('settings_department_$id');

  // ── The form ──────────────────────────────────────────────────────────────
  static const Key form = Key('department_form_screen');
  static const Key name = Key('department_form_name');
  static const Key code = Key('department_form_code');
  static const Key description = Key('department_form_description');
  static const Key head = Key('department_form_head');
  static const Key active = Key('department_form_active');
  static const Key errors = Key('department_form_errors');
  static const Key save = Key('department_form_save');

  // ── Deleting one ──────────────────────────────────────────────────────────
  static const Key delete = Key('department_form_delete');
  static const Key deleteConfirm = Key('department_form_delete_confirm');
  static const Key deleteCancel = Key('department_form_delete_cancel');
}
