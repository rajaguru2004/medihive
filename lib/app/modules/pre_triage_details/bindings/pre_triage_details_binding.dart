import 'package:get/get.dart';

import '../controllers/pre_triage_details_controller.dart';

class PreTriageDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PreTriageDetailsController>(
      () => PreTriageDetailsController(),
    );
  }
}
