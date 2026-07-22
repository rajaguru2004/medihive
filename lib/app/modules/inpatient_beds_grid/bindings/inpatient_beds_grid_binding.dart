import 'package:get/get.dart';

import '../controllers/inpatient_beds_grid_controller.dart';

class InpatientBedsGridBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InpatientBedsGridController>(
      () => InpatientBedsGridController(),
    );
  }
}
