// lib/app/modules/queue/views/queue_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'package:medihive/app/theme/theme.dart';
import '../controllers/queue_controller.dart';
import '../models/queue_model.dart';
import 'add_to_queue_view.dart';
import 'queue_detail_view.dart';

class QueueView extends GetView<QueueController> {
  const QueueView({super.key});

  static const _serviceAreas = [
    ('', 'All Areas'),
    ('opd', 'OPD'),
    ('emergency', 'Emergency'),
    ('mch', 'MCH'),
    ('psychiatric', 'Psychiatric'),
    ('laboratory', 'Laboratory'),
    ('pharmacy', 'Pharmacy'),
    ('radiology', 'Radiology'),
    ('pediatric', 'Pediatric'),
  ];

  static const _priorities = [
    ('', 'All Priorities'),
    ('urgent', 'Urgent'),
    ('normal', 'Normal'),
    ('low', 'Low'),
    ('routine', 'Routine'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      // ── Custom AppBar as body header (avoids overflow) ──────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _QueueAppBar(
          isDark: isDark,
          surface: surface,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
      ),
      body: GetBuilder<QueueController>(
        builder: (ctrl) {
          if (ctrl.isLoading) {
            return _QueueSkeleton(isDark: isDark);
          }
          if (ctrl.hasError) {
            return _QueueErrorState(
              message: ctrl.errorMessage,
              onRetry: ctrl.fetchQueue,
              isDark: isDark,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: surface,
            onRefresh: ctrl.onRefresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── Summary Grid ─────────────────────────────────────────────
                _SummaryGrid(summary: ctrl.summary, isDark: isDark),

                // ── Service Area Tabs ─────────────────────────────────────────
                const SizedBox(height: AppSpacing.xxs),
                _ServiceAreaRow(
                  areas: _serviceAreas,
                  selected: ctrl.selectedArea,
                  onSelect: ctrl.setServiceArea,
                  isDark: isDark,
                ),

                // ── Priority Dropdown ─────────────────────────────────────────
                const SizedBox(height: AppSpacing.sm),
                _PriorityFilterRow(
                  priorities: _priorities,
                  selected: ctrl.selectedPriority,
                  onSelect: ctrl.setPriority,
                  isDark: isDark,
                ),

                // ── Live / History Tabs ───────────────────────────────────────
                const SizedBox(height: AppSpacing.md),
                _ViewTabBar(
                  selected: ctrl.viewTab,
                  onSelect: ctrl.setViewTab,
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Queue List ────────────────────────────────────────────────
                if (ctrl.viewTab == QueueViewTab.live)
                  _QueueList(
                    items: ctrl.filteredItems,
                    isDark: isDark,
                    controller: ctrl,
                  )
                else
                  _HistoryList(
                    items: ctrl.filteredHistory,
                    isLoading: ctrl.isHistoryLoading,
                    isDark: isDark,
                  ),

                const SizedBox(height: AppSpacing.massive),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom AppBar — Title left, buttons right, no overflow
// ─────────────────────────────────────────────────────────────────────────────
class _QueueAppBar extends StatelessWidget {
  const _QueueAppBar({
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Get.back(),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: textPrimary,
                  size: AppSpacing.iconMD,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Title + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Queue Management',
                      style: AppTextStyles.titleMedium(textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Real-time patient queue',
                      style: AppTextStyles.labelSmall(textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Call Next button
              GetBuilder<QueueController>(
                builder: (ctrl) => _AppBarButton(
                  label: 'Call Next',
                  icon: Icons.phone_in_talk_rounded,
                  onTap: ctrl.callNext,
                  backgroundColor: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  foregroundColor: textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Add to Queue button
              _AppBarButton(
                label: 'Add',
                icon: Icons.add_circle_outline_rounded,
                onTap: () async {
                  await Get.to(
                    () => const AddToQueueView(),
                    transition: Transition.cupertino,
                  );
                  // Refresh after returning from Add screen
                  Get.find<QueueController>().fetchQueue();
                },
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.lightSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  const _AppBarButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSpacing.iconXS + 2, color: foregroundColor),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTextStyles.labelSmall(foregroundColor)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Grid (2×2)
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.isDark});

  final QueueSummary summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final cards = [
      _SummaryCardData(
        icon: Icons.people_alt_rounded,
        count: summary.waiting,
        label: 'Waiting',
        color: AppColors.warning,
      ),
      _SummaryCardData(
        icon: Icons.phone_in_talk_rounded,
        count: summary.called,
        label: 'Called',
        color: AppColors.info,
      ),
      _SummaryCardData(
        icon: Icons.medical_services_rounded,
        count: summary.inService,
        label: 'In Service',
        color: AppColors.secondary,
      ),
      _SummaryCardData(
        icon: Icons.check_circle_outline_rounded,
        count: summary.completed,
        label: 'Completed',
        color: isDark
            ? AppColors.darkTextTertiary
            : AppColors.lightTextTertiary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.4,
        children: cards
            .map((c) => _SummaryCard(data: c, surface: surface, isDark: isDark))
            .toList(),
      ),
    );
  }
}

class _SummaryCardData {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _SummaryCardData({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.data,
    required this.surface,
    required this.isDark,
  });

  final _SummaryCardData data;
  final Color surface;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(data.icon, color: data.color, size: AppSpacing.iconSM),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${data.count}',
                style: AppTextStyles.titleLarge(
                  data.color,
                ).copyWith(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              Text(data.label, style: AppTextStyles.labelSmall(textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service Area Tabs — horizontally scrollable chips
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceAreaRow extends StatelessWidget {
  const _ServiceAreaRow({
    required this.areas,
    required this.selected,
    required this.onSelect,
    required this.isDark,
  });

  final List<(String, String)> areas;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: areas.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final (value, label) = areas[i];
          final isSelected = selected == value;
          return _AreaChip(
            label: label,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onSelect(value),
          );
        },
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : surface,
          borderRadius: BorderRadius.circular(AppSpacing.massive),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall(
            isSelected ? AppColors.lightSurface : textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Priority Filter Dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _PriorityFilterRow extends StatelessWidget {
  const _PriorityFilterRow({
    required this.priorities,
    required this.selected,
    required this.onSelect,
    required this.isDark,
  });

  final List<(String, String)> priorities;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: textSecondary,
              size: AppSpacing.iconSM,
            ),
            dropdownColor: surface,
            style: AppTextStyles.bodySmall(textPrimary),
            onChanged: (v) => onSelect(v ?? ''),
            items: priorities
                .map(
                  (p) => DropdownMenuItem(
                    value: p.$1,
                    child: Text(
                      p.$2,
                      style: AppTextStyles.bodySmall(textPrimary),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live / History Tab Bar
// ─────────────────────────────────────────────────────────────────────────────
class _ViewTabBar extends StatelessWidget {
  const _ViewTabBar({
    required this.selected,
    required this.onSelect,
    required this.isDark,
  });

  final QueueViewTab selected;
  final ValueChanged<QueueViewTab> onSelect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _TabBtn(
            label: 'Live Queue',
            isSelected: selected == QueueViewTab.live,
            onTap: () => onSelect(QueueViewTab.live),
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          _TabBtn(
            label: 'History',
            isSelected: selected == QueueViewTab.history,
            onTap: () => onSelect(QueueViewTab.history),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary)
              : AppColors.lightBackground.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium(
            isSelected ? AppColors.lightSurface : textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Queue List
// ─────────────────────────────────────────────────────────────────────────────
class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.items,
    required this.isDark,
    required this.controller,
  });

  final List<QueueModel> items;
  final bool isDark;
  final QueueController controller;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(
        isDark: isDark,
        message: 'No patients in queue',
        icon: Icons.queue_rounded,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) =>
          _QueueCard(item: items[i], isDark: isDark, controller: controller),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Queue Card
// ─────────────────────────────────────────────────────────────────────────────
class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.item,
    required this.isDark,
    required this.controller,
  });

  final QueueModel item;
  final bool isDark;
  final QueueController controller;

  Color get _priorityColor {
    switch (item.priority.toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'normal':
        return AppColors.info;
      case 'low':
        return AppColors.secondary;
      default:
        return AppColors.darkTextTertiary;
    }
  }

  Color get _statusColor {
    switch (item.status.toLowerCase()) {
      case 'waiting':
        return AppColors.warning;
      case 'called':
        return AppColors.primary;
      case 'in_service':
        return AppColors.secondary;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  String get _statusLabel {
    switch (item.status.toLowerCase()) {
      case 'waiting':
        return 'Waiting';
      case 'called':
        return 'Called';
      case 'in_service':
        return 'In Service';
      case 'completed':
        return 'Completed';
      default:
        return item.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textTertiary = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: () {
        Get.to(
          () => QueueDetailView(item: item),
          transition: Transition.cupertino,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Queue number badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              alignment: Alignment.center,
              child: Text(
                item.shortQueueNumber,
                style: AppTextStyles.numeric(AppColors.secondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
  
            // Patient info — takes remaining space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + MRN
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: AppSpacing.iconXS,
                        color: textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.xxs + 2),
                      Expanded(
                        child: Text(
                          '${item.patient.fullName} · ${item.patient.mrn}',
                          style: AppTextStyles.titleSmall(textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
  
                  // Priority chip + Wait time
                  Row(
                    children: [
                      _PriorityChip(
                        label: _capitalize(item.priority),
                        color: _priorityColor,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.access_time_rounded,
                        size: AppSpacing.iconXS,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.xxs + 2),
                      Text(
                        item.formattedWaitTime,
                        style: AppTextStyles.bodySmall(
                          textTertiary,
                        ).copyWith(color: AppColors.error),
                      ),
                    ],
                  ),
                ],
              ),
            ),
  
            const SizedBox(width: AppSpacing.sm),
  
            // Status + 3-dot menu column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusBadge(label: _statusLabel, color: _statusColor),
                _QueueItemMenu(
                  item: item,
                  isDark: isDark,
                  controller: controller,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.massive),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.labelSmall(color)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.massive),
      ),
      child: Text('• $label', style: AppTextStyles.labelSmall(color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-Dot Menu
// ─────────────────────────────────────────────────────────────────────────────
class _QueueItemMenu extends StatelessWidget {
  const _QueueItemMenu({
    required this.item,
    required this.isDark,
    required this.controller,
  });

  final QueueModel item;
  final bool isDark;
  final QueueController controller;

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final surface = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurface;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: AppSpacing.iconSM,
        color: textPrimary,
      ),
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      padding: EdgeInsets.zero,
      elevation: 4,
      onSelected: (val) async {
        switch (val) {
          case 'call':
            await controller.callPatient(item);
            break;
          case 'start_service':
            await controller.startService(item);
            break;
          case 'mark_no_show':
            await controller.markNoShow(item);
            break;
          case 'mark_complete':
            await controller.markComplete(item);
            break;
          case 'cancel':
            await controller.cancelPatient(item);
            break;
          case 'remove':
            await controller.removeFromQueue(item);
            break;
        }
      },
      itemBuilder: (_) {
        final status = item.status.toLowerCase();
        if (status == 'waiting') {
          return [
            _menuItem(
              'call',
              Icons.phone_in_talk_rounded,
              AppColors.primary,
              'Call Patient',
              textPrimary,
            ),
            _menuItem(
              'cancel',
              Icons.cancel_outlined,
              AppColors.error,
              'Cancel',
              AppColors.error,
            ),
            _menuItem(
              'remove',
              Icons.delete_outline_rounded,
              AppColors.error,
              'Remove from Queue',
              AppColors.error,
            ),
          ];
        } else if (status == 'called') {
          return [
            _menuItem(
              'start_service',
              Icons.play_arrow_outlined,
              textPrimary,
              'Start Service',
              textPrimary,
            ),
            _menuItem(
              'mark_no_show',
              Icons.info_outline_rounded,
              textPrimary,
              'Mark No-Show',
              textPrimary,
            ),
            _menuItem(
              'cancel',
              Icons.cancel_outlined,
              AppColors.error,
              'Cancel',
              AppColors.error,
            ),
            _menuItem(
              'remove',
              Icons.delete_outline_rounded,
              AppColors.error,
              'Remove from Queue',
              AppColors.error,
            ),
          ];
        } else if (status == 'in_service') {
          return [
            _menuItem(
              'mark_complete',
              Icons.check_circle_outline_rounded,
              textPrimary,
              'Mark Complete',
              textPrimary,
            ),
            _menuItem(
              'cancel',
              Icons.cancel_outlined,
              AppColors.error,
              'Cancel',
              AppColors.error,
            ),
            _menuItem(
              'remove',
              Icons.delete_outline_rounded,
              AppColors.error,
              'Remove from Queue',
              AppColors.error,
            ),
          ];
        }
        return [];
      },
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    Color iconColor,
    String label,
    Color textColor,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.iconSM, color: iconColor),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTextStyles.bodySmall(textColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History List
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.items,
    required this.isLoading,
    required this.isDark,
  });

  final List<QueueModel> items;
  final bool isLoading;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxxl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (items.isEmpty) {
      return _EmptyState(
        isDark: isDark,
        message: 'No history records found',
        icon: Icons.history_rounded,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _HistoryCard(item: items[i], isDark: isDark),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.isDark});

  final QueueModel item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: () {
        Get.to(
          () => QueueDetailView(item: item),
          transition: Transition.cupertino,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              alignment: Alignment.center,
              child: Text(
                item.shortQueueNumber,
                style: AppTextStyles.numeric(AppColors.success, fontSize: 12),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.patient.fullName,
                    style: AppTextStyles.titleSmall(textPrimary),
                  ),
                  Text(
                    item.patient.mrn,
                    style: AppTextStyles.bodySmall(textSecondary),
                  ),
                ],
              ),
            ),
            _StatusBadge(label: 'Completed', color: AppColors.success),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isDark,
    required this.message,
    required this.icon,
  });

  final bool isDark;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.colossal),
      child: Column(
        children: [
          Icon(
            icon,
            size: AppSpacing.iconXL,
            color: textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: AppTextStyles.bodyMedium(textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────
class _QueueErrorState extends StatelessWidget {
  const _QueueErrorState({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: AppSpacing.iconXL,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load queue',
              style: AppTextStyles.titleSmall(textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodySmall(textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: AppSpacing.iconSM),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.lightSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton Loading
// ─────────────────────────────────────────────────────────────────────────────
class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grid skeleton
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.4,
              children: List.generate(
                4,
                (_) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Chips skeleton
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(AppSpacing.massive),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Cards
            ...List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
