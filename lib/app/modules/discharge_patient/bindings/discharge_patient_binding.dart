import 'package:get/get.dart';

import '../controllers/discharge_patient_controller.dart';

class DischargePatientBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DischargePatientController>(
      () => DischargePatientController(),
    );
  }
}
