import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/pharmacy_keys.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/patient_ref.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/sale_form_controller.dart';
import 'pharmacy_view.dart';

/// A walk-in sale.
///
/// The patient is optional and stays optional: an over-the-counter purchase has
/// no patient record, and inventing one to satisfy a form puts a stranger's
/// paracetamol on somebody's chart.
class SaleFormView extends GetView<SaleFormController> {
  const SaleFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Over-the-counter sale'),
      body: BentoGround(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(BentoSpace.page),
                  child: MaxWidthBody(
                    maxWidth: 560,
                    child: Column(
                      key: PharmacyKeys.saleForm,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Obx(() {
                          final error = controller.errorMessage.value;
                          if (error == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: NoticeBanner(
                              message: error,
                              icon: Icons.inventory_2_outlined,
                              // Amber: a shelf that cannot cover a sale is an
                              // administrative problem, not a clinical one.
                              tint: AppColors.warning,
                            ),
                          );
                        }),
                        _who(),
                        const SizedBox(height: BentoSpace.section),
                        _lines(context),
                        const SizedBox(height: BentoSpace.section),
                        _payment(),
                      ],
                    ),
                  ),
                ),
              ),
              _saveBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _who() => FormCard(
        title: 'Who it is for',
        children: [
          Obx(
            () => AsyncPicker<PatientRef>(
              fieldKey: PharmacyKeys.salePatientPicker,
              label: 'Patient',
              placeholder: 'Walk-in — no record',
              valueLabel: controller.patient.value?.displayName,
              hint: 'Leave this alone for a counter sale to somebody who is '
                  'not registered here',
              onSearch: controller.searchPatients,
              onSelected: controller.setPatient,
            ),
          ),
        ],
      );

  Widget _lines(BuildContext context) => Obx(() {
        final lines = controller.lines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormCard(
              title: 'What is being sold',
              children: [
                AsyncPicker<Drug>(
                  fieldKey: PharmacyKeys.saleDrugPicker,
                  label: 'Add a drug',
                  valueLabel: null,
                  placeholder: 'Search the shelf',
                  // The picker shows what is left and what it costs, because
                  // both decide whether this line can be rung up at all.
                  onSearch: controller.searchDrugs,
                  onSelected: controller.addDrug,
                ),
              ],
            ),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: BentoSpace.section),
                child: EmptyState(
                  key: PharmacyKeys.saleEmpty,
                  icon: Icons.shopping_basket_outlined,
                  title: 'Nothing on this sale yet',
                  message: 'Search the shelf above to add the first line.',
                  compact: true,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: BentoSpace.section),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in lines) ...[
                      _SaleLineCard(line: line),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
          ],
        );
      });

  Widget _payment() => FormCard(
        title: 'Payment',
        children: [
          Obx(
            () => AsyncPicker<String>(
              fieldKey: PharmacyKeys.salePaymentMethod,
              label: 'Method',
              valueLabel: Formatters.label(controller.paymentMethod.value),
              options: [
                for (final method in controller.paymentMethods)
                  PickerOption<String>(
                    value: method,
                    label: Formatters.label(method),
                  ),
              ],
              onSelected: controller.setPaymentMethod,
            ),
          ),
          Obx(
            () => AsyncPicker<String>(
              fieldKey: PharmacyKeys.salePaymentStatus,
              label: 'Status',
              valueLabel: Formatters.label(controller.paymentStatus.value),
              options: [
                for (final status in controller.paymentStatuses)
                  PickerOption<String>(
                    value: status,
                    label: Formatters.label(status),
                  ),
              ],
              onSelected: controller.setPaymentStatus,
            ),
          ),
        ],
      );

  Widget _saveBar() => Padding(
        padding: const EdgeInsets.fromLTRB(
          BentoSpace.page,
          0,
          BentoSpace.page,
          BentoSpace.page,
        ),
        child: MaxWidthBody(
          maxWidth: 560,
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BentoCard(
                  key: PharmacyKeys.saleTotal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: BentoSpace.cardPad,
                    vertical: 14,
                  ),
                  child: MoneyFigure(
                    label: 'TO PAY',
                    amount: controller.totalLabel,
                    size: 26,
                    caption: '${controller.lines.length} '
                        '${controller.lines.length == 1 ? 'line' : 'lines'}',
                  ),
                ),
                const SizedBox(height: BentoSpace.action),
                PrimaryBar(
                  key: PharmacyKeys.saleSave,
                  label: 'Ring it up',
                  icon: Icons.point_of_sale_outlined,
                  busy: controller.submitting.value,
                  enabled: controller.lines.isNotEmpty,
                  onPressed: controller.save,
                ),
              ],
            ),
          ),
        ),
      );
}

/// One line of a walk-in sale.
class _SaleLineCard extends StatelessWidget {
  const _SaleLineCard({required this.line});

  final SaleLine line;

  @override
  Widget build(BuildContext context) {
    final controller = SaleFormController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(
      () => BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.drug.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: isDark
                        ? AppTextStyles.darkHeadline()
                        : AppTextStyles.lightHeadline(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleIconButton(
                  key: PharmacyKeys.saleRemoveLine(line.drug.id),
                  icon: Icons.close_rounded,
                  tooltip: 'Remove this line',
                  onTap: () => controller.removeLine(line),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              stockWord(line.drug),
              style: AppFonts.text(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: stockTone(line.drug) == null
                    ? tertiaryLabelColor(context)
                    : semanticInk(context, stockTone(line.drug)!),
              ),
            ),
            const SizedBox(height: 12),
            QuantityField(
              fieldKey: PharmacyKeys.saleQuantity(line.drug.id),
              label: 'Quantity',
              controller: line.field,
              min: 1,
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
            FactRow(
              label: 'Line total',
              value: controller.moneyOf(line.total),
              dense: true,
              inset: false,
            ),
          ],
        ),
      ),
    );
  }
}
