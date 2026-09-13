import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';

/// Screening, step one: who walked in.
///
/// Split across two screens because it is two jobs: a receptionist takes the
/// identity, a nurse takes the observations, and on a busy door they are two
/// different people at two different desks. One long form would force whoever
/// starts it to finish it.
class NewScreeningStep1Controller extends GetxController {
  static NewScreeningStep1Controller get to =>
      Get.find<NewScreeningStep1Controller>();

  final formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();
  final phoneController = TextEditingController();

  final sex = RxnString();

  static const sexes = ['Male', 'Female', 'Other'];

  String? validateFirstName(String? value) =>
      (value ?? '').trim().isEmpty ? 'A first name is needed' : null;

  String? validateAge(String? value) {
    final text = (value ?? '').trim();
    // Optional: somebody unconscious with no identification still has to be
    // screened, and a form that refuses to proceed without an age is a form
    // that gets filled with zeroes.
    if (text.isEmpty) return null;
    final age = int.tryParse(text);
    if (age == null) return 'Enter a number';
    if (age < 0 || age > 130) return 'Enter an age between 0 and 130';
    return null;
  }

  String? validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    // Deliberately loose. Numbers arrive with country codes, spaces and
    // brackets, and a strict pattern here rejects real numbers at the one
    // moment somebody is standing at the desk waiting.
    if (text.replaceAll(RegExp(r'\D'), '').length < 6) {
      return 'That looks too short for a phone number';
    }
    return null;
  }

  void next() {
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    Get.toNamed<void>(
      Routes.NEW_SCREENING_STEP2,
      arguments: {
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'age': int.tryParse(ageController.text.trim()),
        'gender': sex.value,
        'phone': phoneController.text.trim(),
      },
    );
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    super.onClose();
  }
}
