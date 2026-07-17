import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../models/appointment_model.dart';
import '../../../theme/theme.dart';
import '../controllers/appointments_controller.dart';

class AppointmentsView extends GetView<AppointmentsController> {
  final bool isEmbedded;
  const AppointmentsView({super.key, this.isEmbedded = true});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppointmentsController>()) {
      Get.put(AppointmentsController());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    Widget bodyWidget = GetBuilder<AppointmentsController>(
      builder: (controller) {
        if (controller.isLoading && controller.allAppointments.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (controller.errorMessage.isNotEmpty &&
            controller.allAppointments.isEmpty) {
          return _buildErrorState(isDark);
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.refreshData,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: AppSpacing.lg),
              _buildStatsGrid(isDark),
              const SizedBox(height: AppSpacing.lg),
              _buildTabsRow(isDark),
              const SizedBox(height: AppSpacing.md),
              _buildActiveTabView(context, isDark),
            ],
          ),
        );
      },
    );

    if (isEmbedded) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: bodyWidget),
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
          'Appointments',
          style: AppTextStyles.titleMedium(
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: SafeArea(child: bodyWidget),
    );
  }

  // ─── Component Builders ───────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
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
                'Appointments',
                style: AppTextStyles.headlineSmall(textPrimary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Manage patient consultations and schedules',
                style: AppTextStyles.bodySmall(textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Get.snackbar(
                  'Coming Soon',
                  'Appointment booking is coming soon.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  colorText: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                );
              },
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
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.3,
      children: [
        _buildStatCard(
          icon: Icons.event_note_rounded,
          count: controller.todayTotalCount,
          label: "Today's Total",
          color: AppColors.primary,
          isDark: isDark,
          statusFilter: 'All Statuses',
        ),
        _buildStatCard(
          icon: Icons.pending_actions_rounded,
          count: controller.todayScheduledCount,
          label: 'Scheduled',
          color: AppColors.info,
          isDark: isDark,
          statusFilter: 'scheduled',
        ),
        _buildStatCard(
          icon: Icons.check_circle_outline_rounded,
          count: controller.todayConfirmedCount,
          label: 'Confirmed',
          color: AppColors.success,
          isDark: isDark,
          statusFilter: 'confirmed',
        ),
        _buildStatCard(
          icon: Icons.login_rounded,
          count: controller.todayCheckedInCount,
          label: 'Checked In',
          color: AppColors.tertiary,
          isDark: isDark,
          statusFilter: 'checked_in',
        ),
        _buildStatCard(
          icon: Icons.run_circle_outlined,
          count: controller.todayInProgressCount,
          label: 'In Progress',
          color: AppColors.warning,
          isDark: isDark,
          statusFilter: 'in_progress',
        ),
        _buildStatCard(
          icon: Icons.task_alt_rounded,
          count: controller.todayCompletedCount,
          label: 'Completed',
          color: Colors.teal,
          isDark: isDark,
          statusFilter: 'completed',
        ),
        _buildStatCard(
          icon: Icons.cancel_outlined,
          count: controller.todayCancelledCount,
          label: 'Cancelled',
          color: AppColors.error,
          isDark: isDark,
          statusFilter: 'cancelled',
        ),
        _buildStatCard(
          icon: Icons.person_off_rounded,
          count: controller.todayNoShowCount,
          label: 'No Show',
          color: Colors.grey,
          isDark: isDark,
          statusFilter: 'no_show',
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
    required String statusFilter,
  }) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return InkWell(
      onTap: () {
        controller.setStatusFilter(statusFilter);
        controller.setActiveTab(1); // Switch to All List view
      },
      borderRadius: AppDecorations.borderMD,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppDecorations.borderMD,
          boxShadow: AppDecorations.elevation1(isDark),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
                    '$count',
                    style: AppTextStyles.titleMedium(textPrimary).copyWith(fontSize: 18),
                  ),
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
      ),
    );
  }

  Widget _buildTabsRow(bool isDark) {
    final containerBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: AppDecorations.borderFull,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          _buildToggleButton('Calendar', 0, isDark),
          _buildToggleButton('List', 1, isDark),
          _buildToggleButton("Today's Schedule", 2, isDark),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, int index, bool isDark) {
    final isSelected = controller.activeViewTab == index;
    final bgColor = isSelected ? AppColors.primary : Colors.transparent;
    final textColor = isSelected
        ? Colors.white
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Expanded(
      child: InkWell(
        onTap: () => controller.setActiveTab(index),
        borderRadius: AppDecorations.borderFull,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppDecorations.borderFull,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelMedium(textColor).copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Active Tab Content Switcher ───────────────────────────────────────────

  Widget _buildActiveTabView(BuildContext context, bool isDark) {
    switch (controller.activeViewTab) {
      case 0:
        return _buildCalendarTabView(context, isDark);
      case 1:
        return _buildAllListTabView(context, isDark);
      case 2:
        return _buildTodayScheduleTabView(context, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 1: Calendar View ──────────────────────────────────────────────────

  Widget _buildCalendarTabView(BuildContext context, bool isDark) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final formattedSelected = DateFormat(
      'EEEE, MMM d, yyyy',
    ).format(controller.calendarSelectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Monthly Calendar Widget
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: AppDecorations.borderMD,
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              width: 1,
            ),
            boxShadow: AppDecorations.elevation1(isDark),
          ),
          child: CalendarDatePicker(
            initialDate: controller.calendarSelectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            onDateChanged: (date) {
              controller.setCalendarSelectedDate(date);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formattedSelected,
              style: AppTextStyles.titleMedium(textPrimary),
            ),
            Text(
              '${controller.calendarAppointmentsForDate.length} Appt(s)',
              style: AppTextStyles.bodySmall(
                isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (controller.calendarAppointmentsForDate.isEmpty)
          _buildEmptyState('No appointments scheduled for this day', isDark)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.calendarAppointmentsForDate.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final appt = controller.calendarAppointmentsForDate[index];
              return _buildAppointmentItemCard(context, appt, isDark);
            },
          ),
      ],
    );
  }

  // ─── Tab 2: All List View with Advanced Filtering ─────────────────────────

  Widget _buildAllListTabView(BuildContext context, bool isDark) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          onChanged: controller.setSearchQuery,
          style: AppTextStyles.bodyMedium(textPrimary),
          decoration: InputDecoration(
            hintText: 'Search patients, MRN, complaints...',
            hintStyle: AppTextStyles.bodyMedium(
              isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
            ),
            suffixIcon: controller.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      controller.setSearchQuery('');
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: BorderSide(color: divider, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: BorderSide(color: divider, width: 1),
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

        // Filters row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Status Dropdown
              _buildFilterDropdown(
                value: controller.selectedStatusFilter,
                items: [
                  'All Statuses',
                  'scheduled',
                  'confirmed',
                  'checked_in',
                  'in_progress',
                  'completed',
                  'cancelled',
                  'no_show',
                ],
                onChanged: (val) {
                  if (val != null) controller.setStatusFilter(val);
                },
                isDark: isDark,
              ),
              const SizedBox(width: AppSpacing.sm),

              // Doctor Dropdown
              _buildFilterDropdown(
                value: controller.selectedDoctorFilter,
                items: ['All Doctors', ...controller.doctors.map((d) => d.id)],
                itemLabels: {
                  'All Doctors': 'All Doctors',
                  ...Map.fromEntries(
                    controller.doctors.map(
                      (d) => MapEntry(d.id, 'Dr. ${d.fullName}'),
                    ),
                  ),
                },
                onChanged: (val) {
                  if (val != null) controller.setDoctorFilter(val);
                },
                isDark: isDark,
              ),
              const SizedBox(width: AppSpacing.sm),

              // Date Picker Chip
              ActionChip(
                avatar: Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: controller.selectedFilterDate != null
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
                label: Text(
                  controller.selectedFilterDate != null
                      ? DateFormat(
                          'MMM d, yyyy',
                        ).format(controller.selectedFilterDate!)
                      : 'Pick Date',
                  style: AppTextStyles.labelMedium(
                    controller.selectedFilterDate != null
                        ? Colors.white
                        : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                  ),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        controller.selectedFilterDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    controller.setFilterDate(picked);
                  }
                },
                backgroundColor: controller.selectedFilterDate != null
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.borderMD,
                  side: BorderSide(color: divider, width: 1),
                ),
              ),

              // Reset filters button
              if (controller.searchQuery.isNotEmpty ||
                  controller.selectedFilterDate != null ||
                  controller.selectedStatusFilter != 'All Statuses' ||
                  controller.selectedDoctorFilter != 'All Doctors')
                IconButton(
                  onPressed: controller.resetFilters,
                  icon: const Icon(
                    Icons.filter_alt_off_rounded,
                    color: AppColors.error,
                  ),
                  tooltip: 'Reset Filters',
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Filtered Results',
              style: AppTextStyles.titleMedium(textPrimary),
            ),
            Text(
              '${controller.filteredAppointments.length} item(s)',
              style: AppTextStyles.bodySmall(
                isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (controller.filteredAppointments.isEmpty)
          _buildEmptyState('No appointments match your filters', isDark)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.filteredAppointments.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final appt = controller.filteredAppointments[index];
              return _buildAppointmentItemCard(context, appt, isDark);
            },
          ),
      ],
    );
  }

  // ─── Tab 3: Today's Schedule View ──────────────────────────────────────────

  Widget _buildTodayScheduleTabView(BuildContext context, bool isDark) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final upcoming = controller.todayCurrentAndUpcoming;
    final completed = controller.todayCompletedAndOthers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Current & Upcoming
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Current & Upcoming',
              style: AppTextStyles.titleMedium(textPrimary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppDecorations.borderSM,
              ),
              child: Text(
                '${upcoming.length} active',
                style: AppTextStyles.labelSmall(AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (upcoming.isEmpty)
          _buildEmptyState('No active appointments left today', isDark)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcoming.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              return _buildAppointmentItemCard(
                context,
                upcoming[index],
                isDark,
              );
            },
          ),

        const SizedBox(height: AppSpacing.lg),

        // Section 2: Completed & Others
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Completed, Cancelled & No Shows',
              style: AppTextStyles.titleMedium(textPrimary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: AppDecorations.borderSM,
              ),
              child: Text(
                '${completed.length} items',
                style: AppTextStyles.labelSmall(
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (completed.isEmpty)
          _buildEmptyState(
            'No completed/cancelled appointments today yet',
            isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completed.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              return _buildAppointmentItemCard(
                context,
                completed[index],
                isDark,
              );
            },
          ),
      ],
    );
  }

  // ─── Filter Dropdown Helper ────────────────────────────────────────────────

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    Map<String, String>? itemLabels,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      height: 38,
      decoration: BoxDecoration(
        borderRadius: AppDecorations.borderMD,
        border: Border.all(color: divider, width: 1),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          style: AppTextStyles.labelMedium(textPrimary),
          dropdownColor: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          borderRadius: AppDecorations.borderMD,
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String val) {
            String label = itemLabels != null ? (itemLabels[val] ?? val) : val;
            // Beautify status labels
            if (itemLabels == null) {
              label = label.replaceAll('_', ' ').capitalizeFirst ?? label;
            }
            return DropdownMenuItem<String>(value: val, child: Text(label));
          }).toList(),
        ),
      ),
    );
  }

  // ─── Appointment List Item Card ───────────────────────────────────────────

  Widget _buildAppointmentItemCard(
    BuildContext context,
    AppointmentModel appt,
    bool isDark,
  ) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final Color statusColor = _getStatusColor(appt.status);
    final String formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(appt.appointmentDate);

    return InkWell(
      onTap: () => _showAppointmentDetailSheet(context, appt, isDark),
      borderRadius: AppDecorations.borderMD,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppDecorations.borderMD,
          boxShadow: AppDecorations.elevation1(isDark),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Time, Date & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${appt.appointmentTime} (${appt.durationMinutes}m)',
                      style: AppTextStyles.labelMedium(
                        textPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formattedDate,
                      style: AppTextStyles.bodySmall(textSecondary),
                    ),
                  ],
                ),
                _buildStatusBadge(appt.status),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1, thickness: 0.5),
            ),

            // Middle Section: Patient Initials, Name, Age/Gender, MRN
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Text(
                    appt.patient.initials,
                    style: AppTextStyles.titleMedium(
                      statusColor,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.patient.fullName,
                        style: AppTextStyles.titleSmall(textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${appt.patient.gender ?? "Unknown Gender"} • ${appt.patient.age} yrs • MRN: ${appt.patient.mrn}',
                        style: AppTextStyles.bodySmall(textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Bottom Section: Doctor info, chief complaint
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.medical_services_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Dr. ${appt.doctor.fullName}',
                          style: AppTextStyles.bodySmall(textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          appt.chiefComplaint.isNotEmpty
                              ? appt.chiefComplaint
                              : 'No complaint stated',
                          style: AppTextStyles.bodySmall(textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Sheet Details View ─────────────────────────────────────────────

  void _showAppointmentDetailSheet(
    BuildContext context,
    AppointmentModel appt,
    bool isDark,
  ) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final formatDateTime = DateFormat(
      'EEEE, MMM d, yyyy',
    ).format(appt.appointmentDate);

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDecorations.radiusLG),
            topRight: Radius.circular(AppDecorations.radiusLG),
          ),
          boxShadow: AppDecorations.elevation3(isDark),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handlebar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider,
                    borderRadius: AppDecorations.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Appointment details',
                    style: AppTextStyles.titleMedium(textPrimary),
                  ),
                  _buildStatusBadge(appt.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Patient Info Section
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground
                      : AppColors.lightBackground,
                  borderRadius: AppDecorations.borderMD,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        appt.patient.initials,
                        style: AppTextStyles.titleMedium(
                          AppColors.primary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appt.patient.fullName,
                            style: AppTextStyles.titleSmall(textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Age: ${appt.patient.age} • Gender: ${appt.patient.gender ?? "Unknown"}',
                            style: AppTextStyles.bodySmall(textSecondary),
                          ),
                          Text(
                            'MRN: ${appt.patient.mrn} • Ph: ${appt.patient.phonePrimary ?? "N/A"}',
                            style: AppTextStyles.bodySmall(textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Doctor / Schedule Details
              _buildDetailRow(
                Icons.medical_services_rounded,
                'Attending Doctor',
                'Dr. ${appt.doctor.fullName} (${appt.doctor.specialization ?? "General"})',
                isDark,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                Icons.calendar_today_rounded,
                'Date & Time',
                '$formatDateTime at ${appt.appointmentTime} (${appt.durationMinutes} mins)',
                isDark,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                Icons.help_outline_rounded,
                'Chief Complaint',
                appt.chiefComplaint.isNotEmpty
                    ? appt.chiefComplaint
                    : 'None stated',
                isDark,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                Icons.notes_rounded,
                'Clinical Notes',
                appt.notes.isNotEmpty ? appt.notes : 'No extra notes provided',
                isDark,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                Icons.notifications_active_outlined,
                'Reminder Status',
                appt.reminderSent ? 'Reminder Sent' : 'No Reminder Sent Yet',
                isDark,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Buttons based on status
              Text(
                'Actions',
                style: AppTextStyles.labelSmall(
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildActionButtons(context, appt, isDark),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
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
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall(textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyMedium(textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    AppointmentModel appt,
    bool isDark,
  ) {
    final status = appt.status.toLowerCase();

    // Custom helper to quickly return a flat list of widgets
    final List<Widget> buttons = [];

    // Common action to build standard buttons
    Widget buildBtn({
      required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ElevatedButton.icon(
          onPressed: () {
            Get.back(); // close bottom sheet
            onPressed();
          },
          icon: Icon(icon, size: 18, color: Colors.white),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.borderMD,
            ),
          ),
        ),
      );
    }

    if (status == 'scheduled' || status == 'confirmed') {
      buttons.add(
        buildBtn(
          label: 'Check In Patient',
          icon: Icons.login_rounded,
          color: AppColors.tertiary,
          onPressed: () => controller.updateStatus(appt.id, 'checked_in'),
        ),
      );
      buttons.add(
        buildBtn(
          label: 'Send Email/SMS Reminder',
          icon: Icons.notifications_active_rounded,
          color: AppColors.info,
          onPressed: () => controller.sendReminder(appt.id),
        ),
      );
      buttons.add(
        buildBtn(
          label: 'Reschedule',
          icon: Icons.restore_rounded,
          color: AppColors.warning,
          onPressed: () => _showRescheduleDialog(context, appt),
        ),
      );
      buttons.add(
        buildBtn(
          label: 'Mark as No Show',
          icon: Icons.person_off_rounded,
          color: Colors.grey,
          onPressed: () => controller.updateStatus(appt.id, 'no_show'),
        ),
      );
      buttons.add(
        buildBtn(
          label: 'Cancel Appointment',
          icon: Icons.cancel_outlined,
          color: AppColors.error,
          onPressed: () => controller.updateStatus(appt.id, 'cancelled'),
        ),
      );
    } else if (status == 'checked_in') {
      buttons.add(
        buildBtn(
          label: 'Start Consultation',
          icon: Icons.run_circle_outlined,
          color: AppColors.secondary,
          onPressed: () => controller.updateStatus(appt.id, 'in_progress'),
        ),
      );
      buttons.add(
        buildBtn(
          label: 'Mark as No Show',
          icon: Icons.person_off_rounded,
          color: Colors.grey,
          onPressed: () => controller.updateStatus(appt.id, 'no_show'),
        ),
      );
      buttons.add(
        buildBtn(
          label: 'Cancel Appointment',
          icon: Icons.cancel_outlined,
          color: AppColors.error,
          onPressed: () => controller.updateStatus(appt.id, 'cancelled'),
        ),
      );
    } else if (status == 'in_progress') {
      buttons.add(
        buildBtn(
          label: 'Complete Consultation',
          icon: Icons.task_alt_rounded,
          color: Colors.teal,
          onPressed: () => controller.updateStatus(appt.id, 'completed'),
        ),
      );
      buttons.add(
        buildBtn(
          label: 'Cancel Appointment',
          icon: Icons.cancel_outlined,
          color: AppColors.error,
          onPressed: () => controller.updateStatus(appt.id, 'cancelled'),
        ),
      );
    } else if (status == 'cancelled' || status == 'no_show') {
      buttons.add(
        buildBtn(
          label: 'Reschedule Appointment',
          icon: Icons.restore_rounded,
          color: AppColors.primary,
          onPressed: () => _showRescheduleDialog(context, appt),
        ),
      );
    } else {
      // Completed, etc.
      buttons.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'No further actions available for completed appointments.',
              style: AppTextStyles.bodySmall(
                isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ),
        ),
      );
    }

    return Column(children: buttons);
  }

  // ─── Reschedule Dialog ─────────────────────────────────────────────────────

  void _showRescheduleDialog(BuildContext context, AppointmentModel appt) {
    DateTime selectedDate = appt.appointmentDate;
    String selectedTime = appt.appointmentTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textPrimary = isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary;

            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: AppDecorations.borderLG,
              ),
              title: Text(
                'Reschedule Appointment',
                style: AppTextStyles.titleLarge(textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pick Date
                  ListTile(
                    leading: const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                      style: AppTextStyles.bodyMedium(textPrimary),
                    ),
                    trailing: const Icon(
                      Icons.edit_calendar_rounded,
                      color: AppColors.primary,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),

                  // Pick Time
                  ListTile(
                    leading: const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Time: $selectedTime',
                      style: AppTextStyles.bodyMedium(textPrimary),
                    ),
                    trailing: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.primary,
                    ),
                    onTap: () async {
                      final parsedTime = TimeOfDay(
                        hour: int.tryParse(selectedTime.split(':')[0]) ?? 9,
                        minute: int.tryParse(selectedTime.split(':')[1]) ?? 0,
                      );
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: parsedTime,
                      );
                      if (picked != null) {
                        final formattedTime =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        setState(() {
                          selectedTime = formattedTime;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.back(); // Close Dialog
                    controller.reschedule(appt.id, selectedDate, selectedTime);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppDecorations.borderMD,
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.success;
      case 'checked_in':
        return AppColors.tertiary;
      case 'in_progress':
        return AppColors.warning;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return AppColors.error;
      case 'no_show':
        return Colors.grey;
      case 'scheduled':
      default:
        return AppColors.info;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final String label = status.replaceAll('_', ' ').capitalizeFirst ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppDecorations.borderSM,
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.7),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall(
          color,
        ).copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: isDark
                  ? AppColors.darkTextDisabled
                  : AppColors.lightTextDisabled,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTextStyles.bodyMedium(
                isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              controller.errorMessage,
              style: AppTextStyles.bodyMedium(AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => controller.refreshData(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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
