import 'package:get/get.dart';

import '../controllers/patient_consent_controller.dart';

class PatientConsentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientConsentController>(() => PatientConsentController());
  }
}
