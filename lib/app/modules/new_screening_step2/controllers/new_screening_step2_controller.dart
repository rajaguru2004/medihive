import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../services/pre_triage_service.dart';
import '../../../theme/theme.dart';
import '../../pre_triage/controllers/pre_triage_controller.dart';

class NewScreeningStep2Controller extends GetxController {
  final _service = PreTriageService.to;

  final formKey = GlobalKey<FormState>();

  // Patient Identity details from Step 1
  late final String firstName;
  late final String? lastName;
  late final int? age;
  late final String? gender;
  late final String? phone;

  // Clinical inputs
  final chiefComplaintCtrl = TextEditingController();
  final briefHistoryCtrl = TextEditingController();
  final temperatureCtrl = TextEditingController();
  final pulseCtrl = TextEditingController();
  final bpSystolicCtrl = TextEditingController();
  final bpDiastolicCtrl = TextEditingController();

  final RxnString selectedRoute = RxnString();
  final List<String> routesList = [
    'OPD',
    'Radiology',
    'Emergency',
    'Laboratory',
    'Pharmacy',
    'General Medicine',
    'Orthopedics',
    'Pediatrics',
  ];

  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    firstName = args['firstName'] ?? '';
    lastName = args['lastName'];
    age = args['age'];
    gender = args['gender'];
    phone = args['phone'];
  }

  @override
  void onClose() {
    chiefComplaintCtrl.dispose();
    briefHistoryCtrl.dispose();
    temperatureCtrl.dispose();
    pulseCtrl.dispose();
    bpSystolicCtrl.dispose();
    bpDiastolicCtrl.dispose();
    super.onClose();
  }

  void selectRoute(String route) {
    selectedRoute.value = route;
  }

  Future<void> saveScreening() async {
    if (formKey.currentState?.validate() ?? false) {
      isSaving.value = true;
      try {
        final double? temp = temperatureCtrl.text.trim().isNotEmpty
            ? double.tryParse(temperatureCtrl.text.trim())
            : null;
        final int? pulse = pulseCtrl.text.trim().isNotEmpty
            ? int.tryParse(pulseCtrl.text.trim())
            : null;
        final int? bpSys = bpSystolicCtrl.text.trim().isNotEmpty
            ? int.tryParse(bpSystolicCtrl.text.trim())
            : null;
        final int? bpDia = bpDiastolicCtrl.text.trim().isNotEmpty
            ? int.tryParse(bpDiastolicCtrl.text.trim())
            : null;

        final response = await _service.createScreening(
          firstName: firstName,
          lastName: lastName,
          age: age,
          gender: gender,
          phone: phone,
          chiefComplaint: chiefComplaintCtrl.text.trim(),
          briefHistory: briefHistoryCtrl.text.trim().isNotEmpty
              ? briefHistoryCtrl.text.trim()
              : null,
          temperature: temp,
          pulse: pulse,
          bpSystolic: bpSys,
          bpDiastolic: bpDia,
          routedTo: selectedRoute.value?.toLowerCase(),
        );

        if (response.data != null && response.data['success'] == true) {
          // Trigger reload in PreTriageController if active
          if (Get.isRegistered<PreTriageController>()) {
            Get.find<PreTriageController>().fetchScreenings();
          }

          // Return to Pre-Triage main screen
          Get.until((route) => route.settings.name == Routes.PRE_TRIAGE);

          Get.snackbar(
            'Success',
            'Screening created successfully',
            backgroundColor: AppColors.secondary.withValues(alpha: 0.9),
            colorText: AppColors.lightSurface,
            margin: const EdgeInsets.all(AppSpacing.md),
            borderRadius: AppDecorations.radiusMD,
          );
        } else {
          Get.snackbar(
            'Error',
            response.data['message'] ?? 'Failed to save screening',
            backgroundColor: AppColors.error.withValues(alpha: 0.9),
            colorText: AppColors.lightSurface,
            margin: const EdgeInsets.all(AppSpacing.md),
            borderRadius: AppDecorations.radiusMD,
          );
        }
      } catch (e) {
        String errorMsg = 'An error occurred while saving the screening';
        if (e is DioException) {
          final resData = e.response?.data;
          if (resData is Map && resData['message'] != null) {
            errorMsg = resData['message'].toString();
          } else if (e.message != null) {
            errorMsg = e.message!;
          }
        }
        Get.snackbar(
          'Error',
          errorMsg,
          backgroundColor: AppColors.error.withValues(alpha: 0.9),
          colorText: AppColors.lightSurface,
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );
      } finally {
        isSaving.value = false;
      }
    }
  }
}
