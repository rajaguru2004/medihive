import 'package:get/get.dart';

import '../controllers/patient_activate_controller.dart';

class PatientActivateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientActivateController>(() => PatientActivateController());
  }
}
