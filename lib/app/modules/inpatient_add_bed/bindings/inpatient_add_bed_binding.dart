import 'package:get/get.dart';

import '../controllers/inpatient_add_bed_controller.dart';

class InpatientAddBedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InpatientAddBedController>(
      () => InpatientAddBedController(),
    );
  }
}
