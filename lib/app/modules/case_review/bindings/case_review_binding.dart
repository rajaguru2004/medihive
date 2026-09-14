import 'package:get/get.dart';

import '../../../data/services/patient_case_service.dart';
import '../../../data/services/session_manager.dart';
import '../controllers/case_review_controller.dart';

/// The review screen, and the one thing that has to outlive it.
///
/// `PatientCaseService` is `permanent` because the dashboard reads it after
/// this screen has gone — that is the whole reason it exists — and it is
/// registered with `SessionManager.registerScoped` because `Get.offAllNamed`
/// does not dispose a permanent instance. Without that, the next patient to
/// sign in on a shared clinic tablet would open their dashboard and be told
/// they had already sent somebody else's case.
class CaseReviewBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PatientCaseService>()) {
      Get.put(PatientCaseService(), permanent: true);
      SessionManager.to.registerScoped<PatientCaseService>();
    }
    Get.lazyPut<CaseReviewController>(() => CaseReviewController());
  }
}
