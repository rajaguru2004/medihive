import 'package:get/get.dart';

import '../controllers/lab_catalog_controller.dart';

class LabCatalogBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LabCatalogController>(() => LabCatalogController());
  }
}
