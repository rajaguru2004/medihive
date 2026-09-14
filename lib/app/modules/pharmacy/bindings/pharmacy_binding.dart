import 'package:get/get.dart';

import '../controllers/pharmacy_controller.dart';

class PharmacyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PharmacyController>(PharmacyController.new);
  }
}
