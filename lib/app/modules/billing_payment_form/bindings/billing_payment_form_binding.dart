import 'package:get/get.dart';

import '../controllers/payment_form_controller.dart';

class BillingPaymentFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentFormController>(PaymentFormController.new);
  }
}
