import 'package:get/get.dart';

import '../../../data/repositories/radiology_repository.dart';
import '../controllers/radiology_exam_form_controller.dart';

/// Serves the catalogue form for a new entry and for an existing one: which it
/// is comes from whether `Get.arguments` carries an `examId`.
class RadiologyExamFormBinding extends Bindings {
  @override
  void dependencies() {
    RadiologyRepositories.register();
    Get.lazyPut<RadiologyExamFormController>(RadiologyExamFormController.new);
  }
}
