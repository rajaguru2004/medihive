import 'package:flutter/widgets.dart';

/// Widget keys for the hospital profile — `/settings/profile`.
///
/// The colour swatches are keyed by their hex value rather than by position:
/// the list is built from the brand presets plus whatever the site already
/// stores, so a swatch's index moves the moment a site's own colour joins the
/// row, and a test aiming at "the third swatch" would then be aiming at a
/// different colour than the one it was written for.
abstract final class SettingsProfileKeys {
  static const Key screen = Key('settings_profile_screen');

  /// The locked panel for an account that may read settings and not write them.
  static const Key noAccess = Key('settings_profile_no_access');

  // ── Identity ──────────────────────────────────────────────────────────────
  static const Key name = Key('settings_profile_name');
  static const Key slug = Key('settings_profile_slug');

  // ── Contact ───────────────────────────────────────────────────────────────
  static const Key email = Key('settings_profile_email');
  static const Key phone = Key('settings_profile_phone');
  static const Key address = Key('settings_profile_address');
  static const Key city = Key('settings_profile_city');
  static const Key region = Key('settings_profile_region');
  static const Key country = Key('settings_profile_country');

  // ── Marks ─────────────────────────────────────────────────────────────────
  static const Key logoUpload = Key('settings_profile_logo_upload');
  static const Key logoTextUpload = Key('settings_profile_logo_text_upload');
  static const Key logoPending = Key('settings_profile_logo_pending');
  static const Key uploadError = Key('settings_profile_upload_error');

  // ── Brand ─────────────────────────────────────────────────────────────────
  static Key primarySwatch(String hex) =>
      Key('settings_profile_primary_${hex.toLowerCase()}');

  static Key secondarySwatch(String hex) =>
      Key('settings_profile_secondary_${hex.toLowerCase()}');

  // ── Save bar ──────────────────────────────────────────────────────────────
  static const Key errors = Key('settings_profile_errors');
  static const Key save = Key('settings_profile_save');
}
