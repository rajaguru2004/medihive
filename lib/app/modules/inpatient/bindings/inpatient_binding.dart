// lib/app/modules/inpatient/bindings/inpatient_binding.dart

import 'package:get/get.dart';
import '../controllers/inpatient_controller.dart';

class InpatientBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InpatientController>(() => InpatientController());
  }
}
