import 'package:get/get.dart';

import '../controllers/sale_form_controller.dart';

class SaleFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SaleFormController>(SaleFormController.new);
  }
}
