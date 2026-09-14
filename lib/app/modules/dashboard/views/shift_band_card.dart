import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/shift_keys.dart';
import '../../../theme/theme.dart';
import '../../billing/billing_status.dart';
import '../../laboratory/lab_status.dart';
import '../../pharmacy/views/pharmacy_view.dart' show prescriptionTone;
import '../../radiology/views/radiology_shared.dart'
    show radiologyStatusColor, radiologyStatusLabel;
import '../controllers/dashboard_controller.dart';
import '../shift_board.dart';
import '../shift_sections.dart';

/// One band of the shift board.
///
/// Its own load state, and its own `Obx`, because the bands fail separately: a
/// laboratory outage must not blank a nurse's bed counts, and a board where one
/// failure takes the other three down is a board nobody trusts after the first
/// time it happens.
///
/// The `Obx` is here rather than around the list of bands for the reason the
/// rest of this app keeps repeating: a widget constructed inside an `Obx`
/// closure is **not** inside its reactive scope. The closure only builds the
/// widget object; Flutter calls `build` on it later, outside the proxy that
/// records reads. A band that updated while its neighbours did not would never
/// repaint.
class ShiftBandCard extends StatelessWidget {
  const ShiftBandCard({
    super.key,
    required this.controller,
    required this.section,
  });

  final DashboardController controller;
  final ShiftSection section;

  @override
  Widget build(BuildContext context) => Obx(
        () => _card(context, controller.bandOf(section.id).value),
      );

  Widget _card(BuildContext context, ShiftBand band) {
    return KeyedSubtree(
      key: ShiftKeys.band(section.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: section.title,
            // The count travels on the way in, so the header answers "how
            // much" and the rows answer "who". `50+` when the band stopped
            // counting — a floor drawn as a total is a board under-reporting
            // its own workload.
            actionLabel: _headerLabel(band),
            onAction: () => Get.toNamed<void>(section.route),
          ),
          if (band.isLoading)
            const BentoSkeleton(rows: 2, hasHeader: false)
          else
            BentoCard(
              padding: const EdgeInsets.symmetric(
                vertical: BentoSpace.listCardPad,
              ),
              child: _body(context, band),
            ),
        ],
      ),
    );
  }

  String _headerLabel(ShiftBand band) {
    if (band.phase != ShiftBandPhase.ready) return 'Open';
    return band.total > band.rows.length ? 'All ${band.countLabel}' : 'Open';
  }

  Widget _body(BuildContext context, ShiftBand band) => switch (band.phase) {
        // Handled above: a skeleton inside a card would be a card inside a
        // card.
        ShiftBandPhase.loading => const SizedBox.shrink(),
        ShiftBandPhase.locked => _locked(),
        ShiftBandPhase.empty => _empty(),
        ShiftBandPhase.failed => _failed(band),
        ShiftBandPhase.ready => _rows(context, band),
      };

  /// Nothing is broken, so nothing here is red and nothing offers a retry.
  Widget _locked() => EmptyState(
        key: ShiftKeys.bandLocked(section.id),
        compact: true,
        icon: Icons.lock_outline_rounded,
        title: 'Not available to your role',
        message: 'Ask an administrator if you need to see this.',
      );

  /// An empty band is information. "Nobody is waiting" is a good shift; a
  /// blank space is a bug.
  Widget _empty() => EmptyState(
        key: ShiftKeys.bandEmpty(section.id),
        compact: true,
        icon: _icon,
        title: section.emptyMessage,
      );

  /// Inline and persistent, with whatever the band was already showing kept
  /// under it. A toast would take the retry with it in three seconds and leave
  /// an empty card that reads as "there is nobody waiting".
  Widget _failed(ShiftBand band) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BentoSpace.listPad),
            child: ErrorRetryBanner(
              key: ShiftKeys.bandError(section.id),
              title: "Couldn't load this",
              message: band.error ?? "That didn't load.",
              margin: EdgeInsets.zero,
              onRetry: () => controller.retryBand(section.id),
            ),
          ),
          if (band.hasRows) ...[
            const SizedBox(height: 10),
            _list(band),
          ],
        ],
      );

  Widget _rows(BuildContext context, ShiftBand band) => _list(band);

  Widget _list(ShiftBand band) => Column(
        children: [
          for (var i = 0; i < band.rows.length; i++) ...[
            if (i > 0) const Hairline(indent: BentoSpace.listPad),
            _row(band.rows[i]),
          ],
        ],
      );

  Widget _row(ShiftRow row) => BentoRow(
        key: ShiftKeys.bandRow(section.id, row.id),
        title: row.title,
        subtitle: row.subtitle,
        leading: row.lead == null ? null : _Lead(text: row.lead!),
        showChevron: false,
        trailing: _Trailing(row: row, bandId: section.id),
        onTap: row.route == null
            ? null
            : () => Get.toNamed<void>(row.route!, arguments: row.arguments),
      );

  IconData get _icon => switch (section.id) {
        ShiftBandId.waiting => Icons.groups_outlined,
        ShiftBandId.screenings => Icons.assignment_turned_in_outlined,
        ShiftBandId.clinic => Icons.event_available_outlined,
        ShiftBandId.ward => Icons.local_hotel_outlined,
        ShiftBandId.lab => Icons.science_outlined,
        ShiftBandId.imaging => Icons.monitor_heart_outlined,
        ShiftBandId.dispense => Icons.medication_outlined,
        ShiftBandId.unpaid => Icons.receipt_long_outlined,
        _ => Icons.check_circle_outline_rounded,
      };
}

/// The first column: a queue number, a clock time, a bed, an order number.
///
/// Tabular and fixed-width, so a column of them lines up and does not shiver
/// as the board refreshes.
class _Lead extends StatelessWidget {
  const _Lead({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        // Shrinks rather than elides. An order number read back over the
        // phone has to be the one stored against the record, character for
        // character — and `LAB-2026-0…` is not.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            text,
            maxLines: 1,
            style: AppFonts.numeric(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: labelColor(context),
              height: 1.1,
            ),
          ),
        ),
      );
}

/// The right of a row: its figure and its state, in that order.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.row, required this.bandId});

  final ShiftRow row;
  final String bandId;

  @override
  Widget build(BuildContext context) {
    final state = row.status == null ? null : _statusOf(bandId, row.status!);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (row.trailing != null) ...[
          // Shrinks, never elides. `16…` could be 160 or 168, and this is a
          // wait, a length of stay or an amount somebody acts on. A row at the
          // 1.3 text scale a ward tablet is usually left at is where the
          // difference shows.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                row.trailing!,
                maxLines: 1,
                style: numeralStyle(context, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (row.critical)
          // The one thing on a band allowed to be red: a result flagged
          // critical that nobody has signed off. It says the word too.
          const StatusPill(
            status: 'critical',
            label: 'Critical',
            compact: true,
          )
        else if (state != null)
          StatusPill(
            status: row.status!,
            label: state.label,
            color: state.color,
            compact: true,
          ),
      ],
    );
  }

  /// Each band's state through the vocabulary that owns it.
  ///
  /// `CaseStatus` answers for the clinical bands and for nothing else: a lab
  /// order's `in_progress` is where a tube has got to, an invoice's `overdue`
  /// is a money state, and both land on the ramp's grey fallback — which is
  /// how a whole band ends up one colour.
  static ({String label, Color color}) _statusOf(String band, String raw) =>
      switch (band) {
        ShiftBandId.lab => (
            label: LabOrderStatus.labelOf(raw),
            color: LabOrderStatus.colorOf(raw),
          ),
        ShiftBandId.imaging => (
            label: radiologyStatusLabel(raw),
            color: radiologyStatusColor(raw),
          ),
        ShiftBandId.dispense => (
            label: CaseStatus.labelOf(raw),
            color: prescriptionTone(raw),
          ),
        ShiftBandId.unpaid => (
            label: InvoiceStatus.labelOf(raw),
            color: InvoiceStatus.colorOf(raw),
          ),
        _ => (label: CaseStatus.labelOf(raw), color: CaseStatus.colorOf(raw)),
      };
}
