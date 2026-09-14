import 'package:get/get.dart';

import '../controllers/integrations_controller.dart';

class IntegrationsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<IntegrationsController>(() => IntegrationsController());
  }
}
