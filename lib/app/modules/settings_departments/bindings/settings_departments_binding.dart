import 'package:get/get.dart';

import '../controllers/department_form_controller.dart';
import '../controllers/settings_departments_controller.dart';

/// The department list.
class SettingsDepartmentsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsDepartmentsController>(
      SettingsDepartmentsController.new,
    );
  }
}

/// The editor the list opens.
///
/// Its own binding rather than the list's, so a deep link straight to
/// `/settings/departments/edit` builds the controller it needs instead of
/// finding nothing and rendering an empty form.
class DepartmentFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DepartmentFormController>(DepartmentFormController.new);
  }
}
