import 'package:get/get.dart';

import '../controllers/consultation_form_controller.dart';

class ConsultationFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ConsultationFormController>(
      () => ConsultationFormController(),
    );
  }
}
