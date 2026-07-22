import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../theme/theme.dart';
import '../../inpatient_add_ward/bindings/inpatient_add_ward_binding.dart';
import '../../inpatient_add_ward/views/inpatient_add_ward_view.dart';
import '../controllers/inpatient_wards_controller.dart';

class InpatientWardsView extends GetView<InpatientWardsController> {
  final bool isEmbedded;
  const InpatientWardsView({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    if (isEmbedded && !Get.isRegistered<InpatientWardsController>()) {
      Get.put(InpatientWardsController());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    Widget buildViewContent(InpatientWardsController controller) {
      if (controller.isLoading && controller.wards.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      if (controller.errorMessage.isNotEmpty && controller.wards.isEmpty) {
        return _buildErrorState(context, controller, isDark);
      }

      final wardsList = controller.wards;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wards Overview',
                      style: AppTextStyles.titleMedium(
                        textPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Manage hospital wards & view occupancy.',
                      style: AppTextStyles.bodySmall(textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => Get.to(
                  () => const InpatientAddWardView(),
                  binding: InpatientAddWardBinding(),
                ),
                icon: const Icon(Icons.add, size: AppSpacing.iconSM),
                label: Text(
                  'Add Ward',
                  style: AppTextStyles.labelLarge(
                    AppColors.lightSurface,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.lightSurface,
                  elevation: 0,
                  minimumSize: const Size(0, 42),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (wardsList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.meeting_room_rounded,
                      size: AppSpacing.iconXL,
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No wards found',
                      style: AppTextStyles.bodyMedium(textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: wardsList.length,
              itemBuilder: (context, index) {
                final ward = wardsList[index];
                final rate = ward.occupancyRate.toStringAsFixed(0);
                final progress =
                    ward.capacity > 0 ? ward.occupiedBeds / ward.capacity : 0.0;

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
                      // Ward Name, Code, Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                color: AppColors.error,
                                size: AppSpacing.iconMD,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                ward.name,
                                style: AppTextStyles.titleMedium(
                                  textPrimary,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          StatusBadge(
                            label: ward.isActive ? 'Active' : 'Inactive',
                            type: ward.isActive
                                ? StatusType.success
                                : StatusType.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'CODE: ${ward.code} | TYPE: ${ward.type.toUpperCase()}',
                        style: AppTextStyles.labelSmall(textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Stats Summary Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryBox(
                              label: 'Beds',
                              value: '${ward.capacity}',
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildSummaryBox(
                              label: 'Occupied',
                              value: '${ward.occupiedBeds}',
                              isDark: isDark,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildSummaryBox(
                              label: 'Available',
                              value: '${ward.availableBeds}',
                              isDark: isDark,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Progress bar details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Occupancy Rate',
                            style: AppTextStyles.bodyMedium(textSecondary),
                          ),
                          Text(
                            '$rate%',
                            style: AppTextStyles.bodyMedium(
                              textPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          color: ward.occupancyRate > 80
                              ? AppColors.error
                              : ward.occupancyRate > 50
                                  ? AppColors.warning
                                  : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Actions Panel
                      Row(
                        children: [
                          if (ward.isActive) ...[
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _confirmDeactivation(
                                  context,
                                  controller,
                                  ward.id,
                                  ward.name,
                                ),
                                icon: const Icon(
                                  Icons.power_settings_new_rounded,
                                  size: AppSpacing.iconSM,
                                ),
                                label: const Text('Deactivate'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Get.to(
                                () => InpatientAddWardView(
                                  ward: ward,
                                  isEdit: true,
                                ),
                                binding: InpatientAddWardBinding(),
                              ),
                              icon: const Icon(
                                Icons.edit_rounded,
                                size: AppSpacing.iconSM,
                              ),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.darkSurfaceVariant
                                      : AppColors.lightSurfaceVariant,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDecorations.borderMD,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      );
    }

    if (isEmbedded) {
      return GetBuilder<InpatientWardsController>(
        builder: buildViewContent,
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
          'Inpatient Wards',
          style: AppTextStyles.titleMedium(textPrimary),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.refreshAllData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            children: [
              GetBuilder<InpatientWardsController>(
                builder: buildViewContent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String value,
    required bool isDark,
    Color? color,
  }) {
    final boxBg =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: AppDecorations.borderMD,
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.labelSmall(textSecondary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: AppTextStyles.titleMedium(
              color ?? textPrimary,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivation(
    BuildContext context,
    InpatientWardsController controller,
    String wardId,
    String wardName,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    Get.dialog(
      AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.borderMD,
        ),
        title: Text(
          'Confirm Deactivation',
          style: AppTextStyles.titleMedium(textPrimary).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to deactivate $wardName? This will remove it from active options.',
          style: AppTextStyles.bodyMedium(textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelMedium(AppColors.primary).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deactivateWard(wardId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(120, 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppDecorations.borderSM,
              ),
            ),
            child: Text(
              'Deactivate',
              style: AppTextStyles.labelMedium(Colors.white).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    InpatientWardsController controller,
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
              'Error Loading Wards',
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
              onPressed: controller.refreshAllData,
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
