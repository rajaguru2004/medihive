import 'package:get/get.dart';

import '../controllers/lab_order_detail_controller.dart';

class LabOrderDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LabOrderDetailController>(() => LabOrderDetailController());
  }
}
