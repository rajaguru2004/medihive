import 'package:get/get.dart';

import '../controllers/consultation_detail_controller.dart';

class ConsultationDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ConsultationDetailController>(
      () => ConsultationDetailController(),
    );
  }
}
