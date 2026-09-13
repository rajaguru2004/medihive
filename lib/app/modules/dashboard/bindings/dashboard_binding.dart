import 'package:get/get.dart';

import '../controllers/dashboard_controller.dart';

/// For the standalone `/dashboard` route.
///
/// Inside the shell the controller is already `permanent` (see `HomeBinding`),
/// so `lazyPut` finds it rather than building a second one — which is why this
/// must not be a `Get.put`.
class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardController>(DashboardController.new);
  }
}
