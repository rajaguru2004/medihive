import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/dashboard_controller.dart';

/// Today's board.
///
/// Ordered by what a charge nurse looks for on picking the tablet up, in that
/// order: **is anyone in trouble**, then how full are we, then who is waiting,
/// then what is booked. The old dashboard opened on a welcome card and put the
/// critical-alert count seventh; nobody scrolls a ward board.
///
/// No title of its own — the shell bar already says "Today", and a tab that
/// repeats its own heading is a tab that has given up a row of viewport for
/// nothing.
class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading && controller.rxFirstLoad.value) {
        return const _DashboardSkeleton();
      }

      return BentoScreen(
        key: HomeKeys.dashboard,
        onRefresh: controller.reload,
        // The shell's tab bar is a real `bottomNavigationBar`, so the Scaffold
        // has already reserved its height. Adding the kit's floating-bar
        // clearance on top would leave a second empty bar's worth of gap under
        // every screen.
        bottomClearance: false,
        slivers: [
          if (controller.hasLoadError)
            BentoSection(
              top: BentoSpace.page,
              child: ErrorRetryBanner(
                key: HomeKeys.error,
                message: controller.rxLoadError.value!,
                onRetry: controller.load,
              ),
            ),

          // ── Attention ───────────────────────────────────────────────────
          // First, and only when there is something to say. A permanent
          // "0 alerts" card trains a reader to skip the place alerts appear.
          if (controller.stats.criticalAlerts > 0)
            BentoSection(
              top: BentoSpace.page,
              child: _AttentionCard(count: controller.stats.criticalAlerts),
            ),

          // ── Census ──────────────────────────────────────────────────────
          // Suppressed when the fetch failed and there is nothing behind it: a
          // wall of zeros under an error banner reads as a department with no
          // patients rather than as a board that did not load.
          if (!(controller.hasLoadError && controller.dashboard == null))
            BentoSection(
              top: controller.stats.criticalAlerts > 0 ? 0 : BentoSpace.page,
              child: _CensusCard(controller: controller),
            ),

          // ── Quick actions ───────────────────────────────────────────────
          BentoSection(child: _QuickActions(controller: controller)),

          // ── Waiting ─────────────────────────────────────────────────────
          if (controller.queueByService.isNotEmpty)
            BentoSection(
              child: _QueueLoadCard(services: controller.queueByService),
            ),

          // ── Clinic ──────────────────────────────────────────────────────
          BentoSection(
            child: _AppointmentsCard(
              statuses: controller.appointmentStatuses,
              upcoming: controller.upcomingAppointments,
            ),
          ),

          // ── Recently registered ─────────────────────────────────────────
          if (controller.recentPatients.isNotEmpty)
            BentoSection(child: _RecentPatientsCard(controller: controller)),

          if (controller.isEmpty)
            const BentoSection(
              top: BentoSpace.page,
              child: EmptyState(
                key: HomeKeys.empty,
                icon: Icons.monitor_heart_outlined,
                title: 'Nothing on the board yet',
                message:
                    'Once patients are registered and appointments booked, '
                    "today's numbers appear here.",
              ),
            ),
        ],
      );
    });
  }
}

// ── Attention ───────────────────────────────────────────────────────────────

/// The one card that is allowed to be red.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ActionCard(
      key: HomeKeys.attention,
      title: count == 1 ? '1 patient needs attention' : '$count patients need attention',
      message: count == 1
          ? 'One patient has been flagged as critical or is deteriorating.'
          : 'These patients have been flagged as critical or are deteriorating.',
      actionLabel: 'Open queue',
      icon: Icons.priority_high_rounded,
      tint: AppColors.acuityCritical,
      onAction: () => Get.toNamed<void>(Routes.QUEUE),
    );
  }
}

// ── Census ──────────────────────────────────────────────────────────────────

/// Beds and today's headline counts. The hero card of the screen.
class _CensusCard extends StatelessWidget {
  const _CensusCard({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final stats = controller.stats;

    return BentoCard(
      key: HomeKeys.census,
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BED OCCUPANCY',
            style: AppTextStyles.overline(Theme.of(context).brightness),
          ),
          const SizedBox(height: 12),
          WardCapacityBar(
            key: HomeKeys.occupancy,
            occupied: stats.occupiedBeds,
            total: controller.totalBeds,
          ),
          const SizedBox(height: 18),
          const Hairline(),
          const SizedBox(height: 18),
          VitalsGrid(
            columns: 3,
            tiles: [
              VitalTile(
                key: HomeKeys.figure('waiting'),
                label: 'Waiting',
                value: '${stats.queueWaiting}',
                // Colour only when it means something. A queue is a queue
                // until it is long, and a figure that is always tinted is a
                // figure whose tint says nothing.
                tone: stats.queueWaiting >= 10 ? AppColors.acuityUrgent : null,
                onTap: () => Get.toNamed<void>(Routes.QUEUE),
              ),
              VitalTile(
                key: HomeKeys.figure('appointments'),
                label: 'Booked',
                value: '${stats.todayAppointments}',
                onTap: () => Get.toNamed<void>(Routes.APPOINTMENTS),
              ),
              VitalTile(
                key: HomeKeys.figure('patients'),
                label: 'Patients',
                value: '${stats.totalPatients}',
              ),
              VitalTile(
                key: HomeKeys.figure('labs'),
                label: 'Labs',
                value: '${stats.pendingLabOrders}',
                onTap: () => Get.toNamed<void>(Routes.LABORATORY),
              ),
              VitalTile(
                key: HomeKeys.figure('prescriptions'),
                label: 'Scripts',
                value: '${stats.pendingPrescriptions}',
                onTap: () => Get.toNamed<void>(Routes.PHARMACY),
              ),
              VitalTile(
                key: HomeKeys.figure('free-beds'),
                label: 'Beds free',
                value: '${stats.availableBeds}',
                tone: stats.availableBeds == 0 && controller.totalBeds > 0
                    ? AppColors.acuityCritical
                    : null,
                onTap: () => Get.toNamed<void>(Routes.INPATIENT_BEDS_GRID),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ───────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    // Four, on one row, all of them things somebody standing at a desk does
    // several times an hour. Anything done once a shift belongs on its own
    // screen, not here.
    const actions = [
      (
        id: 'screening',
        icon: Icons.assignment_outlined,
        label: 'New screening',
        route: Routes.NEW_SCREENING_STEP1,
      ),
      (
        id: 'queue',
        icon: Icons.person_add_alt_1_outlined,
        label: 'Add to queue',
        route: Routes.ADD_TO_QUEUE,
      ),
      (
        id: 'admit',
        icon: Icons.local_hotel_outlined,
        label: 'Admit patient',
        route: Routes.INPATIENT_ADMIT,
      ),
    ];

    return Column(
      key: HomeKeys.quickActions,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick actions'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: QuickActionTile(
                    key: HomeKeys.quickAction(actions[i].id),
                    icon: actions[i].icon,
                    label: actions[i].label,
                    onTap: () => Get.toNamed<void>(actions[i].route),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Queue load ──────────────────────────────────────────────────────────────

/// Who is waiting, by service.
///
/// A ranked list rather than a pie chart: the question is "where is the
/// backlog", and a reader answers that from a sorted list in a fraction of the
/// time a pie takes. The bars are there to make the gap between first and
/// second legible at a glance, not to be read as values.
class _QueueLoadCard extends StatelessWidget {
  const _QueueLoadCard({required this.services});

  final List<QueueService> services;

  @override
  Widget build(BuildContext context) {
    final sorted = [...services]..sort((a, b) => b.count.compareTo(a.count));
    final busiest = sorted.first.count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Waiting by service',
          actionLabel: 'Queue',
          onAction: () => Get.toNamed<void>(Routes.QUEUE),
        ),
        BentoCard(
          key: HomeKeys.queueLoad,
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: 14),
                  const Hairline(),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sorted[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? AppTextStyles.darkSubheadline(
                                    weight: FontWeight.w600)
                                : AppTextStyles.lightSubheadline(
                                    weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          UsedBar(
                            fraction:
                                busiest == 0 ? 0 : sorted[i].count / busiest,
                            // The accent, not an acuity: a long queue for
                            // radiology is a workload fact, not a clinical
                            // state, and painting it red would put a
                            // deteriorating patient and a busy scanner in the
                            // same colour.
                            color: AppColors.accent,
                            height: 5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    VitalFigure(value: '${sorted[i].count}', size: 17),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Appointments ────────────────────────────────────────────────────────────

class _AppointmentsCard extends StatelessWidget {
  const _AppointmentsCard({required this.statuses, required this.upcoming});

  final AppointmentStatuses statuses;
  final List<UpcomingAppointment> upcoming;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Clinic today',
          actionLabel: 'All',
          onAction: () => Get.toNamed<void>(Routes.APPOINTMENTS),
        ),
        BentoCard(
          padding: const EdgeInsets.symmetric(
            vertical: BentoSpace.cardPad,
            horizontal: BentoSpace.cardPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (statuses.total > 0) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (statuses.scheduled > 0)
                      StatusPill(
                        status: 'scheduled',
                        label: '${statuses.scheduled} scheduled',
                      ),
                    if (statuses.confirmed > 0)
                      StatusPill(
                        status: 'confirmed',
                        label: '${statuses.confirmed} confirmed',
                      ),
                    if (statuses.completed > 0)
                      StatusPill(
                        status: 'completed',
                        label: '${statuses.completed} seen',
                      ),
                    if (statuses.cancelled > 0)
                      StatusPill(
                        status: 'cancelled',
                        label: '${statuses.cancelled} cancelled',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Hairline(),
                const SizedBox(height: 4),
              ],
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: EmptyState(
                    compact: true,
                    icon: Icons.event_available_outlined,
                    title: 'Nothing else booked today',
                  ),
                )
              else
                for (var i = 0; i < upcoming.length; i++) ...[
                  if (i > 0) const Hairline(),
                  _AppointmentRow(appointment: upcoming[i]),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment});

  final UpcomingAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final patient = appointment.patient;
    final name = '${patient.firstName} ${patient.lastName}'.trim();

    return BentoRow(
      title: name.isEmpty ? 'Patient ${patient.mrn}' : name,
      subtitle: patient.mrn.isEmpty ? null : 'MRN ${patient.mrn}',
      showChevron: false,
      padding: const EdgeInsets.symmetric(vertical: 12),
      // The time, not an icon. A clinic list is read down its time column.
      leading: SizedBox(
        width: 46,
        child: Text(
          appointment.appointmentTime,
          style: AppFonts.numeric(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: labelColor(context),
            height: 1.0,
          ),
        ),
      ),
      trailing: StatusPill(status: appointment.status, compact: true),
      onTap: () => Get.toNamed<void>(Routes.APPOINTMENTS),
    );
  }
}

// ── Recent patients ─────────────────────────────────────────────────────────

class _RecentPatientsCard extends StatelessWidget {
  const _RecentPatientsCard({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final patients = controller.recentPatients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recently registered',
          actionLabel: controller.hasMorePatients
              ? (controller.showAllPatients ? 'Show less' : 'Show all')
              : null,
          onAction: controller.hasMorePatients
              ? controller.toggleShowAllPatients
              : null,
        ),
        BentoCard(
          padding: const EdgeInsets.symmetric(
            vertical: BentoSpace.listCardPad,
          ),
          child: Column(
            children: [
              for (var i = 0; i < patients.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                _PatientRow(patient: patients[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient});

  final RecentPatient patient;

  @override
  Widget build(BuildContext context) {
    final name = '${patient.firstName} ${patient.lastName}'.trim();
    final age = Formatters.age(patient.dateOfBirth);
    final facts = [
      if (patient.mrn.isNotEmpty) 'MRN ${patient.mrn}',
      if (age != '—') age,
      if (patient.gender.isNotEmpty) patient.gender,
    ];

    return BentoRow(
      title: name.isEmpty ? 'Unnamed patient' : name,
      subtitle: facts.isEmpty ? null : facts.join(' · '),
      icon: Icons.person_outline_rounded,
      showChevron: false,
      trailing: Text(
        Formatters.relativeDay(patient.createdAt),
        style: Theme.of(context).brightness == Brightness.dark
            ? AppTextStyles.darkCaption1()
            : AppTextStyles.lightCaption1(),
      ),
    );
  }
}

// ── Loading ─────────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const BentoScreen(
      bottomClearance: false,
      slivers: [
        BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 3)),
        BentoSection(child: BentoSkeleton(rows: 2)),
        BentoSection(child: BentoSkeleton(rows: 3)),
      ],
    );
  }
}
