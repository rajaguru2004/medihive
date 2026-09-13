import 'package:get/get.dart';

import '../data/services/appointment_service.dart';
import '../data/services/consultation_service.dart';
import '../data/services/home_service.dart';
import '../data/services/inpatient_service.dart';
import '../data/services/pre_triage_service.dart';
import '../data/services/queue_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeService(), permanent: true);
    Get.put(QueueService(), permanent: true);
    Get.put(AppointmentService(), permanent: true);
    Get.put(InpatientService(), permanent: true);
    Get.put(PreTriageService(), permanent: true);
    Get.put(ConsultationService(), permanent: true);
  }
}
