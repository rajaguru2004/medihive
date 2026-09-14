import 'package:get/get.dart';

import '../controllers/appointment_form_controller.dart';

class AppointmentFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppointmentFormController>(
      () => AppointmentFormController(),
    );
  }
}
