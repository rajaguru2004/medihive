import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../../inpatient_overview/controllers/inpatient_overview_controller.dart';
import '../../inpatient_overview/views/inpatient_overview_view.dart';
import '../../inpatient_wards/controllers/inpatient_wards_controller.dart';
import '../../inpatient_wards/views/inpatient_wards_view.dart';
import '../../inpatient_beds_grid/controllers/inpatient_beds_grid_controller.dart';
import '../../inpatient_beds_grid/views/inpatient_beds_grid_view.dart';
import '../../inpatient_admissions/controllers/inpatient_admissions_controller.dart';
import '../../inpatient_admissions/views/inpatient_admissions_view.dart';
import '../controllers/inpatient_controller.dart';

class InpatientView extends GetView<InpatientController> {
  final bool isEmbedded;
  const InpatientView({super.key, this.isEmbedded = true});

  @override
  Widget build(BuildContext context) {
    // Ensure InpatientController is registered
    if (!Get.isRegistered<InpatientController>()) {
      Get.put(InpatientController());
    }

    // Ensure InpatientWardsController is registered
    if (!Get.isRegistered<InpatientWardsController>()) {
      Get.put(InpatientWardsController());
    }

    // Ensure InpatientOverviewController is registered
    if (!Get.isRegistered<InpatientOverviewController>()) {
      Get.put(InpatientOverviewController());
    }

    // Ensure InpatientBedsGridController is registered
    if (!Get.isRegistered<InpatientBedsGridController>()) {
      Get.put(InpatientBedsGridController());
    }

    // Ensure InpatientAdmissionsController is registered
    if (!Get.isRegistered<InpatientAdmissionsController>()) {
      Get.put(InpatientAdmissionsController());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    Widget buildViewContent(InpatientController controller) {
      if (controller.isLoading && controller.stats == null) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      if (controller.errorMessage.isNotEmpty && controller.stats == null) {
        return _buildErrorState(context, controller, isDark);
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await controller.refreshActiveTabData();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          children: [
            _buildHeader(context, controller, isDark),
            const SizedBox(height: AppSpacing.lg),
            _buildStatsGrid(controller, isDark),
            const SizedBox(height: AppSpacing.lg),
            _buildToggleButtons(controller, isDark),
            const SizedBox(height: AppSpacing.lg),
            _buildActiveTabContent(controller),
          ],
        ),
      );
    }

    if (isEmbedded) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: GetBuilder<InpatientController>(builder: buildViewContent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
            size: AppSpacing.iconMD,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Inpatient',
          style: AppTextStyles.titleMedium(
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: GetBuilder<InpatientController>(builder: buildViewContent),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    InpatientController controller,
    bool isDark,
  ) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inpatient Ward Control',
                style: AppTextStyles.headlineSmall(textPrimary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Manage bed occupancy, patient admissions, and ward configuration',
                style: AppTextStyles.bodySmall(textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        ElevatedButton.icon(
          onPressed: () => Get.toNamed(Routes.INPATIENT_ADMIT),
          icon: const Icon(
            Icons.person_add_alt_1_rounded,
            size: AppSpacing.iconSM,
          ),
          label: const Text('Admit Patient'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.lightSurface,
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.borderMD,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButtons(InpatientController controller, bool isDark) {
    final activeTab = controller.activeTab;
    final containerBg = isDark ? AppColors.darkSurface : Colors.grey[200];
    final border = Border.all(
      color: isDark ? AppColors.darkSurfaceVariant : Colors.grey[300]!,
      width: 0.5,
    );

    Widget buildToggleItem(String title, int index) {
      final isSelected = activeTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => controller.changeTab(index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.darkSurfaceVariant : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : Colors.grey[300]!,
                      width: 0.5,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                title,
                style:
                    AppTextStyles.bodyMedium(
                      isSelected
                          ? (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary)
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ).copyWith(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Row(
        children: [
          buildToggleItem('Overview', 0),
          buildToggleItem('Wards', 1),
          buildToggleItem('Beds Grid', 2),
          buildToggleItem('Admissions', 3),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(InpatientController controller) {
    switch (controller.activeTab) {
      case 0:
        return const InpatientOverviewView(isEmbedded: true);
      case 1:
        return const InpatientWardsView(isEmbedded: true);
      case 2:
        return const InpatientBedsGridView(isEmbedded: true);
      case 3:
        return const InpatientAdmissionsView(isEmbedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatsGrid(InpatientController controller, bool isDark) {
    final stats = controller.stats;
    if (stats == null) return const SizedBox.shrink();

    final rateVal = stats.occupancyRate.toStringAsFixed(0);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          title: 'OCCUPANCY RATE',
          value: '$rateVal%',
          icon: Icons.trending_up_rounded,
          color: AppColors.primary,
          isDark: isDark,
        ),
        _buildStatCard(
          title: 'ACTIVE PATIENTS',
          value: '${stats.occupiedBeds}',
          icon: Icons.airline_seat_flat_rounded,
          color: AppColors.success,
          isDark: isDark,
        ),
        _buildStatCard(
          title: 'AVAILABLE BEDS',
          value: '${stats.availableBeds}',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.info,
          isDark: isDark,
        ),
        _buildStatCard(
          title: 'TOTAL BEDS',
          value: '${stats.totalBeds}',
          icon: Icons.bed_rounded,
          color: AppColors.secondary,
          isDark: isDark,
        ),
        _buildStatCard(
          title: 'TODAY ADMISSIONS',
          value: '${stats.todayAdmissions}',
          icon: Icons.login_rounded,
          color: AppColors.warning,
          isDark: isDark,
        ),
        _buildStatCard(
          title: 'TODAY DISCHARGES',
          value: '${stats.todayDischarges}',
          icon: Icons.logout_rounded,
          color: AppColors.error,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
          color: isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: AppDecorations.borderSM,
            ),
            child: Icon(icon, color: color, size: AppSpacing.iconSM),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelSmall(
                    textSecondary,
                  ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: AppTextStyles.titleMedium(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    InpatientController controller,
    bool isDark,
  ) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

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
