import 'package:get/get.dart';

import '../controllers/settings_locale_controller.dart';

/// Locale and money.
class SettingsLocaleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsLocaleController>(SettingsLocaleController.new);
  }
}
