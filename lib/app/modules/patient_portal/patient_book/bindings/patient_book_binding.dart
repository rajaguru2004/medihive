import 'package:get/get.dart';

import '../controllers/patient_book_controller.dart';

/// Lazy, and deliberately **not** `permanent`.
///
/// A booking is finished or abandoned in one sitting: the controller holds a
/// half-filled form and one clinician's day, and neither is worth carrying
/// past the screen. Keeping it would also be a hazard on a hospital tablet —
/// the next patient to pick the device up would find the last one's reason
/// for coming in still typed into the box.
class PatientBookBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PatientBookController>(() => PatientBookController());
  }
}
