import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../../inpatient_admissions/views/inpatient_admissions_view.dart'
    show AdmissionRow;
import '../controllers/inpatient_overview_controller.dart';

/// The ward round: everyone currently in a bed, longest stay first.
class InpatientOverviewView extends GetView<InpatientOverviewController> {
  const InpatientOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(
        title: 'Ward round',
        subtitle: 'Everyone currently in a bed',
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
        final filtered = controller.query.value.trim().isNotEmpty;

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

            BentoSection(
              top: controller.hasLoadError ? 0 : BentoSpace.page,
              bottom: BentoSpace.header,
              child: BentoCard(
                child: VitalsGrid(
                  columns: 3,
                  tiles: [
                    VitalTile(
                      label: 'In beds',
                      value: '${controller.active.length}',
                    ),
                    VitalTile(
                      label: 'Admitted',
                      value: '${controller.admittedToday}',
                    ),
                    VitalTile(
                      label: 'Over 7 days',
                      value: '${controller.longStayCount}',
                      // A prompt, not an alarm: a long stay means somebody
                      // should check a discharge plan exists, which is amber
                      // work rather than red.
                      tone: controller.longStayCount > 0
                          ? AppColors.warning
                          : null,
                      caption: controller.longStayCount > 0
                          ? 'check plans'
                          : null,
                    ),
                  ],
                ),
              ),
            ),

            BentoSection(
              bottom: BentoSpace.header,
              child: SearchField(
                hint: 'Patient, MRN, ward or bed',
                onChanged: controller.search,
              ),
            ),

            if (rows.isEmpty)
              BentoSection(
                top: BentoSpace.header,
                child: EmptyState(
                  icon: Icons.local_hotel_outlined,
                  title: filtered
                      ? 'Nobody matches that'
                      : 'No patients in beds',
                  message: filtered
                      ? null
                      : 'Admitted patients appear here, longest stay first.',
                  // A search matching nothing is not an empty ward, so it does
                  // not offer an admission — it offers the query back. An
                  // empty state with no action at all is a dead end reached by
                  // typing, which is the easiest dead end in the app to reach.
                  actionLabel: filtered ? 'Clear search' : 'Admit patient',
                  onAction: filtered
                      ? controller.clearSearch
                      : () => Get.toNamed<void>(Routes.INPATIENT_ADMIT),
                ),
              )
            else
              BentoSection(
                child: BentoCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: BentoSpace.listCardPad,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Hairline(indent: BentoSpace.listPad),
                        AdmissionRow(
                          key: InpatientKeys.admission(rows[i].id),
                          admission: rows[i],
                          onTap: () => Get.toNamed<void>(
                            Routes.DISCHARGE_PATIENT,
                            arguments: {'admissionId': rows[i].id},
                          ),
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
