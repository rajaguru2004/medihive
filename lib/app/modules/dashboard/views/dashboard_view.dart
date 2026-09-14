import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../../appointments/appointment_routes.dart';
import '../../laboratory/laboratory_routes.dart';
import '../../patients/patient_routes.dart';
import '../../pharmacy/pharmacy_routes.dart';
import '../controllers/dashboard_controller.dart';
import '../shift_board.dart';
import 'shift_band_card.dart';
import 'shift_charts.dart';

/// Today's board, shaped by what this account is on shift to do.
///
/// Read in the order a clinician picking the tablet up reads it: **is anybody
/// in trouble**, then the department's figures, then the work that is waiting
/// on *them* — at most four bands, resolved from the access map rather than
/// from a role name, because a hospital can define its own roles and a board
/// that switches on `role == 'NURSE'` is a board that ignores them.
///
/// Every section owns its own `Obx`. A widget constructed inside an `Obx`
/// closure is not inside its reactive scope — the closure builds the widget
/// object and Flutter calls `build` on it later, outside the proxy that
/// records reads — so a section that read an observable through its parent's
/// subscription would simply stop repainting.
///
/// No title of its own: the shell bar already says "Today", and a tab that
/// repeats its own heading has given up a row of viewport for nothing.
class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`, before anything else. A `GetView` whose
    // build never touches `controller` never constructs the `lazyPut` one, so
    // `onReady` never runs and the screen loads nothing — the trap that hung
    // the splash screen for a whole debugging session.
    final board = controller;

    return BentoScreen(
      key: HomeKeys.dashboard,
      onRefresh: board.reload,
      // The shell's tab bar is a real `bottomNavigationBar`, so the Scaffold
      // has already reserved its height. Adding the kit's floating-bar
      // clearance on top would leave a second empty bar's worth of gap under
      // every screen.
      bottomClearance: false,
      slivers: [
        // One fixed gap at the top rather than a conditional one on whichever
        // section happens to be first: which sections are drawn depends on the
        // account and on what loaded, and a `top:` that has to guess is a
        // board that jumps as its parts arrive.
        const SliverToBoxAdapter(child: SizedBox(height: BentoSpace.page)),
        _Freshness(board: board),
        _BoardError(board: board),
        _Attention(board: board),
        _Census(board: board),
        // The shortcuts and the bands sit **above** the charts. The bands are
        // what this screen is for — the work waiting on this account — and the
        // charts are the web console's figures drawn again. A board that puts
        // two charts between a nurse and her ward round is a board she scrolls
        // past twice a shift.
        _QuickActions(board: board),
        _Bands(board: board),
        _Charts(board: board),
        _Upcoming(board: board),
        _RecentPatients(board: board),
        _BoardEmpty(board: board),
      ],
    );
  }
}

/// Page-padded content, or nothing at all.
///
/// The padding is inside the reactive builder rather than around it: a
/// `BentoSection` wrapped around a `SizedBox.shrink()` still spends a
/// section's worth of space, so a board with three suppressed sections has
/// three gaps nobody put there.
Widget _padded(Widget? child, {double bottom = BentoSpace.section}) =>
    child == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.fromLTRB(
              BentoSpace.page,
              0,
              BentoSpace.page,
              bottom,
            ),
            child: child,
          );

// ── Freshness ───────────────────────────────────────────────────────────────

/// When these numbers were last true, and whether they still are.
///
/// A board that refreshes silently has to say so somewhere, or a clinician
/// cannot tell a quiet department from a dead connection.
class _Freshness extends StatelessWidget {
  const _Freshness({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(() {
          final at = board.updatedAt.value;
          final stale = board.isStale.value;
          if (at == null && !stale) return const SizedBox.shrink();

          return _padded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (at != null)
                  Text(
                    'Updated ${SettingsService.to.time(at)}',
                    key: ShiftKeys.updatedAt,
                    style: AppTextStyles.overline(
                      Theme.of(context).brightness,
                    ),
                  ),
                if (stale) ...[
                  if (at != null) const SizedBox(height: 10),
                  const NoticeBanner(
                    key: ShiftKeys.stale,
                    // Amber, not red: nothing is wrong with the patients, the
                    // last refresh did not land. And it says what is on
                    // screen rather than what failed, because that is the
                    // question somebody reading it actually has.
                    icon: Icons.cloud_off_rounded,
                    tint: AppColors.warning,
                    message: 'These are the last figures that reached this '
                        'device. Pull down to try again.',
                  ),
                ],
              ],
            ),
            bottom: BentoSpace.header,
          );
        }),
      );
}

// ── The board's own failure ─────────────────────────────────────────────────

class _BoardError extends StatelessWidget {
  const _BoardError({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(
          () => _padded(
            board.hasLoadError
                ? ErrorRetryBanner(
                    key: HomeKeys.error,
                    message: board.rxLoadError.value!,
                    onRetry: board.load,
                    margin: EdgeInsets.zero,
                  )
                : null,
          ),
        ),
      );
}

// ── Attention ───────────────────────────────────────────────────────────────

/// The one card on this screen allowed to be red.
///
/// Drawn only when there is something to say. A permanent "0 alerts" card
/// trains a reader to skip the place alerts appear.
class _Attention extends StatelessWidget {
  const _Attention({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(() {
          final count = board.stats.criticalAlerts;
          // `<= 0`, not `== 0`: this backend stores an uncounted figure as
          // zero and has answered a negative one from a stats route that
          // subtracted two counts taken a second apart.
          if (count <= 0) return const SizedBox.shrink();

          // The count is everybody's business — a deteriorating patient is —
          // but the way in is only offered to somebody who can open it. A red
          // card whose one action is refused is an alarm with no answer.
          final canOpen = AccessService.to.canRead(Modules.queue);

          return _padded(
            ActionCard(
              key: HomeKeys.attention,
              title: count == 1
                  ? '1 patient needs attention'
                  : '$count patients need attention',
              message: count == 1
                  ? 'One patient has been flagged as critical or is '
                      'deteriorating.'
                  : 'These patients have been flagged as critical or are '
                      'deteriorating.',
              actionLabel: canOpen ? 'Open queue' : null,
              icon: Icons.priority_high_rounded,
              tint: AppColors.acuityCritical,
              onAction: canOpen ? () => Get.toNamed<void>(Routes.QUEUE) : null,
            ),
          );
        }),
      );
}

// ── Census ──────────────────────────────────────────────────────────────────

/// Beds, today's takings, and the eight figures the web console shows.
class _Census extends StatelessWidget {
  const _Census({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(() => _padded(_card(context))),
      );

  Widget? _card(BuildContext context) {
    if (board.hasNoAccess) {
      return const BentoCard(
        key: HomeKeys.census,
        child: EmptyState(
          compact: true,
          icon: Icons.lock_outline_rounded,
          title: "Today's figures are not available to your role",
          message: 'The work waiting on you is still below.',
        ),
      );
    }

    // First load only. A refresh keeps the numbers that are already on screen
    // rather than collapsing them to a skeleton under somebody's thumb.
    if (board.dashboard == null) {
      if (board.isLoading) return const BentoSkeleton(rows: 3);
      // Nothing loaded and not loading: the banner above or the empty state
      // below is already saying why, and a wall of zeros under either reads as
      // a department with no patients.
      return null;
    }

    final stats = board.stats;

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
            total: board.totalBeds,
          ),
          if (board.canSeeRevenue) ...[
            const SizedBox(height: 18),
            const Hairline(),
            const SizedBox(height: 18),
            MoneyFigure(
              key: ShiftKeys.revenue,
              label: 'Taken today',
              amount: board.money(stats.todayRevenue),
              caption: 'Across every method',
              // The ledger blue, never a clinical colour. Money is not a
              // patient state.
              color: semanticInk(context, AppColors.accent),
            ),
          ],
          const SizedBox(height: 18),
          const Hairline(),
          const SizedBox(height: 18),
          FigureGrid(
            key: ShiftKeys.figures,
            figures: _figures(stats),
          ),
        ],
      ),
    );
  }

  /// The eight the web console shows, in the order somebody reads them.
  ///
  /// Each figure navigates only where this account can actually go: a tile
  /// that opens a refusal screen is the same defect as a shortcut that does.
  List<Figure> _figures(DashboardStats stats) => [
        Figure(
          label: 'Waiting',
          value: '${stats.queueWaiting}',
          icon: Icons.groups_outlined,
          // Colour only when it means something. A queue is a queue until it
          // is long, and a figure that is always tinted is a figure whose tint
          // says nothing.
          color: stats.queueWaiting >= 10 ? AppColors.acuityUrgent : null,
          onTap: _open(Modules.queue, Routes.QUEUE),
        ),
        Figure(
          label: 'Booked today',
          value: '${stats.todayAppointments}',
          icon: Icons.event_outlined,
          onTap: _open(Modules.appointments, AppointmentRoutes.board),
        ),
        Figure(
          label: 'Patients',
          value: '${stats.totalPatients}',
          icon: Icons.badge_outlined,
          onTap: _open(Modules.patients, PatientRoutes.registry),
        ),
        Figure(
          label: 'Lab orders',
          value: '${stats.pendingLabOrders}',
          icon: Icons.science_outlined,
          onTap: _open(Modules.laboratory, LabRoutes.worklist),
        ),
        Figure(
          label: 'Prescriptions',
          value: '${stats.pendingPrescriptions}',
          icon: Icons.medication_outlined,
          onTap: _open(Modules.pharmacy, PharmacyRoutes.hub),
        ),
        Figure(
          label: 'Beds free',
          value: '${stats.availableBeds}',
          icon: Icons.bed_outlined,
          // A ward with no free bed is the one bed figure that is an alarm:
          // the next admission has nowhere to go.
          color: stats.availableBeds <= 0 && board.totalBeds > 0
              ? AppColors.acuityCritical
              : null,
          onTap: _open(Modules.inpatient, Routes.INPATIENT_BEDS_GRID),
        ),
        Figure(
          label: 'Beds in use',
          value: '${stats.occupiedBeds}',
          icon: Icons.local_hotel_outlined,
          onTap: _open(Modules.inpatient, Routes.INPATIENT_ADMISSIONS),
        ),
        Figure(
          label: 'Needs attention',
          value: '${stats.criticalAlerts}',
          icon: Icons.priority_high_rounded,
          // Red only when there is one. A zero painted in the app's one alarm
          // colour is a false alarm, and a board that cries wolf in the corner
          // it reserves for wolves stops being read.
          color: stats.criticalAlerts > 0 ? AppColors.acuityCritical : null,
          onTap: _open(Modules.queue, Routes.QUEUE),
        ),
      ];

  VoidCallback? _open(String module, String route) =>
      AccessService.to.canRead(module)
          ? () => Get.toNamed<void>(route)
          : null;
}

// ── Charts ──────────────────────────────────────────────────────────────────

/// The two the web console draws: today's clinic by status, and who is waiting
/// by service area.
class _Charts extends StatelessWidget {
  const _Charts({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(() {
          final clinic = board.appointmentSeries;
          final queue = board.queueSeries;
          if (clinic.isEmpty && queue.isEmpty) return const SizedBox.shrink();

          return _padded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (clinic.isNotEmpty) ...[
                  const SectionHeader(title: 'Clinic by status'),
                  BentoCard(
                    key: ShiftKeys.appointmentChart,
                    child: AppointmentStatusChart(series: clinic),
                  ),
                ],
                if (clinic.isNotEmpty && queue.isNotEmpty)
                  const SizedBox(height: BentoSpace.section),
                if (queue.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Waiting by service',
                    // The breakdown is worth seeing without the board — a lab
                    // technician cares how many people are waiting on them —
                    // but the way through is only offered to somebody who can
                    // open it.
                    actionLabel: AccessService.to.canRead(Modules.queue)
                        ? 'Queue'
                        : null,
                    onAction: AccessService.to.canRead(Modules.queue)
                        ? () => Get.toNamed<void>(Routes.QUEUE)
                        : null,
                  ),
                  BentoCard(
                    key: ShiftKeys.queueChart,
                    child: QueueAreaChart(series: queue),
                  ),
                ],
              ],
            ),
          );
        }),
      );
}

// ── Quick actions ───────────────────────────────────────────────────────────

/// Things somebody standing at a desk does several times an hour.
///
/// Every tile is gated on the module **and verb the screen it opens actually
/// needs**, and every route here is a real screen rather than a placeholder. A
/// screenshot round once caught this row offering a lab technician four
/// shortcuts that all landed on the refusal screen, which is worse than
/// offering none: it teaches a clinician that the app's own shortcuts cannot
/// be trusted.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(() {
          // Read reactively: a cold start paints from the stored map and
          // `/auth/me` lands a moment later, so a row resolved once would show
          // the first frame's shortcuts for the rest of the session.
          final actions = ShiftBoard.actionsFor(AccessService.to.rx.value);
          if (actions.isEmpty) return const SizedBox.shrink();

          return _padded(
            Column(
              key: ShiftKeys.quickActions,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Quick actions'),
                IntrinsicHeight(
                  // IntrinsicHeight, not `CrossAxisAlignment.stretch` alone: a
                  // stretched Row inside a sliver is laid out at infinite
                  // height and asserts.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0;
                          i < ShiftBoard.quickActionSlots;
                          i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          // An empty slot keeps a short row the same shape as
                          // a full one. An account with one permitted action
                          // would otherwise get a single tile stretched across
                          // the whole width with its icon adrift in the middle
                          // of it, which reads as a layout that broke rather
                          // than a row with less in it.
                          child: i < actions.length
                              ? QuickActionTile(
                                  key: ShiftKeys.quickAction(actions[i].id),
                                  icon: actions[i].icon,
                                  label: actions[i].label,
                                  onTap: () => Get.toNamed<void>(
                                    actions[i].route,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      );
}

// ── The bands ───────────────────────────────────────────────────────────────

/// What this account is on shift to do, at most four bands of it.
class _Bands extends StatelessWidget {
  const _Bands({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(() {
          final sections = board.sections;
          if (sections.isEmpty) return const SizedBox.shrink();

          return _padded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: BentoSpace.section),
                  // Each band owns its own `Obx`, inside `ShiftBandCard`. The
                  // one here tracks which bands exist, not what is in them.
                  ShiftBandCard(
                    controller: board,
                    section: sections[i],
                  ),
                ],
              ],
            ),
          );
        }),
      );
}

// ── Upcoming ────────────────────────────────────────────────────────────────

/// What is still booked today, from the same payload as the figures.
class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(() {
          final rows = board.upcomingAppointments;
          if (rows.isEmpty) return const SizedBox.shrink();
          if (!AccessService.to.canRead(Modules.appointments)) {
            return const SizedBox.shrink();
          }

          return _padded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Next in clinic',
                  actionLabel: 'All',
                  onAction: () =>
                      Get.toNamed<void>(AppointmentRoutes.board),
                ),
                BentoCard(
                  key: ShiftKeys.upcoming,
                  padding: const EdgeInsets.symmetric(
                    vertical: BentoSpace.listCardPad,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          const Hairline(indent: BentoSpace.listPad),
                        _AppointmentRow(appointment: rows[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      );
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment});

  final UpcomingAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final patient = appointment.patient;

    return BentoRow(
      key: ShiftKeys.appointment(appointment.id),
      title: patient.displayName,
      subtitle: patient.mrn.isEmpty ? null : 'MRN ${patient.mrn}',
      showChevron: false,
      // The time, not an icon. A clinic list is read down its time column.
      leading: SizedBox(
        width: 52,
        child: Text(
          Formatters.clockTime(appointment.appointmentTime),
          style: AppFonts.numeric(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: labelColor(context),
            height: 1.0,
          ),
        ),
      ),
      trailing: StatusPill(status: appointment.status, compact: true),
      onTap: () =>
          Get.toNamed<void>(AppointmentRoutes.detailFor(appointment.id)),
    );
  }
}

// ── Recently registered ─────────────────────────────────────────────────────

class _RecentPatients extends StatelessWidget {
  const _RecentPatients({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(() {
          final patients = board.recentPatients;
          if (patients.isEmpty) return const SizedBox.shrink();

          final canOpen = AccessService.to.canRead(Modules.patients);

          return _padded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Recently registered',
                  actionLabel: board.hasMorePatients
                      ? (board.showAllPatients ? 'Show less' : 'Show all')
                      : null,
                  onAction: board.hasMorePatients
                      ? board.toggleShowAllPatients
                      : null,
                ),
                BentoCard(
                  key: ShiftKeys.recentPatients,
                  padding: const EdgeInsets.symmetric(
                    vertical: BentoSpace.listCardPad,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < patients.length; i++) ...[
                        if (i > 0)
                          const Hairline(indent: BentoSpace.listPad),
                        _PatientRow(
                          patient: patients[i],
                          canOpen: canOpen,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      );
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.canOpen});

  final RecentPatient patient;

  /// Whether this account may open the record. The row still shows — the
  /// payload already carried it — but it does not offer a way into a screen
  /// that would refuse.
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final name = patient.fullName;
    final age = patient.age;
    final facts = [
      if (patient.mrn.isNotEmpty) 'MRN ${patient.mrn}',
      if (age != '—') age,
      if (patient.gender.isNotEmpty) Formatters.label(patient.gender),
    ];

    return BentoRow(
      key: ShiftKeys.patient(patient.id),
      title: name.isEmpty ? 'Unnamed patient' : name,
      subtitle: facts.isEmpty ? null : facts.join(' · '),
      icon: Icons.person_outline_rounded,
      showChevron: canOpen,
      trailing: Text(
        Formatters.relativeDay(patient.createdAt),
        style: Theme.of(context).brightness == Brightness.dark
            ? AppTextStyles.darkCaption1()
            : AppTextStyles.lightCaption1(),
      ),
      // `/patients/record` rather than `/patients/:id`: a parameter registered
      // at that position also matches `search` and `edit`, so the hub would
      // swallow both siblings. The id travels in `Get.arguments`.
      onTap: canOpen
          ? () => Get.toNamed<void>(
                PatientRoutes.hub,
                arguments: {'id': patient.id},
              )
          : null,
    );
  }
}

// ── Nothing at all ──────────────────────────────────────────────────────────

class _BoardEmpty extends StatelessWidget {
  const _BoardEmpty({required this.board});

  final DashboardController board;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Obx(
          () => _padded(
            board.isEmpty
                ? const EmptyState(
                    key: HomeKeys.empty,
                    icon: Icons.monitor_heart_outlined,
                    title: 'Nothing on the board yet',
                    message: 'Once patients are registered and appointments '
                        "booked, today's numbers appear here.",
                  )
                : null,
          ),
        ),
      );
}
