import 'package:get/get.dart';

import '../services/appointment_service.dart';
import '../services/home_service.dart';
import '../services/inpatient_service.dart';
import '../services/queue_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeService(), permanent: true);
    Get.put(QueueService(), permanent: true);
    Get.put(AppointmentService(), permanent: true);
    Get.put(InpatientService(), permanent: true);
  }
}

