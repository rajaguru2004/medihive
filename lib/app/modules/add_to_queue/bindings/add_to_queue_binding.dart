import 'package:get/get.dart';
import '../controllers/add_to_queue_controller.dart';

class AddToQueueBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AddToQueueController>(
      () => AddToQueueController(),
    );
  }
}
