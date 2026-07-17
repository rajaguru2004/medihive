import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/theme.dart';
import '../controllers/inpatient_controller.dart';

class InpatientWardsView extends StatelessWidget {
  const InpatientWardsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GetBuilder<InpatientController>(
      builder: (controller) {
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
                        style: AppTextStyles.titleMedium(textPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Manage hospital wards, adjust capacities, and view live occupancy.',
                        style: AppTextStyles.bodySmall(textSecondary),
                      ),
                    ],
                  ),
                ),
                // + Add Ward Button
                IconButton.filled(
                  onPressed: () => Get.snackbar('Add Ward', 'Coming soon', snackPosition: SnackPosition.BOTTOM),
                  icon: const Icon(Icons.add, size: AppSpacing.iconSM),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.lightSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
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
                  final progress = ward.capacity > 0 ? ward.occupiedBeds / ward.capacity : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: AppDecorations.borderLG,
                      border: Border.all(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
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
                                  style: AppTextStyles.titleMedium(textPrimary).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            StatusBadge(
                              label: ward.isActive ? 'Active' : 'Inactive',
                              type: ward.isActive ? StatusType.success : StatusType.neutral,
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
                              style: AppTextStyles.bodyMedium(textPrimary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
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
                                  onPressed: () => _confirmDeactivation(context, controller, ward.id, ward.name),
                                  icon: const Icon(Icons.power_settings_new_rounded, size: AppSpacing.iconSM),
                                  label: const Text('Deactivate'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Get.snackbar('Edit Ward', 'Coming soon', snackPosition: SnackPosition.BOTTOM),
                                icon: const Icon(Icons.edit_rounded, size: AppSpacing.iconSM),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textPrimary,
                                  side: BorderSide(
                                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
      },
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String value,
    required bool isDark,
    Color? color,
  }) {
    final boxBg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: AppDecorations.borderMD,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall(textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: AppTextStyles.titleMedium(color ?? textPrimary).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivation(
      BuildContext context, InpatientController controller, String wardId, String wardName) {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirm Deactivation'),
        content: Text('Are you sure you want to deactivate $wardName? This will remove it from active options.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deactivateWard(wardId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}
