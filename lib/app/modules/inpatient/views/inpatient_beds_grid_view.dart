import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/theme.dart';
import '../controllers/inpatient_controller.dart';

class InpatientBedsGridView extends StatelessWidget {
  const InpatientBedsGridView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GetBuilder<InpatientController>(
      builder: (controller) {
        final activeWards = controller.activeWards;
        final selectedWard = controller.selectedWardDetails;
        final bedsList = controller.filteredBeds;

        if (activeWards.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bed_rounded,
                    size: AppSpacing.iconXL,
                    color: textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No active wards found. Please activate/add a ward first.',
                    style: AppTextStyles.bodyMedium(textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Beds Allocation Grid',
                  style: AppTextStyles.titleMedium(textPrimary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // + Add Bed Button
                IconButton.filled(
                  onPressed: () => Get.snackbar('Add Bed', 'Coming soon', snackPosition: SnackPosition.BOTTOM),
                  icon: const Icon(Icons.add, size: AppSpacing.iconSM),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.lightSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Dropdowns Filter Row
            Row(
              children: [
                // Ward Dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Ward',
                        style: AppTextStyles.labelSmall(textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: AppDecorations.borderMD,
                          border: Border.all(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.selectedWardId,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            items: [
                              for (final w in activeWards)
                                DropdownMenuItem(
                                  value: w.id,
                                  child: Text(
                                    '${w.name} (${w.code})',
                                    style: AppTextStyles.bodyMedium(textPrimary),
                                  ),
                                )
                            ],
                            onChanged: controller.changeSelectedWard,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Status Dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Filter',
                        style: AppTextStyles.labelSmall(textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: AppDecorations.borderMD,
                          border: Border.all(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.selectedBedStatusFilter,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            items: const [
                              DropdownMenuItem(value: 'All Beds', child: Text('All Beds')),
                              DropdownMenuItem(value: 'Available', child: Text('Available')),
                              DropdownMenuItem(value: 'Occupied', child: Text('Occupied')),
                              DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                controller.changeBedStatusFilter(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Live ward details banner
            if (selectedWard != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
                  borderRadius: AppDecorations.borderMD,
                  border: Border.all(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSmallStat(
                          label: 'Ward Type',
                          value: selectedWard.type.toUpperCase(),
                          isDark: isDark,
                        ),
                        _buildSmallStat(
                          label: 'Total Capacity',
                          value: '${selectedWard.capacity} Beds',
                          isDark: isDark,
                        ),
                        _buildSmallStat(
                          label: 'Current Occupancy',
                          value: '${selectedWard.occupiedBeds} Beds (${selectedWard.occupancyRate.toStringAsFixed(0)}%)',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (bedsList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.single_bed_rounded,
                        size: AppSpacing.iconXL,
                        color: textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No beds match the selected filters',
                        style: AppTextStyles.bodyMedium(textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.78,
                ),
                itemCount: bedsList.length,
                itemBuilder: (context, index) {
                  final bed = bedsList[index];
                  final isOccupied = bed.status.toLowerCase() == 'occupied';
                  final isMaintenance = bed.status.toLowerCase() == 'maintenance';
                  final isAvailable = bed.status.toLowerCase() == 'available';

                  StatusType badgeType = StatusType.neutral;
                  if (isOccupied) badgeType = StatusType.success;
                  if (isMaintenance) badgeType = StatusType.warning;
                  if (isAvailable) badgeType = StatusType.info;

                  return Container(
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
                        // Bed Name & Status Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.single_bed_rounded, color: AppColors.primary, size: AppSpacing.iconSM),
                                const SizedBox(width: AppSpacing.xxs),
                                Text(
                                  bed.bedNumber,
                                  style: AppTextStyles.titleMedium(textPrimary).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            StatusBadge(
                              label: bed.status.toUpperCase(),
                              type: badgeType,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Bed Type: ${bed.type.toUpperCase()}',
                          style: AppTextStyles.labelSmall(textSecondary),
                        ),
                        const Divider(height: AppSpacing.md),

                        // Occupant / Details Panel
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isOccupied) ...[
                                Text(
                                  'Current Occupant',
                                  style: AppTextStyles.labelSmall(textSecondary).copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Admitted Patient',
                                  style: AppTextStyles.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Active Admission',
                                  style: AppTextStyles.bodySmall(textSecondary),
                                ),
                              ] else if (isMaintenance) ...[
                                const Spacer(),
                                Row(
                                  children: [
                                    const Icon(Icons.build_rounded, color: AppColors.warning, size: AppSpacing.iconXS),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Expanded(
                                      child: Text(
                                        'Under maintenance',
                                        style: AppTextStyles.bodySmall(AppColors.warning),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                              ] else ...[
                                const Spacer(),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: AppSpacing.iconXS),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Expanded(
                                      child: Text(
                                        'Available for use',
                                        style: AppTextStyles.bodySmall(AppColors.success),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                              ],
                            ],
                          ),
                        ),

                        // Action Panel
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            if (isOccupied) ...[
                              // Button to Available
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => controller.updateBedStatus(bed.id, 'available'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                    side: const BorderSide(color: AppColors.success),
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(fontSize: 10),
                                  ),
                                  child: const Text('Available'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              // Button to Maintain
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => controller.updateBedStatus(bed.id, 'maintenance'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.warning,
                                    side: const BorderSide(color: AppColors.warning),
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(fontSize: 10),
                                  ),
                                  child: const Text('Maintain'),
                                ),
                              ),
                            ] else if (isMaintenance) ...[
                              // Button to Available
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => controller.updateBedStatus(bed.id, 'available'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                    side: const BorderSide(color: AppColors.success),
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(fontSize: 10),
                                  ),
                                  child: const Text('Available'),
                                ),
                              ),
                            ] else ...[
                              // Button to Maintain
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => controller.updateBedStatus(bed.id, 'maintenance'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.warning,
                                    side: const BorderSide(color: AppColors.warning),
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(fontSize: 10),
                                  ),
                                  child: const Text('Maintain'),
                                ),
                              ),
                            ],
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

  Widget _buildSmallStat({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall(textSecondary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: AppTextStyles.labelMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
