import 'package:get/get.dart';

import '../../../data/services/session_manager.dart';
import '../controllers/patient_search_controller.dart';

/// Registers the lookup, and arranges for its recents to die with the session.
///
/// `permanent` because the recents list is the whole point and would be empty
/// every time otherwise; guarded on `isRegistered` because a binding runs on
/// every push of its route, and a second `Get.put` would replace the instance
/// and take the recents with it.
///
/// `registerScoped` is not optional beside that: `Get.offAllNamed` — which is
/// how sign-out leaves — does **not** dispose a permanent instance, so without
/// this line the next clinician on a shared ward tablet opens the lookup and
/// reads the last one's patients.
class PatientSearchBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PatientSearchController>()) {
      Get.put<PatientSearchController>(
        PatientSearchController(),
        permanent: true,
      );
    }
    SessionManager.to.registerScoped<PatientSearchController>();
  }
}
