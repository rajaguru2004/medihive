import 'package:flutter/widgets.dart';

/// Widget keys for the settings hub and the screens it opens.
///
/// Rows are keyed by a stable id rather than their label: the label is display
/// copy that changes with the wording, the id is what the row actually does.
abstract final class SettingsKeys {
  static const Key screen = Key('settings_screen');
  static const Key noAccess = Key('settings_no_access');

  static Key row(String id) => Key('settings_row_$id');

  // ── The rows the hub itself draws ─────────────────────────────────────────
  //
  // One anchor per destination, and nothing from inside it. Profile, locale
  // and core modules each own a key file of their own — `settings_profile_
  // keys.dart` and its two siblings — and this file used to carry a second
  // spelling of each screen's name and save button, which meant two constants
  // producing one key string and a `findsOneWidget` that could match either.
  static const Key profile = Key('settings_profile');
  static const Key locale = Key('settings_locale');

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
}
