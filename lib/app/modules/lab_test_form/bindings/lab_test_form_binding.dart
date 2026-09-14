import 'package:get/get.dart';

import '../controllers/lab_test_form_controller.dart';

class LabTestFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LabTestFormController>(() => LabTestFormController());
  }
}
