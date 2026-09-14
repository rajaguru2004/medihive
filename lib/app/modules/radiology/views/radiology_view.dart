import 'package:flutter/material.dart';
import 'package:get/get.dart';

// The keys barrel is assembled by another stream; this module's own key file
// is imported directly so the screens compile before it is re-exported.
import '../../../core/keys/radiology_keys.dart';
import '../../../core/window_class.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../theme/theme.dart';
import '../../radiology_order_detail/views/radiology_order_detail_view.dart';
import '../controllers/radiology_controller.dart';
import '../radiology_routes.dart';
import 'radiology_shared.dart';

/// The imaging worklist.
///
/// Read the way a radiographer reads a list at the start of a shift: whether
/// any of it is a patient in trouble, how much work there is, then the studies
/// themselves. The critical-findings banner sits above the figures for that
/// reason — a count of pending studies can wait a second; a read that found
/// something cannot.
class RadiologyView extends GetView<RadiologyController> {
  const RadiologyView({super.key, this.embedded = true});

  /// False when pushed as its own route rather than shown inside the shell.
  ///
  /// The difference is the header, nothing else — a screen that renders
  /// differently depending on where it is mounted is two screens pretending to
  /// be one.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Obx(
      () => ListDetailScaffold(
        listPaneKey: RadiologyKeys.listPane,
        detailPaneKey: RadiologyKeys.detailPane,
        // Only ever set on a window wide enough to show both. On a phone a row
        // pushes the detail, so nothing is "selected" and the pane never
        // exists to be out of step with the screen on top of it.
        selectedId: controller.selectedId.value,
        list: _Worklist(controller: controller),
        placeholder: const EmptyState(
          icon: Icons.monitor_heart_outlined,
          title: 'No study selected',
          message: 'Choose an order on the left to see it here.',
        ),
        detailBuilder: (context, id) =>
            RadiologyOrderDetailView(orderId: id, embedded: true),
      ),
    );

    if (embedded) return body;

    return Scaffold(
      appBar: DetailHeader(
        title: 'Radiology',
        action: CircleIconButton(
          key: RadiologyKeys.openCatalog,
          icon: Icons.list_alt_rounded,
          tooltip: 'Exam catalogue',
          onTap: () => Get.toNamed<void>(RadiologyRoutes.catalog),
        ),
      ),
      body: body,
    );
  }
}

/// The list half: the figures, the filters and the orders.
class _Worklist extends StatelessWidget {
  const _Worklist({required this.controller});

  final RadiologyController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.items;
      final twoPane = WindowClass.of(context).isTwoPane;
      // Read here, inside the observer, and not in the item builder: an
      // `itemBuilder` runs when the sliver lays out, which is outside the
      // `Obx`'s reactive scope, so an observable read there is never
      // subscribed and the row that should look selected never does.
      final selected = controller.selectedId.value;

      return BentoScreen(
        key: RadiologyKeys.screen,
        onRefresh: controller.reloadAll,
        // The shell has already reserved its bar's height, and a pushed copy
        // has no bar under it at all.
        bottomClearance: false,
        // The shell paints the washed ground; a tab painting its own flat one
        // on top of it leaves a seam exactly where the two meet.
        ground: false,
        slivers: [
          // ── A patient in trouble, first ───────────────────────────────
          //
          // Red, and with the figure it counts the only red on this screen: a
          // critical imaging finding is the one thing here that is about a
          // patient deteriorating rather than about throughput. Absent
          // entirely when there are none — an empty red banner reading "0
          // critical findings" is a red that has been taught to mean nothing.
          if (controller.hasCriticalFindings)
            BentoSection(
              top: BentoSpace.page,
              bottom: BentoSpace.header,
              child: NoticeBanner(
                key: RadiologyKeys.critical,
                message: controller.criticalMessage,
                icon: Icons.priority_high_rounded,
                tint: AppColors.acuityCritical,
              ),
            ),

          // ── The department's figures ─────────────────────────────────
          BentoSection(
            top: controller.hasCriticalFindings ? 0 : BentoSpace.page,
            bottom: BentoSpace.header,
            child: _Figures(controller: controller),
          ),

          // ── Narrowing it down ────────────────────────────────────────
          BentoSection(
            bottom: BentoSpace.header,
            child: SearchField(
              fieldKey: RadiologyKeys.search,
              hint: 'Patient, MRN or order number',
              initial: controller.query.value,
              onChanged: controller.search,
            ),
          ),
          SliverToBoxAdapter(
            child: FilterChips<String>(
              key: RadiologyKeys.statusFilters,
              options: const [
                RadiologyController.anyValue,
                ...RadiologyOrderStatus.all,
              ],
              selected: controller.statusFilter.value,
              labelOf: (value) => value == RadiologyController.anyValue
                  ? 'All states'
                  : radiologyStatusLabel(value),
              keyOf: RadiologyKeys.statusFilter,
              onSelected: controller.filterByStatus,
            ),
          ),
          SliverToBoxAdapter(
            child: FilterChips<String>(
              key: RadiologyKeys.urgencyFilters,
              options: const [
                RadiologyController.anyValue,
                ...RadiologyUrgency.all,
              ],
              selected: controller.urgencyFilter.value,
              labelOf: (value) => value == RadiologyController.anyValue
                  ? 'Any urgency'
                  : radiologyUrgencyLabel(value),
              keyOf: RadiologyKeys.urgencyFilter,
              onSelected: controller.filterByUrgency,
            ),
          ),

          // ── The one action worth a button ────────────────────────────
          //
          // Absent rather than disabled when this account may not raise one: a
          // greyed control is a promise the server is going to refuse.
          if (controller.canOrder)
            BentoSection(
              top: BentoSpace.header,
              bottom: 0,
              child: PrimaryBar(
                key: RadiologyKeys.newOrder,
                label: 'New order',
                icon: Icons.add_rounded,
                onPressed: () => Get.toNamed<void>(RadiologyRoutes.orderNew),
              ),
            ),

          BentoSection(
            top: BentoSpace.section,
            bottom: BentoSpace.header,
            child: SectionHeader(
              title: 'Worklist',
              actionLabel: 'Exam catalogue',
              onAction: () => Get.toNamed<void>(RadiologyRoutes.catalog),
            ),
          ),

          // ── The five states ──────────────────────────────────────────
          //
          // Refused and failed are handled here rather than inside
          // `InfiniteList` only so each carries a key: they are the two a flow
          // test has to be able to tell apart from an empty worklist, and from
          // each other.
          if (controller.isForbidden)
            const BentoSection(
              child: EmptyState(
                key: RadiologyKeys.locked,
                icon: Icons.lock_outline_rounded,
                title: 'Imaging is not part of your role',
                // No retry: nothing is broken and a button would fail again.
                // The next step here is a person.
                message: 'An administrator can give your account access to it.',
              ),
            )
          else if (controller.phase.value == ListPhase.error)
            BentoSection(
              child: ErrorRetryBanner(
                key: RadiologyKeys.error,
                message: controller.errorMessage.value ??
                    "Couldn't load the imaging worklist.",
                onRetry: controller.reload,
              ),
            )
          else
            InfiniteList(
              key: RadiologyKeys.list,
              phase: controller.phase.value,
              itemCount: rows.length,
              hasMore: controller.hasMore,
              loadingMore: controller.loadingMore.value,
              onLoadMore: controller.loadMore,
              separator: const Hairline(indent: BentoSpace.listPad),
              skeletonRows: 5,
              empty: _Empty(controller: controller),
              itemBuilder: (context, i) => RadiologyOrderRow(
                key: RadiologyKeys.order(rows[i].id),
                order: rows[i],
                selected: twoPane && selected == rows[i].id,
                onTap: () {
                  // Beside the list when there is room for both, a pushed
                  // screen when there is not. Pushing on a two-pane window
                  // would cover the list the choice was made from.
                  if (twoPane) {
                    controller.select(rows[i].id);
                  } else {
                    Get.toNamed<void>(RadiologyRoutes.orderFor(rows[i].id));
                  }
                },
              ),
            ),
        ],
      );
    });
  }
}

/// Nothing on the worklist — because there is no work, or because the filters
/// hid it. A filtered empty offers the way back rather than the way forward.
class _Empty extends StatelessWidget {
  const _Empty({required this.controller});

  final RadiologyController controller;

  @override
  Widget build(BuildContext context) {
    // Its own observer: this widget is *constructed* inside the worklist's
    // `Obx` but *built* outside it, so anything reactive it reads has to be
    // subscribed here or the empty state never notices a filter change.
    return Obx(() {
      final filtered = controller.isFiltered;

      return EmptyState(
        key: RadiologyKeys.empty,
        icon: filtered
            ? Icons.filter_alt_off_outlined
            : Icons.monitor_heart_outlined,
        title: filtered ? 'Nothing matches those filters' : 'No imaging orders',
        message: filtered
            ? null
            : 'Studies requested from a consultation or from here appear on '
                'this worklist.',
        actionLabel: filtered
            ? 'Clear filters'
            : (controller.canOrder ? 'New order' : null),
        onAction: filtered
            ? controller.clearFilters
            : (controller.canOrder
                ? () => Get.toNamed<void>(RadiologyRoutes.orderNew)
                : null),
      );
    });
  }
}

/// Pending, in progress, done today, and the one figure that is about a
/// patient rather than about throughput.
class _Figures extends StatelessWidget {
  const _Figures({required this.controller});

  final RadiologyController controller;

  @override
  Widget build(BuildContext context) {
    // Its own observer — see `_Empty`. The figures land a round trip after the
    // rows do, so without this they would paint zeroes and stay there.
    return Obx(() {
      final stats = controller.stats.value;
      final critical = stats.criticalFindings;

      return FigureGrid(
        key: RadiologyKeys.stats,
        figures: [
          Figure(
            label: 'Pending',
            value: '${stats.pending}',
            icon: Icons.pending_actions_outlined,
          ),
          Figure(
            label: 'In progress',
            value: '${stats.inProgress}',
            icon: Icons.play_circle_outline_rounded,
            color: AppColors.acuityStandard,
          ),
          Figure(
            label: 'Done today',
            value: '${stats.completedToday}',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.acuityStable,
          ),
          Figure(
            label: 'Critical',
            value: '$critical',
            icon: Icons.priority_high_rounded,
            // Red only when there is one. A permanently red zero is a red that
            // has been taught to mean nothing, and this app has exactly one
            // meaning for red.
            color: critical > 0 ? AppColors.acuityCritical : null,
          ),
        ],
      );
    });
  }
}
