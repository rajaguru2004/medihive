import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../routes/app_pages.dart';

class NewScreeningStep1Controller extends GetxController {
  final formKey = GlobalKey<FormState>();

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  final RxnString selectedGender = RxnString();
  final List<String> genders = ['Male', 'Female', 'Other'];

  @override
  void onClose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    ageCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }

  void selectGender(String gender) {
    selectedGender.value = gender;
  }

  void validateAndNavigate() {
    if (formKey.currentState?.validate() ?? false) {
      final arguments = {
        'firstName': firstNameCtrl.text.trim(),
        'lastName': lastNameCtrl.text.trim().isNotEmpty
            ? lastNameCtrl.text.trim()
            : null,
        'age': ageCtrl.text.trim().isNotEmpty
            ? int.tryParse(ageCtrl.text.trim())
            : null,
        'gender': selectedGender.value?.toLowerCase(),
        'phone':
            phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
      };
      Get.toNamed(Routes.NEW_SCREENING_STEP2, arguments: arguments);
    }
  }
}
