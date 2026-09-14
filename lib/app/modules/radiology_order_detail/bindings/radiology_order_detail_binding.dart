import 'package:get/get.dart';

import '../../../data/repositories/radiology_repository.dart';
import '../controllers/radiology_order_detail_controller.dart';

/// Prepares the controller for the order this route names.
///
/// Tagged by order id, because the same screen is also the worklist's second
/// pane on a tablet — two studies can be alive at once, and one untagged
/// controller between them answers for whichever was opened last.
class RadiologyOrderDetailBinding extends Bindings {
  @override
  void dependencies() {
    RadiologyRepositories.register();
    final id = RadiologyOrderDetailController.routeOrderId();
    Get.lazyPut<RadiologyOrderDetailController>(
      () => RadiologyOrderDetailController(orderId: id),
      tag: id,
    );
  }
}
