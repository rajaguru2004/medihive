import 'package:get/get.dart';

import '../../../data/repositories/radiology_repository.dart';
import '../controllers/radiology_controller.dart';

class RadiologyBinding extends Bindings {
  @override
  void dependencies() {
    // Before the controller, which reads one of them in its constructor.
    RadiologyRepositories.register();
    Get.lazyPut<RadiologyController>(RadiologyController.new);
  }
}
