import 'package:get/get.dart';

import '../controllers/new_screening_step1_controller.dart';

class NewScreeningStep1Binding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewScreeningStep1Controller>(
      () => NewScreeningStep1Controller(),
    );
  }
}
