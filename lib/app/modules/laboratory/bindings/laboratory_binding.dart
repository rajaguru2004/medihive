import 'package:get/get.dart';

import '../controllers/laboratory_controller.dart';

class LaboratoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LaboratoryController>(() => LaboratoryController());
  }
}
