import 'package:get/get.dart';

import '../controllers/inpatient_admissions_controller.dart';

class InpatientAdmissionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InpatientAdmissionsController>(
      () => InpatientAdmissionsController(),
    );
  }
}
