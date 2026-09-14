import 'package:get/get.dart';

import '../controllers/patient_language_controller.dart';

class PatientLanguageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientLanguageController>(() => PatientLanguageController());
  }
}
