import 'package:get/get.dart';

import '../controllers/lab_result_form_controller.dart';

class LabResultFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LabResultFormController>(() => LabResultFormController());
  }
}
