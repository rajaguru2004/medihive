import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/pre_triage_model.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/pre_triage_controller.dart';

/// The screening board.
///
/// Open screenings first, because each one is somebody sitting in a waiting
/// room who has been assessed and not yet routed anywhere. Each row carries
/// its worst vital as a chip, so the board answers "is anyone here
/// deteriorating" without opening a record.
class PreTriageView extends GetView<PreTriageController> {
  const PreTriageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: 'Pre-triage',
        action: CircleIconButton(
          key: PreTriageKeys.newScreening,
          icon: Icons.add_rounded,
          tooltip: 'New screening',
          onTap: () => Get.toNamed<void>(Routes.NEW_SCREENING_STEP1),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading && controller.rxFirstLoad.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 2)),
              BentoSection(child: BentoSkeleton(rows: 4)),
            ],
          );
        }

        final rows = controller.displayed;

        return BentoScreen(
          key: PreTriageKeys.screen,
          onRefresh: controller.reload,
          bottomClearance: false,
          slivers: [
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  key: PreTriageKeys.error,
                  message: controller.rxLoadError.value!,
                  onRetry: controller.load,
                ),
              ),

            BentoSection(
              top: controller.hasLoadError ? 0 : BentoSpace.page,
              bottom: BentoSpace.header,
              child: BentoCard(
                hero: true,
                child: VitalsGrid(
                  columns: 3,
                  tiles: [
                    VitalTile(
                      label: 'Waiting',
                      value: '${controller.openCount}',
                      tone: controller.openCount >= 10
                          ? AppColors.acuityUrgent
                          : null,
                      caption: 'not yet routed',
                    ),
                    VitalTile(
                      label: 'Routed',
                      value: '${controller.countOf(PreTriageController.routed)}',
                    ),
                    VitalTile(
                      label: 'Registered',
                      value:
                          '${controller.countOf(PreTriageController.registered)}',
                    ),
                  ],
                ),
              ),
            ),

            BentoSection(
              bottom: BentoSpace.header,
              child: SearchField(
                key: PreTriageKeys.search,
                hint: 'Name, screening ID, phone or complaint',
                onChanged: controller.search,
              ),
            ),

            SliverToBoxAdapter(
              child: FilterChips<String>(
                key: PreTriageKeys.filters,
                options: PreTriageController.filters,
                selected: controller.statusFilter.value,
                labelOf: (filter) => filter,
                countOf: controller.countOf,
                keyOf: (filter) => PreTriageKeys.filter(filter),
                onSelected: controller.filterBy,
              ),
            ),

            if (rows.isEmpty)
              BentoSection(
                top: BentoSpace.section,
                child: EmptyState(
                  key: PreTriageKeys.empty,
                  icon: Icons.assignment_outlined,
                  title: controller.isFiltered
                      ? 'Nothing matches'
                      : 'No screenings yet',
                  message: controller.isFiltered
                      ? null
                      : 'A screening records a walk-in before a patient record '
                          'exists — the complaint, the observations, and where '
                          'they should go next.',
                  actionLabel: controller.isFiltered
                      ? 'Clear filters'
                      : 'New screening',
                  onAction: controller.isFiltered
                      ? controller.clearFilters
                      : () => Get.toNamed<void>(Routes.NEW_SCREENING_STEP1),
                ),
              )
            else
              BentoSection(
                top: BentoSpace.header,
                child: BentoCard(
                  key: PreTriageKeys.list,
                  padding: const EdgeInsets.symmetric(
                    vertical: BentoSpace.listCardPad,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Hairline(indent: BentoSpace.listPad),
                        _ScreeningRow(
                          key: PreTriageKeys.row(rows[i].id),
                          screening: rows[i],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _ScreeningRow extends StatelessWidget {
  const _ScreeningRow({super.key, required this.screening});

  final PreTriageModel screening;

  @override
  Widget build(BuildContext context) {
    final flag = worstVitalFlag(screening);
    final facts = [
      if (screening.screeningId.isNotEmpty) screening.screeningId,
      if (screening.age != null) '${screening.age}y',
      if (screening.gender?.isNotEmpty ?? false) screening.gender!,
    ].join(' · ');

    return BentoRow(
      title: screening.fullName.isEmpty ? 'Unnamed' : screening.fullName,
      subtitle: screening.chiefComplaint.trim().isEmpty
          ? (facts.isEmpty ? null : facts)
          : screening.chiefComplaint,
      subtitleMaxLines: 2,
      // The flag when there is one, a neutral glyph otherwise. A row that
      // always shows a coloured icon is a row whose colour means nothing.
      icon: flag == null
          ? Icons.assignment_outlined
          : Icons.monitor_heart_rounded,
      iconColor: flag == null ? null : semanticInk(context, flag),
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 12,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPill(status: screening.status, compact: true),
          const SizedBox(height: 4),
          Text(
            Formatters.elapsed(screening.createdAt),
            style: Theme.of(context).brightness == Brightness.dark
                ? AppTextStyles.darkCaption1()
                : AppTextStyles.lightCaption1(),
          ),
        ],
      ),
      onTap: () => Get.toNamed<void>(
        Routes.PRE_TRIAGE_DETAILS,
        arguments: {'id': screening.id},
      ),
    );
  }
}

/// The most concerning of a screening's observations, or null when all are
/// within range.
///
/// Shared with the detail screen, so a row and the record it opens agree.
Color? worstVitalFlag(PreTriageModel screening) {
  final flags = [
    VitalRange.temperature(screening.temperature),
    VitalRange.pulse(screening.pulse),
    VitalRange.bloodPressure(screening.bpSystolic, screening.bpDiastolic),
  ].whereType<Color>();

  if (flags.isEmpty) return null;
  // Critical beats urgent: the flag is there to say "look at this one", and
  // the worst reading is the reason to look.
  return flags.contains(AppColors.acuityCritical)
      ? AppColors.acuityCritical
      : AppColors.acuityUrgent;
}
