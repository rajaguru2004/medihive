import 'package:get/get.dart';

import '../controllers/new_screening_step2_controller.dart';

class NewScreeningStep2Binding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewScreeningStep2Controller>(
      () => NewScreeningStep2Controller(),
    );
  }
}
