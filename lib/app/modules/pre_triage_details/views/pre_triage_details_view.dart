import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/pre_triage_model.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../controllers/pre_triage_details_controller.dart';

/// One screening.
///
/// Identity, then observations, then the complaint, then what happens next.
/// The observations come second rather than last because they are the reason
/// somebody opened this record — a clinician checking a walk-in is checking
/// the numbers.
class PreTriageDetailsView extends GetView<PreTriageDetailsController> {
  const PreTriageDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Screening'),
      body: Obx(() {
        final screening = controller.screening.value;

        if (screening == null) {
          return Padding(
            padding: const EdgeInsets.all(BentoSpace.page),
            child: controller.isLoading
                ? const BentoSkeleton(rows: 4)
                : EmptyState(
                    key: PreTriageKeys.detailError,
                    icon: Icons.search_off_rounded,
                    title: 'Screening not found',
                    message: controller.rxLoadError.value,
                    actionLabel: 'Go back',
                    onAction: Get.back,
                  ),
          );
        }

        return BentoScreen(
          key: PreTriageKeys.detail,
          onRefresh: controller.load,
          slivers: [
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  message: controller.rxLoadError.value!,
                  onRetry: controller.load,
                ),
              ),

            // ── Who ─────────────────────────────────────────────────────
            BentoSection(
              top: controller.hasLoadError ? 0 : BentoSpace.page,
              bottom: BentoSpace.header,
              child: BentoCard(
                hero: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PatientIdentityBand(
                      name: screening.fullName.isEmpty
                          ? 'Unnamed'
                          : screening.fullName,
                      mrn: screening.mrn,
                      age: screening.age == null ? null : '${screening.age}y',
                      sex: screening.gender,
                      acuityCode: screening.status,
                    ),
                    const SizedBox(height: 14),
                    const Hairline(),
                    const SizedBox(height: 6),
                    FactRow(
                      label: 'Screening ID',
                      value: screening.screeningId,
                    ),
                    FactRow(
                      label: 'Screened',
                      value: '${Formatters.dateMedium(screening.createdAt)} · '
                          '${Formatters.time(screening.createdAt)}',
                    ),
                    if (screening.phone?.trim().isNotEmpty ?? false)
                      FactRow(label: 'Phone', value: screening.phone!),
                    if (screening.route?.trim().isNotEmpty ?? false)
                      FactRow(label: 'Routed to', value: screening.route!),
                  ],
                ),
              ),
            ),

            // ── Observations ────────────────────────────────────────────
            BentoSection(
              bottom: BentoSpace.header,
              child: _Vitals(screening: screening),
            ),

            // ── What they came in with ──────────────────────────────────
            if (screening.chiefComplaint.trim().isNotEmpty ||
                (screening.briefHistory?.trim().isNotEmpty ?? false))
              BentoSection(
                bottom: BentoSpace.header,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Presentation'),
                    BentoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (screening.chiefComplaint.trim().isNotEmpty) ...[
                            Text(
                              'COMPLAINT',
                              style: AppTextStyles.overline(
                                Theme.of(context).brightness,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              screening.chiefComplaint,
                              style: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTextStyles.darkBody()
                                  : AppTextStyles.lightBody(),
                            ),
                          ],
                          if (screening.briefHistory?.trim().isNotEmpty ??
                              false) ...[
                            if (screening.chiefComplaint.trim().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Hairline(),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              'HISTORY',
                              style: AppTextStyles.overline(
                                Theme.of(context).brightness,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              screening.briefHistory!,
                              style: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTextStyles.darkCallout()
                                  : AppTextStyles.lightCallout(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── What happens next ───────────────────────────────────────
            BentoSection(
              child: _Actions(screening: screening, controller: controller),
            ),
          ],
        );
      }),
    );
  }
}

// ── Observations ────────────────────────────────────────────────────────────

class _Vitals extends StatelessWidget {
  const _Vitals({required this.screening});

  final PreTriageModel screening;

  @override
  Widget build(BuildContext context) {
    final tiles = <VitalTile>[
      if (screening.temperature != null)
        VitalTile(
          label: 'Temp',
          value: screening.temperature!.toStringAsFixed(1),
          unit: '°C',
          tone: VitalRange.temperature(screening.temperature),
          caption: VitalRange.captions['temperature'],
        ),
      if (screening.pulse != null)
        VitalTile(
          label: 'Pulse',
          value: '${screening.pulse}',
          unit: 'bpm',
          tone: VitalRange.pulse(screening.pulse),
          caption: VitalRange.captions['pulse'],
        ),
      if (screening.bpSystolic != null)
        VitalTile(
          label: 'BP',
          value: screening.bpDiastolic == null
              ? '${screening.bpSystolic}'
              : '${screening.bpSystolic}/${screening.bpDiastolic}',
          unit: 'mmHg',
          tone: VitalRange.bloodPressure(
            screening.bpSystolic,
            screening.bpDiastolic,
          ),
          caption: VitalRange.captions['bloodPressure'],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Observations'),
        BentoCard(
          key: PreTriageKeys.detailVitals,
          child: tiles.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.monitor_heart_outlined,
                  title: 'No observations recorded',
                  message: 'Add them by editing this screening.',
                )
              : VitalsGrid(tiles: tiles, columns: 3),
        ),
      ],
    );
  }
}

// ── Actions ─────────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({required this.screening, required this.controller});

  final PreTriageModel screening;
  final PreTriageDetailsController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isOpen) {
      return NoticeBanner(
        message: screening.status == 'registered_as_patient'
            ? 'This screening has been registered as a patient record. '
                'Further changes are made on the patient.'
            : 'This screening has been routed and can no longer be changed '
                'here.',
        icon: Icons.lock_outline_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => PrimaryBar(
            key: PreTriageKeys.detailConvert,
            label: 'Register as patient',
            icon: Icons.how_to_reg_outlined,
            busy: controller.isActing.value,
            onPressed: () async {
              final confirmed = await ConfirmDialog.show(
                context,
                title: 'Register ${screening.fullName}?',
                message: 'A patient record is created from this screening and '
                    'an MRN is issued. The screening itself stops being '
                    'editable.',
                confirmLabel: 'Register',
              );
              if (confirmed) await controller.convertToPatient();
            },
          ),
        ),
        const SizedBox(height: BentoSpace.action),
        SecondaryBar(
          key: PreTriageKeys.detailEdit,
          label: 'Edit screening',
          icon: Icons.edit_outlined,
          onPressed: () => Get.toNamed<void>(
            Routes.EDIT_SCREENING,
            arguments: screening,
          ),
        ),
        const SizedBox(height: BentoSpace.action),
        SecondaryBar(
          label: 'Delete screening',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onPressed: () async {
            final confirmed = await ConfirmDialog.show(
              context,
              title: 'Delete this screening?',
              message: 'The observations and the complaint are lost. If the '
                  'patient is still here they will need screening again.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (confirmed) await controller.deleteScreening();
          },
        ),
      ],
    );
  }
}
