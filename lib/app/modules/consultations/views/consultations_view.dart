import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/keys/app_keys.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/consultation_model.dart';
import '../../../data/services/access_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../consultation_routes.dart';
import '../controllers/consultations_controller.dart';

/// Consultations.
///
/// A log, so it reads newest-first and pages as it is scrolled. The waiting
/// count sits at the top because a clinician opening this screen between
/// patients wants to know how many are left before they read what they did
/// with the last one.
class ConsultationsView extends GetView<ConsultationsController> {
  const ConsultationsView({super.key});

  @override
  Widget build(BuildContext context) {
    // The hint, not the permission: the server authorises the write itself,
    // and the form still handles the 403 that can arrive anyway. What this
    // decides is whether somebody is *offered* a door that would refuse them.
    final canWrite = !Get.isRegistered<AccessService>() ||
        AccessService.to.can(Modules.consultations, AccessVerb.create);

    return Scaffold(
      appBar: DetailHeader(
        title: 'Consultations',
        action: canWrite
            ? CircleIconButton(
                key: ConsultationsKeys.createButton,
                icon: Icons.add_rounded,
                tooltip: 'New consultation',
                onTap: () => Get.toNamed<void>(ConsultationRoutes.form),
              )
            : null,
      ),
      body: Obx(() {
        if (controller.isLoading && controller.rxFirstLoad.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 2)),
              BentoSection(child: BentoSkeleton(rows: 5)),
            ],
          );
        }

        final rows = controller.consultations;

        return BentoScreen(
          key: ConsultationsKeys.screen,
          controller: controller.scrollController,
          onRefresh: controller.reload,
          bottomClearance: false,
          slivers: [
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  key: ConsultationsKeys.error,
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
                      value: '${controller.waiting.length}',
                      tone: controller.waiting.length >= 10
                          ? AppColors.acuityUrgent
                          : null,
                    ),
                    VitalTile(
                      label: 'Seen',
                      value: '${controller.totalVisits}',
                      caption: 'all time',
                    ),
                    VitalTile(
                      label: 'Emergency',
                      value: '${controller.emergencyCount}',
                    ),
                  ],
                ),
              ),
            ),

            BentoSection(
              bottom: BentoSpace.header,
              child: SearchField(
                key: ConsultationsKeys.search,
                hint: 'Patient, MRN, diagnosis or clinician',
                onChanged: controller.search,
              ),
            ),

            SliverToBoxAdapter(
              child: _Filters(controller: controller),
            ),

            if (rows.isEmpty)
              BentoSection(
                top: BentoSpace.section,
                child: EmptyState(
                  key: ConsultationsKeys.empty,
                  icon: Icons.medical_information_outlined,
                  title: controller.isFiltered
                      ? 'Nothing matches'
                      : 'No consultations yet',
                  message: controller.isFiltered
                      ? null
                      : 'A consultation records what happened in the room — '
                          'the examination, the diagnosis and the plan.',
                  // A filtered empty offers the way back; a genuinely empty
                  // one offers the thing that would put something here.
                  actionLabel: controller.isFiltered
                      ? 'Clear filters'
                      : canWrite
                          ? 'Write one'
                          : null,
                  onAction: controller.isFiltered
                      ? controller.clearFilters
                      : canWrite
                          ? () => Get.toNamed<void>(ConsultationRoutes.form)
                          : null,
                ),
              )
            else ...[
              BentoSection(
                top: BentoSpace.header,
                bottom: BentoSpace.header,
                child: BentoCard(
                  key: ConsultationsKeys.list,
                  padding: const EdgeInsets.symmetric(
                    vertical: BentoSpace.listCardPad,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Hairline(indent: BentoSpace.listPad),
                        _ConsultationRow(
                          key: ConsultationsKeys.row(rows[i].id),
                          consultation: rows[i],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // The paging footer. Says which of the three states it is in,
              // rather than leaving a reader at the bottom of a list unsure
              // whether more is coming.
              BentoSection(
                child: Center(
                  child: controller.isLoadingMore.value
                      ? const ShimmerBox(width: 130, height: 14)
                      : Text(
                          controller.hasMore.value
                              ? 'Scroll for more'
                              : 'That is all of them',
                          style: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? AppTextStyles.darkCaption1()
                              : AppTextStyles.lightCaption1(),
                        ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller});

  final ConsultationsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpace.page),
      child: Row(
        key: ConsultationsKeys.filters,
        children: [
          Expanded(
            child: BentoPicker(
              label: 'Date',
              value: controller.onDate.value == null
                  ? null
                  : Formatters.dateMedium(controller.onDate.value),
              placeholder: 'Any day',
              onTap: () async {
                final now = AppClock.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: controller.onDate.value ?? now,
                  firstDate: DateTime(now.year - 5),
                  lastDate: now,
                );
                if (picked != null) controller.filterByDate(picked);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BentoPicker(
              label: 'Clinician',
              value: controller.doctor.value?.fullName,
              placeholder: 'Anyone',
              onTap: () => _openDoctorPicker(controller),
            ),
          ),
          if (controller.isFiltered) ...[
            const SizedBox(width: 8),
            CircleIconButton(
              icon: Icons.filter_alt_off_outlined,
              tooltip: 'Clear filters',
              onTap: controller.clearFilters,
            ),
          ],
        ],
      ),
    );
  }
}

/// `follow_up` and `followup` both arrive from this backend; neither is a word.
String _visitTypeLabel(String raw) {
  final value = raw.trim().toLowerCase().replaceAll('_', '');
  return switch (value) {
    'followup' => 'Follow-up',
    'outpatient' => 'Outpatient',
    'inpatient' => 'Inpatient',
    'emergency' => 'Emergency',
    '' => '—',
    _ => CaseStatus.labelOf(raw),
  };
}

class _ConsultationRow extends StatelessWidget {
  const _ConsultationRow({super.key, required this.consultation});

  final ConsultationModel consultation;

  @override
  Widget build(BuildContext context) {
    final diagnosis = consultation.diagnosis?.trim() ?? '';
    final subtitle = diagnosis.isNotEmpty
        ? diagnosis
        : consultation.chiefComplaint;

    return BentoRow(
      title: consultation.patient.fullName.trim().isEmpty
          ? 'Patient ${consultation.patient.mrn}'
          : consultation.patient.fullName,
      subtitle: subtitle.trim().isEmpty ? null : subtitle,
      subtitleMaxLines: 2,
      icon: Icons.medical_information_outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 12,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPill(
            status: consultation.visitType,
            label: _visitTypeLabel(consultation.visitType),
            // A visit type is a category, not a clinical state, so it takes
            // one neutral tint rather than going through the acuity ramp.
            // Routed through `CaseStatus` it would paint an emergency-
            // department visit red — and on a ward board red means a
            // deteriorating patient, not a door somebody came through.
            color: AppColors.acuityRoutine,
            compact: true,
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.dateMedium(consultation.visitDate),
            style: Theme.of(context).brightness == Brightness.dark
                ? AppTextStyles.darkCaption1()
                : AppTextStyles.lightCaption1(),
          ),
        ],
      ),
      // Into the record rather than into a read-only sheet: the detail carries
      // the same facts and the actions a clinician needs on them — an edit, a
      // test, a study, an invoice — each gated on what this account may do.
      onTap: () => Get.toNamed<void>(
        ConsultationRoutes.detailFor(consultation.id),
        arguments: {'id': consultation.id},
      ),
    );
  }
}

Future<void> _openDoctorPicker(ConsultationsController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Clinician',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetRow(
            icon: Icons.groups_outlined,
            label: 'Anyone',
            selected: controller.doctor.value == null,
            onTap: () {
              Get.back<void>();
              controller.filterByDoctor(null);
            },
          ),
          const Hairline(),
          for (final doctor in controller.doctors)
            SheetRow(
              icon: Icons.badge_outlined,
              label: doctor.fullName,
              sublabel: doctor.specialization,
              selected: controller.doctor.value?.id == doctor.id,
              onTap: () {
                Get.back<void>();
                controller.filterByDoctor(doctor);
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
