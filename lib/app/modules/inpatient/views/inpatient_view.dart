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
        return _InpatientSkeleton(embedded: embedded);
      }

      final stats = controller.stats.value;
      final wards = controller.activeWards;

      return BentoScreen(
        key: InpatientKeys.overview,
        onRefresh: controller.reload,
        bottomClearance: !embedded,
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
                        tone: stats.availableBeds == 0
                            ? AppColors.acuityCritical
                            : null,
                      ),
                      VitalTile(
                        label: 'Admitted today',
                        value: '${stats.todayAdmissions}',
                      ),
                      VitalTile(
                        label: 'Discharged today',
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
    final facts = [
      if (ward.code.trim().isNotEmpty) ward.code,
      if (ward.type.trim().isNotEmpty) ward.type,
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
                  // Red only when there is genuinely nowhere to put anybody.
                  // A ward at 90% is busy, not an emergency.
                  tone: full ? AppColors.acuityCritical : null,
                ),
                const SizedBox(height: 6),
                UsedBar(
                  fraction: ward.capacity == 0
                      ? 0
                      : ward.occupiedBeds / ward.capacity,
                  color: full ? AppColors.acuityCritical : AppColors.bedOccupied,
                  height: 4,
                ),
              ],
            ),
          ),
    );
  }
}

class _InpatientSkeleton extends StatelessWidget {
  const _InpatientSkeleton({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BentoScreen(
      bottomClearance: !embedded,
      slivers: const [
        BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 3)),
        BentoSection(child: BentoSkeleton(rows: 4)),
      ],
    );
  }
}
