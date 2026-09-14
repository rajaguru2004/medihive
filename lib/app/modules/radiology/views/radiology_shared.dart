import 'package:flutter/material.dart';

import '../../../data/models/radiology_order.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';

/// How imaging's own vocabularies are shown, in one place.
///
/// Six screens show an order's state and its urgency; three of them show both
/// on one row. A screen resolving either for itself is how two views of one
/// study end up disagreeing about whether it has been read.

/// The colour for an order state.
///
/// [CaseStatus] answers for four of the six. The two it does not know are
/// spelled the way this backend's column spells them: `in_progress` carries an
/// underscore the word ramp has no entry for, and `reported` is imaging's own
/// end state. Bridged here rather than by inventing a parallel ramp — the
/// colours are the same ramp, and a state this app cannot place still lands on
/// [CaseStatus]'s own fallback.
Color radiologyStatusColor(String? status) {
  final raw = (status ?? '').trim().toLowerCase();
  if (raw == RadiologyOrderStatus.inProgress) return AppColors.acuityStandard;
  // Read and signed off. The good end of an imaging pathway, and the same
  // green `completed` gets, because to a ward they mean the same thing.
  if (raw == RadiologyOrderStatus.reported) return AppColors.acuityStable;
  return CaseStatus.colorOf(raw);
}

/// The words for an order state — `in_progress` → `In progress`.
String radiologyStatusLabel(String? status) => CaseStatus.labelOf(status);

/// The colour for an urgency.
///
/// **`stat` is amber, not red.** Red on a board in this app means a patient is
/// deteriorating or a read found something critical; a stat request is a
/// scheduling instruction, and painting it red costs the scan its meaning on
/// every screen that shows both. The ladder still reads as a ladder: slate,
/// blue, amber.
Color radiologyUrgencyColor(String? urgency) =>
    switch ((urgency ?? '').trim().toLowerCase()) {
      RadiologyUrgency.stat => AppColors.acuityUrgent,
      RadiologyUrgency.urgent => AppColors.acuityStandard,
      _ => AppColors.acuityRoutine,
    };

/// The words for an urgency. `stat` is set in capitals because that is how it
/// is said and written on a request card.
String radiologyUrgencyLabel(String? urgency) {
  final raw = (urgency ?? '').trim().toLowerCase();
  return raw == RadiologyUrgency.stat ? 'STAT' : Formatters.label(raw);
}

/// The colour for a report state.
Color radiologyReportStatusColor(String? status) =>
    switch ((status ?? '').trim().toLowerCase()) {
      RadiologyReportStatus.isFinal => AppColors.acuityStable,
      RadiologyReportStatus.amended => AppColors.acuityReview,
      _ => AppColors.acuityRoutine,
    };

/// One order on the worklist.
///
/// Shared with the tablet's list pane, so an order reads the same whether the
/// detail is beside it or a screen away.
class RadiologyOrderRow extends StatelessWidget {
  const RadiologyOrderRow({
    super.key,
    required this.order,
    this.onTap,
    this.selected = false,
  });

  final RadiologyOrder order;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (order.orderNumber.trim().isNotEmpty) order.orderNumber,
      order.examName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    return PersonRow(
      name: order.patient.displayName,
      subtitle: subtitle,
      selected: selected,
      onTap: onTap,
      trailing: RadiologyOrderPills(order: order),
    );
  }
}

/// What state a study is in, what it was asked for, and whether its read found
/// something the ward has to hear about.
///
/// A `Wrap` because all three can be on at once and a fixed row would push the
/// patient's name off its own row — which is the one thing on it that has to
/// stay whole.
class RadiologyOrderPills extends StatelessWidget {
  const RadiologyOrderPills({super.key, required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    final urgency = order.urgency.trim().toLowerCase();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 4,
        runSpacing: 4,
        children: [
          if (order.hasCriticalFindings)
            const StatusPill(
              status: 'critical',
              color: AppColors.acuityCritical,
              label: 'Critical',
              icon: Icons.priority_high_rounded,
              compact: true,
            ),
          // Routine is the resting state; a badge on every ordinary request
          // makes the two that are not ordinary harder to find.
          if (urgency != RadiologyUrgency.routine && urgency.isNotEmpty)
            StatusPill(
              status: urgency,
              color: radiologyUrgencyColor(urgency),
              label: radiologyUrgencyLabel(urgency),
              compact: true,
            ),
          StatusPill(
            status: order.status,
            color: radiologyStatusColor(order.status),
            label: radiologyStatusLabel(order.status),
            compact: true,
          ),
        ],
      ),
    );
  }
}
