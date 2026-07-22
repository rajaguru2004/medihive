import 'package:get/get.dart';

import '../controllers/edit_screening_controller.dart';

class EditScreeningBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EditScreeningController>(
      () => EditScreeningController(),
    );
  }
}
