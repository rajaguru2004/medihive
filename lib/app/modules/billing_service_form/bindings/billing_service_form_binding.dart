import 'package:get/get.dart';

import '../controllers/billing_service_form_controller.dart';

class BillingServiceFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BillingServiceFormController>(
      BillingServiceFormController.new,
    );
  }
}
