import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/pharmacy_keys.dart';
import '../../../data/models/prescription.dart';
import '../../../data/services/settings_service.dart';
import '../../../theme/theme.dart';
import '../controllers/prescription_detail_controller.dart';
import 'pharmacy_view.dart';

/// One prescription, as the counter reads it before handing it over.
///
/// Who it is for comes first and in the band every clinical screen in this app
/// uses, because the single most expensive mistake at a counter is dispensing
/// the right drugs to the wrong person.
class PrescriptionDetailView extends GetView<PrescriptionDetailController> {
  const PrescriptionDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Prescription'),
      body: Obx(() {
        if (controller.isLoading && controller.rxFirstLoad.value) {
          return const BentoScreen(
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 2)),
              BentoSection(child: BentoSkeleton(rows: 4)),
            ],
          );
        }

        if (controller.hasNoAccess) {
          return const BentoScreen(
            slivers: [
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  key: PharmacyKeys.noAccess,
                  icon: Icons.lock_outline_rounded,
                  title: 'The pharmacy is not part of your role',
                  message: 'An administrator can give your account access to '
                      'dispensing.',
                ),
              ),
            ],
          );
        }

        final record = controller.prescription.value;

        return BentoScreen(
          key: PharmacyKeys.prescriptionScreen,
          onRefresh: controller.reload,
          bottomClearance: false,
          slivers: [
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  key: PharmacyKeys.error,
                  message: controller.rxLoadError.value!,
                  onRetry: controller.load,
                ),
              ),
            if (record.isEmpty)
              const BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  key: PharmacyKeys.prescriptionMissing,
                  icon: Icons.receipt_long_outlined,
                  title: 'That prescription is no longer here',
                  message: 'It may have been cancelled, or the link is from an '
                      'older version of the app.',
                ),
              )
            else ...[
              _identity(record),
              _facts(context, record),
              _items(context, record),
              if (controller.canUpdate && record.isOutstanding) _actions(record),
            ],
          ],
        );
      }),
    );
  }

  Widget _identity(Prescription record) => BentoSection(
        top: controller.hasLoadError ? 0 : BentoSpace.page,
        child: PatientIdentityBand(
          name: record.patient.displayName,
          mrn: record.patient.mrn,
          age: record.patient.age,
          sex: record.patient.gender,
          extra: record.doctor.fullName.isEmpty
              ? null
              : 'Prescribed by ${record.doctor.fullName}',
        ),
      );

  Widget _facts(BuildContext context, Prescription record) => BentoSection(
        child: BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FactRow(
                label: 'Status',
                value: CaseStatus.labelOf(record.status),
                valueWidget: StatusPill(
                  status: record.status,
                  color: prescriptionTone(record.status),
                ),
              ),
              FactRow(
                label: 'Written',
                value: SettingsService.to.date(record.prescriptionDate),
              ),
              if (record.doctor.fullName.isNotEmpty)
                FactRow(label: 'Prescriber', value: record.doctor.fullName),
              if (record.dispensedAt != null)
                FactRow(
                  label: 'Dispensed',
                  value: '${SettingsService.to.date(record.dispensedAt)} '
                      '${SettingsService.to.time(record.dispensedAt)}',
                ),
              if ((record.notes ?? '').trim().isNotEmpty)
                FactRow(
                  label: 'Notes',
                  value: record.notes!.trim(),
                  stacked: true,
                ),
            ],
          ),
        ),
      );

  Widget _items(BuildContext context, Prescription record) {
    final items = record.items;
    if (items.isEmpty) {
      return const BentoSection(
        child: EmptyState(
          icon: Icons.medication_outlined,
          title: 'No drugs on this prescription',
          message: 'Nothing was written against it, so there is nothing to '
              'dispense.',
          compact: true,
        ),
      );
    }

    return BentoSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Drugs',
            actionLabel: '${items.length}',
          ),
          BentoCard(
            key: PharmacyKeys.prescriptionItems,
            padding: const EdgeInsets.symmetric(
              vertical: BentoSpace.listCardPad,
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  _PrescriptionItemRow(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(Prescription record) => BentoSection(
        child: Column(
          children: [
            PrimaryBar(
              key: PharmacyKeys.dispenseAction,
              label: 'Dispense',
              icon: Icons.local_pharmacy_outlined,
              enabled: controller.canDispense,
              onPressed: controller.openDispense,
            ),
            const SizedBox(height: BentoSpace.action),
            SecondaryBar(
              key: PharmacyKeys.cancelAction,
              label: 'Cancel prescription',
              icon: Icons.block_outlined,
              destructive: true,
              onPressed: controller.cancelling.value ? null : controller.cancel,
            ),
          ],
        ),
      );
}

/// One drug as the prescriber wrote it: the sig, and the count to hand over.
class _PrescriptionItemRow extends StatelessWidget {
  const _PrescriptionItemRow({required this.item});

  final PrescriptionItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sig = item.sig;
    final instructions = (item.instructions ?? '').trim();

    return BentoRow(
      title: item.drugName,
      subtitle: [
        if (sig.isNotEmpty) sig,
        if (instructions.isNotEmpty) instructions,
      ].join('\n'),
      subtitleMaxLines: 2,
      showChevron: false,
      trailing: SizedBox(
        width: 86,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Never ellipsised: "16…" could be 160, 168 or 16, and the count
            // is what somebody is about to put in a bag.
            VitalFigure(value: '${item.quantity}', size: 17),
            Text(
              'to give',
              style: isDark
                  ? AppTextStyles.darkCaption2()
                  : AppTextStyles.lightCaption2(),
            ),
          ],
        ),
      ),
    );
  }
}
