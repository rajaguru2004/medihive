import 'package:get/get.dart';

import '../controllers/settings_modules_controller.dart';

/// The core-module switches.
class SettingsModulesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsModulesController>(SettingsModulesController.new);
  }
}
