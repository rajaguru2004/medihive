import 'package:get/get.dart';

import '../controllers/case_intake_controller.dart';

/// Lazy and not `permanent`. One intake, read and left — and on a shared ward
/// tablet, a controller that outlived the screen would be one patient's
/// history still in memory while the next clinician signs in.
class CaseIntakeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CaseIntakeController>(() => CaseIntakeController());
  }
}
