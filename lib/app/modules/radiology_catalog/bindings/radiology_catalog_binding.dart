import 'package:get/get.dart';

import '../../../data/repositories/radiology_repository.dart';
import '../controllers/radiology_catalog_controller.dart';

class RadiologyCatalogBinding extends Bindings {
  @override
  void dependencies() {
    // Before the controller, which reads the exam repository in its
    // constructor.
    RadiologyRepositories.register();
    Get.lazyPut<RadiologyCatalogController>(RadiologyCatalogController.new);
  }
}
