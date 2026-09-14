import 'package:get/get.dart';

import '../controllers/role_editor_controller.dart';

class RoleEditorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RoleEditorController>(RoleEditorController.new);
  }
}
