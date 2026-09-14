import 'package:get/get.dart';

import '../controllers/session_lock_controller.dart';

class SessionLockBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionLockController>(SessionLockController.new);
  }
}
