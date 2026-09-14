import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/pharmacy_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/dispense_controller.dart';
import 'pharmacy_view.dart';

/// Handing a prescription over the counter.
///
/// Every line opens at the largest amount that will actually fit — the whole
/// prescription when the shelf can cover it, what is left when it cannot —
/// because handing the lot over is what happens nearly every time. A
/// pharmacist lowers the exception rather than typing the rule.
class DispenseView extends GetView<DispenseController> {
  const DispenseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No subtitle naming the patient: an `AppBar` cannot sit inside an
      // `Obx`, so a deep-linked dispense would carry a blank one until the
      // record landed and then never fill it in. The identity band below does
      // the job, reactively and in the form every clinical screen uses.
      appBar: const DetailHeader(title: 'Dispense'),
      body: Obx(() {
        if (controller.isLoading && controller.rxFirstLoad.value) {
          return const BentoScreen(
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 2)),
              BentoSection(child: BentoSkeleton(rows: 4)),
            ],
          );
        }

        if (controller.hasNoAccess || !controller.canDispense) {
          return const BentoScreen(
            slivers: [
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  key: PharmacyKeys.noAccess,
                  icon: Icons.lock_outline_rounded,
                  title: 'Dispensing is not part of your role',
                  message: 'An administrator can give your account permission '
                      'to hand prescriptions over.',
                ),
              ),
            ],
          );
        }

        final record = controller.prescription.value;
        final lines = controller.lines;

        return BentoScreen(
          key: PharmacyKeys.dispenseScreen,
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
            BentoSection(
              top: controller.hasLoadError ? 0 : BentoSpace.page,
              child: PatientIdentityBand(
                name: record.patient.displayName,
                mrn: record.patient.mrn,
                age: record.patient.age,
                sex: record.patient.gender,
              ),
            ),
            if (lines.isEmpty)
              const BentoSection(
                child: EmptyState(
                  icon: Icons.medication_outlined,
                  title: 'There is nothing on this prescription',
                  message: 'Nothing was written against it, so there is '
                      'nothing to hand over.',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BentoSpace.page,
                    0,
                    BentoSpace.page,
                    BentoSpace.header,
                  ),
                  child: Column(
                    key: PharmacyKeys.dispenseLines,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in lines) ...[
                        _DispenseLineCard(line: line),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              _payment(context),
              _summary(context),
            ],
          ],
        );
      }),
    );
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  Widget _payment(BuildContext context) => BentoSection(
        child: FormCard(
          title: 'Payment',
          children: [
            AsyncPicker<String>(
              fieldKey: PharmacyKeys.dispensePaymentMethod,
              label: 'Method',
              valueLabel: Formatters.label(controller.paymentMethod.value),
              options: [
                for (final method in DispenseController.paymentMethods)
                  PickerOption<String>(
                    value: method,
                    label: Formatters.label(method),
                  ),
              ],
              onSelected: controller.setPaymentMethod,
            ),
            AsyncPicker<String>(
              fieldKey: PharmacyKeys.dispensePaymentStatus,
              label: 'Status',
              valueLabel: Formatters.label(controller.paymentStatus.value),
              options: [
                for (final status in DispenseController.paymentStatuses)
                  PickerOption<String>(
                    value: status,
                    label: Formatters.label(status),
                  ),
              ],
              onSelected: controller.setPaymentStatus,
            ),
          ],
        ),
      );

  // ── The total, and the tap ────────────────────────────────────────────────

  Widget _summary(BuildContext context) {
    final short = controller.shortLines.value;
    final failure = controller.failure.value;

    return BentoSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BentoCard(
            key: PharmacyKeys.dispenseTotal,
            hero: true,
            child: MoneyFigure(
              label: 'TO PAY',
              // The site's own currency, read from settings. A symbol written
              // into a screen is a symbol that is wrong somewhere.
              amount: controller.totalLabel,
              caption: short == 0
                  ? 'Everything on the prescription is going out'
                  : '$short of ${controller.lines.length} '
                      '${controller.lines.length == 1 ? 'drug' : 'drugs'} '
                      'short — the rest stays owed',
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: BentoSpace.action),
            NoticeBanner(
              key: PharmacyKeys.dispenseError,
              message: failure,
              icon: Icons.inventory_2_outlined,
              // Amber: the shelf is short, which is an administrative problem
              // and not a clinical one. Nothing about it is an emergency.
              tint: AppColors.warning,
            ),
          ],
          const SizedBox(height: BentoSpace.action),
          PrimaryBar(
            key: PharmacyKeys.dispenseConfirm,
            label: controller.isFullDispense
                ? 'Dispense and take payment'
                : 'Dispense what is in stock',
            icon: Icons.check_rounded,
            busy: controller.submitting.value,
            enabled: !controller.isEmptyDispense,
            onPressed: controller.confirm,
          ),
        ],
      ),
    );
  }
}

/// One drug going over the counter: what was written, what is on the shelf,
/// what is actually going out, and what that comes to.
class _DispenseLineCard extends StatelessWidget {
  const _DispenseLineCard({required this.line});

  final DispenseLine line;

  @override
  Widget build(BuildContext context) {
    final controller = DispenseController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final drug = line.drug.value;
      final tone = line.isUnstocked ? AppColors.warning : stockTone(drug);
      final sig = line.item.sig;

      return BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.item.drugName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: isDark
                  ? AppTextStyles.darkHeadline()
                  : AppTextStyles.lightHeadline(),
            ),
            if (sig.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sig,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: isDark
                    ? AppTextStyles.darkFootnote()
                    : AppTextStyles.lightFootnote(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Reading(
                    label: 'PRESCRIBED',
                    value: '${line.prescribed}',
                    unit: drug.unitOfMeasure,
                  ),
                ),
                Expanded(
                  child: _Reading(
                    label: 'ON THE SHELF',
                    value: line.isUnstocked ? '—' : '${line.stock}',
                    unit: line.isUnstocked ? null : drug.unitOfMeasure,
                    // Amber when the shelf cannot cover the prescription, and
                    // never red: an empty shelf is an administrative problem.
                    tone: tone,
                    caption: line.isUnstocked
                        ? 'Not in the catalogue'
                        : stockWord(drug),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            QuantityField(
              fieldKey: PharmacyKeys.dispenseQuantity(line.item.drugId),
              label: 'Dispensing',
              controller: line.field,
              enabled: line.cap > 0,
              onChanged: (raw) => controller.setQuantity(line, raw),
            ),
            const SizedBox(height: 10),
            const Hairline(),
            const SizedBox(height: 10),
            FactRow(
              label: 'Unit price',
              value: controller.moneyOf(line.unitPrice),
              dense: true,
              inset: false,
            ),
            KeyedSubtree(
              key: PharmacyKeys.dispenseLineTotal(line.item.drugId),
              child: FactRow(
                label: 'Line total',
                value: controller.moneyOf(line.total),
                dense: true,
                inset: false,
              ),
            ),
            if (line.isShort && line.cap > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${line.prescribed - line.quantity.value} still owed after this',
                style: AppFonts.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: semanticInk(context, AppColors.warning),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// A labelled figure inside a dispense line.
class _Reading extends StatelessWidget {
  const _Reading({
    required this.label,
    required this.value,
    this.unit,
    this.tone,
    this.caption,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? tone;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.overline(Theme.of(context).brightness)),
        const SizedBox(height: 4),
        VitalFigure(value: value, unit: unit, size: 19, tone: tone),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.text(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tone == null
                  ? tertiaryLabelColor(context)
                  : semanticInk(context, tone!),
            ),
          ),
        ],
      ],
    );
  }
}
