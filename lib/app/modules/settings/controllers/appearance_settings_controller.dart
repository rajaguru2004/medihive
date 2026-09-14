import 'package:get/get.dart';

import '../../../data/models/drafts/drafts.dart';
import '../../../data/services/settings_service.dart';
import '../../../theme/theme.dart';
import 'settings_form_controller.dart';

/// The site's theme and typeface — the two settings everybody notices.
///
/// Site-wide, unlike light/dark, which is a device preference and lives in the
/// account sheet. A hospital picks its colour once; a clinician picks dark mode
/// every night shift.
class AppearanceSettingsController extends SettingsFormController {
  static AppearanceSettingsController get to =>
      Get.find<AppearanceSettingsController>();

  final _preset = ''.obs;
  final _font = ''.obs;

  String get preset => _preset.value;
  String get font => _font.value;

  late String _initialPreset;
  late String _initialFont;

  List<BrandPalette> get presets => BrandPalette.presets;
  List<AppFontFace> get fonts => AppFontRegistry.faces;

  @override
  void onInit() {
    super.onInit();
    final settings = SettingsService.to.settings;
    _initialPreset = settings.themePreset;
    _initialFont = settings.themeFont;
    _preset.value = _initialPreset;
    _font.value = _initialFont;
  }

  void selectPreset(String id) => _preset.value = id;
  void selectFont(String id) => _font.value = id;

  @override
  bool get isDirty =>
      _preset.value != _initialPreset || _font.value != _initialFont;

  @override
  OrganizationSettingsDraft buildDraft() => OrganizationSettingsDraft(
        themePreset: _preset.value,
        themeFont: _font.value,
      );

  @override
  void onSaved() {
    // The adopted settings have already re-themed the app through
    // `ThemeService`; this only stops the save button offering to do it again.
    _initialPreset = _preset.value;
    _initialFont = _font.value;
  }
}
