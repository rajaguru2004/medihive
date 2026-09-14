import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/laboratory_keys.dart';
import '../../../data/models/lab_order.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../lab_status.dart';
import '../laboratory_routes.dart';

/// One order beside the worklist, on a window wide enough to hold both.
///
/// Read-only on purpose. Collecting a sample, rejecting one and signing a
/// result are each a confirmed write with its own sheet, and duplicating that
/// machinery into a pane is two places for the same action to disagree about
/// what it is allowed to do. The pane answers "which order is this" and hands
/// over to the screen that can act on it.
class LabOrderPane extends StatelessWidget {
  const LabOrderPane({super.key, required this.order});

  final LabOrder order;

  @override
  Widget build(BuildContext context) {
    final critical = order.results.where((r) => r.isCritical).toList();

    return BentoScreen(
      bottomClearance: false,
      ground: false,
      slivers: [
        BentoSection(
          top: BentoSpace.page,
          bottom: BentoSpace.header,
          child: RecordHeader(
            title: order.orderNumber,
            subtitle: Formatters.dateTime(order.orderDate),
            status: LabOrderStatus.labelOf(order.status),
            statusColor: LabOrderStatus.colorOf(order.status),
            secondaryStatus: LabPriority.labelOf(order.priority),
            secondaryStatusColor: LabPriority.colorOf(order.priority),
            actions: [
              RecordAction(
                key: LaboratoryKeys.paneOpen,
                icon: Icons.open_in_full_rounded,
                label: 'Open order',
                onPressed: () => Get.toNamed<void>(
                  LabRoutes.order(order.id),
                  arguments: {'order': order},
                ),
              ),
            ],
          ),
        ),
        if (critical.isNotEmpty)
          BentoSection(
            bottom: BentoSpace.header,
            child: NoticeBanner(
              message: critical.length == 1
                  ? 'Critical result on this order. Somebody has to be told.'
                  : '${critical.length} critical results on this order. '
                      'Somebody has to be told.',
              icon: Icons.priority_high_rounded,
              tint: AppColors.acuityCritical,
            ),
          ),
        BentoSection(
          child: BentoCard(
            padding: const EdgeInsets.symmetric(
              vertical: BentoSpace.listCardPad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactRow(
                  label: 'Patient',
                  value: order.patient.displayName,
                ),
                const Hairline(indent: BentoSpace.listPad),
                FactRow(label: 'MRN', value: order.patient.mrn),
                const Hairline(indent: BentoSpace.listPad),
                FactRow(
                  label: 'Tests',
                  value: order.testSummary.isEmpty ? '—' : order.testSummary,
                  stacked: order.testSummary.length > 28,
                ),
                if ((order.accessionNumber ?? '').isNotEmpty) ...[
                  const Hairline(indent: BentoSpace.listPad),
                  FactRow(label: 'Accession', value: order.accessionNumber!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
