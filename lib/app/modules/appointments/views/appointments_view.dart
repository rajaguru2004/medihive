import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/app_clock.dart';
import '../../../core/keys/app_keys.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/appointments_controller.dart';

/// The clinic board.
///
/// Opens on today, because a clinic desk is asked one question all day: who is
/// still to be seen. The month grid and the searchable full list are the other
/// two answers, behind a segmented control rather than in a drawer.
class AppointmentsView extends GetView<AppointmentsController> {
  const AppointmentsView({super.key, this.embedded = true});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      if (controller.isLoading && controller.rxFirstLoad.value) {
        return const _ClinicSkeleton();
      }

      return BentoScreen(
        key: AppointmentsKeys.screen,
        onRefresh: controller.reload,
        bottomClearance: false,
        slivers: [
          if (controller.hasLoadError)
            BentoSection(
              top: BentoSpace.page,
              child: ErrorRetryBanner(
                key: AppointmentsKeys.error,
                message: controller.rxLoadError.value!,
                onRetry: controller.load,
              ),
            ),

          BentoSection(
            top: controller.hasLoadError ? 0 : BentoSpace.page,
            bottom: BentoSpace.header,
            child: _TodaySummary(controller: controller),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BentoSpace.page),
              child: BentoSegmented<ClinicView>(
                options: const [
                  ClinicView.today,
                  ClinicView.day,
                  ClinicView.all,
                ],
                selected: controller.view.value,
                labelOf: (v) => switch (v) {
                  ClinicView.today => 'Today',
                  ClinicView.day => 'By date',
                  ClinicView.all => 'All',
                },
                onSelected: controller.showView,
              ),
            ),
          ),

          if (controller.view.value == ClinicView.day) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            BentoSection(
              bottom: BentoSpace.header,
              child: _MonthGrid(controller: controller),
            ),
          ],

          if (controller.view.value == ClinicView.all) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            BentoSection(
              bottom: BentoSpace.header,
              child: SearchField(
                key: AppointmentsKeys.search,
                hint: 'Patient, MRN, clinician or complaint',
                onChanged: controller.search,
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChips<String>(
                options: controller.statuses,
                selected: controller.statusFilter.value,
                labelOf: CaseStatus.labelOf,
                keyOf: (value) => AppointmentsKeys.filter(value),
                onSelected: controller.filterByStatus,
              ),
            ),
          ],

          ..._rows(context),
        ],
      );
    });

    if (embedded) return body;

    return Scaffold(
      appBar: DetailHeader(
        title: 'Appointments',
        action: CircleIconButton(
          key: AppointmentsKeys.createButton,
          icon: Icons.add_rounded,
          tooltip: 'Book appointment',
          onTap: () => Get.toNamed<void>(Routes.APPOINTMENT_CREATE),
        ),
      ),
      body: body,
    );
  }

  /// The list, in whichever shape this view calls for.
  ///
  /// Today splits into still-to-be-seen and dealt-with, because that is the
  /// only split a clinic desk cares about. The other two views are one list.
  List<Widget> _rows(BuildContext context) {
    if (controller.view.value == ClinicView.today) {
      final open = controller.todayOpen;
      final closed = controller.todayClosed;

      if (open.isEmpty && closed.isEmpty) {
        return [
          const BentoSection(
            top: BentoSpace.section,
            child: EmptyState(
              key: AppointmentsKeys.empty,
              icon: Icons.event_available_outlined,
              title: 'Nothing booked today',
              message: 'Appointments booked for today appear here in time '
                  'order.',
            ),
          ),
        ];
      }

      return [
        if (open.isNotEmpty)
          BentoSection(
            top: BentoSpace.header,
            bottom: closed.isEmpty ? BentoSpace.section : BentoSpace.header,
            child: _AppointmentList(
              listKey: AppointmentsKeys.list,
              title: 'Still to be seen',
              rows: open,
              controller: controller,
            ),
          ),
        if (closed.isNotEmpty)
          BentoSection(
            child: _AppointmentList(
              title: 'Dealt with',
              rows: closed,
              controller: controller,
            ),
          ),
      ];
    }

    final rows = controller.displayed;
    if (rows.isEmpty) {
      return [
        BentoSection(
          top: BentoSpace.section,
          child: EmptyState(
            key: AppointmentsKeys.empty,
            icon: Icons.event_busy_outlined,
            title: controller.isFiltered
                ? 'Nothing matches those filters'
                : controller.view.value == ClinicView.day
                    ? 'Nothing booked on '
                        '${Formatters.dateMedium(controller.selectedDay.value)}'
                    : 'No appointments yet',
            actionLabel: controller.isFiltered ? 'Clear filters' : null,
            onAction: controller.isFiltered ? controller.clearFilters : null,
          ),
        ),
      ];
    }

    return [
      BentoSection(
        top: BentoSpace.header,
        child: _AppointmentList(
          listKey: AppointmentsKeys.list,
          rows: rows,
          controller: controller,
          showDate: controller.view.value == ClinicView.all,
        ),
      ),
    ];
  }
}

// ── Today summary ───────────────────────────────────────────────────────────

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.controller});

  final AppointmentsController controller;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      hero: true,
      child: VitalsGrid(
        columns: 3,
        tiles: [
          VitalTile(
            label: 'Booked today',
            value: '${controller.countToday(null)}',
          ),
          VitalTile(
            label: 'Arrived',
            value: '${controller.countToday('checked_in')}',
          ),
          VitalTile(
            label: 'Seen',
            value: '${controller.countToday('completed')}',
          ),
        ],
      ),
    );
  }
}

// ── Month grid ──────────────────────────────────────────────────────────────

/// A month, with a dot on every day that has something booked.
///
/// Deliberately not a full calendar widget: the question is "which days are
/// busy", and a 7×5 grid of numbers answers it in one glance without a package
/// or a gesture vocabulary nobody taught the user.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.controller});

  final AppointmentsController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedDay.value;
    final month = DateTime(selected.year, selected.month);
    final counts = controller.countsForMonth(month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Monday-first. `DateTime.weekday` is 1–7 with Monday at 1, so the leading
    // blanks are simply weekday − 1.
    final leading = month.weekday - 1;
    final today = AppClock.now();

    return BentoCard(
      key: AppointmentsKeys.datePicker,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: Theme.of(context).brightness == Brightness.dark
                      ? AppTextStyles.darkHeadline()
                      : AppTextStyles.lightHeadline(),
                ),
              ),
              CircleIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous month',
                onTap: () => controller.selectDay(
                  DateTime(month.year, month.month - 1, 1),
                ),
              ),
              CircleIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next month',
                onTap: () => controller.selectDay(
                  DateTime(month.year, month.month + 1, 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: AppTextStyles.overline(
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var week = 0; week * 7 < leading + daysInMonth; week++)
            Row(
              children: [
                for (var slot = 0; slot < 7; slot++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = week * 7 + slot - leading + 1;
                        if (day < 1 || day > daysInMonth) {
                          return const SizedBox(height: AppTheme.minTapTarget);
                        }
                        final date = DateTime(month.year, month.month, day);
                        return _DayCell(
                          day: day,
                          count: counts[day] ?? 0,
                          isToday: _sameDay(date, today),
                          isSelected: _sameDay(date, selected),
                          onTap: () => controller.selectDay(date),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = isSelected
        ? onBrandFillColor(context)
        : count > 0
            ? labelColor(context)
            : tertiaryLabelColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BentoRadius.small),
      child: SizedBox(
        // The disc stays 34 — it is a date, not a button — but the target
        // under it is the full minimum. A month grid is thirty-odd targets
        // side by side, which is exactly where a near-miss costs a mis-booking.
        height: AppTheme.minTapTarget,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? brandFillColor(context) : null,
              borderRadius: BorderRadius.circular(BentoRadius.small),
              // Today is marked by a ring, selection by a fill, so the two can
              // be true at once and still be told apart.
              border: isToday && !isSelected
                  ? Border.all(color: brandInkColor(context))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: AppFonts.numeric(
                    fontSize: 13,
                    fontWeight:
                        count > 0 ? FontWeight.w700 : FontWeight.w400,
                    color: ink,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                // A dot rather than the count: the count is on the list below,
                // and three digits in a 34 dp cell is unreadable anyway.
                SizedBox(
                  height: 4,
                  child: count > 0
                      ? StatusMark(
                          color: isSelected
                              ? onBrandFillColor(context)
                              : AppColors.accent,
                          size: 4,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── List ────────────────────────────────────────────────────────────────────

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    this.listKey,
    this.title,
    required this.rows,
    required this.controller,
    this.showDate = false,
  });

  final Key? listKey;
  final String? title;
  final List<AppointmentModel> rows;
  final AppointmentsController controller;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) SectionHeader(title: title!),
        // Nothing dims this group. Opacity over live text is a contrast
        // defect, not a shade of emphasis: 0.62 took these subtitles to
        // 2.80:1, under the 4.5:1 floor, and a dealt-with appointment is
        // still the record somebody opens to check what was done. It is
        // already said twice without costing a single ratio — by the header
        // above and by each row's StatusPill.
        BentoCard(
          key: listKey,
          padding: const EdgeInsets.symmetric(
            vertical: BentoSpace.listCardPad,
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                _AppointmentRow(
                  key: AppointmentsKeys.row(rows[i].id),
                  appointment: rows[i],
                  controller: controller,
                  showDate: showDate,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({
    super.key,
    required this.appointment,
    required this.controller,
    this.showDate = false,
  });

  final AppointmentModel appointment;
  final AppointmentsController controller;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final patient = appointment.patient;
    final name = patient.fullName.trim();
    final facts = [
      if (appointment.doctor.fullName.trim().isNotEmpty)
        appointment.doctor.fullName,
      if (appointment.chiefComplaint.trim().isNotEmpty)
        appointment.chiefComplaint,
    ].join(' · ');

    return BentoRow(
      title: name.isEmpty ? 'Patient ${patient.mrn}' : name,
      subtitle: facts.isEmpty ? null : facts,
      showChevron: false,
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 10,
      ),
      leading: SizedBox(
        width: 52,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appointment.appointmentTime,
              style: AppFonts.numeric(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: labelColor(context),
                height: 1.0,
              ),
            ),
            if (showDate) ...[
              const SizedBox(height: 3),
              Text(
                DateFormat('d MMM').format(appointment.appointmentDate),
                style: AppTextStyles.unit(Theme.of(context).brightness,
                    size: 11),
              ),
            ],
          ],
        ),
      ),
      trailing: StatusPill(status: appointment.status, compact: true),
      onTap: () => _openActions(context, appointment, controller),
    );
  }
}

Future<void> _openActions(
  BuildContext context,
  AppointmentModel appointment,
  AppointmentsController controller,
) {
  final patient = appointment.patient;
  final name = patient.fullName.trim().isEmpty
      ? 'Patient ${patient.mrn}'
      : patient.fullName;
  final status = appointment.status.trim().toLowerCase();
  final closed = const {'completed', 'cancelled', 'no_show'}.contains(status);

  return Get.bottomSheet<void>(
    SheetShell(
      title: name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PatientIdentityBand(
            name: name,
            mrn: patient.mrn,
            sex: patient.gender,
            extra: '${appointment.appointmentTime} · '
                '${appointment.doctor.fullName}',
          ),
          if (appointment.chiefComplaint.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            FactRow(
              label: 'Complaint',
              value: appointment.chiefComplaint,
            ),
          ],
          const SizedBox(height: BentoSpace.section),
          if (closed)
            const NoticeBanner(
              message: 'This appointment is closed. Reopening it is done in '
                  'the admin console.',
              icon: Icons.lock_outline_rounded,
            )
          else ...[
            if (status == 'scheduled' || status == 'confirmed')
              SheetRow(
                icon: Icons.how_to_reg_outlined,
                label: 'Check in',
                sublabel: 'The patient has arrived',
                onTap: () {
                  Get.back<void>();
                  controller.setStatus(appointment, 'checked_in');
                },
              ),
            if (status == 'checked_in')
              SheetRow(
                icon: Icons.play_arrow_rounded,
                label: 'Start',
                sublabel: 'With the clinician now',
                onTap: () {
                  Get.back<void>();
                  controller.setStatus(appointment, 'in_progress');
                },
              ),
            if (status == 'in_progress' || status == 'checked_in')
              SheetRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Complete',
                onTap: () {
                  Get.back<void>();
                  controller.setStatus(appointment, 'completed');
                },
              ),
            SheetRow(
              icon: Icons.person_off_outlined,
              label: 'Did not attend',
              onTap: () {
                Get.back<void>();
                controller.setStatus(appointment, 'no_show');
              },
            ),
            const Hairline(),
            SheetRow(
              icon: Icons.event_busy_outlined,
              label: 'Cancel appointment',
              destructive: true,
              onTap: () async {
                Get.back<void>();
                final confirmed = await ConfirmDialog.show(
                  context,
                  title: 'Cancel $name’s appointment?',
                  message: 'The slot is released. Rebooking is done from the '
                      'admin console.',
                  confirmLabel: 'Cancel appointment',
                  cancelLabel: 'Keep it',
                  destructive: true,
                );
                if (confirmed) {
                  await controller.setStatus(appointment, 'cancelled');
                }
              },
            ),
          ],
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

// ── Loading ─────────────────────────────────────────────────────────────────

class _ClinicSkeleton extends StatelessWidget {
  const _ClinicSkeleton();

  @override
  Widget build(BuildContext context) {
    return const BentoScreen(
      bottomClearance: false,
      slivers: [
        BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 2)),
        BentoSection(child: BentoSkeleton(rows: 5)),
      ],
    );
  }
}
