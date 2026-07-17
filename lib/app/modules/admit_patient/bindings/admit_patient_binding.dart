import 'package:get/get.dart';

import '../controllers/admit_patient_controller.dart';

class AdmitPatientBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdmitPatientController>(() => AdmitPatientController());
  }
}
