import 'package:get/get.dart';

import '../controllers/patients_controller.dart';

/// The register, as a pushed route.
///
/// `lazyPut` rather than `permanent`, deliberately: the shell registers its
/// own tab controllers in `HomeBinding` and pairs each with
/// `SessionManager.registerScoped`. If the register ever becomes a shell tab
/// that entry belongs there, beside the other eight, rather than here — one
/// list of destinations is what keeps a module from being added to four places
/// and forgotten in the fifth.
class PatientsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientsController>(PatientsController.new);
  }
}
