import 'package:get/get.dart';

import '../controllers/patient_claim_controller.dart';

class PatientClaimBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientClaimController>(() => PatientClaimController());
  }
}
