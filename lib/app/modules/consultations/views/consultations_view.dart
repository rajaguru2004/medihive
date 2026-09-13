import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/keys/app_keys.dart';
import '../../../data/models/consultation_model.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
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
    return Scaffold(
      appBar: const DetailHeader(title: 'Consultations'),
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
                      label: 'Still waiting',
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
                  actionLabel: controller.isFiltered ? 'Clear filters' : null,
                  onAction:
                      controller.isFiltered ? controller.clearFilters : null,
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
          StatusPill(status: consultation.visitType, compact: true),
          const SizedBox(height: 4),
          Text(
            Formatters.dateMedium(consultation.visitDate),
            style: Theme.of(context).brightness == Brightness.dark
                ? AppTextStyles.darkCaption1()
                : AppTextStyles.lightCaption1(),
          ),
        ],
      ),
      onTap: () => _openConsultationSheet(context, consultation),
    );
  }
}

/// One consultation, in full.
///
/// A sheet rather than a pushed screen: it is a record to read, not a place to
/// work, and a reader on a ward round wants to glance at it and dismiss it
/// without losing their place in the list.
Future<void> _openConsultationSheet(
  BuildContext context,
  ConsultationModel consultation,
) {
  final vitals = <VitalTile>[
    if (consultation.temperature != null)
      VitalTile(
        label: 'Temp',
        value: consultation.temperature!.toStringAsFixed(1),
        unit: '°C',
        tone: VitalRange.temperature(consultation.temperature),
      ),
    if (consultation.pulseRate != null)
      VitalTile(
        label: 'Pulse',
        value: '${consultation.pulseRate}',
        unit: 'bpm',
        tone: VitalRange.pulse(consultation.pulseRate),
      ),
    if (consultation.bloodPressureSystolic != null)
      VitalTile(
        label: 'BP',
        value: consultation.bloodPressureDiastolic == null
            ? '${consultation.bloodPressureSystolic}'
            : '${consultation.bloodPressureSystolic}/'
                '${consultation.bloodPressureDiastolic}',
        unit: 'mmHg',
        tone: VitalRange.bloodPressure(
          consultation.bloodPressureSystolic,
          consultation.bloodPressureDiastolic,
        ),
      ),
    if (consultation.oxygenSaturation != null)
      VitalTile(
        label: 'SpO₂',
        value: '${consultation.oxygenSaturation}',
        unit: '%',
        tone: VitalRange.oxygenSaturation(consultation.oxygenSaturation),
      ),
    if (consultation.respiratoryRate != null)
      VitalTile(
        label: 'Resp',
        value: '${consultation.respiratoryRate}',
        unit: '/min',
        tone: VitalRange.respiratoryRate(consultation.respiratoryRate),
      ),
    if (consultation.weight != null)
      VitalTile(
        label: 'Weight',
        value: consultation.weight!.toStringAsFixed(1),
        unit: 'kg',
      ),
  ];

  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Consultation',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PatientIdentityBand(
            name: consultation.patient.fullName,
            mrn: consultation.patient.mrn,
            age: Formatters.age(consultation.patient.dateOfBirth),
            sex: consultation.patient.gender,
            extra: '${Formatters.dateMedium(consultation.visitDate)} · '
                '${consultation.doctor.fullName}',
          ),
          if (vitals.isNotEmpty) ...[
            const SizedBox(height: BentoSpace.section),
            InsetSurface(
              padding: const EdgeInsets.all(16),
              child: VitalsGrid(tiles: vitals, columns: 3),
            ),
          ],
          const SizedBox(height: BentoSpace.section),
          _Note(label: 'Complaint', value: consultation.chiefComplaint),
          _Note(
            label: 'History',
            value: consultation.historyOfPresentIllness,
          ),
          _Note(
            label: 'Examination',
            value: consultation.physicalExamination,
          ),
          _Note(label: 'Diagnosis', value: consultation.diagnosis),
          _Note(label: 'Plan', value: consultation.treatmentPlan),
          _Note(
            label: 'Follow-up',
            value: [
              if (consultation.followUpDate != null)
                Formatters.dateMedium(consultation.followUpDate),
              if (consultation.followUpInstructions?.trim().isNotEmpty ?? false)
                consultation.followUpInstructions!,
            ].join(' · '),
          ),
          _Note(label: 'Referred to', value: consultation.referredTo),
          _Note(label: 'Notes', value: consultation.notes),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

/// One labelled block of clinical prose, or nothing when there is none.
///
/// Omitted rather than shown empty: a record where half the headings say "—"
/// is a record whose real content is harder to find.
class _Note extends StatelessWidget {
  const _Note({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.overline(Theme.of(context).brightness),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: isDark
                ? AppTextStyles.darkCallout()
                : AppTextStyles.lightCallout(),
          ),
        ],
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
