import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:get/get.dart';

import '../../../models/pre_triage_model.dart';
import '../../../services/pre_triage_service.dart';
import '../../../theme/theme.dart';
import '../../pre_triage/controllers/pre_triage_controller.dart';

class EditScreeningController extends GetxController {
  final _service = PreTriageService.to;

  final formKey = GlobalKey<FormState>();

  late final String screeningId;
  late final String status;
  late final String screeningNumber;

  // Input Controllers
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final RxnString selectedGender = RxnString();
  final chiefComplaintCtrl = TextEditingController();
  final briefHistoryCtrl = TextEditingController();
  final temperatureCtrl = TextEditingController();
  final pulseCtrl = TextEditingController();
  final bpSystolicCtrl = TextEditingController();
  final bpDiastolicCtrl = TextEditingController();
  final RxnString selectedRoute = RxnString();

  final List<String> genders = ['Male', 'Female', 'Other'];
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
    final item = Get.arguments as PreTriageModel;
    screeningId = item.id;
    status = item.status;
    screeningNumber = item.screeningId;

    firstNameCtrl.text = item.firstName;
    lastNameCtrl.text = item.lastName ?? '';
    ageCtrl.text = item.age != null ? '${item.age}' : '';
    phoneCtrl.text = item.phone ?? '';
    chiefComplaintCtrl.text = item.chiefComplaint;
    briefHistoryCtrl.text = item.briefHistory ?? '';
    temperatureCtrl.text =
        item.temperature != null ? '${item.temperature}' : '';
    pulseCtrl.text = item.pulse != null ? '${item.pulse}' : '';
    bpSystolicCtrl.text = item.bpSystolic != null ? '${item.bpSystolic}' : '';
    bpDiastolicCtrl.text =
        item.bpDiastolic != null ? '${item.bpDiastolic}' : '';

    if (item.gender != null && item.gender!.trim().isNotEmpty) {
      final matchedGender = genders.firstWhere(
        (g) => g.toLowerCase() == item.gender!.trim().toLowerCase(),
        orElse: () => '',
      );
      if (matchedGender.isNotEmpty) {
        selectedGender.value = matchedGender;
      }
    }

    if (item.route != null && item.route!.isNotEmpty) {
      final found = routesList.firstWhere(
        (r) => r.toLowerCase() == item.route!.toLowerCase(),
        orElse: () => '',
      );
      if (found.isNotEmpty) selectedRoute.value = found;
    }
  }

  @override
  void onClose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    ageCtrl.dispose();
    phoneCtrl.dispose();
    chiefComplaintCtrl.dispose();
    briefHistoryCtrl.dispose();
    temperatureCtrl.dispose();
    pulseCtrl.dispose();
    bpSystolicCtrl.dispose();
    bpDiastolicCtrl.dispose();
    super.onClose();
  }

  void selectGender(String gender) {
    selectedGender.value = gender;
  }

  void selectRoute(String route) {
    selectedRoute.value = route;
  }

  Future<void> saveChanges() async {
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

        final response = await _service.updateScreening(
          screeningId,
          firstName: firstNameCtrl.text.trim(),
          lastName: lastNameCtrl.text.trim().isNotEmpty
              ? lastNameCtrl.text.trim()
              : null,
          age: ageCtrl.text.trim().isNotEmpty
              ? int.tryParse(ageCtrl.text.trim())
              : null,
          gender: selectedGender.value?.toLowerCase(),
          phone:
              phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
          chiefComplaint: chiefComplaintCtrl.text.trim(),
          briefHistory: briefHistoryCtrl.text.trim().isNotEmpty
              ? briefHistoryCtrl.text.trim()
              : null,
          temperature: temp,
          pulse: pulse,
          bpSystolic: bpSys,
          bpDiastolic: bpDia,
          routedTo: selectedRoute.value?.toLowerCase(),
          status: status,
        );

        final bool isSuccess = (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) ||
                               (response.data is Map && response.data['success'] == true);

        if (isSuccess) {
          if (Get.isRegistered<PreTriageController>()) {
            Get.find<PreTriageController>().fetchScreenings();
          }

          Get.back(); // Return to Pre-Triage list

          Get.snackbar(
            'Success',
            'Screening updated successfully',
            backgroundColor: AppColors.secondary.withValues(alpha: 0.9),
            colorText: AppColors.lightSurface,
            margin: const EdgeInsets.all(AppSpacing.md),
            borderRadius: AppDecorations.radiusMD,
          );
        } else {
          final errorMsg = (response.data is Map) ? response.data['message'] : null;
          Get.snackbar(
            'Error',
            errorMsg ?? 'Failed to update screening',
            backgroundColor: AppColors.error.withValues(alpha: 0.9),
            colorText: AppColors.lightSurface,
            margin: const EdgeInsets.all(AppSpacing.md),
            borderRadius: AppDecorations.radiusMD,
          );
        }
      } catch (e) {
        String errorMsg = 'An error occurred while updating the screening';
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
