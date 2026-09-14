import 'package:flutter/widgets.dart';

/// Widget keys for the settings hub and the screens it opens.
///
/// Rows are keyed by a stable id rather than their label: the label is display
/// copy that changes with the wording, the id is what the row actually does.
abstract final class SettingsKeys {
  static const Key screen = Key('settings_screen');
  static const Key noAccess = Key('settings_no_access');

  static Key row(String id) => Key('settings_row_$id');

  // ── Hospital profile ──────────────────────────────────────────────────────
  static const Key profile = Key('settings_profile');
  static const Key profileName = Key('settings_profile_name');
  static const Key profileLogo = Key('settings_profile_logo');
  static const Key profileColor = Key('settings_profile_color');
  static const Key profileSave = Key('settings_profile_save');

  // ── Locale ────────────────────────────────────────────────────────────────
  static const Key locale = Key('settings_locale');
  static const Key currency = Key('settings_currency');
  static const Key timezone = Key('settings_timezone');
  static const Key dateFormat = Key('settings_date_format');
  static const Key clock24 = Key('settings_clock_24');
  static const Key localeSave = Key('settings_locale_save');

  // ── Appearance ────────────────────────────────────────────────────────────
  static const Key appearance = Key('settings_appearance');
  static const Key themeFont = Key('settings_theme_font');
  static const Key appearanceSave = Key('settings_appearance_save');

  static Key preset(String id) => Key('settings_preset_$id');

  // ── Clinical ──────────────────────────────────────────────────────────────
  static const Key clinical = Key('settings_clinical');
  static const Key waitBreach = Key('settings_wait_breach');
  static const Key triageScale = Key('settings_triage_scale');
  static const Key showNames = Key('settings_show_names');
  static const Key sessionLock = Key('settings_session_lock');
  static const Key clinicalSave = Key('settings_clinical_save');

  // ── Core modules ──────────────────────────────────────────────────────────
  static const Key modules = Key('settings_modules');
  static const Key modulesSave = Key('settings_modules_save');

  static Key module(String key) => Key('settings_module_$key');
}
