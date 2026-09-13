import 'package:get/get.dart';

import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // `Get.put`, not `lazyPut`. A lazy controller is constructed by the first
    // widget that reads `controller`, and `SplashView` never does — it draws a
    // wordmark and nothing else. The controller would then never be built, its
    // `onReady` would never fire, and the app would sit on the splash screen
    // forever.
    //
    // This is the one screen in the app whose controller does all its work
    // without the view asking it for anything, which is exactly why it is the
    // one that has to be eager.
    Get.put<SplashController>(SplashController());
  }
}
