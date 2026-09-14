import 'package:get/get.dart';

import '../controllers/roles_controller.dart';

class RolesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RolesController>(RolesController.new);
  }
}
