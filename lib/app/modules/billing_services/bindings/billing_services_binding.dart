import 'package:get/get.dart';

import '../controllers/billing_services_controller.dart';

class BillingServicesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BillingServicesController>(BillingServicesController.new);
  }
}
