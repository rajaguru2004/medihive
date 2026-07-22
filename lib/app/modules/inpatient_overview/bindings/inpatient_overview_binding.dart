import 'package:get/get.dart';

import '../controllers/inpatient_overview_controller.dart';

class InpatientOverviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InpatientOverviewController>(
      () => InpatientOverviewController(),
    );
  }
}
