import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/ward_model.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../../inpatient/views/inpatient_view.dart' show WardRow;
import '../controllers/inpatient_wards_controller.dart';

/// The ward list, ordered by how close each one is to full.
class InpatientWardsView extends GetView<InpatientWardsController> {
  const InpatientWardsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: 'Wards',
        action: CircleIconButton(
          key: InpatientKeys.addWard,
          icon: Icons.add_rounded,
          tooltip: 'Add ward',
          onTap: () => Get.toNamed<void>(Routes.INPATIENT_ADD_WARD),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading && controller.rxFirstLoad.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 5)),
            ],
          );
        }

        final rows = controller.displayed;

        return BentoScreen(
          key: InpatientKeys.wards,
          onRefresh: controller.reload,
          bottomClearance: false,
          slivers: [
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  message: controller.rxLoadError.value!,
                  onRetry: controller.load,
                ),
              ),

            if (rows.isEmpty)
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  key: InpatientKeys.wardsEmpty,
                  icon: Icons.meeting_room_outlined,
                  title: controller.showInactive.value
                      ? 'No wards at all yet'
                      : 'No wards in service',
                  message: 'A ward holds the beds patients are admitted into.',
                  actionLabel: 'Add ward',
                  onAction: () => Get.toNamed<void>(Routes.INPATIENT_ADD_WARD),
                ),
              )
            else
              BentoSection(
                top: controller.hasLoadError ? 0 : BentoSpace.page,
                child: BentoCard(
                  key: InpatientKeys.wardsList,
                  padding: const EdgeInsets.symmetric(
                    vertical: BentoSpace.listCardPad,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Hairline(indent: BentoSpace.listPad),
                        WardRow(
                          key: InpatientKeys.ward(rows[i].id),
                          ward: rows[i],
                          onTap: () =>
                              _openWardSheet(context, rows[i], controller),
                          // Out of service is a word, not a fade. Dimming the
                          // row put its title at 4.14:1 and its subtitle at
                          // 2.41:1 — the wards that need the closest read were
                          // the ones hardest to read.
                          trailing: rows[i].isActive
                              ? null
                              : const StatusPill(
                                  status: 'inactive',
                                  label: 'Out of service',
                                  compact: true,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // The inactive toggle sits below the list rather than above it:
            // it changes what the list contains, and a control that reshapes
            // a list belongs after the reader has seen the list.
            if (controller.inactiveCount > 0)
              BentoSection(
                child: SecondaryBar(
                  label: controller.showInactive.value
                      ? 'Hide out of service'
                      : 'Show ${controller.inactiveCount} out of service',
                  icon: controller.showInactive.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onPressed: controller.toggleInactive,
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// The sheet takes the ward itself, never its position in the list.
///
/// `displayed` is derived from an observable, so a `DataBus` tick between the
/// row being built and the row being tapped can reorder or shorten it. An
/// index read back at tap time is then either somebody else's ward or a
/// `RangeError`, and the first of those is the dangerous one — it is silent.
Future<void> _openWardSheet(
  BuildContext context,
  WardModel ward,
  InpatientWardsController controller,
) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: ward.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSection(
            bottom: BentoSpace.section,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FactRow(label: 'Code', value: ward.code, inset: false),
                FactRow(label: 'Type', value: ward.type, inset: false),
                FactRow(
                  label: 'Beds',
                  value: '${ward.occupiedBeds} occupied of ${ward.capacity}',
                  inset: false,
                ),
              ],
            ),
          ),
          SheetRow(
            icon: Icons.grid_view_rounded,
            label: 'Bed map',
            sublabel: 'See every bed in this ward',
            onTap: () {
              Get.back<void>();
              Get.toNamed<void>(
                Routes.INPATIENT_BEDS_GRID,
                arguments: {'wardId': ward.id},
              );
            },
          ),
          SheetRow(
            icon: Icons.add_rounded,
            label: 'Add bed',
            onTap: () {
              Get.back<void>();
              Get.toNamed<void>(
                Routes.INPATIENT_ADD_BED,
                arguments: {'wardId': ward.id},
              );
            },
          ),
          const Hairline(),
          if (ward.isActive)
            SheetRow(
              icon: Icons.do_not_disturb_on_outlined,
              label: 'Take out of service',
              sublabel: 'Keeps its beds and its history',
              destructive: true,
              onTap: () async {
                Get.back<void>();
                final confirmed = await ConfirmDialog.show(
                  context,
                  title: 'Take ${ward.name} out of service?',
                  message: ward.occupiedBeds > 0
                      ? '${ward.occupiedBeds} patients are still in this ward. '
                          'They stay admitted; the ward simply stops accepting '
                          'new admissions.'
                      : 'It stops accepting admissions. Nothing is deleted.',
                  confirmLabel: 'Take out of service',
                  destructive: true,
                );
                if (confirmed) {
                  await controller.setActive(ward, active: false);
                }
              },
            )
          else
            SheetRow(
              icon: Icons.play_circle_outline_rounded,
              label: 'Bring back into service',
              onTap: () {
                Get.back<void>();
                controller.setActive(ward, active: true);
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
