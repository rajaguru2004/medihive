import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/models/pre_triage_model.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/pre_triage_controller.dart';

class PreTriageView extends GetView<PreTriageController> {
  const PreTriageView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        elevation: 0,
        toolbarHeight: 82,
        leadingWidth: 64,
        titleSpacing: 8,
        leading: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textPrimary,
                size: 16,
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkGlass : AppColors.lightGlass,
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.borderSM,
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkGlassBorder
                        : AppColors.lightGlassBorder,
                    width: 0.5,
                  ),
                ),
              ),
              onPressed: () => Get.back(),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pre-Triage Screenings',
              style: AppTextStyles.titleMedium(textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              'Capture and manage walk-in patient screenings.',
              style: AppTextStyles.bodySmall(textSecondary),
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed(Routes.NEW_SCREENING_STEP1),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.borderMD,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.onRefresh,
          child: Column(
            children: [
              // ─── Header Stats ───
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: _buildStatsGrid(context, isDark),
              ),

              // ─── Search & Filter Controls ───
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: _buildSearchAndFilter(context, isDark),
              ),

              // ─── Screenings ListView ───
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value &&
                      controller.screenings.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (controller.errorMessage.isNotEmpty &&
                      controller.screenings.isEmpty) {
                    return _buildErrorState(context, isDark);
                  }

                  final list = controller.filteredScreenings;

                  if (list.isEmpty) {
                    return _buildEmptyState(context, isDark);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      bottom: AppSpacing.huge + AppSpacing.huge,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _buildScreeningCard(context, item, isDark);
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Grid of stats: 2x2 Material cards
  Widget _buildStatsGrid(BuildContext context, bool isDark) {
    return Obx(() {
      final total = controller.totalCount.value;
      final screening = controller.screeningCount.value;
      final routed = controller.routedCount.value;
      final registered = controller.registeredCount.value;

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.2,
        children: [
          _buildStatCard(
            title: 'TOTAL SCREENINGS',
            value: '$total',
            icon: Icons.assignment_rounded,
            color: AppColors.primary,
            isDark: isDark,
          ),
          _buildStatCard(
            title: 'IN SCREENING',
            value: '$screening',
            icon: Icons.pending_actions_rounded,
            color: AppColors.primary,
            isDark: isDark,
          ),
          _buildStatCard(
            title: 'ROUTED',
            value: '$routed',
            icon: Icons.alt_route_rounded,
            color: AppColors.warning,
            isDark: isDark,
          ),
          _buildStatCard(
            title: 'REGISTERED',
            value: '$registered',
            icon: Icons.how_to_reg_rounded,
            color: AppColors.secondary,
            isDark: isDark,
          ),
        ],
      );
    });
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

  /// Search & Filter Row
  Widget _buildSearchAndFilter(BuildContext context, bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Row(
      children: [
        // Search text field
        Expanded(
          flex: 3,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: AppDecorations.borderMD,
              boxShadow: AppDecorations.elevation1(isDark),
            ),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.setSearchQuery,
              style: AppTextStyles.bodyMedium(textPrimary),
              decoration: InputDecoration(
                hintText: 'Search patient...',
                hintStyle: AppTextStyles.bodyMedium(textSecondary),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                suffixIcon: Obx(() {
                  if (controller.searchQuery.value.isNotEmpty) {
                    return IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        controller.searchController.clear();
                        controller.setSearchQuery('');
                      },
                    );
                  }
                  return const SizedBox.shrink();
                }),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Dropdown Filter
        Expanded(
          flex: 2,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: AppDecorations.borderMD,
              boxShadow: AppDecorations.elevation1(isDark),
              border: Border.all(
                color: isDark
                    ? AppColors.darkGlassBorder
                    : AppColors.lightGlassBorder,
                width: 0.5,
              ),
            ),
            child: Obx(
              () => DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.selectedFilter.value,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                  style: AppTextStyles.labelMedium(textPrimary),
                  dropdownColor: surface,
                  borderRadius: AppDecorations.borderMD,
                  onChanged: (val) {
                    if (val != null) controller.setFilter(val);
                  },
                  items: controller.filterOptions.map((e) {
                    return DropdownMenuItem<String>(value: e, child: Text(e));
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Screening List Card Item
  Widget _buildScreeningCard(
    BuildContext context,
    PreTriageModel item,
    bool isDark,
  ) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
        border: Border.all(
          color: isDark
              ? AppColors.darkGlassBorder
              : AppColors.lightGlassBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name, Age, Gender, ID, and Status Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.fullName,
                          style: AppTextStyles.titleMedium(textPrimary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildGenderBadge(item.gender, isDark),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${item.age ?? "N/A"} yrs • ID: ${item.screeningId}',
                      style: AppTextStyles.bodySmall(textSecondary),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(item.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 2: Chief Complaint
          Text(
            'Chief Complaint',
            style: AppTextStyles.labelSmall(textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            item.chiefComplaint,
            style: AppTextStyles.bodyMedium(textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 3: Vitals Chips
          _buildVitalsChips(item, isDark),
          const SizedBox(height: AppSpacing.md),

          // Row 4: Route, Date, Time & Popup Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route to: ${item.route != null && item.route!.isNotEmpty ? item.route!.toUpperCase() : "N/A"}',
                    style: AppTextStyles.labelMedium(AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt),
                    style: AppTextStyles.bodySmall(textSecondary),
                  ),
                ],
              ),
              _buildPopupMenuButton(context, item, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderBadge(String? gender, bool isDark) {
    if (gender == null) return const SizedBox.shrink();
    final isMale = gender.toLowerCase() == 'male';
    final color = isMale ? AppColors.info : AppColors.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppDecorations.borderFull,
      ),
      child: Text(gender.toUpperCase(), style: AppTextStyles.labelSmall(color)),
    );
  }

  Widget _buildStatusChip(String status) {
    StatusType type;
    String label;

    switch (status) {
      case 'screening':
        type = StatusType.neutral; // Blue fallback
        label = 'Screening';
        break;
      case 'routed':
        type = StatusType.warning; // Orange
        label = 'Routed';
        break;
      case 'registered_as_patient':
        type = StatusType.success; // Green
        label = 'Registered';
        break;
      default:
        type = StatusType.neutral;
        label = status.toUpperCase();
    }

    return StatusBadge(label: label, type: type);
  }

  Widget _buildVitalsChips(PreTriageModel item, bool isDark) {
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (item.temperature == null &&
        item.bpSystolic == null &&
        item.bpDiastolic == null &&
        item.pulse == null) {
      return Text(
        'Vitals: Not recorded',
        style: AppTextStyles.bodySmall(textSecondary),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (item.temperature != null)
          _buildVitalPill(
            icon: Icons.thermostat_rounded,
            label: '${item.temperature}°C',
            color: AppColors.error,
            isDark: isDark,
          ),
        if (item.bpSystolic != null || item.bpDiastolic != null)
          _buildVitalPill(
            icon: Icons.favorite_rounded,
            label: '${item.bpSystolic ?? "?"}/${item.bpDiastolic ?? "?"} mmHg',
            color: AppColors.primary,
            isDark: isDark,
          ),
        if (item.pulse != null)
          _buildVitalPill(
            icon: Icons.favorite_rounded, // fallback Pulse icon
            label: '${item.pulse} bpm',
            color: AppColors.secondary,
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildVitalPill({
    required IconData icon,
    IconData? iconData,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    final surface = isDark ? AppColors.darkSurfaceVariant : Colors.grey[100]!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderSM,
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData ?? icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.numeric(color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPopupMenuButton(
    BuildContext context,
    PreTriageModel item,
    bool isDark,
  ) {
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'details') {
          Get.toNamed(Routes.PRE_TRIAGE_DETAILS, arguments: item);
        } else if (val == 'edit') {
          Get.toNamed(Routes.EDIT_SCREENING, arguments: item);
        } else if (val == 'convert') {
          _showConvertDialog(context, item, isDark);
        } else if (val == 'delete') {
          _showDeleteDialog(context, item, isDark);
        }
      },
      icon: Icon(Icons.more_vert_rounded, color: textColor),
      shape: RoundedRectangleBorder(borderRadius: AppDecorations.borderMD),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> menu = [
          PopupMenuItem<String>(
            value: 'details',
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'View Details',
                  style: AppTextStyles.labelMedium(textColor),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text('Edit', style: AppTextStyles.labelMedium(textColor)),
              ],
            ),
          ),
        ];

        if (item.status == 'screening') {
          menu.add(
            PopupMenuItem<String>(
              value: 'convert',
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_outlined,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Convert to Patient',
                    style: AppTextStyles.labelMedium(AppColors.secondary),
                  ),
                ],
              ),
            ),
          );
        }

        menu.add(
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Delete',
                  style: AppTextStyles.labelMedium(AppColors.error),
                ),
              ],
            ),
          ),
        );

        return menu;
      },
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    PreTriageModel item,
    bool isDark,
  ) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.borderXL,
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Stack(
            children: [
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(
                    Icons.close,
                    color: textSecondary.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Delete Screening?',
                      style: AppTextStyles.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium(textSecondary).copyWith(
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Are you sure you want to delete the screening for ',
                          ),
                          TextSpan(
                            text: item.fullName,
                            style: AppTextStyles.bodyMedium(textPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: '? This action cannot be undone.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () => Get.back(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 40),
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.darkDivider
                                      : AppColors.lightDivider,
                                  width: 1.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDecorations.borderSM,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.labelLarge(textPrimary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: () => controller.deleteScreeningItem(item),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: Text(
                                'Delete',
                                style: AppTextStyles.labelLarge(Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 40),
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDecorations.borderSM,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConvertDialog(
    BuildContext context,
    PreTriageModel item,
    bool isDark,
  ) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.borderXL,
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Stack(
            children: [
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(
                    Icons.close,
                    color: textSecondary.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Convert to Patient?',
                      style: AppTextStyles.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium(textSecondary).copyWith(
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text: 'This will create a full patient record for ',
                          ),
                          TextSpan(
                            text: item.fullName,
                            style: AppTextStyles.bodyMedium(textPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' and assign a permanent MRN. This action cannot be undone.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () => Get.back(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 40),
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.darkDivider
                                      : AppColors.lightDivider,
                                  width: 1.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDecorations.borderSM,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.labelLarge(textPrimary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Get.back();
                                controller.convertScreeningToPatient(item);
                              },
                              icon: const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: Text(
                                'Convert',
                                style: AppTextStyles.labelLarge(Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 40),
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDecorations.borderSM,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_ind_outlined,
                color: AppColors.primary,
                size: 64,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Screenings Found',
              style: AppTextStyles.titleMedium(textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try adjusting your search or filters.',
              style: AppTextStyles.bodySmall(textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Failed to load data',
              style: AppTextStyles.titleMedium(AppColors.error),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                controller.errorMessage.value,
                style: AppTextStyles.bodySmall(textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: controller.fetchScreenings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.borderSM,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
