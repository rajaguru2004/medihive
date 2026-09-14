import 'package:get/get.dart';

import '../controllers/patient_hub_controller.dart';

/// The hub, as a pushed route.
///
/// The tablet's detail pane does not come through here: it hosts its own
/// tagged instance (see `PatientHubPane`), because two patients can be open at
/// once — one in the pane, one pushed over it — and a single untagged
/// controller would give both the same record.
class PatientHubBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientHubController>(PatientHubController.new);
  }
}
