import 'package:get/get.dart';

import '../controllers/patient_form_controller.dart';

class PatientFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientFormController>(PatientFormController.new);
  }
}
