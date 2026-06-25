import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'package:medihive/app/theme/theme.dart';
import 'package:medihive/app/routes/app_pages.dart';
import '../controllers/appointments_controller.dart';
import '../models/appointment_model.dart';

class AppointmentsView extends GetView<AppointmentsController> {
  const AppointmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(context, isDark),
      body: GetBuilder<AppointmentsController>(
        builder: (ctrl) {
          if (ctrl.isLoading) return _AppointmentsSkeleton(isDark: isDark);
          if (ctrl.hasError) {
            return _AppointmentsErrorState(
              message: ctrl.errorMessage,
              onRetry: ctrl.fetchAppointments,
              isDark: isDark,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            onRefresh: ctrl.onRefresh,
            child: CustomScrollView(
              slivers: [
                // ── Summary Cards ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SummaryCardsRow(isDark: isDark),
                ),
                // ── View Switcher ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _ViewSwitcher(isDark: isDark),
                ),
                // ── Content ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _buildTabContent(ctrl, isDark),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.huge)),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.08),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: textPrimary, size: AppSpacing.iconMD),
        onPressed: () => Get.back(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointments',
            style: AppTextStyles.titleMedium(textPrimary),
          ),
          Text(
            'Schedule & manage patient appointments',
            style: AppTextStyles.labelSmall(AppColors.primary),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded,
              color: AppColors.primary, size: AppSpacing.iconMD),
          onPressed: () => controller.fetchAppointments(),
          tooltip: 'Refresh',
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppDecorations.borderMD,
            ),
            child: TextButton.icon(
              onPressed: () => Get.toNamed(Routes.APPOINTMENT_CREATE),
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.lightSurface, size: AppSpacing.iconSM),
              label: Text(
                'New',
                style: AppTextStyles.labelMedium(AppColors.lightSurface),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(AppointmentsController ctrl, bool isDark) {
    switch (ctrl.selectedTab) {
      case AppointmentViewTab.calendar:
        return _CalendarView(isDark: isDark);
      case AppointmentViewTab.list:
        return _ListView(isDark: isDark);
      case AppointmentViewTab.todaySchedule:
        return _TodayScheduleView(isDark: isDark);
    }
  }
}

// ─── Summary Cards Row ─────────────────────────────────────────────────────────

class _SummaryCardsRow extends GetView<AppointmentsController> {
  const _SummaryCardsRow({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppointmentsController>(
      builder: (ctrl) {
        final s = ctrl.summary;
        final cards = [
          _SummaryCardData(
              label: "Today's Total",
              count: s.todayTotal,
              icon: Icons.calendar_today_rounded,
              color: AppColors.primary),
          _SummaryCardData(
              label: 'Confirmed',
              count: s.confirmed,
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.secondary),
          _SummaryCardData(
              label: 'Checked In',
              count: s.checkedIn,
              icon: Icons.login_rounded,
              color: AppColors.info),
          _SummaryCardData(
              label: 'In Progress',
              count: s.inProgress,
              icon: Icons.play_circle_outline_rounded,
              color: AppColors.warning),
          _SummaryCardData(
              label: 'Completed',
              count: s.completed,
              icon: Icons.task_alt_rounded,
              color: AppColors.success),
          _SummaryCardData(
              label: 'Cancelled',
              count: s.cancelled,
              icon: Icons.cancel_outlined,
              color: AppColors.error),
          _SummaryCardData(
              label: 'No Shows',
              count: s.noShows,
              icon: Icons.person_off_outlined,
              color: const Color(0xFFFF6B35)),
          _SummaryCardData(
              label: 'Scheduled',
              count: s.scheduled,
              icon: Icons.schedule_rounded,
              color: AppColors.tertiary),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.3,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) =>
              _SummaryCard(data: cards[i], isDark: isDark),
        );
      },
    );
  }
}

class _SummaryCardData {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _SummaryCardData(
      {required this.label,
      required this.count,
      required this.icon,
      required this.color});
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.isDark});
  final _SummaryCardData data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderLG,
        border: Border.all(color: data.color.withValues(alpha: 0.2), width: 1),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: AppDecorations.borderSM,
                ),
                child: Icon(data.icon, color: data.color, size: 14),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${data.count}',
                style: AppTextStyles.titleMedium(textPrimary)
                    .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.label,
            style: AppTextStyles.labelSmall(data.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── View Switcher ─────────────────────────────────────────────────────────────

class _ViewSwitcher extends GetView<AppointmentsController> {
  const _ViewSwitcher({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceVariant =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GetBuilder<AppointmentsController>(
      builder: (ctrl) {
        return Container(
          margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: surfaceVariant,
            borderRadius: AppDecorations.borderLG,
          ),
          child: Row(
            children: [
              _TabButton(
                label: 'Calendar',
                icon: Icons.calendar_month_rounded,
                selected: ctrl.selectedTab == AppointmentViewTab.calendar,
                isDark: isDark,
                surface: surface,
                textSecondary: textSecondary,
                onTap: () => ctrl.setTab(AppointmentViewTab.calendar),
              ),
              _TabButton(
                label: 'List',
                icon: Icons.list_alt_rounded,
                selected: ctrl.selectedTab == AppointmentViewTab.list,
                isDark: isDark,
                surface: surface,
                textSecondary: textSecondary,
                onTap: () => ctrl.setTab(AppointmentViewTab.list),
              ),
              _TabButton(
                label: "Today",
                icon: Icons.today_rounded,
                selected:
                    ctrl.selectedTab == AppointmentViewTab.todaySchedule,
                isDark: isDark,
                surface: surface,
                textSecondary: textSecondary,
                onTap: () => ctrl.setTab(AppointmentViewTab.todaySchedule),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.surface,
    required this.textSecondary,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final Color surface;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? surface : Colors.transparent,
            borderRadius: AppDecorations.borderMD,
            boxShadow: selected ? AppDecorations.elevation1(isDark) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.primary : textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.labelMedium(
                    selected ? AppColors.primary : textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Calendar View ─────────────────────────────────────────────────────────────

class _CalendarView extends GetView<AppointmentsController> {
  const _CalendarView({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppointmentsController>(
      builder: (ctrl) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              _MonthCalendar(isDark: isDark),
              const SizedBox(height: AppSpacing.lg),
              // Day detail panel
              if (ctrl.selectedDate != null)
                _DayAppointmentsList(
                  date: ctrl.selectedDate!,
                  isDark: isDark,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthCalendar extends GetView<AppointmentsController> {
  const _MonthCalendar({required this.isDark});
  final bool isDark;

  static const List<String> _weekDays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GetBuilder<AppointmentsController>(
      builder: (ctrl) {
        final focused = ctrl.focusedDate;
        final selected = ctrl.selectedDate;
        final today = DateTime.now();

        // Build grid data
        final firstOfMonth = DateTime(focused.year, focused.month, 1);
        final lastOfMonth = DateTime(focused.year, focused.month + 1, 0);
        final startWeekday = firstOfMonth.weekday % 7; // 0=Sun
        final totalDays = lastOfMonth.day;

        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: AppDecorations.borderLG,
            boxShadow: AppDecorations.elevation1(isDark),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              // Header: Month/Year + Navigation
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded,
                        color: AppColors.primary, size: AppSpacing.iconMD),
                    onPressed: () => ctrl.setFocusedDate(
                        DateTime(focused.year, focused.month - 1)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[focused.month - 1]} ${focused.year}',
                      style: AppTextStyles.titleMedium(textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ctrl.setFocusedDate(today);
                      ctrl.setSelectedDate(today);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                    ),
                    child: Text('Today',
                        style: AppTextStyles.labelSmall(AppColors.primary)),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary, size: AppSpacing.iconMD),
                    onPressed: () => ctrl.setFocusedDate(
                        DateTime(focused.year, focused.month + 1)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Week day headers
              Row(
                children: _weekDays
                    .map((d) => Expanded(
                          child: Text(d,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.labelSmall(textSecondary)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Calendar grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: startWeekday + totalDays,
                itemBuilder: (_, i) {
                  if (i < startWeekday) return const SizedBox();
                  final day = i - startWeekday + 1;
                  final cellDate =
                      DateTime(focused.year, focused.month, day);
                  final isToday = cellDate.year == today.year &&
                      cellDate.month == today.month &&
                      cellDate.day == today.day;
                  final isSelected = selected != null &&
                      cellDate.year == selected.year &&
                      cellDate.month == selected.month &&
                      cellDate.day == selected.day;
                  final hasAppts =
                      ctrl.hasAppointmentsOnDate(cellDate);

                  return GestureDetector(
                    onTap: () => ctrl.setSelectedDate(cellDate),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : isToday
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : null,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$day',
                            style: AppTextStyles.bodySmall(
                              isSelected
                                  ? AppColors.lightSurface
                                  : isToday
                                      ? AppColors.primary
                                      : textPrimary,
                            ).copyWith(fontWeight: isToday ? FontWeight.w600 : null),
                          ),
                          if (hasAppts)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.lightSurface
                                      : AppColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayAppointmentsList extends GetView<AppointmentsController> {
  const _DayAppointmentsList(
      {required this.date, required this.isDark});
  final DateTime date;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GetBuilder<AppointmentsController>(
      builder: (ctrl) {
        final appts = ctrl.appointmentsForDate(date);
        final formatted =
            '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: AppDecorations.borderLG,
            boxShadow: AppDecorations.elevation1(isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: AppDecorations.borderSM,
                      ),
                      child: const Icon(Icons.event_note_rounded,
                          color: AppColors.secondary, size: AppSpacing.iconMD),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatted,
                              style:
                                  AppTextStyles.titleSmall(textPrimary)),
                          Text(
                              '${appts.length} appointment${appts.length != 1 ? 's' : ''}',
                              style:
                                  AppTextStyles.bodySmall(textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (appts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xl),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded,
                            color: textSecondary.withValues(alpha: 0.4),
                            size: AppSpacing.iconXL),
                        const SizedBox(height: AppSpacing.sm),
                        Text('No appointments on this day',
                            style: AppTextStyles.bodyMedium(textSecondary)),
                      ],
                    ),
                  ),
                )
              else
                ...appts.map((a) => _AppointmentListCard(
                    appointment: a, isDark: isDark, showMenu: false)),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
}

// ─── List View ─────────────────────────────────────────────────────────────────

class _ListView extends GetView<AppointmentsController> {
  const _ListView({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppointmentsController>(
      builder: (ctrl) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              // Search + Filter row
              _SearchFilterBar(isDark: isDark),
              const SizedBox(height: AppSpacing.md),
              // Appointment cards
              if (ctrl.isListLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (ctrl.filteredAppointments.isEmpty)
                _EmptyAppointments(isDark: isDark)
              else
                ...ctrl.filteredAppointments
                    .map((a) => _AppointmentListCard(
                        appointment: a, isDark: isDark)),
            ],
          ),
        );
      },
    );
  }
}

class _SearchFilterBar extends GetView<AppointmentsController> {
  const _SearchFilterBar({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final hintStyle = AppTextStyles.bodyMedium(textSecondary);

    return GetBuilder<AppointmentsController>(
      builder: (ctrl) {
        return Column(
          children: [
            // Search Field
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: AppDecorations.borderLG,
                boxShadow: AppDecorations.elevation1(isDark),
              ),
              child: TextField(
                onChanged: ctrl.setSearchQuery,
                style: AppTextStyles.bodyMedium(textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by patient, doctor, MRN…',
                  hintStyle: hintStyle,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: textSecondary, size: AppSpacing.iconMD),
                  suffixIcon: ctrl.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: textSecondary,
                              size: AppSpacing.iconSM),
                          onPressed: () => ctrl.setSearchQuery(''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Single horizontal filter row
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(context, ctrl, surface, textPrimary, textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildStatusDropdown(ctrl, surface, textPrimary, textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildDoctorDropdown(ctrl, surface, textPrimary, textSecondary),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    AppointmentsController ctrl,
    Color surface,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: ctrl.listFilterDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? const ColorScheme.dark(
                        primary: AppColors.primary,
                        onPrimary: AppColors.lightSurface,
                        surface: AppColors.darkSurface,
                        onSurface: AppColors.darkTextPrimary,
                      )
                    : const ColorScheme.light(
                        primary: AppColors.primary,
                        onPrimary: AppColors.lightSurface,
                        surface: AppColors.lightSurface,
                        onSurface: AppColors.lightTextPrimary,
                      ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          ctrl.setListFilterDate(picked);
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppDecorations.borderMD,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: AppDecorations.elevation1(isDark),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDatePickerDate(ctrl.listFilterDate),
                    style: AppTextStyles.labelMedium(textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatFriendlyDatePickerDate(ctrl.listFilterDate),
                    style: AppTextStyles.labelSmall(textSecondary).copyWith(
                      fontSize: 9,
                    ),
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

  Widget _buildStatusDropdown(
    AppointmentsController ctrl,
    Color surface,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ctrl.filterStatus,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: textSecondary, size: 18),
          dropdownColor: surface,
          style: AppTextStyles.labelMedium(textPrimary),
          onChanged: (val) {
            if (val != null) ctrl.setFilterStatus(val);
          },
          items: const [
            DropdownMenuItem(value: '', child: Text('All Status')),
            DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
            DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
            DropdownMenuItem(value: 'checked_in', child: Text('Checked In')),
            DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
            DropdownMenuItem(value: 'completed', child: Text('Completed')),
            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            DropdownMenuItem(value: 'no_show', child: Text('No Show')),
            DropdownMenuItem(value: 'rescheduled', child: Text('Rescheduled')),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorDropdown(
    AppointmentsController ctrl,
    Color surface,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ctrl.filterDoctorId,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: textSecondary, size: 18),
          dropdownColor: surface,
          style: AppTextStyles.labelMedium(textPrimary),
          onChanged: (val) {
            if (val != null) ctrl.setFilterDoctor(val);
          },
          items: [
            const DropdownMenuItem(value: '', child: Text('All Doctors')),
            ...ctrl.doctors.map((doc) => DropdownMenuItem(
                  value: doc.id,
                  child: Text(
                    doc.fullName,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _formatDatePickerDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatFriendlyDatePickerDate(DateTime date) {
    final fullMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthStr = fullMonths[date.month - 1];
    
    String suffix = 'th';
    final day = date.day;
    if (day >= 11 && day <= 13) {
      suffix = 'th';
    } else {
      switch (day % 10) {
        case 1: suffix = 'st'; break;
        case 2: suffix = 'nd'; break;
        case 3: suffix = 'rd'; break;
      }
    }
    return "($monthStr ${date.day}$suffix, ${date.year})";
  }
}

// ─── Today's Schedule View ─────────────────────────────────────────────────────

class _TodayScheduleView extends GetView<AppointmentsController> {
  const _TodayScheduleView({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppointmentsController>(
      builder: (ctrl) {
        final active = ctrl.todayActiveAppointments;
        final completed = ctrl.todayCompletedAppointments;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              // Current & Upcoming section
              _TodaySectionHeader(
                icon: Icons.schedule_rounded,
                color: AppColors.primary,
                title: 'Current & Upcoming',
                subtitle: 'Active and pending appointments for today',
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.md),
              if (active.isEmpty)
                _EmptyAppointments(
                    message: 'No active appointments today',
                    isDark: isDark)
              else
                ...active.map((a) => _TodayActiveCard(
                    appointment: a, isDark: isDark)),
              const SizedBox(height: AppSpacing.xl),
              // Completed & Others
              _TodaySectionHeader(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.secondary,
                title: 'Completed & Others',
                subtitle: 'Finished, cancelled, or no-show appointments',
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.md),
              if (completed.isEmpty)
                _EmptyAppointments(
                    message: 'No completed appointments',
                    isDark: isDark)
              else
                ...completed.map((a) => _AppointmentListCard(
                    appointment: a, isDark: isDark)),
            ],
          ),
        );
      },
    );
  }
}

class _TodaySectionHeader extends StatelessWidget {
  const _TodaySectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppDecorations.borderSM,
          ),
          child: Icon(icon, color: color, size: AppSpacing.iconSM),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTextStyles.titleSmall(textPrimary)),
              Text(subtitle,
                  style: AppTextStyles.bodySmall(textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Active appointment card with Confirm + Check In buttons
class _TodayActiveCard extends GetView<AppointmentsController> {
  const _TodayActiveCard(
      {required this.appointment, required this.isDark});
  final AppointmentModel appointment;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    final initials = appointment.patient.initials;
    final avatarColor = _avatarColor(initials);
    final statusInfo = _statusInfo(appointment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appointment.formattedTime,
                        style: AppTextStyles.labelLarge(AppColors.primary)
                            .copyWith(fontSize: 13)),
                    Text(
                        '${appointment.durationMinutes} min',
                        style: AppTextStyles.bodySmall(textSecondary)),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                // Avatar
                CircleAvatar(
                  radius: AppSpacing.avatarMD / 2,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(initials,
                      style: AppTextStyles.labelMedium(avatarColor)),
                ),
                const SizedBox(width: AppSpacing.md),
                // Patient info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appointment.patient.fullName,
                          style: AppTextStyles.titleSmall(textPrimary)),
                      Text(
                          '${appointment.doctor.fullName} • ${appointment.patient.mrn}',
                          style: AppTextStyles.bodySmall(textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                StatusBadge(
                    label: appointment.formattedStatus,
                    type: statusInfo.type),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Chief complaint + type badge
            Row(
              children: [
                if (appointment.chiefComplaint != null &&
                    appointment.chiefComplaint!.isNotEmpty) ...[
                  Expanded(
                    child: Text(
                      appointment.chiefComplaint!,
                      style: AppTextStyles.bodySmall(textSecondary)
                          .copyWith(fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                _TypeBadge(type: appointment.appointmentType),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: divider),
            const SizedBox(height: AppSpacing.sm),
            // Action buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => controller.updateStatus(
                        appointment, 'confirmed'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppDecorations.borderMD),
                    ),
                    child: Text('Confirm',
                        style:
                            AppTextStyles.labelSmall(AppColors.primary)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => controller.updateStatus(
                        appointment, 'checked_in'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.lightSurface,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppDecorations.borderMD),
                      elevation: 0,
                    ),
                    child: Text('Check In',
                        style: AppTextStyles.labelSmall(
                            AppColors.lightSurface)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Send reminder
                TextButton.icon(
                  onPressed: () => Get.snackbar(
                    'Reminder Sent',
                    'SMS reminder sent to patient',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  ),
                  icon: Icon(Icons.notifications_outlined,
                      size: 14, color: textSecondary),
                  label: Text('Remind',
                      style: AppTextStyles.labelSmall(textSecondary)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(String initials) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.warning,
      AppColors.info,
      const Color(0xFFFF6B35),
    ];
    return colors[initials.isNotEmpty ? initials.codeUnitAt(0) % colors.length : 0];
  }

  _StatusInfo _statusInfo(String status) {
    return switch (status) {
      'confirmed' => _StatusInfo(type: StatusType.success),
      'scheduled' => _StatusInfo(type: StatusType.info),
      'checked_in' => _StatusInfo(type: StatusType.warning),
      'in_progress' => _StatusInfo(type: StatusType.warning),
      'completed' => _StatusInfo(type: StatusType.success),
      'cancelled' => _StatusInfo(type: StatusType.error),
      'no_show' => _StatusInfo(type: StatusType.error),
      _ => _StatusInfo(type: StatusType.neutral),
    };
  }
}

// ─── Appointment List Card (general, used in List View + Calendar Day panel) ───

class _AppointmentListCard extends GetView<AppointmentsController> {
  const _AppointmentListCard({
    required this.appointment,
    required this.isDark,
    this.showMenu = true,
  });
  final AppointmentModel appointment;
  final bool isDark;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final initials = appointment.patient.initials;
    final avatarColor = _avatarColor(initials);
    final statusInfo = _statusInfo(appointment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: AppSpacing.avatarMD / 2,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(initials,
                      style: AppTextStyles.labelMedium(avatarColor)),
                ),
                const SizedBox(width: AppSpacing.md),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status
                      Row(
                        children: [
                          Expanded(
                            child: Text(appointment.patient.fullName,
                                style:
                                    AppTextStyles.titleSmall(textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          StatusBadge(
                              label: appointment.formattedStatus,
                              type: statusInfo.type),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      // Doctor name
                      Text(
                          '${appointment.doctor.fullName}${appointment.doctor.specialization != null ? ' • ${appointment.doctor.specialization}' : ''}',
                          style: AppTextStyles.bodySmall(textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.xs),
                      // Time + duration
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: AppDecorations.borderFull,
                            ),
                            child: Text(appointment.formattedTime,
                                style: AppTextStyles.numeric(
                                    AppColors.primary,
                                    fontSize: 11)),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('${appointment.durationMinutes} min',
                              style:
                                  AppTextStyles.bodySmall(textSecondary)),
                          const Spacer(),
                          Text(appointment.patient.mrn,
                              style: AppTextStyles.numeric(textSecondary,
                                  fontSize: 10)),
                        ],
                      ),
                      if (appointment.chiefComplaint != null &&
                          appointment.chiefComplaint!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(appointment.chiefComplaint!,
                            style: AppTextStyles.bodySmall(textSecondary)
                                .copyWith(fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      _TypeBadge(type: appointment.appointmentType),
                    ],
                  ),
                ),
                // 3-dot menu
                if (showMenu)
                  _AppointmentMenu(appointment: appointment, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _avatarColor(String initials) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.warning,
      AppColors.info,
      const Color(0xFFFF6B35),
    ];
    return colors[
        initials.isNotEmpty ? initials.codeUnitAt(0) % colors.length : 0];
  }

  _StatusInfo _statusInfo(String status) {
    return switch (status) {
      'confirmed' => _StatusInfo(type: StatusType.success),
      'scheduled' => _StatusInfo(type: StatusType.info),
      'checked_in' => _StatusInfo(type: StatusType.warning),
      'in_progress' => _StatusInfo(type: StatusType.warning),
      'completed' => _StatusInfo(type: StatusType.success),
      'cancelled' => _StatusInfo(type: StatusType.error),
      'no_show' => _StatusInfo(type: StatusType.error),
      _ => _StatusInfo(type: StatusType.neutral),
    };
  }
}

// ─── 3-Dot Menu ────────────────────────────────────────────────────────────────

class _AppointmentMenu extends GetView<AppointmentsController> {
  const _AppointmentMenu(
      {required this.appointment, required this.isDark});
  final AppointmentModel appointment;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return IconButton(
      icon: Icon(Icons.more_vert_rounded,
          color: textSecondary, size: AppSpacing.iconSM),
      onPressed: () => _showActionSheet(context, textPrimary, textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  void _showActionSheet(
      BuildContext context, Color textPrimary, Color textSecondary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionsBottomSheet(
        appointment: appointment,
        isDark: isDark,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ),
    );
  }
}

class _ActionsBottomSheet extends GetView<AppointmentsController> {
  const _ActionsBottomSheet({
    required this.appointment,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });
  final AppointmentModel appointment;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final actions = [
      _ActionItem(
          icon: Icons.check_circle_outline,
          label: 'Confirm',
          color: AppColors.secondary,
          onTap: () {
            Get.back();
            controller.updateStatus(appointment, 'confirmed');
          }),
      _ActionItem(
          icon: Icons.notifications_outlined,
          label: 'Send Reminder',
          color: AppColors.info,
          onTap: () {
            Get.back();
            Get.snackbar('Reminder', 'SMS sent to patient',
                snackPosition: SnackPosition.BOTTOM);
          }),
      _ActionItem(
          icon: Icons.login_rounded,
          label: 'Check In',
          color: AppColors.primary,
          onTap: () {
            Get.back();
            controller.updateStatus(appointment, 'checked_in');
          }),
      _ActionItem(
          icon: Icons.play_circle_outline,
          label: 'Start Consultation',
          color: AppColors.warning,
          onTap: () {
            Get.back();
            controller.updateStatus(appointment, 'in_progress');
          }),
      _ActionItem(
          icon: Icons.schedule_rounded,
          label: 'Reschedule',
          color: AppColors.tertiary,
          onTap: () {
            Get.back();
            Get.snackbar('Reschedule', 'Coming soon',
                snackPosition: SnackPosition.BOTTOM);
          }),
      _ActionItem(
          icon: Icons.cancel_outlined,
          label: 'Cancel',
          color: AppColors.error,
          onTap: () {
            Get.back();
            controller.updateStatus(appointment, 'cancelled');
          }),
      _ActionItem(
          icon: Icons.person_off_outlined,
          label: 'Mark No-Show',
          color: const Color(0xFFFF6B35),
          onTap: () {
            Get.back();
            controller.updateStatus(appointment, 'no_show');
          }),
      _ActionItem(
          icon: Icons.info_outline_rounded,
          label: 'View Details',
          color: textSecondary,
          onTap: () {
            Get.back();
            Get.snackbar('Details', 'Coming soon',
                snackPosition: SnackPosition.BOTTOM);
          }),
      _ActionItem(
          icon: Icons.folder_shared_outlined,
          label: 'View Patient Record',
          color: textSecondary,
          onTap: () {
            Get.back();
            Get.snackbar('Patient Record', 'Coming soon',
                snackPosition: SnackPosition.BOTTOM);
          }),
    ];

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDecorations.radiusXL)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: AppDecorations.borderFull,
              ),
            ),
            // Patient header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: AppSpacing.avatarMD / 2,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      appointment.patient.initials,
                      style: AppTextStyles.labelMedium(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appointment.patient.fullName,
                            style: AppTextStyles.titleSmall(textPrimary)),
                        Text(
                            '${appointment.formattedTime} • ${appointment.formattedType}',
                            style: AppTextStyles.bodySmall(textSecondary)),
                      ],
                    ),
                  ),
                  StatusBadge(
                      label: appointment.formattedStatus,
                      type: _statusType(appointment.status)),
                ],
              ),
            ),
            const Divider(height: 1),
            // Actions grid
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 2.4,
                physics: const NeverScrollableScrollPhysics(),
                children: actions
                    .map((a) => _ActionTile(item: a, isDark: isDark))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  StatusType _statusType(String status) => switch (status) {
        'confirmed' => StatusType.success,
        'scheduled' => StatusType.info,
        'checked_in' || 'in_progress' => StatusType.warning,
        'completed' => StatusType.success,
        'cancelled' || 'no_show' => StatusType.error,
        _ => StatusType.neutral,
      };
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item, required this.isDark});
  final _ActionItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.08),
          borderRadius: AppDecorations.borderMD,
          border: Border.all(
              color: item.color.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: item.color, size: 14),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(item.label,
                  style: AppTextStyles.labelSmall(item.color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Type Badge ────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'emergency' => ('Emergency', AppColors.error),
      'new_patient' => ('New Patient', AppColors.primary),
      'follow_up' => ('Follow Up', AppColors.secondary),
      'routine' => ('Routine', AppColors.info),
      _ => (
          type
              .split('_')
              .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
              .join(' '),
          AppColors.tertiary
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppDecorations.borderFull,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(label, style: AppTextStyles.labelSmall(color)),
    );
  }
}

// ─── Helper data class ─────────────────────────────────────────────────────────

class _StatusInfo {
  final StatusType type;
  const _StatusInfo({required this.type});
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments({this.message, required this.isDark});
  final String? message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.calendar_month_outlined,
                color: textSecondary.withValues(alpha: 0.4),
                size: AppSpacing.iconXL),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? 'No appointments found',
              style: AppTextStyles.bodyMedium(textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ──────────────────────────────────────────────────────────────────

class _AppointmentsSkeleton extends StatelessWidget {
  const _AppointmentsSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final base =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final highlight =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Summary strip
          _SkeletonBox(height: 80, borderRadius: AppDecorations.radiusLG),
          const SizedBox(height: AppSpacing.md),
          // Tab switcher
          _SkeletonBox(height: 48, borderRadius: AppDecorations.radiusLG),
          const SizedBox(height: AppSpacing.lg),
          // Calendar or cards
          _SkeletonBox(height: 340, borderRadius: AppDecorations.radiusLG),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(
              3,
              (_) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _SkeletonBox(
                        height: 120,
                        borderRadius: AppDecorations.radiusLG),
                  )),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox(
      {required this.height, required this.borderRadius});
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
}

// ─── Error State ───────────────────────────────────────────────────────────────

class _AppointmentsErrorState extends StatelessWidget {
  const _AppointmentsErrorState(
      {required this.message,
      required this.onRetry,
      required this.isDark});
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
                  shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded,
                  color: AppColors.error, size: AppSpacing.iconXL),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Connection Error',
                style: AppTextStyles.titleLarge(textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                style: AppTextStyles.bodyMedium(textSecondary),
                textAlign: TextAlign.center),
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
