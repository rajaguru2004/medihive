import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/inpatient_controller.dart';
import 'inpatient_admissions_view.dart';
import 'inpatient_beds_grid_view.dart';
import 'inpatient_overview_view.dart';
import 'inpatient_wards_view.dart';

class InpatientView extends GetView<InpatientController> {
  final bool isEmbedded;
  const InpatientView({super.key, this.isEmbedded = true});

  @override
  Widget build(BuildContext context) {
    // Ensure InpatientController is registered
    if (!Get.isRegistered<InpatientController>()) {
      Get.put(InpatientController());
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
        onRefresh: controller.refreshAllData,
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
            _buildTabBar(controller, isDark),
            const SizedBox(height: AppSpacing.md),
            _buildActiveTabView(controller),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inpatient',
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
          icon: const Icon(Icons.add_rounded, size: AppSpacing.iconSM),
          label: const Text('Admit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
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

  Widget _buildTabBar(InpatientController controller, bool isDark) {
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final tabs = ['Overview', 'Wards', 'Beds Grid', 'Admissions'];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
          color: isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant,
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = controller.activeTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.changeTab(index),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: AppDecorations.borderSM,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  style:
                      AppTextStyles.labelMedium(
                        isSelected ? AppColors.lightSurface : textSecondary,
                      ).copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveTabView(InpatientController controller) {
    switch (controller.activeTabIndex) {
      case 0:
        return const InpatientOverviewView();
      case 1:
        return const InpatientWardsView();
      case 2:
        return const InpatientBedsGridView();
      case 3:
        return const InpatientAdmissionsView();
      default:
        return const SizedBox.shrink();
    }
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
