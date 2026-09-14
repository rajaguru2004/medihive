import 'package:get/get.dart';

import '../../../data/repositories/radiology_repository.dart';
import '../controllers/radiology_order_form_controller.dart';

class RadiologyOrderFormBinding extends Bindings {
  @override
  void dependencies() {
    RadiologyRepositories.register();
    Get.lazyPut<RadiologyOrderFormController>(
      RadiologyOrderFormController.new,
    );
  }
}
