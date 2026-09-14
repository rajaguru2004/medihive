import 'package:get/get.dart';

import '../controllers/document_review_controller.dart';

/// Lazy and not permanent: one patient's document, built when they open it.
///
/// `fenix` is deliberately off. A controller resurrected after disposal would
/// come back with an empty `checks` map while the screen behind it still
/// believed the patient had agreed with three lines.
class DocumentReviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DocumentReviewController>(() => DocumentReviewController());
  }
}
