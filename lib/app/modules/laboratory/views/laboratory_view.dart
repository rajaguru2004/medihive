import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/laboratory_keys.dart';
import '../../../core/window_class.dart';
import '../../../data/models/lab_order.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/laboratory_controller.dart';
import '../lab_status.dart';
import '../laboratory_routes.dart';
import 'lab_order_pane.dart';

/// The laboratory worklist.
///
/// What the bench works from: every open order, STAT at the top, with the six
/// figures that say how much of each kind of work is waiting.
class LaboratoryView extends GetView<LaboratoryController> {
  const LaboratoryView({super.key, this.embedded = true});

  /// True inside the shell's tab stack, false when this screen was pushed.
  ///
  /// The difference is the header and the ground, nothing else. The shell
  /// draws both for a tab, and the two actions the pushed header carries have
  /// their own place in the body — `New order` as a bar, the catalogue on the
  /// figure that counts it — so neither is lost when the header is.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`. A `GetView` whose build never touches
    // `controller` never constructs the lazyPut one, and nothing ever loads.
    final lab = controller;
    final window = WindowClass.of(context);

    final panes = Obx(
          () => ListDetailScaffold(
            listPaneKey: LaboratoryKeys.listPane,
            detailPaneKey: LaboratoryKeys.detailPane,
            selectedId: lab.selectedId.value,
            placeholder: const EmptyState(
              icon: Icons.science_outlined,
              title: 'No order chosen',
              message: 'Pick an order on the left to see what it is for.',
            ),
            detailBuilder: (context, id) {
              final order = lab.items.firstWhereOrNull((o) => o.id == id);
              return order == null
                  ? const EmptyState(
                      icon: Icons.science_outlined,
                      title: 'That order is no longer on this page',
                    )
                  : LabOrderPane(order: order);
            },
            list: _worklist(context, lab, window),
          ),
        );

    if (embedded) {
      return KeyedSubtree(key: LaboratoryKeys.screen, child: panes);
    }

    return Scaffold(
      key: LaboratoryKeys.screen,
      appBar: DetailHeader(
        title: 'Laboratory',
        subtitle: 'Orders, samples and results',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleIconButton(
              key: LaboratoryKeys.openCatalog,
              icon: Icons.menu_book_outlined,
              tooltip: 'Test catalogue',
              onTap: () => Get.toNamed<void>(LabRoutes.catalog),
            ),
            // Absent, not disabled, for an account that may not raise one.
            if (lab.canCreate)
              CircleIconButton(
                key: LaboratoryKeys.createOrder,
                icon: Icons.add_rounded,
                tooltip: 'New lab order',
                onTap: () => Get.toNamed<void>(LabRoutes.orderNew),
              ),
          ],
        ),
      ),
      // The ground is painted once, around both panes. Each pane painting its
      // own would put two washes side by side and a visible seam down the
      // divider between them.
      body: BentoGround(child: panes),
    );
  }

  Widget _worklist(
    BuildContext context,
    LaboratoryController lab,
    WindowClass window,
  ) {
    final rows = lab.visible;

    return BentoScreen(
      onRefresh: lab.reloadAll,
      // Pushed, under a DetailHeader, with no tab bar anywhere beneath it.
      bottomClearance: false,
      // The screen paints the ground once, outside both panes.
      ground: false,
      slivers: [
        if (lab.hasStats.value)
          BentoSection(
            top: BentoSpace.page,
            bottom: BentoSpace.header,
            child: _figures(lab),
          ),
        BentoSection(
          top: lab.hasStats.value ? 0 : BentoSpace.page,
          bottom: BentoSpace.header,
          child: SearchField(
            fieldKey: LaboratoryKeys.search,
            // Short enough for the list pane on a tablet, which is half the
            // width the phone gives it.
            hint: 'Order, accession or patient',
            initial: lab.query.value,
            onChanged: lab.search,
          ),
        ),
        SliverToBoxAdapter(
          child: FilterChips<String>(
            key: LaboratoryKeys.statusFilters,
            options: LaboratoryController.statusOptions,
            selected: lab.statusFilter,
            labelOf: LaboratoryController.statusChipLabel,
            keyOf: (status) => LaboratoryKeys.filterOption('status', status),
            onSelected: lab.filterByStatus,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: FilterChips<String>(
            key: LaboratoryKeys.priorityFilters,
            options: LaboratoryController.priorityOptions,
            selected: lab.priorityFilter,
            labelOf: LaboratoryController.priorityChipLabel,
            keyOf: (priority) =>
                LaboratoryKeys.filterOption('priority', priority),
            onSelected: lab.filterByPriority,
          ),
        ),
        // The action the shell's header has nowhere to put. Absent rather
        // than disabled when this account may not raise an order: a greyed
        // control is a promise the server is going to refuse. Only when
        // embedded — the pushed screen carries it in its own header, and two
        // copies under one key is a test that cannot say which it tapped.
        if (embedded && lab.canCreate)
          BentoSection(
            top: BentoSpace.header,
            bottom: 0,
            child: PrimaryBar(
              key: LaboratoryKeys.createOrder,
              label: 'New order',
              icon: Icons.add_rounded,
              onPressed: () => Get.toNamed<void>(LabRoutes.orderNew),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: BentoSpace.header)),
        InfiniteList(
          key: LaboratoryKeys.list,
          phase: lab.phase.value,
          itemCount: rows.length,
          hasMore: lab.hasMore,
          loadingMore: lab.loadingMore.value,
          onLoadMore: lab.loadMore,
          error: lab.errorMessage.value,
          onRetry: lab.reload,
          empty: _empty(lab),
          separator: const Hairline(indent: BentoSpace.listPad),
          itemBuilder: (context, index) => _row(lab, rows[index], window),
        ),
      ],
    );
  }

  Widget _figures(LaboratoryController lab) {
    final stats = lab.stats.value;
    return FigureGrid(
      key: LaboratoryKeys.stats,
      figures: [
        Figure(
          label: 'Pending',
          value: '${stats.pending}',
          icon: Icons.schedule_rounded,
          onTap: () => lab.filterByStatus(LabOrderStatus.pending),
        ),
        Figure(
          label: 'Samples in',
          value: '${stats.sampleCollected}',
          icon: Icons.science_outlined,
          onTap: () => lab.filterByStatus(LabOrderStatus.sampleCollected),
        ),
        Figure(
          label: 'On the bench',
          value: '${stats.inProgress}',
          icon: Icons.biotech_outlined,
          onTap: () => lab.filterByStatus(LabOrderStatus.inProgress),
        ),
        Figure(
          label: 'Done today',
          value: '${stats.completedToday}',
          icon: Icons.check_circle_outline_rounded,
          onTap: () => lab.filterByStatus(LabOrderStatus.completed),
        ),
        Figure(
          // Red only when there is one. A zero painted in the app's one alarm
          // colour is a false alarm, and a board that cries wolf in the corner
          // it reserves for wolves stops being read.
          label: 'Critical',
          value: '${stats.criticalResults}',
          icon: Icons.priority_high_rounded,
          color: stats.criticalResults > 0 ? AppColors.acuityCritical : null,
        ),
        Figure(
          label: 'Catalogue',
          value: '${stats.totalTests}',
          icon: Icons.menu_book_outlined,
          onTap: () => Get.toNamed<void>(LabRoutes.catalog),
        ),
      ],
    );
  }

  Widget _empty(LaboratoryController lab) {
    if (lab.isFiltered) {
      return EmptyState(
        key: LaboratoryKeys.empty,
        icon: Icons.filter_list_off_rounded,
        title: 'Nothing matches',
        message: 'No order on this worklist matches what you asked for.',
        actionLabel: 'Clear filters',
        actionKey: LaboratoryKeys.clearFilters,
        onAction: lab.clearFilters,
      );
    }
    return EmptyState(
      key: LaboratoryKeys.empty,
      icon: Icons.science_outlined,
      title: 'No lab work waiting',
      message: 'Orders raised on a consultation or from here appear on this '
          'worklist.',
      actionLabel: lab.canCreate ? 'New order' : null,
      onAction:
          lab.canCreate ? () => Get.toNamed<void>(LabRoutes.orderNew) : null,
    );
  }

  Widget _row(LaboratoryController lab, LabOrder order, WindowClass window) {
    // A result nobody has signed off yet outranks the priority on the second
    // pill: the priority is how fast the bench was asked to work, and this is
    // a number somebody has to be told about now. The order's own rank is not
    // lost — STAT still sorts to the top of the list.
    final critical = order.results.any((r) => r.isCritical && !r.isVerified);

    final facts = <String>[
      if (order.testSummary.isNotEmpty) order.testSummary,
      if ((order.accessionNumber ?? '').isNotEmpty) order.accessionNumber!,
      Formatters.elapsed(order.orderDate),
    ];

    return DocumentRow(
      key: LaboratoryKeys.row(order.id),
      number: order.orderNumber,
      amount: order.tests.length == 1 ? '1 test' : '${order.tests.length} tests',
      title: order.patient.displayName,
      subtitle: facts.join(' · '),
      status: LabOrderStatus.labelOf(order.status),
      statusColor: LabOrderStatus.colorOf(order.status),
      secondaryStatus:
          critical ? 'Critical' : LabPriority.labelOf(order.priority),
      secondaryStatusColor:
          critical ? AppColors.acuityCritical : LabPriority.colorOf(order.priority),
      dimmed: !LabOrderStatus.isOpen(order.status),
      selected: window.isTwoPane && lab.selectedId.value == order.id,
      onTap: () {
        if (window.isTwoPane) {
          lab.select(order.id);
          return;
        }
        Get.toNamed<void>(
          LabRoutes.order(order.id),
          arguments: {'order': order},
        );
      },
    );
  }
}
