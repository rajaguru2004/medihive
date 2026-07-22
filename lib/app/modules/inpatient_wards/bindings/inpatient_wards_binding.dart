import 'package:get/get.dart';

import '../controllers/inpatient_wards_controller.dart';

class InpatientWardsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InpatientWardsController>(
      () => InpatientWardsController(),
    );
  }
}
