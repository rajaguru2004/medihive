import 'package:get/get.dart';

import '../controllers/lab_order_form_controller.dart';

class LabOrderFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LabOrderFormController>(() => LabOrderFormController());
  }
}
