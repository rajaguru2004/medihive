import 'package:get/get.dart';

import '../controllers/invoice_form_controller.dart';

class BillingInvoiceFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InvoiceFormController>(InvoiceFormController.new);
  }
}
