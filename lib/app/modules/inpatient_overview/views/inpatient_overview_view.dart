import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/inpatient_overview_controller.dart';

class InpatientOverviewView extends GetView<InpatientOverviewController> {
  final bool isEmbedded;
  const InpatientOverviewView({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    if (isEmbedded && !Get.isRegistered<InpatientOverviewController>()) {
      Get.put(InpatientOverviewController());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    if (isEmbedded) {
      return GetBuilder<InpatientOverviewController>(
        builder: (controller) => _buildViewContent(context, controller, isDark),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: AppSpacing.iconMD,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Inpatient Overview',
          style: AppTextStyles.titleMedium(textPrimary),
        ),
      ),
      body: SafeArea(
        child: GetBuilder<InpatientOverviewController>(
          builder: (controller) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                children: [
                  _buildViewContent(context, controller, isDark),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewContent(
    BuildContext context,
    InpatientOverviewController controller,
    bool isDark,
  ) {
    if (controller.isLoading && controller.admissions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (controller.errorMessage.isNotEmpty && controller.admissions.isEmpty) {
      return _buildErrorState(context, controller, isDark);
    }

    final admissionsList = controller.filteredActiveAdmissions;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Patient Admissions',
          style: AppTextStyles.titleMedium(textPrimary).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Search Input
        TextField(
          onChanged: controller.updateOverviewSearch,
          decoration: InputDecoration(
            hintText: 'Search patient by name or MRN...',
            prefixIcon:
                const Icon(Icons.search_rounded, size: AppSpacing.iconMD),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (admissionsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.airline_seat_flat_rounded,
                    size: AppSpacing.iconXL,
                    color: (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary)
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No active admissions found',
                    style: AppTextStyles.bodyMedium(isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: admissionsList.length,
            itemBuilder: (context, index) {
              final admission = admissionsList[index];
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: AppDecorations.borderLG,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Name & MRN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            admission.patient.fullName,
                            style:
                                AppTextStyles.titleMedium(textPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: admission.status.toUpperCase(),
                          type: StatusType.success,
                        ),
                      ],
                    ),
                    Text(
                      'MRN: ${admission.patient.mrn}',
                      style: AppTextStyles.bodySmall(isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                    ),
                    const Divider(height: AppSpacing.lg),
                    // Details Grid/List
                    _buildDetailRow(
                      label: 'Admission Date',
                      value: DateFormat('dd/MM/yyyy HH:mm')
                          .format(admission.admissionDate.toLocal()),
                      isDark: isDark,
                    ),
                    _buildDetailRow(
                      label: 'Ward & Bed',
                      value:
                          '${admission.bed.ward?.name ?? 'ICU'} - Bed ${admission.bed.bedNumber}',
                      isDark: isDark,
                    ),
                    _buildDetailRow(
                      label: 'Admission Type',
                      value: admission.admissionType.toUpperCase(),
                      isDark: isDark,
                    ),
                    _buildDetailRow(
                      label: 'Attending Doctor',
                      value: 'Assigned Doctor',
                      isDark: isDark,
                    ),
                    _buildDetailRow(
                      label: 'Discharge Date',
                      value: admission.dischargeDate != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(admission.dischargeDate!.toLocal())
                          : 'Active',
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Get.toNamed(Routes.DISCHARGE_PATIENT,
                            arguments: admission),
                        icon: const Icon(Icons.logout_rounded,
                            size: AppSpacing.iconSM),
                        label: const Text('Discharge'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.lightSurface,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderMD,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium(textSecondary)),
          Text(value,
              style: AppTextStyles.bodyMedium(textPrimary)
                  .copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    InpatientOverviewController controller,
    bool isDark,
  ) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: AppSpacing.iconXL * 1.5,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error Loading Data',
              style: AppTextStyles.titleLarge(textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              controller.errorMessage,
              style: AppTextStyles.bodyMedium(textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: controller.refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.lightSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.borderMD,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
