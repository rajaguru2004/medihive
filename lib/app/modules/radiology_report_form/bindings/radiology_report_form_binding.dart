import 'package:get/get.dart';

import '../../../data/repositories/radiology_repository.dart';
import '../controllers/radiology_report_form_controller.dart';

/// Serves both `/radiology/reports/new` and `/radiology/reports/edit`.
///
/// One module for two routes because they are one screen: which it is comes
/// from whether `Get.arguments` carries a `reportId`, and a second controller
/// that differed only in that would drift from this one the first time a field
/// was added.
class RadiologyReportFormBinding extends Bindings {
  @override
  void dependencies() {
    RadiologyRepositories.register();
    Get.lazyPut<RadiologyReportFormController>(
      RadiologyReportFormController.new,
    );
  }
}
