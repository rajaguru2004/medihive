import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/admission_model.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/inpatient_admissions_controller.dart';

/// The admissions register: everyone who has been in a bed, live first.
class InpatientAdmissionsView extends GetView<InpatientAdmissionsController> {
  const InpatientAdmissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: 'Admissions',
        action: CircleIconButton(
          icon: Icons.add_rounded,
          tooltip: 'Admit patient',
          onTap: () => Get.toNamed<void>(Routes.INPATIENT_ADMIT),
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
          key: InpatientKeys.admissions,
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
            BentoSection(
              top: controller.hasLoadError ? 0 : BentoSpace.page,
              bottom: BentoSpace.header,
              child: SearchField(
                hint: 'Patient, MRN, ward or bed',
                onChanged: controller.search,
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChips<String>(
                key: InpatientKeys.admissionsFilters,
                options: controller.statuses,
                selected: controller.statusFilter.value,
                labelOf: CaseStatus.labelOf,
                onSelected: controller.filterByStatus,
              ),
            ),
            if (rows.isEmpty)
              BentoSection(
                top: BentoSpace.section,
                child: EmptyState(
                  key: InpatientKeys.admissionsEmpty,
                  icon: Icons.assignment_ind_outlined,
                  title: controller.isFiltered
                      ? 'Nothing matches'
                      : 'No admissions yet',
                  message: controller.isFiltered
                      ? null
                      : 'Patients admitted into a bed appear here.',
                  actionLabel:
                      controller.isFiltered ? 'Clear filters' : 'Admit patient',
                  onAction: controller.isFiltered
                      ? controller.clearFilters
                      : () => Get.toNamed<void>(Routes.INPATIENT_ADMIT),
                ),
              )
            else
              BentoSection(
                top: BentoSpace.header,
                child: BentoCard(
                  key: InpatientKeys.admissionsList,
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

/// One admission. Shared with the ward round, so an admission reads the same
/// on both screens.
class AdmissionRow extends StatelessWidget {
  const AdmissionRow({super.key, required this.admission, this.onTap});

  final AdmissionModel admission;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final live = admission.status.trim().toLowerCase() == 'active';
    final ward = admission.bed.ward?.name ?? '';
    final where = [
      if (ward.isNotEmpty) ward,
      if (admission.bed.bedNumber.trim().isNotEmpty)
        'bed ${admission.bed.bedNumber}',
    ].join(' · ');

    return BentoRow(
      title: admission.patient.fullName.trim().isEmpty
          ? 'Patient ${admission.patient.mrn}'
          : admission.patient.fullName,
      subtitle: where.isEmpty ? admission.admissionReason : where,
      icon: Icons.person_outline_rounded,
      showChevron: onTap != null,
      onTap: onTap ??
          () => Get.toNamed<void>(
                Routes.DISCHARGE_PATIENT,
                arguments: {'admissionId': admission.id},
              ),
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 12,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPill(status: admission.status, compact: true),
          const SizedBox(height: 4),
          Text(
            // Day count for a live admission; the discharge date for a closed
            // one. Both answer "when", for the state the record is actually in.
            live
                ? 'Day ${Formatters.lengthOfStayDays(admission.admissionDate) + 1}'
                : Formatters.dateMedium(
                    admission.dischargeDate ?? admission.admissionDate,
                  ),
            style: Theme.of(context).brightness == Brightness.dark
                ? AppTextStyles.darkCaption1()
                : AppTextStyles.lightCaption1(),
          ),
        ],
      ),
    );
  }
}
