import 'package:get/get.dart';

import '../../../data/models/pre_triage_model.dart';

class PreTriageDetailsController extends GetxController {
  late final PreTriageModel screening;

  @override
  void onInit() {
    super.onInit();
    screening = Get.arguments as PreTriageModel;
  }
}
