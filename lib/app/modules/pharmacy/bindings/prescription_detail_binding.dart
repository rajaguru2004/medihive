import 'package:get/get.dart';

import '../controllers/prescription_detail_controller.dart';

class PrescriptionDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PrescriptionDetailController>(
      PrescriptionDetailController.new,
    );
  }
}
