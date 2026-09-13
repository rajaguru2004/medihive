import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/bed_model.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/inpatient_beds_grid_controller.dart';

/// One ward's beds, as a map.
///
/// A grid rather than a list, because a ward *is* a floor plan and the
/// question — where is there a free bed — is a spatial one. Each tile carries
/// its state as a fill, a glyph and a word, so it survives a colour-blind
/// reader and a screen seen from across a corridor.
class InpatientBedsGridView extends GetView<InpatientBedsGridController> {
  const InpatientBedsGridView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PreferredSize because the header's subtitle is reactive and `Obx`
      // is not a `PreferredSizeWidget`. The height is DetailHeader's own.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Obx(
          () => DetailHeader(
            title: 'Bed map',
            subtitle: controller.selectedWard?.name,
            action: CircleIconButton(
              key: InpatientKeys.addBed,
              icon: Icons.add_rounded,
              tooltip: 'Add bed',
              onTap: () => Get.toNamed<void>(
                Routes.INPATIENT_ADD_BED,
                arguments: {'wardId': controller.selectedWardId.value},
              ),
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading && controller.rxFirstLoad.value) {
          return const BentoScreen(
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 4)),
            ],
          );
        }

        final beds = controller.displayed;

        return BentoScreen(
          key: InpatientKeys.beds,
          onRefresh: controller.reload,
          slivers: [
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  message: controller.rxLoadError.value!,
                  onRetry: controller.load,
                ),
              ),

            // ── Ward picker ───────────────────────────────────────────────
            if (controller.activeWards.length > 1)
              BentoSection(
                top: controller.hasLoadError ? 0 : BentoSpace.page,
                bottom: BentoSpace.header,
                child: BentoPicker(
                  label: 'Ward',
                  value: controller.selectedWard?.name,
                  placeholder: 'Choose a ward',
                  onTap: () => _openWardPicker(context, controller),
                ),
              ),

            // ── State counts, doubling as filters ─────────────────────────
            if (controller.beds.isNotEmpty)
              BentoSection(
                top: controller.activeWards.length > 1
                    ? 0
                    : (controller.hasLoadError ? 0 : BentoSpace.page),
                bottom: BentoSpace.header,
                child: _StateFilters(controller: controller),
              ),

            // ── The map ───────────────────────────────────────────────────
            if (beds.isEmpty)
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  key: InpatientKeys.bedsEmpty,
                  icon: Icons.bed_outlined,
                  title: controller.stateFilter.value != null
                      ? 'No ${controller.stateFilter.value!.label.toLowerCase()} beds'
                      : controller.selectedWard == null
                          ? 'Choose a ward'
                          : 'No beds in this ward yet',
                  message: controller.stateFilter.value != null
                      ? null
                      : 'Beds added to this ward appear here as a map.',
                  actionLabel: controller.stateFilter.value != null
                      ? 'Show all beds'
                      : 'Add bed',
                  onAction: controller.stateFilter.value != null
                      ? () => controller.filterByState(null)
                      : () => Get.toNamed<void>(
                            Routes.INPATIENT_ADD_BED,
                            arguments: {
                              'wardId': controller.selectedWardId.value,
                            },
                          ),
                ),
              )
            else
              BentoSection(
                child: BedGrid(
                  key: InpatientKeys.bedGrid,
                  tiles: [
                    for (final bed in beds)
                      BedTile(
                        key: InpatientKeys.bed(bed.id),
                        number: bed.bedNumber,
                        state: BedState.resolve(bed.status),
                        occupant: controller.showNames
                            ? controller.occupantOf(bed)?.patient.fullName
                            : null,
                        onTap: () => _openBedSheet(context, bed, controller),
                      ),
                  ],
                ),
              ),

            if (beds.isNotEmpty)
              const BentoSection(
                child: Padding(
                  key: InpatientKeys.bedLegend,
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: _BedLegend(),
                ),
              ),
          ],
        );
      }),
    );
  }
}

// ── Filters ─────────────────────────────────────────────────────────────────

/// The four bed states as counts that are also filters.
///
/// A count somebody wants to act on should be the thing they tap. Two separate
/// controls — a stat row and a filter row saying the same four words — is the
/// version of this screen that was there before.
class _StateFilters extends StatelessWidget {
  const _StateFilters({required this.controller});

  final InpatientBedsGridController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < BedState.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _StateChip(
              state: BedState.values[i],
              count: controller.countOf(BedState.values[i]),
              selected: controller.stateFilter.value == BedState.values[i],
              onTap: () => controller.filterByState(BedState.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.state,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final BedState state;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = state.color;
    final ink = semanticInk(context, tint);

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BentoRadius.control),
        child: AnimatedContainer(
          duration: motionDuration(context),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: selected ? 0.2 : 0.09),
            borderRadius: BorderRadius.circular(BentoRadius.control),
            border: Border.all(
              color: tint.withValues(alpha: selected ? 0.7 : 0.24),
              // A selected chip gains a heavier edge as well as a stronger
              // fill, so selection survives on a screen nobody can see colour
              // on.
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: AppFonts.numeric(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.text(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BedLegend extends StatelessWidget {
  const _BedLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final state in BedState.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(state.icon, size: 13, color: semanticInk(context, state.color)),
              const SizedBox(width: 5),
              Text(
                state.label,
                style: AppFonts.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryLabelColor(context),
                  height: 1.0,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Sheets ──────────────────────────────────────────────────────────────────

Future<void> _openWardPicker(
  BuildContext context,
  InpatientBedsGridController controller,
) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Ward',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ward in controller.activeWards)
            SheetRow(
              icon: Icons.meeting_room_outlined,
              label: ward.name,
              sublabel: '${ward.availableBeds} free of ${ward.capacity}',
              selected: ward.id == controller.selectedWardId.value,
              onTap: () {
                Get.back<void>();
                controller.selectWard(ward.id);
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openBedSheet(
  BuildContext context,
  BedModel bed,
  InpatientBedsGridController controller,
) {
  final state = BedState.resolve(bed.status);
  final occupant = controller.occupantOf(bed);

  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Bed ${bed.bedNumber}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (occupant != null) ...[
            PatientIdentityBand(
              name: controller.showNames
                  ? occupant.patient.fullName
                  : 'Occupied',
              mrn: controller.showNames ? occupant.patient.mrn : null,
              sex: controller.showNames ? occupant.patient.gender : null,
              extra: 'Day ${Formatters.lengthOfStayDays(occupant.admissionDate) + 1}'
                  ' · admitted ${Formatters.dateMedium(occupant.admissionDate)}',
            ),
            if (occupant.admissionReason.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              FactRow(label: 'Reason', value: occupant.admissionReason),
            ],
            const SizedBox(height: BentoSpace.section),
            SheetRow(
              icon: Icons.logout_rounded,
              label: 'Discharge',
              sublabel: 'Frees this bed',
              onTap: () {
                Get.back<void>();
                Get.toNamed<void>(
                  Routes.DISCHARGE_PATIENT,
                  arguments: {'admissionId': occupant.id},
                );
              },
            ),
          ] else ...[
            FactRow(label: 'State', value: state.label),
            if (bed.type.trim().isNotEmpty)
              FactRow(label: 'Type', value: bed.type),
            const SizedBox(height: BentoSpace.section),
            if (state == BedState.vacant)
              SheetRow(
                icon: Icons.local_hotel_outlined,
                label: 'Admit a patient here',
                onTap: () {
                  Get.back<void>();
                  Get.toNamed<void>(
                    Routes.INPATIENT_ADMIT,
                    arguments: {
                      'bedId': bed.id,
                      'wardId': controller.selectedWardId.value,
                    },
                  );
                },
              ),
            // Only the states this bed can actually move to. Offering
            // "occupied" as a manual state is how a bed ends up marked full
            // with nobody in it.
            for (final next in const [
              BedState.vacant,
              BedState.reserved,
              BedState.blocked,
            ])
              if (next != state)
                SheetRow(
                  icon: next.icon,
                  label: 'Mark ${next.label.toLowerCase()}',
                  onTap: () {
                    Get.back<void>();
                    controller.setBedState(bed, next);
                  },
                ),
          ],
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
