// lib/app/modules/home/views/home_view.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'package:medihive/app/theme/theme.dart';
import '../controllers/home_controller.dart';
import '../models/dashboard_model.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(context, isDark),
      body: Obx(() {
        if (controller.isLoading) {
          return _DashboardSkeleton(isDark: isDark);
        }
        if (controller.hasError) {
          return _ErrorState(
            message: controller.errorMessage,
            onRetry: controller.fetchAll,
            isDark: isDark,
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          onRefresh: controller.onRefresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            children: [
              _WelcomeCard(isDark: isDark),
              const SizedBox(height: AppSpacing.xl),
              _StatsGrid(isDark: isDark),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _AppointmentBreakdownCard(isDark: isDark)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _QueueDistributionCard(isDark: isDark),
              const SizedBox(height: AppSpacing.lg),
              _CriticalAlertsCard(isDark: isDark),
              const SizedBox(height: AppSpacing.lg),
              _RecentPatientsCard(isDark: isDark),
              const SizedBox(height: AppSpacing.lg),
              _UpcomingAppointmentsCard(isDark: isDark),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        );
      }),
      bottomNavigationBar: const _BottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.08),
      leading: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppDecorations.borderSM,
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: AppColors.lightSurface,
            size: AppSpacing.iconMD,
          ),
        ),
      ),
      title: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.orgName,
                style: AppTextStyles.titleMedium(textPrimary),
              ),
              Text(
                'Hospital Dashboard',
                style: AppTextStyles.labelSmall(AppColors.primary),
              ),
            ],
          )),
      actions: [
        // Notification Bell
        Obx(() => Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: textPrimary,
                    size: AppSpacing.iconLG,
                  ),
                  onPressed: () {},
                ),
                if (controller.stats.criticalAlerts > 0)
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: Container(
                      width: AppSpacing.md,
                      height: AppSpacing.md,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${controller.stats.criticalAlerts}',
                          style: AppTextStyles.labelSmall(AppColors.lightSurface)
                              .copyWith(fontSize: 8),
                        ),
                      ),
                    ),
                  ),
              ],
            )),
        // Profile Avatar with menu
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'sign_out') {
                Get.offAllNamed('/login');
              }
            },
            offset: const Offset(0, AppSpacing.massive),
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.borderMD,
            ),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            child: CircleAvatar(
              radius: AppSpacing.avatarSM / 2,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                'A',
                style: AppTextStyles.labelMedium(AppColors.primary),
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin',
                      style: AppTextStyles.titleSmall(
                        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'admin@hms.local',
                      style: AppTextStyles.bodySmall(
                        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'sign_out',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: AppColors.error, size: AppSpacing.iconMD),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Sign Out',
                      style: AppTextStyles.labelLarge(AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Welcome Card ─────────────────────────────────────────────────────────────

class _WelcomeCard extends GetView<HomeController> {
  const _WelcomeCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.7),
            AppColors.secondary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppDecorations.borderLG,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back, Admin 👋',
                  style: AppTextStyles.titleLarge(AppColors.lightSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Here's today's hospital overview",
                  style: AppTextStyles.bodyMedium(
                      AppColors.lightSurface.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(() => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface.withValues(alpha: 0.2),
                        borderRadius: AppDecorations.borderFull,
                        border: Border.all(
                          color: AppColors.lightSurface.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '${controller.stats.totalPatients} Total Patients',
                        style: AppTextStyles.labelMedium(AppColors.lightSurface),
                      ),
                    )),
              ],
            ),
          ),
          Container(
            width: AppSpacing.huge + AppSpacing.huge,
            height: AppSpacing.huge + AppSpacing.huge,
            decoration: BoxDecoration(
              color: AppColors.lightSurface.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: AppColors.lightSurface,
              size: AppSpacing.iconXL,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends GetView<HomeController> {
  const _StatsGrid({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = controller.stats;
      final cards = [
        _StatCardData(
          icon: Icons.people_alt_rounded,
          title: 'Total Patients',
          value: '${s.totalPatients}',
          description: 'Cumulative registered',
          color: AppColors.primary,
          statusLabel: 'Active',
          statusType: StatusType.info,
        ),
        _StatCardData(
          icon: Icons.calendar_today_rounded,
          title: "Today's Appointments",
          value: '${s.todayAppointments}',
          description: 'Scheduled for today',
          color: AppColors.secondary,
          statusLabel: s.todayAppointments > 0 ? 'Scheduled' : 'None',
          statusType: s.todayAppointments > 0
              ? StatusType.success
              : StatusType.neutral,
        ),
        _StatCardData(
          icon: Icons.currency_rupee_rounded,
          title: "Today's Revenue",
          value: '₹${s.todayRevenue.toStringAsFixed(0)}',
          description: 'Inflow from bills',
          color: AppColors.tertiary,
          statusLabel: 'Today',
          statusType: StatusType.info,
        ),
        _StatCardData(
          icon: Icons.warning_amber_rounded,
          title: 'Critical Alerts',
          value: '${s.criticalAlerts}',
          description: 'Require immediate action',
          color: AppColors.error,
          statusLabel: s.criticalAlerts > 0 ? 'Critical' : 'All Clear',
          statusType: s.criticalAlerts > 0 ? StatusType.error : StatusType.success,
        ),
        _StatCardData(
          icon: Icons.queue_rounded,
          title: 'Queue Status',
          value: '${s.queueWaiting}',
          description: 'Patients waiting to consult',
          color: AppColors.warning,
          statusLabel: s.queueWaiting > 0 ? 'Waiting' : 'Empty',
          statusType: s.queueWaiting > 0 ? StatusType.warning : StatusType.success,
        ),
        _StatCardData(
          icon: Icons.bed_rounded,
          title: 'Bed Availability',
          value: '${s.availableBeds}/${s.occupiedBeds + s.availableBeds}',
          description: '${s.availableBeds} beds currently free',
          color: AppColors.info,
          statusLabel: s.availableBeds > 0 ? 'Available' : 'Full',
          statusType: s.availableBeds > 0 ? StatusType.success : StatusType.error,
        ),
        _StatCardData(
          icon: Icons.science_rounded,
          title: 'Pending Lab Orders',
          value: '${s.pendingLabOrders}',
          description: 'Awaiting results',
          color: const Color(0xFFFF6B35),
          statusLabel: s.pendingLabOrders > 0 ? 'Pending' : 'Clear',
          statusType: s.pendingLabOrders > 0 ? StatusType.warning : StatusType.success,
        ),
        _StatCardData(
          icon: Icons.medication_rounded,
          title: 'Pending Prescriptions',
          value: '${s.pendingPrescriptions}',
          description: 'Awaiting dispensation',
          color: const Color(0xFF8B5CF6),
          statusLabel: s.pendingPrescriptions > 0 ? 'Pending' : 'Clear',
          statusType: s.pendingPrescriptions > 0 ? StatusType.warning : StatusType.success,
        ),
      ];

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.3,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => _StatCard(data: cards[i], isDark: isDark),
      );
    });
  }
}

class _StatCardData {
  final IconData icon;
  final String title;
  final String value;
  final String description;
  final Color color;
  final String statusLabel;
  final StatusType statusType;

  const _StatCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    required this.color,
    required this.statusLabel,
    required this.statusType,
  });
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data, required this.isDark});
  final _StatCardData data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
        border: Border.all(
          color: data.color.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: AppDecorations.borderSM,
                ),
                child: Icon(data.icon, color: data.color, size: AppSpacing.iconMD),
              ),
              StatusBadge(label: data.statusLabel, type: data.statusType),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: AppTextStyles.headlineSmall(textPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            data.title,
            style: AppTextStyles.labelMedium(data.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            data.description,
            style: AppTextStyles.bodySmall(textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


// ─── Appointment Breakdown Card ────────────────────────────────────────────────

class _AppointmentBreakdownCard extends GetView<HomeController> {
  const _AppointmentBreakdownCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Obx(() {
      final s = controller.appointmentStatuses;
      final total = s.total;
      final isEmpty = total == 0;

      final sections = [
        _PieSegment(label: 'Completed', count: s.completed, color: AppColors.secondary),
        _PieSegment(label: 'Confirmed', count: s.confirmed, color: AppColors.primary),
        _PieSegment(label: 'Scheduled', count: s.scheduled, color: AppColors.warning),
        _PieSegment(label: 'Cancelled', count: s.cancelled, color: AppColors.error),
      ];

      return Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppDecorations.borderLG,
          boxShadow: AppDecorations.elevation1(isDark),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppDecorations.borderSM,
                  ),
                  child: const Icon(Icons.pie_chart_rounded,
                      color: AppColors.primary, size: AppSpacing.iconMD),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appointment Breakdown',
                          style: AppTextStyles.titleMedium(textPrimary)),
                      Text('Daily status distribution',
                          style: AppTextStyles.bodySmall(textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (isEmpty)
              _EmptyState(
                icon: Icons.calendar_month_outlined,
                message: 'No appointments today',
                isDark: isDark,
              )
            else ...[
              SizedBox(
                height: 180,
                child: _AppointmentPieChart(
                    sections: _buildSections(sections, total),
                    isDark: isDark,
                    total: total),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...sections.map((seg) => _LegendRow(
                    label: seg.label,
                    count: seg.count,
                    total: total,
                    color: seg.color,
                    isDark: isDark,
                  )),
            ],
          ],
        ),
      );
    });
  }

  List<PieChartSectionData> _buildSections(
      List<_PieSegment> segs, int total) {
    return segs
        .where((s) => s.count > 0)
        .map((s) => PieChartSectionData(
              value: s.count.toDouble(),
              color: s.color,
              radius: 42,
              showTitle: false,
            ))
        .toList();
  }
}

class _PieSegment {
  final String label;
  final int count;
  final Color color;

  const _PieSegment({
    required this.label,
    required this.count,
    required this.color,
  });
}

class _AppointmentPieChart extends StatelessWidget {
  const _AppointmentPieChart({
    required this.sections,
    required this.isDark,
    required this.total,
  });
  final List<PieChartSectionData> sections;
  final bool isDark;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 44,
            sectionsSpace: 3,
            borderData: FlBorderData(show: false),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: AppTextStyles.headlineSmall(textPrimary),
            ),
            Text(
              'Total Slots',
              style: AppTextStyles.labelSmall(textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.isDark,
  });
  final String label;
  final int count;
  final int total;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTextStyles.bodySmall(textPrimary))),
          Text('$count', style: AppTextStyles.labelMedium(textPrimary)),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 36,
            child: Text('$pct%',
                style: AppTextStyles.labelSmall(textSecondary),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

// ─── Queue Distribution Card ───────────────────────────────────────────────────

class _QueueDistributionCard extends GetView<HomeController> {
  const _QueueDistributionCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Obx(() {
      final queue = controller.queueByService;
      final waiting = controller.stats.queueWaiting;

      return Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppDecorations.borderLG,
          boxShadow: AppDecorations.elevation1(isDark),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: AppDecorations.borderSM,
                  ),
                  child: const Icon(Icons.queue_rounded,
                      color: AppColors.warning, size: AppSpacing.iconMD),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Queue Distribution',
                          style: AppTextStyles.titleMedium(textPrimary)),
                      Text('Active waiting time by department',
                          style: AppTextStyles.bodySmall(textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: AppDecorations.borderFull,
                  ),
                  child: Text('$waiting waiting',
                      style: AppTextStyles.labelSmall(AppColors.warning)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (queue.isEmpty || waiting == 0)
              _EmptyState(
                icon: Icons.check_circle_outline_rounded,
                message: 'No patients waiting in any queue',
                isDark: isDark,
              )
            else
              ...queue.map((q) => _QueueServiceRow(service: q, isDark: isDark)),
          ],
        ),
      );
    });
  }
}

class _QueueServiceRow extends StatelessWidget {
  const _QueueServiceRow({required this.service, required this.isDark});
  final QueueService service;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final surfaceVariant = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(Icons.arrow_right_rounded,
              color: AppColors.warning, size: AppSpacing.iconSM),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(service.name, style: AppTextStyles.bodyMedium(textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: surfaceVariant,
              borderRadius: AppDecorations.borderFull,
            ),
            child: Text('${service.count}',
                style: AppTextStyles.labelSmall(AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

// ─── Critical Alerts Card ──────────────────────────────────────────────────────

class _CriticalAlertsCard extends GetView<HomeController> {
  const _CriticalAlertsCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Obx(() {
      final count = controller.stats.criticalAlerts;

      return Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppDecorations.borderLG,
          boxShadow: AppDecorations.elevation1(isDark),
          border: count > 0
              ? Border.all(
                  color: AppColors.error.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: AppDecorations.borderSM,
                  ),
                  child: const Icon(Icons.warning_rounded,
                      color: AppColors.error, size: AppSpacing.iconMD),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Critical Alerts',
                          style: AppTextStyles.titleMedium(textPrimary)),
                      Text('Require immediate action',
                          style: AppTextStyles.bodySmall(textSecondary)),
                    ],
                  ),
                ),
                if (count > 0)
                  StatusBadge(
                      label: '$count Alert${count > 1 ? 's' : ''}',
                      type: StatusType.error,
                      icon: Icons.warning_rounded),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (count == 0)
              _EmptyState(
                icon: Icons.check_circle_outline_rounded,
                message: 'No critical alerts',
                color: AppColors.success,
                isDark: isDark,
              )
            else
              // Placeholder alerts (would be real alert objects from API)
              ...List.generate(
                  count,
                  (i) => _AlertRow(
                        title: 'Critical Alert ${i + 1}',
                        priority: 'High',
                        timestamp: 'Just now',
                        isDark: isDark,
                      )),
          ],
        ),
      );
    });
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.title,
    required this.priority,
    required this.timestamp,
    required this.isDark,
  });
  final String title;
  final String priority;
  final String timestamp;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded,
              color: AppColors.error, size: AppSpacing.iconSM),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge(textPrimary)),
                Text(timestamp, style: AppTextStyles.bodySmall(textSecondary)),
              ],
            ),
          ),
          StatusBadge(label: priority, type: StatusType.error),
        ],
      ),
    );
  }
}

// ─── Recent Patients Card ──────────────────────────────────────────────────────

class _RecentPatientsCard extends GetView<HomeController> {
  const _RecentPatientsCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Obx(() {
      final patients = controller.recentPatients;

      return Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppDecorations.borderLG,
          boxShadow: AppDecorations.elevation1(isDark),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppDecorations.borderSM,
                  ),
                  child: const Icon(Icons.people_rounded,
                      color: AppColors.primary, size: AppSpacing.iconMD),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Patients',
                          style: AppTextStyles.titleMedium(textPrimary)),
                      Text('Latest admissions & registrations',
                          style: AppTextStyles.bodySmall(textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: controller.toggleShowAllPatients,
                  child: Text(
                    controller.showAllPatients ? 'Show Less' : 'View All →',
                    style: AppTextStyles.labelMedium(AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (patients.isEmpty)
              _EmptyState(
                  icon: Icons.people_outline,
                  message: 'No patients registered',
                  isDark: isDark)
            else
              ...patients.map((p) => _PatientRow(patient: p, isDark: isDark)),
          ],
        ),
      );
    });
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.isDark});
  final RecentPatient patient;
  final bool isDark;

  Color _avatarColor(String initials) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.warning,
      AppColors.info,
      const Color(0xFFFF6B35),
    ];
    final idx = initials.isNotEmpty
        ? initials.codeUnitAt(0) % colors.length
        : 0;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final divider =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final avatarColor = _avatarColor(patient.initials);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: AppSpacing.avatarMD / 2,
                backgroundColor: avatarColor.withValues(alpha: 0.15),
                child: Text(
                  patient.initials,
                  style: AppTextStyles.labelMedium(avatarColor),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.fullName,
                        style: AppTextStyles.titleSmall(textPrimary)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      patient.mrn,
                      style: AppTextStyles.numeric(textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        _GenderBadge(gender: patient.gender, isDark: isDark),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${patient.age} yrs',
                          style: AppTextStyles.bodySmall(textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // View Button
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDecorations.borderSM,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Profile',
                    style: AppTextStyles.labelSmall(AppColors.primary)),
              ),
            ],
          ),
        ),
        Divider(color: divider, height: 1, thickness: 0.5),
      ],
    );
  }
}

class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.gender, required this.isDark});
  final String gender;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isMale = gender.toLowerCase() == 'male';
    final color = isMale ? AppColors.info : AppColors.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppDecorations.borderFull,
      ),
      child: Text(
        isMale ? 'Male' : 'Female',
        style: AppTextStyles.labelSmall(color),
      ),
    );
  }
}

// ─── Upcoming Appointments Card ────────────────────────────────────────────────

class _UpcomingAppointmentsCard extends GetView<HomeController> {
  const _UpcomingAppointmentsCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Obx(() {
      final appointments = controller.upcomingAppointments;

      return Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppDecorations.borderLG,
          boxShadow: AppDecorations.elevation1(isDark),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: AppDecorations.borderSM,
                  ),
                  child: const Icon(Icons.event_rounded,
                      color: AppColors.secondary, size: AppSpacing.iconMD),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upcoming Appointments',
                          style: AppTextStyles.titleMedium(textPrimary)),
                      Text('Chronological calendar slots',
                          style: AppTextStyles.bodySmall(textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Get.toNamed('/appointments'),
                  child: Text('View Calendar →',
                      style: AppTextStyles.labelMedium(AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (appointments.isEmpty)
              _EmptyState(
                icon: Icons.calendar_month_outlined,
                message: 'No upcoming appointments today',
                isDark: isDark,
              )
            else
              ...appointments.map((a) =>
                  _AppointmentRow(appointment: a, isDark: isDark)),
          ],
        ),
      );
    });
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment, required this.isDark});
  final UpcomingAppointment appointment;
  final bool isDark;

  Color _avatarColor(String initials) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.warning,
      AppColors.info,
    ];
    final idx = initials.isNotEmpty ? initials.codeUnitAt(0) % colors.length : 0;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final surface =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;

    final initials = appointment.patient.initials;
    final avatarColor = _avatarColor(initials);

    StatusType statusType;
    switch (appointment.status.toLowerCase()) {
      case 'confirmed':
        statusType = StatusType.success;
        break;
      case 'scheduled':
        statusType = StatusType.info;
        break;
      case 'cancelled':
        statusType = StatusType.error;
        break;
      default:
        statusType = StatusType.neutral;
    }

    final statusLabel = appointment.status.isEmpty
        ? 'Unknown'
        : '${appointment.status[0].toUpperCase()}${appointment.status.substring(1)}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──
              CircleAvatar(
                radius: AppSpacing.avatarMD / 2,
                backgroundColor: avatarColor.withValues(alpha: 0.15),
                child: Text(
                  initials,
                  style: AppTextStyles.labelMedium(avatarColor),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // ── Main Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time + Date row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppDecorations.borderFull,
                          ),
                          child: Text(
                            appointment.formattedTime,
                            style: AppTextStyles.numeric(
                                AppColors.primary,
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          appointment.formattedDate,
                          style: AppTextStyles.bodySmall(textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Patient name
                    Text(
                      appointment.patient.fullName,
                      style: AppTextStyles.titleSmall(textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    // MRN
                    Text(
                      appointment.patient.mrn,
                      style: AppTextStyles.numeric(textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // ── Trailing: status + details ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(label: statusLabel, type: statusType),
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: AppDecorations.borderFull,
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Details',
                        style: AppTextStyles.labelSmall(AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(color: divider, height: 1, thickness: 0.5),
      ],
    );
  }
}

// ─── Bottom Navigation ─────────────────────────────────────────────────────────


class _BottomNav extends StatefulWidget {
  const _BottomNav();

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
  }

  void _closeMenu() {
    if (_overlayEntry == null) return;
    _animationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _animationController.dispose();
    super.dispose();
  }

  OverlayEntry _createOverlayEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _closeMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
          Positioned(
            right: AppSpacing.md,
            bottom: kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom + AppSpacing.sm,
            child: FadeTransition(
              opacity: _animation,
              child: ScaleTransition(
                scale: _animation,
                alignment: Alignment.bottomRight,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 290,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: AppDecorations.glassCard(isDark: isDark),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.xs,
                            bottom: AppSpacing.sm,
                          ),
                          child: Text(
                            'Quick Services',
                            style: AppTextStyles.labelMedium(AppColors.primary),
                          ),
                        ),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.95,
                          children: [
                            _buildMenuItem(
                              context,
                              'Consultations',
                              Icons.medical_services_outlined,
                              '/consultations',
                              isDark,
                              textPrimary,
                            ),
                            _buildMenuItem(
                              context,
                              'Patients',
                              Icons.people_rounded,
                              '/patients',
                              isDark,
                              textPrimary,
                            ),
                            _buildMenuItem(
                              context,
                              'Pharmacy',
                              Icons.local_pharmacy_rounded,
                              '/pharmacy',
                              isDark,
                              textPrimary,
                            ),
                            _buildMenuItem(
                              context,
                              'Laboratory',
                              Icons.science_rounded,
                              '/laboratory',
                              isDark,
                              textPrimary,
                            ),
                            _buildMenuItem(
                              context,
                              'Radiology',
                              Icons.settings_accessibility_rounded,
                              '/radiology',
                              isDark,
                              textPrimary,
                            ),
                            _buildMenuItem(
                              context,
                              'Pre-Triage',
                              Icons.assignment_ind_rounded,
                              '/pre-triage',
                              isDark,
                              textPrimary,
                            ),
                            _buildMenuItem(
                              context,
                              'Billing & Rev',
                              Icons.currency_rupee_rounded,
                              '/billing',
                              isDark,
                              textPrimary,
                            ),
                            _buildMenuItem(
                              context,
                              'Users & Staff',
                              Icons.badge_rounded,
                              '/users-staff',
                              isDark,
                              textPrimary,
                            ),
                            _buildMenuItem(
                              context,
                              'Integrations',
                              Icons.integration_instructions_rounded,
                              '/integrations',
                              isDark,
                              textPrimary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String label,
    IconData icon,
    String route,
    bool isDark,
    Color textPrimary,
  ) {
    final cardBg = isDark
        ? AppColors.darkSurfaceVariant.withValues(alpha: 0.6)
        : AppColors.lightSurfaceVariant.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppDecorations.borderSM,
      ),
      child: ClipRRect(
        borderRadius: AppDecorations.borderSM,
        child: InkWell(
          onTap: () {
            _closeMenu();
            Get.toNamed(route);
          },
          splashColor: AppColors.primary.withValues(alpha: 0.15),
          highlightColor: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.xxs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: AppColors.primary,
                  size: AppSpacing.iconLG,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTextStyles.labelSmall(textPrimary).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Obx(() => Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppDecorations.radiusLG),
              topRight: Radius.circular(AppDecorations.radiusLG),
            ),
            border: Border(
                top: BorderSide(color: divider, width: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    index: 0,
                    selected: controller.selectedNavIndex == 0,
                    isDark: isDark,
                    onTap: () => controller.setNavIndex(0),
                  ),
                  _NavItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Appointments',
                    index: 1,
                    selected: controller.selectedNavIndex == 1,
                    isDark: isDark,
                    onTap: () {
                      controller.setNavIndex(1);
                      Get.toNamed('/appointments');
                    },
                  ),
                  _NavItem(
                    icon: Icons.bed_rounded,
                    label: 'Inpatient',
                    index: 2,
                    selected: controller.selectedNavIndex == 2,
                    isDark: isDark,
                    onTap: () {
                      controller.setNavIndex(2);
                      Get.toNamed('/inpatient');
                    },
                  ),
                  _NavItem(
                    icon: Icons.queue_rounded,
                    label: 'Queue',
                    index: 3,
                    selected: controller.selectedNavIndex == 3,
                    isDark: isDark,
                    onTap: () {
                      controller.setNavIndex(3);
                      Get.toNamed('/queue');
                    },
                  ),
                  // Floating More Button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleMenu,
                          splashColor: AppColors.primary.withValues(alpha: 0.25),
                          highlightColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: AppColors.primary,
                            size: AppSpacing.iconLG,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int index;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: AppDecorations.borderMD,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : textSecondary,
              size: AppSpacing.iconMD,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: AppTextStyles.labelSmall(
                  selected ? AppColors.primary : textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton Loader ───────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final highlight = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Welcome skeleton
          _SkeletonBox(height: 110, radius: AppDecorations.radiusLG),
          const SizedBox(height: AppSpacing.xl),
          // Grid skeleton
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.3,
            ),
            itemCount: 8,
            itemBuilder: (context, index) =>
                _SkeletonBox(height: 100, radius: AppDecorations.radiusLG),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Quick actions
          _SkeletonBox(height: 88, radius: AppDecorations.radiusMD),
          const SizedBox(height: AppSpacing.xl),
          // Cards
          _SkeletonBox(height: 180, radius: AppDecorations.radiusLG),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBox(height: 140, radius: AppDecorations.radiusLG),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBox(height: 260, radius: AppDecorations.radiusLG),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, required this.radius});
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Error State ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });
  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: AppColors.error, size: AppSpacing.iconXL),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Connection Error',
                style: AppTextStyles.titleLarge(textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodyMedium(textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.lightSurface,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxxl, vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                    borderRadius: AppDecorations.borderMD),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.isDark,
    this.color,
  });
  final IconData icon;
  final String message;
  final bool isDark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final iconColor = color ?? textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor.withValues(alpha: 0.4), size: AppSpacing.iconXL),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodyMedium(textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
