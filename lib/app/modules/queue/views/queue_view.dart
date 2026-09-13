import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/queue_item.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/queue_controller.dart';

/// The queue board.
///
/// Rows are ordered by acuity then arrival, and the ordering is visible: the
/// position number is a figure, the acuity carries its rank, and a wait past
/// the site's threshold turns. Everything else on the row is subordinate to
/// those three facts.
class QueueView extends GetView<QueueController> {
  const QueueView({super.key, this.embedded = true});

  /// False when pushed as its own route rather than shown inside the shell.
  ///
  /// The difference is the header, nothing else — a screen that renders
  /// differently depending on where it is mounted is two screens pretending to
  /// be one.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      if (controller.isLoading && controller.rxFirstLoad.value) {
        return const _QueueSkeleton();
      }

      final rows = controller.displayed;

      return BentoScreen(
        key: QueueKeys.screen,
        onRefresh: controller.reload,
        bottomClearance: false,
        slivers: [
          if (controller.hasLoadError)
            BentoSection(
              top: BentoSpace.page,
              child: ErrorRetryBanner(
                key: QueueKeys.error,
                message: controller.rxLoadError.value!,
                onRetry: controller.load,
              ),
            ),

          // ── Board state ─────────────────────────────────────────────────
          BentoSection(
            top: controller.hasLoadError ? 0 : BentoSpace.page,
            bottom: BentoSpace.header,
            child: _BoardSummary(controller: controller),
          ),

          // ── Filters ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _Filters(controller: controller),
          ),

          // ── Rows ────────────────────────────────────────────────────────
          if (rows.isEmpty)
            BentoSection(
              top: BentoSpace.section,
              child: EmptyState(
                key: QueueKeys.empty,
                icon: controller.board.value == QueueBoard.live
                    ? Icons.groups_outlined
                    : Icons.history_rounded,
                title: controller.isFiltered
                    ? 'Nothing matches those filters'
                    : controller.board.value == QueueBoard.live
                        ? 'Nobody is waiting'
                        : 'Nobody has been seen yet today',
                message: controller.isFiltered
                    ? null
                    : controller.board.value == QueueBoard.live
                        ? 'Patients added to the queue appear here, most '
                            'urgent first.'
                        : null,
                actionLabel:
                    controller.isFiltered ? 'Clear filters' : 'Add to queue',
                onAction: controller.isFiltered
                    ? controller.clearFilters
                    : () => Get.toNamed<void>(Routes.ADD_TO_QUEUE),
              ),
            )
          else
            BentoSection(
              top: BentoSpace.header,
              child: BentoCard(
                key: QueueKeys.list,
                padding: const EdgeInsets.symmetric(
                  vertical: BentoSpace.listCardPad,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Hairline(indent: BentoSpace.listPad),
                      _QueueRow(
                        key: QueueKeys.row(rows[i].id),
                        item: rows[i],
                        position: i + 1,
                        controller: controller,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── Legend ──────────────────────────────────────────────────────
          // Once, under the board. A board that uses colour to carry rank owes
          // the reader its key exactly once, and below is where a key belongs.
          if (rows.isNotEmpty)
            const BentoSection(
              child: Padding(
                key: QueueKeys.legend,
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: AcuityLegend(),
              ),
            ),
        ],
      );
    });

    if (embedded) return body;

    return Scaffold(
      appBar: DetailHeader(
        title: 'Queue',
        action: CircleIconButton(
          key: QueueKeys.addButton,
          icon: Icons.person_add_alt_1_outlined,
          tooltip: 'Add to queue',
          onTap: () => Get.toNamed<void>(Routes.ADD_TO_QUEUE),
        ),
      ),
      body: body,
    );
  }
}

// ── Board summary ───────────────────────────────────────────────────────────

/// What the floor looks like, and the one action worth a button.
class _BoardSummary extends StatelessWidget {
  const _BoardSummary({required this.controller});

  final QueueController controller;

  @override
  Widget build(BuildContext context) {
    final breached = controller.breachedCount;

    return BentoCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VitalsGrid(
            columns: 3,
            tiles: [
              VitalTile(
                label: 'Waiting',
                value: '${controller.waitingCount}',
                tone: breached > 0 ? AppColors.acuityUrgent : null,
                caption: breached > 0
                    ? '$breached over ${controller.breachMinutes}m'
                    : null,
              ),
              VitalTile(
                label: 'Called',
                value: '${controller.calledCount}',
              ),
              VitalTile(
                label: 'In service',
                value: '${controller.inServiceCount}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          SecondaryBar(
            key: QueueKeys.callNext,
            label: 'Call next',
            icon: Icons.campaign_outlined,
            onPressed: controller.waitingCount == 0 ? null : controller.callNext,
          ),
        ],
      ),
    );
  }
}

// ── Filters ─────────────────────────────────────────────────────────────────

class _Filters extends StatelessWidget {
  const _Filters({required this.controller});

  final QueueController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: QueueKeys.filters,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live / History. A segmented control rather than two chips: these are
        // two views of one board, not two filters that could both be off.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BentoSpace.page),
          child: BentoSegmented<QueueBoard>(
            options: const [QueueBoard.live, QueueBoard.history],
            selected: controller.board.value,
            labelOf: (board) =>
                board == QueueBoard.live ? 'On the floor' : 'Seen today',
            onSelected: controller.showBoard,
          ),
        ),
        const SizedBox(height: 12),
        FilterChips<String>(
          options: controller.acuities,
          selected: controller.acuity.value,
          labelOf: CaseStatus.labelOf,
          keyOf: (value) => QueueKeys.filter(value),
          onSelected: controller.filterByAcuity,
        ),
        if (controller.serviceAreas.length > 2) ...[
          const SizedBox(height: 8),
          FilterChips<String>(
            options: controller.serviceAreas,
            selected: controller.serviceArea.value,
            labelOf: (area) => area,
            onSelected: controller.filterByArea,
          ),
        ],
      ],
    );
  }
}

// ── Row ─────────────────────────────────────────────────────────────────────

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.item,
    required this.position,
    required this.controller,
  });

  final QueueItem item;
  final int position;
  final QueueController controller;

  @override
  Widget build(BuildContext context) {
    final isLive = controller.board.value == QueueBoard.live;
    final where = [
      if (item.serviceArea.trim().isNotEmpty) item.serviceArea,
      if (item.assignedRoom?.trim().isNotEmpty ?? false) item.assignedRoom!,
      if (item.queueNumber.trim().isNotEmpty) '#${item.queueNumber}',
    ].join(' · ');

    return QueueTicketRow(
      position: position,
      name: item.patient.fullName.isEmpty
          ? 'Patient ${item.patient.mrn}'
          : item.patient.fullName,
      subtitle: where.isEmpty ? null : where,
      acuityCode: item.priority,
      // Only on the live board. A wait chip in the history is a stopwatch on
      // something that already finished.
      waited: isLive ? controller.waitedBy(item) : null,
      breachMinutes: controller.breachMinutes,
      trailing: isLive
          ? CircleIconButton(
              key: QueueKeys.advance(item.id),
              icon: Icons.more_horiz_rounded,
              tooltip: 'Actions',
              onTap: () => _openActions(context, item, controller),
            )
          : StatusPill(status: item.status, compact: true),
      onTap: isLive ? () => _openActions(context, item, controller) : null,
    );
  }
}

/// What can be done to one person in the queue.
///
/// A sheet rather than a row of icon buttons: there are five actions, one is
/// destructive, and five targets at the 48 dp minimum leave nothing of a phone
/// row for the name. The sheet also gets to say the patient's name at the top,
/// which is the check somebody makes before calling the wrong person.
Future<void> _openActions(
  BuildContext context,
  QueueItem item,
  QueueController controller,
) {
  final name = item.patient.fullName.isEmpty
      ? 'Patient ${item.patient.mrn}'
      : item.patient.fullName;
  final status = item.status.trim().toLowerCase();

  return Get.bottomSheet<void>(
    SheetShell(
      title: name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PatientIdentityBand(
            name: name,
            mrn: item.patient.mrn,
            sex: item.patient.gender,
            acuityCode: item.priority,
            extra: 'Waiting ${Formatters.elapsed(item.joinedQueueAt)}',
          ),
          const SizedBox(height: BentoSpace.section),
          if (status == 'waiting')
            SheetRow(
              icon: Icons.campaign_outlined,
              label: 'Call',
              sublabel: 'Announce and mark as called',
              onTap: () {
                Get.back<void>();
                controller.setStatus(item, 'called');
              },
            ),
          if (status == 'waiting' || status == 'called')
            SheetRow(
              icon: Icons.play_arrow_rounded,
              label: 'Start',
              sublabel: 'Mark as in service',
              onTap: () {
                Get.back<void>();
                controller.setStatus(item, 'in_service');
              },
            ),
          if (status == 'in_service' || status == 'called')
            SheetRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Complete',
              sublabel: 'Seen and finished',
              onTap: () {
                Get.back<void>();
                controller.setStatus(item, 'completed');
              },
            ),
          if (status == 'called')
            SheetRow(
              icon: Icons.person_off_outlined,
              label: 'No show',
              sublabel: 'Called, did not attend',
              onTap: () {
                Get.back<void>();
                controller.setStatus(item, 'no_show');
              },
            ),
          const Hairline(),
          SheetRow(
            icon: Icons.remove_circle_outline_rounded,
            label: 'Remove from queue',
            destructive: true,
            onTap: () async {
              Get.back<void>();
              final confirmed = await ConfirmDialog.show(
                context,
                title: 'Remove $name?',
                message: 'They come off the queue entirely. If they are still '
                    'here, they will need to be added again.',
                confirmLabel: 'Remove',
                destructive: true,
              );
              if (confirmed) await controller.removeFromQueue(item);
            },
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

// ── Loading ─────────────────────────────────────────────────────────────────

class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

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
