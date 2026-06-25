// lib/app/modules/appointments/bindings/appointment_create_binding.dart

import 'package:get/get.dart';
import '../controllers/appointment_create_controller.dart';

class AppointmentCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppointmentCreateController>(
      () => AppointmentCreateController(),
    );
  }
}
