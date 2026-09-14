import 'package:flutter/widgets.dart';

/// Widget keys for the core-module switches — `/settings/modules`.
///
/// Rows are keyed by the module's stored key (`pharmacy`, `inpatient`) rather
/// than by its label: the label is display copy, the key is what is written to
/// `modulesEnabled` and what the shell reads back when it decides which tabs
/// this site has.
abstract final class SettingsModulesKeys {
  static const Key screen = Key('settings_modules_screen');
  static const Key noAccess = Key('settings_modules_no_access');

  /// The banner that says a switch here is only visible after the next start.
  static const Key restartNotice = Key('settings_modules_restart_notice');

  static Key module(String key) => Key('settings_modules_$key');

  /// The confirm that names the tabs about to disappear.
  static const Key confirm = Key('settings_modules_confirm');
  static const Key cancel = Key('settings_modules_cancel');

  static const Key errors = Key('settings_modules_errors');
  static const Key save = Key('settings_modules_save');
}
