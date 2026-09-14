import 'package:get/get.dart';

import '../../../data/services/image_source.dart';
import '../controllers/settings_profile_controller.dart';

/// The hospital profile.
class SettingsProfileBinding extends Bindings {
  @override
  void dependencies() {
    // The stub until `image_picker` is a dependency — see
    // `data/services/image_source.dart`. Registered permanently rather than
    // scoped to this screen so a test can swap it before the screen is built,
    // and so the imaging screens that also want one find the same instance.
    if (!Get.isRegistered<ImageSource>()) {
      Get.put<ImageSource>(const StubImageSource(), permanent: true);
    }
    Get.lazyPut<SettingsProfileController>(SettingsProfileController.new);
  }
}
