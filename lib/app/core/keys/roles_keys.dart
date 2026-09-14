import 'package:flutter/widgets.dart';

/// Widget keys for the roles list and the permission editor.
abstract final class RolesKeys {
  static const Key screen = Key('roles_screen');
  static const Key list = Key('roles_list');
  static const Key add = Key('roles_add');
  static const Key empty = Key('roles_empty');
  static const Key noAccess = Key('roles_no_access');

  static Key card(String id) => Key('roles_card_$id');

  // ── Editor ────────────────────────────────────────────────────────────────
  static const Key editor = Key('role_editor');
  static const Key name = Key('role_editor_name');
  static const Key description = Key('role_editor_description');
  static const Key systemNotice = Key('role_editor_system_notice');
  static const Key save = Key('role_editor_save');

  /// One switch per module and verb. Keyed by both, because a test asserting
  /// "a nurse may create a screening" has to name the exact control.
  static Key verb(String module, String verb) =>
      Key('role_editor_${module}_$verb');

  static Key moduleCard(String module) => Key('role_editor_module_$module');
}
