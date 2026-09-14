import 'package:get/get.dart';

import '../controllers/drug_form_controller.dart';

class DrugFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DrugFormController>(DrugFormController.new);
  }
}
