import 'package:get/get.dart';

import '../controllers/document_list_controller.dart';

/// Lazy, and deliberately **not** `permanent`.
///
/// The staff shell keeps its tab controllers alive because switching tabs must
/// not refetch a ward board. This is a pushed screen holding one patient's own
/// documents: it is built when they open it and disposed when they leave, so
/// `SessionManager` has nothing to tear down on handover.
class DocumentListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DocumentListController>(() => DocumentListController());
  }
}
