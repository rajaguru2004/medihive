import 'package:get/get.dart';

import '../controllers/inpatient_add_ward_controller.dart';

class InpatientAddWardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InpatientAddWardController>(
      () => InpatientAddWardController(),
    );
  }
}
