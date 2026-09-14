import 'package:get/get.dart';

import '../controllers/machine_form_controller.dart';

class MachineFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MachineFormController>(() => MachineFormController());
  }
}
