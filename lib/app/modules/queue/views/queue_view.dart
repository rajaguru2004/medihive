import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../../../data/models/queue_item.dart';
import '../controllers/queue_controller.dart';

class QueueView extends GetView<QueueController> {
  final bool isEmbedded;
  const QueueView({super.key, this.isEmbedded = true});

  @override
  Widget build(BuildContext context) {
    // Ensure controller is initialized
    if (!Get.isRegistered<QueueController>()) {
      Get.put(QueueController());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    Widget bodyWidget = Obx(() {
      if (controller.isLoading && controller.liveQueueItems.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      if (controller.hasError && controller.liveQueueItems.isEmpty) {
        return _buildErrorState(isDark);
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.onRefresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          children: [
            _buildTopSection(context, isDark),
            const SizedBox(height: AppSpacing.lg),
            _buildStatsGrid(isDark),
            const SizedBox(height: AppSpacing.lg),
            _buildFilterRow(context, isDark),
            const SizedBox(height: AppSpacing.lg),
            _buildTabsRow(isDark),
            const SizedBox(height: AppSpacing.md),
            _buildQueueList(isDark),
          ],
        ),
      );
    });

    if (isEmbedded) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: bodyWidget),
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
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            size: AppSpacing.iconMD,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Queue Management',
          style: AppTextStyles.titleMedium(
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: SafeArea(child: bodyWidget),
    );
  }

  // ─── Component Builders ───────────────────────────────────────────────────

  Widget _buildTopSection(BuildContext context, bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Queue Management',
                    style: AppTextStyles.headlineSmall(textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Real-time patient queue across service areas',
                    style: AppTextStyles.bodySmall(textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => controller.callNextPatient(),
                icon: const Icon(
                  Icons.volume_up_rounded,
                  size: AppSpacing.iconSM,
                ),
                label: const Text('Call Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDecorations.borderMD,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Get.toNamed(Routes.ADD_TO_QUEUE),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: AppSpacing.iconSM,
                ),
                label: const Text('Add to Queue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDecorations.borderMD,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          icon: Icons.hourglass_empty_rounded,
          count: controller.waitingCount,
          label: 'Waiting',
          color: AppColors.warning,
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.phone_forwarded_rounded,
          count: controller.calledCount,
          label: 'Called',
          color: AppColors.secondary,
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.medical_services_rounded,
          count: controller.inServiceCount,
          label: 'In Service',
          color: AppColors.primary,
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.check_circle_rounded,
          count: controller.completedCount,
          label: 'Completed',
          color: AppColors.tertiary,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        boxShadow: AppDecorations.elevation1(isDark),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppDecorations.borderSM,
            ),
            child: Icon(icon, color: color, size: AppSpacing.iconMD),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$count', style: AppTextStyles.headlineSmall(textPrimary)),
                Text(
                  label,
                  style: AppTextStyles.labelSmall(color),
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

  Widget _buildFilterRow(BuildContext context, bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final List<String> areas = [
      'All Areas',
      'OPD',
      'Emergency',
      'MCH',
      'Psychiatric',
      'Laboratory',
      'Pharmacy',
      'Radiology',
      'Pediatric',
    ];

    return Row(
      children: [
        // Horizontal scroll area for Service tabs
        Expanded(
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: areas.length,
              itemBuilder: (context, idx) {
                final area = areas[idx];
                final isSelected = controller.selectedServiceArea.value == area;

                return GestureDetector(
                  onTap: () => controller.setServiceAreaFilter(area),
                  child: Container(
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.secondary : Colors.transparent,
                      borderRadius: AppDecorations.borderMD,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.secondary
                            : (isDark
                                ? AppColors.darkDivider
                                : AppColors.lightDivider),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      area,
                      style: AppTextStyles.labelMedium(
                        isSelected ? Colors.white : textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Dropdown filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppDecorations.borderMD,
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: controller.selectedPriority.value,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
              ),
              style: AppTextStyles.labelMedium(textPrimary),
              dropdownColor:
                  isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: AppDecorations.borderMD,
              onChanged: (val) {
                if (val != null) controller.setPriorityFilter(val);
              },
              items: <String>[
                'All Priorities',
                'Urgent',
                'Normal',
                'Low',
                'Routine',
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabsRow(bool isDark) {
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      child: Row(
        children: [
          _buildTabButton('Live Queue', isDark),
          _buildTabButton('History', isDark),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabName, bool isDark) {
    final isSelected = controller.activeTab.value == tabName;
    final color = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary);

    return GestureDetector(
      onTap: () => controller.setActiveTab(tabName),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(tabName, style: AppTextStyles.labelLarge(color)),
      ),
    );
  }

  Widget _buildQueueList(bool isDark) {
    final items = controller.displayedQueueItems;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.colossal),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_rounded,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
                size: AppSpacing.iconXL,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No queue items found matching filters',
                style: AppTextStyles.bodyMedium(
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildQueueCard(context, item, isDark);
      },
    );
  }

  Widget _buildQueueCard(BuildContext context, QueueItem item, bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Calculate waiting time
    final diff = DateTime.now().difference(item.joinedQueueAt);
    final waitText = "${diff.inHours}h ${diff.inMinutes % 60}m";

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Queue Number Badge (Left)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: AppDecorations.borderSM,
            ),
            child: Text(
              item.displayQueueNumber,
              style: AppTextStyles.numeric(
                AppColors.secondary,
                fontSize: 16,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Patient info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.patient.fullName,
                  style: AppTextStyles.titleSmall(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  item.patient.mrn,
                  style: AppTextStyles.numeric(textSecondary, fontSize: 11),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _buildPriorityChip(item.priority),
                    const SizedBox(width: AppSpacing.sm),
                    // Clock icon and wait time
                    Icon(
                      Icons.access_time_rounded,
                      color: AppColors.error,
                      size: AppSpacing.iconXS,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      waitText,
                      style: AppTextStyles.labelSmall(AppColors.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Status Badge
          _buildStatusBadge(item.status),
          const SizedBox(width: AppSpacing.sm),
          // Option menu
          if (item.status.toLowerCase() == 'waiting' ||
              item.status.toLowerCase() == 'called' ||
              item.status.toLowerCase() == 'in_service')
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
                size: AppSpacing.iconMD,
              ),
              offset: const Offset(0, AppSpacing.massive),
              shape: RoundedRectangleBorder(
                borderRadius: AppDecorations.borderMD,
              ),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              onSelected: (val) {
                if (val == 'call') {
                  controller.callPatient(item.id, item.patient.fullName);
                } else if (val == 'start_service') {
                  controller.startService(item.id, item.patient.fullName);
                } else if (val == 'mark_no_show') {
                  controller.markNoShow(item.id, item.patient.fullName);
                } else if (val == 'mark_complete') {
                  controller.markComplete(item.id, item.patient.fullName);
                } else if (val == 'cancel') {
                  controller.cancelQueueItem(item.id, item.patient.fullName);
                } else if (val == 'remove') {
                  controller.deleteQueueItem(item.id, item.patient.fullName);
                }
              },
              itemBuilder: (context) {
                final status = item.status.toLowerCase();
                final menuItems = <PopupMenuEntry<String>>[];

                if (status == 'waiting') {
                  menuItems.addAll([
                    _buildMenuItem(
                        'call',
                        'Call Patient',
                        Icons.volume_up_rounded,
                        AppColors.primary,
                        textPrimary),
                    _buildMenuItem('cancel', 'Cancel', Icons.cancel_outlined,
                        AppColors.error, textPrimary),
                    _buildMenuItem(
                        'remove',
                        'Remove from Queue',
                        Icons.delete_outline_rounded,
                        AppColors.error,
                        AppColors.error),
                  ]);
                } else if (status == 'called') {
                  menuItems.addAll([
                    _buildMenuItem(
                        'start_service',
                        'Start Service',
                        Icons.play_arrow_rounded,
                        AppColors.secondary,
                        textPrimary),
                    _buildMenuItem(
                        'mark_no_show',
                        'Mark No-Show',
                        Icons.person_off_rounded,
                        AppColors.warning,
                        textPrimary),
                    _buildMenuItem('cancel', 'Cancel', Icons.cancel_outlined,
                        AppColors.error, textPrimary),
                    _buildMenuItem(
                        'remove',
                        'Remove from Queue',
                        Icons.delete_outline_rounded,
                        AppColors.error,
                        AppColors.error),
                  ]);
                } else if (status == 'in_service') {
                  menuItems.addAll([
                    _buildMenuItem(
                        'mark_complete',
                        'Mark Complete',
                        Icons.check_circle_outline_rounded,
                        AppColors.secondary,
                        textPrimary),
                    _buildMenuItem('cancel', 'Cancel', Icons.cancel_outlined,
                        AppColors.error, textPrimary),
                    _buildMenuItem(
                        'remove',
                        'Remove from Queue',
                        Icons.delete_outline_rounded,
                        AppColors.error,
                        AppColors.error),
                  ]);
                }

                return menuItems;
              },
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    final p = priority.toLowerCase();
    Color color;
    switch (p) {
      case 'urgent':
        color = AppColors.error;
        break;
      case 'normal':
        color = AppColors.secondary;
        break;
      case 'low':
        color = AppColors.info;
        break;
      case 'routine':
      default:
        color = AppColors.tertiary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppDecorations.borderFull,
      ),
      child: Text(
        priority[0].toUpperCase() + priority.substring(1),
        style: AppTextStyles.labelSmall(color),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toLowerCase();
    String label;
    StatusType type;

    switch (s) {
      case 'waiting':
        label = '• Waiting';
        type = StatusType.warning;
        break;
      case 'called':
        label = '• Called';
        type = StatusType.success;
        break;
      case 'in_service':
        label = '• In Service';
        type = StatusType.info;
        break;
      case 'completed':
        label = 'Completed';
        type = StatusType.success;
        break;
      case 'cancelled':
        label = 'Cancelled';
        type = StatusType.error;
        break;
      default:
        label = status;
        type = StatusType.neutral;
    }

    return StatusBadge(label: label, type: type);
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: AppSpacing.iconXL,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error loading queue data',
              style: AppTextStyles.titleMedium(
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              controller.errorMessage,
              style: AppTextStyles.bodySmall(
                isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => controller.fetchQueueData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    String label,
    IconData icon,
    Color iconColor,
    Color textColor,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: AppSpacing.iconSM,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.bodyMedium(textColor),
          ),
        ],
      ),
    );
  }
}
