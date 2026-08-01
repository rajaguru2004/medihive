import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/consultation_model.dart';
import '../../../models/doctor_model.dart';
import '../../../models/queue_item.dart';
import '../../../theme/theme.dart';
import '../controllers/consultations_controller.dart';

class ConsultationsView extends GetView<ConsultationsController> {
  const ConsultationsView({super.key});

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
        toolbarHeight: 90,
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
                backgroundColor: isDark
                    ? AppColors.darkGlass
                    : AppColors.lightGlass,
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
              'Clinical Consultations',
              style: AppTextStyles.titleMedium(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage patient visits, assessments & prescriptions.',
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
              onPressed: () {
                Get.snackbar(
                  'Info',
                  'Starting a new consultation visit...',
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                  colorText: AppColors.secondary,
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
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
          onRefresh: controller.loadAllData,
          child: CustomScrollView(
            controller: controller.scrollController,
            slivers: [
              // Statistics Cards Grid
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: Obx(() {
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.45,
                      children: [
                        _StatisticsCard(
                          title: 'Total Visits',
                          count: controller.totalVisits.value,
                          icon: Icons.assignment_rounded,
                          accentColor: AppColors.primary,
                        ),
                        _StatisticsCard(
                          title: 'Outpatient',
                          count: controller.outpatientCount.value,
                          icon: Icons.medical_services_outlined,
                          accentColor: AppColors.secondary,
                        ),
                        _StatisticsCard(
                          title: 'Emergency',
                          count: controller.emergencyCount.value,
                          icon: Icons.warning_amber_rounded,
                          accentColor: AppColors.error,
                        ),
                        _StatisticsCard(
                          title: 'Follow-up',
                          count: controller.followUpCount.value,
                          icon: Icons.timeline_rounded,
                          accentColor: AppColors.tertiary,
                        ),
                      ],
                    );
                  }),
                ),
              ),

              // Search & Filters Row
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(child: _SearchFilterBar()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              // OPD Waiting Queue
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(child: _WaitingQueueCard()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              // Consultation list
              Obx(() {
                if (controller.isLoading.value &&
                    controller.consultations.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                if (controller.consultations.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            color: textSecondary.withValues(alpha: 0.4),
                            size: 64,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No clinical consultations found',
                            style: AppTextStyles.titleMedium(
                              textSecondary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Try adjusting search queries or date filters.',
                            style: AppTextStyles.bodyMedium(textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == controller.consultations.length) {
                        return controller.hasMore.value
                            ? const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();
                      }

                      final consultation = controller.consultations[index];
                      return _ConsultationCard(consultation: consultation);
                    }, childCount: controller.consultations.length + 1),
                  ),
                );
              }),

              // Extra spacing at bottom to prevent floating action buttons clashing
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-Widget: Statistics Card ─────────────────────────────────────────────
class _StatisticsCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;

  const _StatisticsCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final valueColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTextStyles.labelSmall(
                    titleColor,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: AppDecorations.borderSM,
                ),
                child: Icon(icon, color: accentColor, size: AppSpacing.iconSM),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            count.toString(),
            style: AppTextStyles.numeric(
              valueColor,
              fontSize: 24,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-Widget: Search & Filter Bar ─────────────────────────────────────────
class _SearchFilterBar extends GetView<ConsultationsController> {
  const _SearchFilterBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final labelColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Column(
      children: [
        // Search Input
        TextField(
          controller: controller.searchController,
          onChanged: controller.updateSearch,
          style: AppTextStyles.bodyMedium(textColor),
          decoration: InputDecoration(
            hintText: 'Search Patient CUID...',
            hintStyle: AppTextStyles.bodyMedium(labelColor),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: labelColor,
              size: AppSpacing.iconMD,
            ),
            suffixIcon: Obx(
              () => controller.searchQuery.value.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: labelColor),
                      onPressed: () {
                        controller.searchController.clear();
                        controller.updateSearch('');
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            filled: true,
            fillColor: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                width: 0.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Row of Date Picker and Doctor Dropdown
        Row(
          children: [
            // Date Picker Button
            Expanded(
              child: Obx(() {
                final hasDate = controller.selectedDate.value != null;
                final dateText = hasDate
                    ? '${controller.selectedDate.value!.day.toString().padLeft(2, '0')}/${controller.selectedDate.value!.month.toString().padLeft(2, '0')}/${controller.selectedDate.value!.year}'
                    : 'Pick a Date';

                return InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          controller.selectedDate.value ?? DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: isDark
                                ? const ColorScheme.dark(
                                    primary: AppColors.primary,
                                    onPrimary: Colors.white,
                                    surface: AppColors.darkSurface,
                                    onSurface: Colors.white,
                                  )
                                : const ColorScheme.light(
                                    primary: AppColors.primary,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      controller.selectDate(picked);
                    }
                  },
                  borderRadius: AppDecorations.borderMD,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurface,
                      borderRadius: AppDecorations.borderMD,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: labelColor,
                          size: AppSpacing.iconSM,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            dateText,
                            style: AppTextStyles.bodyMedium(textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasDate)
                          GestureDetector(
                            onTap: () => controller.selectDate(null),
                            child: Icon(
                              Icons.close_rounded,
                              color: labelColor,
                              size: AppSpacing.iconSM,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: AppSpacing.md),

            // Doctor Dropdown
            Expanded(
              child: Obx(() {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurface,
                    borderRadius: AppDecorations.borderMD,
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                      width: 0.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DoctorModel?>(
                      value: controller.selectedDoctor.value,
                      hint: Text(
                        'All Doctors',
                        style: AppTextStyles.bodyMedium(labelColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                      dropdownColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: labelColor,
                        size: AppSpacing.iconMD,
                      ),
                      style: AppTextStyles.bodyMedium(textColor),
                      onChanged: (DoctorModel? value) {
                        controller.selectDoctor(value);
                      },
                      items: [
                        DropdownMenuItem<DoctorModel?>(
                          value: null,
                          child: Text(
                            'All Doctors',
                            style: AppTextStyles.bodyMedium(textColor),
                          ),
                        ),
                        ...controller.doctors.map((doc) {
                          return DropdownMenuItem<DoctorModel?>(
                            value: doc,
                            child: Text(
                              doc.fullName,
                              style: AppTextStyles.bodyMedium(textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Sub-Widget: Waiting Queue Card ──────────────────────────────────────────
class _WaitingQueueCard extends GetView<ConsultationsController> {
  const _WaitingQueueCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.supervised_user_circle_rounded,
                color: AppColors.secondary,
                size: AppSpacing.iconLG,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OPD Waiting Queue',
                      style: AppTextStyles.titleMedium(
                        textColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Patients routed from Pre-Triage awaiting consultation.',
                      style: AppTextStyles.bodySmall(subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Obx(() {
            if (controller.isLoadingQueue.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            if (controller.waitingQueue.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant.withValues(alpha: 0.3)
                      : AppColors.lightBackground.withValues(alpha: 0.5),
                  borderRadius: AppDecorations.borderMD,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      color: subColor.withValues(alpha: 0.5),
                      size: AppSpacing.avatarLG,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No patients waiting in OPD queue',
                      style: AppTextStyles.bodyMedium(
                        subColor,
                      ).copyWith(fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.waitingQueue.length,
              separatorBuilder: (context, index) => Divider(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = controller.waitingQueue[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.secondary.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          item.patient.firstName.isNotEmpty
                              ? item.patient.firstName[0].toUpperCase()
                              : 'P',
                          style: AppTextStyles.titleMedium(AppColors.secondary),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.patient.fullName,
                              style: AppTextStyles.bodyLarge(
                                textColor,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'MRN: ${item.patient.mrn}',
                              style: AppTextStyles.numeric(
                                subColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: AppDecorations.borderSM,
                            ),
                            child: Text(
                              'Q-${item.displayQueueNumber}',
                              style: AppTextStyles.numeric(
                                AppColors.primary,
                                fontSize: 12,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Wait: ${item.waitTime} min',
                            style: AppTextStyles.bodySmall(subColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

// ─── Sub-Widget: Consultation Card ───────────────────────────────────────────
class _ConsultationCard extends GetView<ConsultationsController> {
  final ConsultationModel consultation;

  const _ConsultationCard({required this.consultation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final date = consultation.visitDate;
    final formattedDate =
        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";

    final visitTypeLower = consultation.visitType.toLowerCase();
    final badgeType = visitTypeLower == 'emergency'
        ? StatusType.error
        : (visitTypeLower.contains('follow')
              ? StatusType.warning
              : StatusType.success);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Date, Badge, and Actions Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                    size: AppSpacing.iconSM,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    formattedDate,
                    style: AppTextStyles.numeric(
                      textColor,
                      fontSize: 13,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  StatusBadge(
                    label:
                        consultation.visitType.capitalizeFirst ??
                        consultation.visitType,
                    type: badgeType,
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: subColor,
                      size: AppSpacing.iconMD,
                    ),
                    onSelected: (value) {
                      if (value == 'view') {
                        _showDetailsDialog(context);
                      } else if (value == 'edit') {
                        Get.snackbar(
                          'Info',
                          'Edit Record function for patient ${consultation.patient.fullName}',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } else if (value == 'delete') {
                        _showDeleteConfirmation();
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Record'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete Record',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Patient Name & MRN
          Text(
            consultation.patient.fullName,
            style: AppTextStyles.titleMedium(
              textColor,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'MRN: ${consultation.patient.mrn}',
            style: AppTextStyles.numeric(subColor, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),

          // Doctor & Specialization Details
          Row(
            children: [
              Icon(
                Icons.medical_services_rounded,
                color: AppColors.tertiary,
                size: AppSpacing.iconSM,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${consultation.doctor.fullName} (${consultation.doctor.specialization ?? "General"})',
                  style: AppTextStyles.bodyMedium(
                    textColor,
                  ).copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Chief Complaint Card Details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5)
                  : AppColors.lightBackground.withValues(alpha: 0.6),
              borderRadius: AppDecorations.borderMD,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chief Complaint',
                  style: AppTextStyles.labelSmall(
                    subColor,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  consultation.chiefComplaint.isNotEmpty
                      ? consultation.chiefComplaint
                      : '—',
                  style: AppTextStyles.bodyMedium(textColor),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Diagnosis',
                  style: AppTextStyles.labelSmall(
                    subColor,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  consultation.diagnosis != null &&
                          consultation.diagnosis!.isNotEmpty
                      ? consultation.diagnosis!
                      : '—',
                  style: AppTextStyles.bodyMedium(textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Record'),
        content: Text(
          'Are you sure you want to delete the consultation record for ${consultation.patient.fullName}?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteConsultationRecord(consultation.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppDecorations.borderXL),
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Consultation Details',
                    style: AppTextStyles.titleLarge(
                      textColor,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              _buildDetailRow(
                'Patient Name',
                consultation.patient.fullName,
                textColor,
                subColor,
              ),
              _buildDetailRow(
                'MRN',
                consultation.patient.mrn,
                textColor,
                subColor,
              ),
              _buildDetailRow(
                'Gender',
                consultation.patient.gender.capitalizeFirst ??
                    consultation.patient.gender,
                textColor,
                subColor,
              ),

              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              _buildDetailRow(
                'Doctor Name',
                consultation.doctor.fullName,
                textColor,
                subColor,
              ),
              _buildDetailRow(
                'Specialization',
                consultation.doctor.specialization ?? 'General',
                textColor,
                subColor,
              ),
              _buildDetailRow(
                'Visit Date',
                consultation.visitDate.toString().split(' ')[0],
                textColor,
                subColor,
              ),
              _buildDetailRow(
                'Visit Type',
                consultation.visitType.capitalizeFirst ??
                    consultation.visitType,
                textColor,
                subColor,
              ),

              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              Text(
                'Patient Vitals',
                style: AppTextStyles.titleMedium(
                  textColor,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildVitalItem(
                    'Temp',
                    consultation.temperature != null
                        ? '${consultation.temperature}°C'
                        : '—',
                    subColor,
                    textColor,
                  ),
                  _buildVitalItem(
                    'BP',
                    consultation.bloodPressureSystolic != null
                        ? '${consultation.bloodPressureSystolic}/${consultation.bloodPressureDiastolic}'
                        : '—',
                    subColor,
                    textColor,
                  ),
                  _buildVitalItem(
                    'HR',
                    consultation.pulseRate != null
                        ? '${consultation.pulseRate} bpm'
                        : '—',
                    subColor,
                    textColor,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              _buildDetailRow(
                'Chief Complaint',
                consultation.chiefComplaint,
                textColor,
                subColor,
                isMultiLine: true,
              ),
              _buildDetailRow(
                'Diagnosis',
                consultation.diagnosis ?? '—',
                textColor,
                subColor,
                isMultiLine: true,
              ),
              _buildDetailRow(
                'Treatment Plan',
                consultation.treatmentPlan ?? '—',
                textColor,
                subColor,
                isMultiLine: true,
              ),
              _buildDetailRow(
                'Follow-up Instructions',
                consultation.followUpInstructions ?? '—',
                textColor,
                subColor,
                isMultiLine: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color textColor,
    Color subColor, {
    bool isMultiLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall(
              subColor,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value.isNotEmpty ? value : '—',
            style: AppTextStyles.bodyMedium(textColor),
            maxLines: isMultiLine ? 5 : 1,
            overflow: isMultiLine ? TextOverflow.ellipsis : TextOverflow.fade,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalItem(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.labelSmall(labelColor)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTextStyles.numeric(
            valueColor,
            fontSize: 14,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
