import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../controllers/appearance_settings_controller.dart';
import '../controllers/clinical_settings_controller.dart';
import '../controllers/settings_hub_controller.dart';

/// The settings hub.
class SettingsHubBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsHubController>(
      () => SettingsHubController()
        ..entries = SettingsHubController.allEntries(
          Routes.SETTINGS,
          profile: Routes.SETTINGS_PROFILE,
          locale: Routes.SETTINGS_LOCALE,
          appearance: Routes.SETTINGS_APPEARANCE,
          clinical: Routes.SETTINGS_CLINICAL,
          modules: Routes.SETTINGS_MODULES,
          departments: Routes.SETTINGS_DEPARTMENTS,
          staff: Routes.USERS_STAFF,
          roles: Routes.SETTINGS_ROLES,
          integrations: Routes.INTEGRATIONS,
        ),
    );
  }
}

class AppearanceSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppearanceSettingsController>(
      AppearanceSettingsController.new,
    );
  }
}

class ClinicalSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClinicalSettingsController>(ClinicalSettingsController.new);
  }
}
