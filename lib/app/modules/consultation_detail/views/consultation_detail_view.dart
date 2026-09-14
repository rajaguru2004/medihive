import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/consultation_detail_keys.dart';
import '../../../data/models/consultation_model.dart';
import '../../../data/models/consultation_record.dart';
import '../../../data/models/lab_order.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/radiology_order.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../../consultations/consultation_routes.dart';
import '../../laboratory/laboratory_routes.dart';
import '../../radiology/radiology_routes.dart';
import '../controllers/consultation_detail_controller.dart';

/// One consultation.
///
/// Identity, then the observations, then what was found and what was done about
/// it. The observations come second because they are the reason somebody opened
/// the record — and they carry the same worded warning the form raised while
/// they were being typed, because a form that flags a reading and a record that
/// does not is two screens disagreeing about one patient.
class ConsultationDetailView extends GetView<ConsultationDetailController> {
  const ConsultationDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Consultation'),
      body: Obx(() {
        final record = controller.record.value;

        if (record == null) {
          return Padding(
            padding: const EdgeInsets.all(BentoSpace.page),
            child: controller.isLoading
                ? const BentoSkeleton(rows: 5)
                : EmptyState(
                    key: ConsultationDetailKeys.missing,
                    icon: Icons.medical_information_outlined,
                    title: 'That consultation is not here',
                    message: controller.rxLoadError.value,
                    actionLabel: 'Go back',
                    onAction: Get.back,
                  ),
          );
        }

        final consultation = record.consultation;

        return BentoScreen(
          key: ConsultationDetailKeys.screen,
          onRefresh: controller.reload,
          bottomClearance: false,
          slivers: [
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  key: ConsultationDetailKeys.error,
                  message: controller.rxLoadError.value!,
                  onRetry: controller.load,
                ),
              ),

            BentoSection(
              top: controller.hasLoadError ? 0 : BentoSpace.page,
              bottom: BentoSpace.header,
              child: _Header(controller: controller, record: record),
            ),

            BentoSection(
              bottom: BentoSpace.header,
              child: _Vitals(controller: controller),
            ),

            BentoSection(
              bottom: BentoSpace.header,
              child: _Notes(consultation: consultation),
            ),

            BentoSection(
              bottom: BentoSpace.header,
              child: _Diagnosis(
                consultation: consultation,
                codes: controller.icdCodes,
              ),
            ),

            if (record.prescribedItems.isNotEmpty)
              BentoSection(
                bottom: BentoSpace.header,
                child: _Prescription(record: record),
              ),

            if (record.labOrders.isNotEmpty)
              BentoSection(
                bottom: BentoSpace.header,
                child: _LabOrders(orders: record.labOrders),
              ),

            if (record.radiologyOrders.isNotEmpty)
              BentoSection(
                bottom: BentoSpace.header,
                child: _ImagingOrders(orders: record.radiologyOrders),
              ),

            if (_hasFollowUp(consultation))
              BentoSection(
                bottom: BentoSpace.header,
                child: _FollowUp(
                  consultation: consultation,
                  controller: controller,
                ),
              ),

            BentoSection(child: _Actions(controller: controller)),
          ],
        );
      }),
    );
  }

  static bool _hasFollowUp(ConsultationModel consultation) =>
      consultation.followUpDate != null ||
      (consultation.followUpInstructions?.trim().isNotEmpty ?? false) ||
      (consultation.referredTo?.trim().isNotEmpty ?? false);
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.record});

  final ConsultationDetailController controller;
  final ConsultationRecord record;

  @override
  Widget build(BuildContext context) {
    final consultation = record.consultation;
    final patient = consultation.patient;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecordHeader(
          title: patient.fullName.trim().isEmpty
              ? 'Patient ${patient.mrn}'
              : patient.fullName,
          subtitle: '${controller.formatDate(consultation.visitDate)} · '
              '${consultation.doctor.fullName}',
          status: controller.visitTypeLabel,
          // A visit type is a category, not a clinical state. Through the
          // acuity ramp an emergency-department visit would render red, and on
          // a ward board red means a deteriorating patient — not a door
          // somebody came through.
          statusColor: AppColors.acuityRoutine,
          actions: [
            if (controller.canUpdate)
              RecordAction(
                key: ConsultationDetailKeys.edit,
                icon: Icons.edit_outlined,
                label: 'Edit',
                onPressed: () => Get.toNamed<void>(
                  ConsultationRoutes.form,
                  arguments: {'id': consultation.id},
                ),
              ),
            if (controller.canDelete)
              RecordAction(
                key: ConsultationDetailKeys.delete,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                destructive: true,
                onPressed: () => _confirmDelete(context, controller),
              ),
          ],
        ),
        const SizedBox(height: BentoSpace.header),
        BentoCard(
          child: PatientIdentityBand(
            name: patient.fullName.trim().isEmpty
                ? 'Patient ${patient.mrn}'
                : patient.fullName,
            mrn: patient.mrn,
            age: Formatters.age(patient.dateOfBirth),
            sex: patient.gender,
            extra: patient.bloodGroup,
          ),
        ),
      ],
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  ConsultationDetailController controller,
) async {
  final confirmed = await ConfirmDialog.show(
    context,
    title: 'Delete ${controller.patientName}’s consultation?',
    message: 'The examination, the diagnosis and the plan are removed from '
        'this patient’s record. Anything already ordered against it stays. '
        'This cannot be undone.',
    confirmLabel: 'Delete',
    cancelLabel: 'Keep it',
    destructive: true,
    confirmKey: ConsultationDetailKeys.deleteConfirm,
  );
  if (confirmed) await controller.remove();
}

// ── Observations ────────────────────────────────────────────────────────────

class _Vitals extends StatelessWidget {
  const _Vitals({required this.controller});

  final ConsultationDetailController controller;

  @override
  Widget build(BuildContext context) {
    final reading = controller.reading;

    // Zero is not a reading. This backend stores an unobserved vital as `0`,
    // and `VitalsReading` has already dropped those — so a record nobody
    // examined shows no tiles rather than a row of zeros painted as a patient
    // in extremis.
    final tiles = <VitalTile>[
      if (reading.temperature != null)
        VitalTile(
          label: 'Temp',
          value: reading.temperature!.toStringAsFixed(1),
          unit: '°C',
          tone: reading.temperatureTone,
          caption: VitalRange.captions['temperature'],
        ),
      if (reading.systolic != null)
        VitalTile(
          label: 'BP',
          value: reading.diastolic == null
              ? '${reading.systolic}'
              : '${reading.systolic}/${reading.diastolic}',
          unit: 'mmHg',
          tone: reading.bloodPressureTone,
          caption: VitalRange.captions['bloodPressure'],
        ),
      if (reading.pulse != null)
        VitalTile(
          label: 'Pulse',
          value: '${reading.pulse}',
          unit: 'bpm',
          tone: reading.pulseTone,
          caption: VitalRange.captions['pulse'],
        ),
      if (reading.respiratoryRate != null)
        VitalTile(
          label: 'Resp',
          value: '${reading.respiratoryRate}',
          unit: '/min',
          tone: reading.respiratoryTone,
          caption: VitalRange.captions['respiratoryRate'],
        ),
      if (reading.oxygenSaturation != null)
        VitalTile(
          label: 'SpO₂',
          value: '${reading.oxygenSaturation}',
          unit: '%',
          tone: reading.saturationTone,
          caption: VitalRange.captions['oxygenSaturation'],
        ),
      if (reading.weight != null)
        VitalTile(
          label: 'Weight',
          value: reading.weight!.toStringAsFixed(1),
          unit: 'kg',
        ),
      if (reading.height != null)
        VitalTile(
          label: 'Height',
          value: reading.height!.toStringAsFixed(0),
          unit: 'cm',
        ),
    ];

    final warning = reading.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Observations'),
        if (warning != null) ...[
          NoticeBanner(
            key: ConsultationDetailKeys.vitalsFlag,
            message: warning,
            icon: Icons.monitor_heart_outlined,
            tint: reading.flag!,
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        BentoCard(
          key: ConsultationDetailKeys.vitals,
          child: tiles.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.monitor_heart_outlined,
                  title: 'No observations recorded',
                  message: 'Add them by editing this consultation.',
                )
              // Two across, not three. A blood pressure is a compound value —
              // "168/96" is twice the width of a pulse — and at three columns
              // on a phone it is the one reading that has to shrink. Never
              // ellipsise a clinical figure: "16…" could be 160 or 168.
              : VitalsGrid(tiles: tiles, columns: 2),
        ),
      ],
    );
  }
}

// ── Prose ───────────────────────────────────────────────────────────────────

class _Notes extends StatelessWidget {
  const _Notes({required this.consultation});

  final ConsultationModel consultation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Notes'),
        BentoCard(
          key: ConsultationDetailKeys.notes,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Prose(label: 'Complaint', value: consultation.chiefComplaint),
              _Prose(
                label: 'History',
                value: consultation.historyOfPresentIllness,
              ),
              _Prose(
                label: 'Examination',
                value: consultation.physicalExamination,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Diagnosis extends StatelessWidget {
  const _Diagnosis({required this.consultation, required this.codes});

  final ConsultationModel consultation;
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Diagnosis and plan'),
        BentoCard(
          key: ConsultationDetailKeys.diagnosis,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Prose(label: 'Diagnosis', value: consultation.diagnosis),
              if (codes.isNotEmpty) ...[
                Text(
                  'ICD-10',
                  style: AppTextStyles.overline(Theme.of(context).brightness),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in codes)
                      StatusPill(
                        status: code,
                        label: code,
                        // A diagnostic code is a label, not a state. One
                        // neutral tint, and the word carries it.
                        color: AppColors.acuityRoutine,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _Prose(
                label: 'Plan',
                value: consultation.treatmentPlan,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FollowUp extends StatelessWidget {
  const _FollowUp({required this.consultation, required this.controller});

  final ConsultationModel consultation;
  final ConsultationDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Follow-up'),
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (consultation.followUpDate != null)
                FactRow(
                  label: 'Come back on',
                  value: controller.formatDate(consultation.followUpDate),
                ),
              if (consultation.followUpInstructions?.trim().isNotEmpty ?? false)
                FactRow(
                  label: 'Instructions',
                  value: consultation.followUpInstructions!,
                  stacked: true,
                ),
              if (consultation.referredTo?.trim().isNotEmpty ?? false)
                FactRow(
                  label: 'Referred to',
                  value: consultation.referredTo!,
                ),
              if (consultation.referralReason?.trim().isNotEmpty ?? false)
                FactRow(
                  label: 'Reason',
                  value: consultation.referralReason!,
                  stacked: true,
                ),
              if (consultation.notes?.trim().isNotEmpty ?? false)
                FactRow(
                  label: 'Notes',
                  value: consultation.notes!,
                  stacked: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One labelled block of clinical prose, or nothing when there is none.
///
/// Omitted rather than shown empty: a record where half the headings say "—" is
/// a record whose real content is harder to find.
class _Prose extends StatelessWidget {
  const _Prose({required this.label, required this.value, this.last = false});

  final String label;
  final String? value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
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
            style:
                isDark ? AppTextStyles.darkCallout() : AppTextStyles.lightCallout(),
          ),
        ],
      ),
    );
  }
}

// ── What the encounter produced ─────────────────────────────────────────────

class _Prescription extends StatelessWidget {
  const _Prescription({required this.record});

  final ConsultationRecord record;

  @override
  Widget build(BuildContext context) {
    final items = record.prescribedItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Prescription'),
        BentoCard(
          key: ConsultationDetailKeys.prescription,
          padding: const EdgeInsets.symmetric(
            vertical: BentoSpace.listCardPad,
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                _PrescriptionRow(item: items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow({required this.item});

  final PrescriptionItem item;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.sig.isNotEmpty) item.sig,
      if ((item.instructions ?? '').trim().isNotEmpty) item.instructions!,
    ].join(' · ');

    return BentoRow(
      title: item.drugName.isEmpty ? 'Unnamed drug' : item.drugName,
      subtitle: subtitle.isEmpty ? null : subtitle,
      subtitleMaxLines: 2,
      icon: Icons.medication_outlined,
      showChevron: false,
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 10,
      ),
      // A dispensed count is a clinical figure: tabular, and never ellipsised.
      trailing: VitalFigure(value: '${item.quantity}', unit: 'units', size: 15),
    );
  }
}

class _LabOrders extends StatelessWidget {
  const _LabOrders({required this.orders});

  final List<LabOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Laboratory'),
        BentoCard(
          key: ConsultationDetailKeys.labOrders,
          padding: const EdgeInsets.symmetric(
            vertical: BentoSpace.listCardPad,
          ),
          child: Column(
            children: [
              for (var i = 0; i < orders.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                _OrderRow(
                  title: orders[i].orderNumber.isEmpty
                      ? 'Laboratory order'
                      : orders[i].orderNumber,
                  subtitle: orders[i].testSummary,
                  status: orders[i].status,
                  // Two tints, not the laboratory's six-state ramp: on a
                  // consultation an order is read for one thing — has it come
                  // back — and the worklist's own vocabulary lives in the
                  // laboratory module rather than being restated here.
                  back: orders[i].results.isNotEmpty,
                  icon: Icons.biotech_outlined,
                  onTap: () => Get.toNamed<void>(
                    LabRoutes.order(orders[i].id),
                    arguments: {'id': orders[i].id},
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ImagingOrders extends StatelessWidget {
  const _ImagingOrders({required this.orders});

  final List<RadiologyOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Imaging'),
        BentoCard(
          key: ConsultationDetailKeys.radiologyOrders,
          padding: const EdgeInsets.symmetric(
            vertical: BentoSpace.listCardPad,
          ),
          child: Column(
            children: [
              for (var i = 0; i < orders.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                _OrderRow(
                  title: orders[i].examName,
                  subtitle: orders[i].orderNumber,
                  status: orders[i].status,
                  back: orders[i].isReported,
                  icon: Icons.monitor_heart_outlined,
                  onTap: () => Get.toNamed<void>(
                    RadiologyRoutes.orderFor(orders[i].id),
                    arguments: {'id': orders[i].id},
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.back,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final bool back;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BentoRow(
      title: title,
      subtitle: subtitle.trim().isEmpty ? null : subtitle,
      subtitleMaxLines: 2,
      icon: icon,
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 10,
      ),
      trailing: StatusPill(
        status: status,
        label: Formatters.label(status),
        color: back ? AppColors.acuityStable : AppColors.acuityRoutine,
        compact: true,
      ),
      onTap: onTap,
    );
  }
}

// ── Actions ─────────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final ConsultationDetailController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasActions) {
      return const NoticeBanner(
        key: ConsultationDetailKeys.noActions,
        message: 'This account can read consultations but not act on them.',
        icon: Icons.lock_outline_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'From here'),
        BentoCard(
          padding: const EdgeInsets.symmetric(
            vertical: BentoSpace.listCardPad,
            horizontal: 6,
          ),
          child: Column(
            children: [
              if (controller.canOrderLab)
                SheetRow(
                  key: ConsultationDetailKeys.orderLab,
                  icon: Icons.biotech_outlined,
                  label: 'Order a test',
                  sublabel: 'Raised against this consultation',
                  onTap: () => Get.toNamed<void>(
                    LabRoutes.orderNew,
                    arguments: controller.linkArguments,
                  ),
                ),
              if (controller.canOrderImaging)
                SheetRow(
                  key: ConsultationDetailKeys.orderImaging,
                  icon: Icons.monitor_heart_outlined,
                  label: 'Order imaging',
                  sublabel: 'Raised against this consultation',
                  onTap: () => Get.toNamed<void>(
                    RadiologyRoutes.orderNew,
                    arguments: controller.linkArguments,
                  ),
                ),
              if (controller.canInvoice)
                SheetRow(
                  key: ConsultationDetailKeys.newInvoice,
                  icon: Icons.receipt_long_outlined,
                  label: 'New invoice',
                  sublabel: 'Bill this visit',
                  onTap: () => Get.toNamed<void>(
                    Routes.BILLING,
                    arguments: controller.linkArguments,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
