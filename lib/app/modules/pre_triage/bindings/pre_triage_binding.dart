import 'package:get/get.dart';

import '../controllers/pre_triage_controller.dart';

class PreTriageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PreTriageController>(
      () => PreTriageController(),
    );
  }
}
