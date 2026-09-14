import 'package:get/get.dart';

import '../controllers/patient_dashboard_controller.dart';

/// Lazy, and deliberately **not** `permanent`.
///
/// The staff shell keeps its tab controllers alive because switching tabs must
/// not refetch a ward board. The portal has one screen and one patient, and
/// the thing it holds is that patient's own record — so it is built when the
/// screen opens and disposed when it closes, and `SessionManager` has nothing
/// to tear down on handover.
class PatientDashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientDashboardController>(
      () => PatientDashboardController(),
    );
  }
}
