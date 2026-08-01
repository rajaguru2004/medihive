import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:get/get.dart';

import '../../../models/pre_triage_model.dart';
import '../../../services/pre_triage_service.dart';
import '../../../theme/theme.dart';

class PreTriageController extends GetxController {
  final _service = PreTriageService.to;

  final RxList<PreTriageModel> screenings = <PreTriageModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Search & Filter
  final RxString searchQuery = ''.obs;
  final RxString selectedFilter = 'All Screenings'.obs;
  final searchController = TextEditingController();

  final List<String> filterOptions = [
    'All Screenings',
    'Screening',
    'Routed',
    'Registered',
  ];

  // Statistics
  final RxInt totalCount = 0.obs;
  final RxInt screeningCount = 0.obs;
  final RxInt routedCount = 0.obs;
  final RxInt registeredCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchScreenings();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Fetch screenings from backend API
  Future<void> fetchScreenings() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final response = await _service.fetchScreenings();
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> rawList = response.data['data']['data'] ?? [];
        final parsed = rawList
            .map((e) => PreTriageModel.fromJson(e as Map<String, dynamic>))
            .toList();
        screenings.assignAll(parsed);
        calculateStats();
      } else {
        errorMessage.value =
            response.data['message'] ?? 'Failed to load screenings';
      }
    } catch (e) {
      errorMessage.value =
          'Failed to load screenings. Please check network connection.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Pull to refresh
  Future<void> onRefresh() async {
    await fetchScreenings();
  }

  /// Compute local statistics reactively
  void calculateStats() {
    totalCount.value = screenings.length;
    screeningCount.value =
        screenings.where((e) => e.status == 'screening').length;
    routedCount.value = screenings.where((e) => e.status == 'routed').length;
    registeredCount.value =
        screenings.where((e) => e.status == 'registered_as_patient').length;
  }

  /// Reactive getter for filtered list
  List<PreTriageModel> get filteredScreenings {
    List<PreTriageModel> list = screenings;

    // Filter status
    if (selectedFilter.value == 'Screening') {
      list = list.where((e) => e.status == 'screening').toList();
    } else if (selectedFilter.value == 'Routed') {
      list = list.where((e) => e.status == 'routed').toList();
    } else if (selectedFilter.value == 'Registered') {
      list = list.where((e) => e.status == 'registered_as_patient').toList();
    }

    // Filter search query
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final nameMatch = e.fullName.toLowerCase().contains(q);
        final idMatch = e.screeningId.toLowerCase().contains(q);
        final phoneMatch = e.phone != null && e.phone!.contains(q);
        final complaintMatch = e.chiefComplaint.toLowerCase().contains(q);
        return nameMatch || idMatch || phoneMatch || complaintMatch;
      }).toList();
    }

    return list;
  }

  /// Set search query
  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  /// Set selected status filter
  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  /// Delete a screening
  Future<void> deleteScreeningItem(PreTriageModel item) async {
    Get.back(); // close confirmation dialog
    isLoading.value = true;
    try {
      final response = await _service.deleteScreening(item.id);
      if (response.statusCode == 200 ||
          response.statusCode == 204 ||
          (response.data != null &&
              response.data is Map &&
              response.data['success'] == true)) {
        screenings.removeWhere((e) => e.id == item.id);
        calculateStats();
        Get.snackbar(
          'Success',
          'Screening deleted successfully',
          backgroundColor: AppColors.secondary.withValues(alpha: 0.9),
          colorText: AppColors.lightSurface,
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );
      } else {
        final errorMsg = (response.data is Map) ? response.data['message'] : null;
        Get.snackbar(
          'Error',
          errorMsg ?? 'Failed to delete screening',
          backgroundColor: AppColors.error.withValues(alpha: 0.9),
          colorText: AppColors.lightSurface,
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );
      }
    } catch (e) {
      String msg = 'An error occurred while deleting the screening';
      if (e is DioException) {
        msg = e.response?.data?['message'] as String? ?? e.message ?? msg;
      }
      Get.snackbar(
        'Error',
        msg,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: AppColors.lightSurface,
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Convert to patient
  Future<void> convertScreeningToPatient(PreTriageModel item) async {
    isLoading.value = true;
    try {
      final response = await _service.convertToPatient(item.id);
      if (response.data != null && response.data['success'] == true) {
        final serverMrn = response.data['data']?['mrn'] as String? ?? '';
        
        // Update item status locally in list
        final index = screenings.indexWhere((e) => e.id == item.id);
        if (index != -1) {
          // Re-create the model locally with updated status and MRN
          final current = screenings[index];
          screenings[index] = PreTriageModel(
            id: current.id,
            screeningId: current.screeningId,
            firstName: current.firstName,
            lastName: current.lastName,
            age: current.age,
            gender: current.gender,
            phone: current.phone,
            chiefComplaint: current.chiefComplaint,
            briefHistory: current.briefHistory,
            temperature: current.temperature,
            pulse: current.pulse,
            bpDiastolic: current.bpDiastolic,
            bpSystolic: current.bpSystolic,
            route: current.route,
            status: 'registered_as_patient',
            mrn: serverMrn,
            createdAt: current.createdAt,
          );
        }
        calculateStats();
        // Show success registration dialog
        _showSuccessRegistrationDialog(serverMrn);
      } else {
        Get.snackbar(
          'Error',
          response.data?['message'] ?? 'Failed to convert screening to patient',
          backgroundColor: AppColors.error.withValues(alpha: 0.9),
          colorText: AppColors.lightSurface,
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred during conversion.',
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: AppColors.lightSurface,
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Show Success dialog after converting to patient
  void _showSuccessRegistrationDialog(String mrn) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.borderXL,
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Stack(
            children: [
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(
                    Icons.close,
                    color: textSecondary.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.secondary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Patient Registered!',
                      style: AppTextStyles.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'The screening has been converted to a patient record.',
                      style: AppTextStyles.bodyMedium(textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.secondary.withValues(alpha: 0.05)
                            : AppColors.secondary.withValues(alpha: 0.03),
                        borderRadius: AppDecorations.borderMD,
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Assigned MRN',
                            style: AppTextStyles.labelSmall(textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            mrn,
                            style: AppTextStyles.numeric(
                              AppColors.secondary,
                              fontSize: 18,
                            ).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderSM,
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: AppTextStyles.labelLarge(Colors.white).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
