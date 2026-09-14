import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/ward_model.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/inpatient_controller.dart';

/// The inpatient estate.
///
/// Capacity first, because the question a bed manager arrives with is "have I
/// got a bed", then the wards themselves as a list that answers "where". The
/// bed map, the admissions list and the ward and bed forms are all pushed from
/// here rather than living in tabs inside it — each is a screen in its own
/// right and each is deep-linkable.
class InpatientView extends GetView<InpatientController> {
  const InpatientView({super.key, this.embedded = true});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      if (controller.isLoading && controller.rxFirstLoad.value) {
        return const _InpatientSkeleton();
      }

      final stats = controller.stats.value;
      final wards = controller.activeWards;

      return BentoScreen(
        key: InpatientKeys.overview,
        onRefresh: controller.reload,
        bottomClearance: false,
        slivers: [
          if (controller.hasLoadError)
            BentoSection(
              top: BentoSpace.page,
              child: ErrorRetryBanner(
                key: InpatientKeys.overviewError,
                message: controller.rxLoadError.value!,
                onRetry: controller.load,
              ),
            ),

          // ── Capacity ────────────────────────────────────────────────────
          BentoSection(
            top: controller.hasLoadError ? 0 : BentoSpace.page,
            child: BentoCard(
              key: InpatientKeys.capacity,
              hero: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTATE CAPACITY',
                    style: AppTextStyles.overline(Theme.of(context).brightness),
                  ),
                  const SizedBox(height: 12),
                  WardCapacityBar(
                    occupied: stats.occupiedBeds,
                    total: stats.totalBeds,
                    blocked: stats.otherBeds,
                  ),
                  const SizedBox(height: 18),
                  const Hairline(),
                  const SizedBox(height: 18),
                  VitalsGrid(
                    columns: 3,
                    tiles: [
                      VitalTile(
                        label: 'Beds free',
                        value: '${stats.availableBeds}',
                        // Amber, not red. A full estate is a capacity fact —
                        // the same class as an overdue invoice or an empty
                        // shelf — and red in this app means a deteriorating
                        // patient or an error. A bed manager reading a red
                        // zero here learns nothing they cannot read from the
                        // number itself, and every red that is not a patient
                        // costs the ward board's own reds their meaning.
                        tone: stats.availableBeds == 0
                            ? AppColors.warning
                            : null,
                      ),
                      VitalTile(
                        label: 'Admitted',
                        value: '${stats.todayAdmissions}',
                      ),
                      VitalTile(
                        label: 'Discharged',
                        value: '${stats.todayDischarges}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Where to go ─────────────────────────────────────────────────
          BentoSection(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: QuickActionTile(
                      icon: Icons.grid_view_rounded,
                      label: 'Bed map',
                      onTap: () =>
                          Get.toNamed<void>(Routes.INPATIENT_BEDS_GRID),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickActionTile(
                      icon: Icons.assignment_ind_outlined,
                      label: 'Admissions',
                      onTap: () =>
                          Get.toNamed<void>(Routes.INPATIENT_ADMISSIONS),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickActionTile(
                      icon: Icons.local_hotel_outlined,
                      label: 'Admit patient',
                      onTap: () => Get.toNamed<void>(Routes.INPATIENT_ADMIT),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Wards ───────────────────────────────────────────────────────
          if (wards.isEmpty)
            BentoSection(
              child: EmptyState(
                key: InpatientKeys.wardsEmpty,
                icon: Icons.meeting_room_outlined,
                title: 'No wards set up yet',
                message: 'A ward holds the beds patients are admitted into. '
                    'Add the first one to start admitting.',
                actionLabel: 'Add ward',
                onAction: () => Get.toNamed<void>(Routes.INPATIENT_ADD_WARD),
              ),
            )
          else
            BentoSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Wards',
                    actionLabel: 'All',
                    onAction: () =>
                        Get.toNamed<void>(Routes.INPATIENT_WARDS),
                  ),
                  BentoCard(
                    key: InpatientKeys.wardsList,
                    padding: const EdgeInsets.symmetric(
                      vertical: BentoSpace.listCardPad,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < wards.length; i++) ...[
                          if (i > 0)
                            const Hairline(indent: BentoSpace.listPad),
                          WardRow(
                            key: InpatientKeys.ward(wards[i].id),
                            ward: wards[i],
                            onTap: () => Get.toNamed<void>(
                              Routes.INPATIENT_BEDS_GRID,
                              arguments: {'wardId': wards[i].id},
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });

    if (embedded) return body;

    return Scaffold(
      appBar: const DetailHeader(title: 'Inpatient'),
      body: body,
    );
  }
}

/// `general` → `General`. One word, so no need for anything cleverer.
String _titleCase(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

/// One ward, with its occupancy as a bar rather than a fraction.
///
/// Shared with the wards screen: a ward reads the same wherever it appears, so
/// a bed manager comparing two screens is comparing the same object.
class WardRow extends StatelessWidget {
  const WardRow({super.key, required this.ward, this.onTap, this.trailing});

  final WardModel ward;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final full = ward.availableBeds <= 0;
    // The type is stored lowercase (`icu`, `general`), and printed raw it
    // reads as "ICU · icu" — a database value sitting next to the code that
    // already says it. Dropped entirely when the code already carries it.
    final type = _titleCase(ward.type);
    final facts = [
      if (ward.code.trim().isNotEmpty) ward.code,
      if (type.isNotEmpty &&
          type.toLowerCase() != ward.code.trim().toLowerCase())
        type,
    ].join(' · ');

    return BentoRow(
      title: ward.name,
      subtitle: facts.isEmpty ? null : facts,
      onTap: onTap,
      showChevron: onTap != null && trailing == null,
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 12,
      ),
      trailing: trailing ??
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                VitalFigure(
                  value: '${ward.occupiedBeds}',
                  unit: 'of ${ward.capacity}',
                  size: 15,
                  // Amber at capacity, never red. A full ward is somebody's
                  // afternoon — the next admission goes to another ward or
                  // waits — not a deteriorating patient. The bar below it is
                  // the longest run of colour on this screen, and painting it
                  // in the app's one alarm colour made a bed count the loudest
                  // thing on a board whose reds are supposed to be people.
                  tone: full ? AppColors.warning : null,
                ),
                const SizedBox(height: 6),
                UsedBar(
                  fraction: ward.capacity == 0
                      ? 0
                      : ward.occupiedBeds / ward.capacity,
                  color: full ? AppColors.warning : AppColors.bedOccupied,
                  height: 4,
                ),
              ],
            ),
          ),
    );
  }
}

class _InpatientSkeleton extends StatelessWidget {
  const _InpatientSkeleton();

  @override
  Widget build(BuildContext context) {
    return const BentoScreen(
      bottomClearance: false,
      slivers: [
        BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 3)),
        BentoSection(child: BentoSkeleton(rows: 4)),
      ],
    );
  }
}
