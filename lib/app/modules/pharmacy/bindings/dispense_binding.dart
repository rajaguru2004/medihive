import 'package:get/get.dart';

import '../controllers/dispense_controller.dart';

class DispenseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DispenseController>(DispenseController.new);
  }
}
