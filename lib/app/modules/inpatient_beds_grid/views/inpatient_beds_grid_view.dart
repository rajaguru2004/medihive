import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../theme/theme.dart';
import '../../../routes/app_pages.dart';
import '../controllers/inpatient_beds_grid_controller.dart';

class InpatientBedsGridView extends GetView<InpatientBedsGridController> {
  final bool isEmbedded;
  const InpatientBedsGridView({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    if (isEmbedded && !Get.isRegistered<InpatientBedsGridController>()) {
      Get.put(InpatientBedsGridController());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (isEmbedded) {
      return GetBuilder<InpatientBedsGridController>(
        builder: (controller) => _buildViewContent(
            context, controller, isDark, textPrimary, textSecondary),
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
          'Beds Grid',
          style: AppTextStyles.titleMedium(textPrimary),
        ),
      ),
      body: SafeArea(
        child: GetBuilder<InpatientBedsGridController>(
          builder: (controller) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshAllData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                children: [
                  _buildViewContent(
                      context, controller, isDark, textPrimary, textSecondary),
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
    InpatientBedsGridController controller,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
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

    final activeWards = controller.activeWards;
    final selectedWard = controller.selectedWardDetails;
    final bedsList = controller.filteredBeds;

    if (activeWards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
            ElevatedButton.icon(
              onPressed: () => Get.toNamed(
                Routes.INPATIENT_ADD_BED,
                arguments: {'wardId': controller.selectedWardId},
              ),
              icon: const Icon(Icons.add, size: AppSpacing.iconSM),
              label: const Text('Add bed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.lightSurface,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.borderMD,
                ),
                elevation: 0,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: AppDecorations.borderMD,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.selectedWardId,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: AppDecorations.borderMD,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.selectedBedStatusFilter,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        items: const [
                          DropdownMenuItem(
                              value: 'All Beds', child: Text('All Beds')),
                          DropdownMenuItem(
                              value: 'Available', child: Text('Available')),
                          DropdownMenuItem(
                              value: 'Occupied', child: Text('Occupied')),
                          DropdownMenuItem(
                              value: 'Maintenance', child: Text('Maintenance')),
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
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.5)
                  : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
              borderRadius: AppDecorations.borderMD,
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
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
                      value:
                          '${selectedWard.occupiedBeds} Beds (${selectedWard.occupancyRate.toStringAsFixed(0)}%)',
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
              childAspectRatio: 0.65,
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
              if (isAvailable) badgeType = StatusType.success;

              final rawType = bed.type.toLowerCase();
              final displayType = rawType == 'icu'
                  ? 'Icu'
                  : (rawType.isNotEmpty
                      ? '${rawType[0].toUpperCase()}${rawType.substring(1)}'
                      : 'Standard');

              final occupant = controller.bedOccupants[bed.id];
              final patientName = occupant?.fullName ?? 'Admitted Patient';
              final patientMRN = occupant != null ? 'MRN: ${occupant.mrn}' : 'Active Admission';

              return Container(
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
                    // Bed Name & Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.single_bed_rounded,
                                color: AppColors.primary,
                                size: AppSpacing.iconSM),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              bed.bedNumber,
                              style: AppTextStyles.titleMedium(textPrimary)
                                  .copyWith(
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
                    const SizedBox(height: AppSpacing.sm),

                    // Bed Type row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BED TYPE',
                          style: AppTextStyles.labelSmall(textSecondary).copyWith(
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          displayType,
                          style: AppTextStyles.bodyMedium(textPrimary).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Occupant / Details Panel
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isOccupied) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.08),
                                borderRadius: AppDecorations.borderSM,
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        color: AppColors.success,
                                        size: 14,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'CURRENT OCCUPANT',
                                        style: AppTextStyles.labelSmall(AppColors.success).copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    patientName,
                                    style: AppTextStyles.bodyMedium(textPrimary).copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    patientMRN,
                                    style: AppTextStyles.bodySmall(textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isMaintenance) ...[
                            const Spacer(),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.warning,
                                    size: 14,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'Under maintenance',
                                    style: AppTextStyles.bodySmall(AppColors.warning).copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ] else ...[
                            const Spacer(),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.success,
                                    size: 14,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'Available for use',
                                    style: AppTextStyles.bodySmall(AppColors.success).copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                        ],
                      ),
                    ),

                    // Action Panel
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (isOccupied) ...[
                          Expanded(
                            child: _buildActionButton(
                              label: 'Available',
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.success,
                              onPressed: () => controller.updateBedStatus(
                                  bed.id, 'available'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildActionButton(
                              label: 'Maintain',
                              icon: Icons.build_outlined,
                              color: AppColors.warning,
                              onPressed: () => controller.updateBedStatus(
                                  bed.id, 'maintenance'),
                            ),
                          ),
                        ] else if (isMaintenance) ...[
                          Expanded(
                            child: _buildActionButton(
                              label: 'Available',
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.success,
                              onPressed: () => controller.updateBedStatus(
                                  bed.id, 'available'),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: _buildActionButton(
                              label: 'Maintain',
                              icon: Icons.build_outlined,
                              color: AppColors.warning,
                              onPressed: () => controller.updateBedStatus(
                                  bed.id, 'maintenance'),
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
  }

  Widget _buildSmallStat({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall(textSecondary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: AppTextStyles.labelMedium(textPrimary)
                .copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        shape: const RoundedRectangleBorder(
          borderRadius: AppDecorations.borderSM,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        minimumSize: const Size(0, 36),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    InpatientBedsGridController controller,
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
