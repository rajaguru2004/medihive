import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/pharmacy_keys.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/pharmacy_sale.dart';
import '../../../data/models/prescription.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/pharmacy_controller.dart';
import '../pharmacy_routes.dart';

/// The dispensing counter.
///
/// Figures first, because the question a pharmacist arrives with is "what is
/// waiting and what have I run out of", then one of three views of the same
/// department: the queue to dispense, the shelf, and what has gone over the
/// counter today. Everything past this screen — a prescription, a dispense, a
/// catalogue entry, a walk-in sale — is pushed, so each is deep-linkable.
class PharmacyView extends GetView<PharmacyController> {
  const PharmacyView({super.key, this.embedded = true});

  /// True inside the shell's tab stack, false when this screen was pushed.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      if (controller.isLoading && controller.rxFirstLoad.value) {
        return _PharmacySkeleton(embedded: embedded);
      }

      return BentoScreen(
        key: PharmacyKeys.screen,
        onRefresh: controller.reload,
        bottomClearance: false,
        // The shell already paints the washed ground; a tab that paints its
        // own on top leaves a seam exactly where the two meet.
        ground: !embedded,
        slivers: [
          if (controller.hasNoAccess)
            const BentoSection(
              top: BentoSpace.page,
              child: EmptyState(
                key: PharmacyKeys.noAccess,
                icon: Icons.lock_outline_rounded,
                title: 'The pharmacy is not part of your role',
                message: 'An administrator can give your account access to '
                    'dispensing and the drug catalogue.',
              ),
            )
          else ...[
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  key: PharmacyKeys.error,
                  message: controller.rxLoadError.value!,
                  onRetry: controller.load,
                ),
              ),
            _statsSection(context, top: controller.hasLoadError ? 0 : null),
            BentoSection(
              child: BentoSegmented<PharmacyCounter>(
                key: PharmacyKeys.segmented,
                options: PharmacyCounter.values,
                selected: controller.counter.value,
                onSelected: (next) => controller.counter.value = next,
                labelOf: _counterLabel,
                keyOf: (counter) => PharmacyKeys.segment(counter.name),
              ),
            ),
            ...switch (controller.counter.value) {
              PharmacyCounter.dispense => _dispenseSlivers(),
              PharmacyCounter.inventory => _inventorySlivers(context),
              PharmacyCounter.sales => _salesSlivers(context),
            },
          ],
        ],
      );
    });

    if (embedded) return body;
    return Scaffold(appBar: const DetailHeader(title: 'Pharmacy'), body: body);
  }

  // ── Figures ───────────────────────────────────────────────────────────────

  Widget _statsSection(BuildContext context, {double? top}) {
    final stats = controller.stats.value;
    return BentoSection(
      top: top ?? BentoSpace.page,
      child: BentoCard(
        key: PharmacyKeys.stats,
        hero: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoneyFigure(
              label: 'TAKEN TODAY',
              amount: SettingsService.to.money(stats.todaySales),
              caption: '${stats.pendingPrescriptions} '
                  '${stats.pendingPrescriptions == 1 ? 'prescription' : 'prescriptions'} '
                  'still to dispense',
            ),
            const SizedBox(height: 18),
            const Hairline(),
            const SizedBox(height: 18),
            FigureGrid(
              figures: [
                Figure(label: 'On the shelf', value: '${stats.totalDrugs}'),
                Figure(
                  label: 'To dispense',
                  value: '${stats.pendingPrescriptions}',
                ),
                // Amber, never red. An empty shelf is an administrative
                // problem; red on this app means a patient is deteriorating,
                // and every red that is not one costs that scan its meaning.
                Figure(
                  label: 'Low stock',
                  value: '${stats.lowStock}',
                  color: stats.lowStock > 0 ? AppColors.warning : null,
                ),
                Figure(
                  label: 'Out of stock',
                  value: '${stats.outOfStock}',
                  color: stats.outOfStock > 0 ? AppColors.warning : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── To dispense ───────────────────────────────────────────────────────────

  List<Widget> _dispenseSlivers() {
    final waiting = controller.prescriptions;

    if (waiting.isEmpty) {
      return const [
        BentoSection(
          child: EmptyState(
            key: PharmacyKeys.prescriptionsEmpty,
            icon: Icons.medication_liquid_outlined,
            title: 'Nothing is waiting to be dispensed',
            message: 'Prescriptions a clinician writes arrive here for the '
                'counter to hand over.',
          ),
        ),
      ];
    }

    return [
      BentoSection(
        child: BentoCard(
          key: PharmacyKeys.prescriptionsList,
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: Column(
            children: [
              for (var i = 0; i < waiting.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                PrescriptionRow(
                  key: PharmacyKeys.prescription(waiting[i].id),
                  prescription: waiting[i],
                  onTap: () => _openPrescription(waiting[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  // ── Inventory ─────────────────────────────────────────────────────────────

  List<Widget> _inventorySlivers(BuildContext context) {
    final shelf = controller.drugs;
    final categories = controller.categories;

    return [
      BentoSection(
        bottom: categories.isEmpty ? BentoSpace.section : 10,
        child: SearchField(
          // Rebuilt from scratch when the filters are cleared elsewhere: the
          // field keeps its text in its own State, and `initial` is only read
          // once.
          key: ValueKey<int>(controller.searchEpoch.value),
          fieldKey: PharmacyKeys.inventorySearch,
          hint: 'Name, generic or code',
          initial: controller.search.value,
          onChanged: controller.searchDrugs,
        ),
      ),
      if (categories.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: BentoSpace.section),
            child: FilterChips<String>(
              key: PharmacyKeys.inventoryFilters,
              // The empty string is "every category" — a sentinel rather than
              // a nullable selection, because `FilterChips` compares options
              // by equality and null is not one of them.
              options: [_allCategories, ...categories],
              selected: controller.category.value ?? _allCategories,
              onSelected: (next) => controller.filterByCategory(
                next == _allCategories ? null : next,
              ),
              labelOf: (value) =>
                  value == _allCategories ? 'All' : Formatters.label(value),
              keyOf: (value) => PharmacyKeys.category(
                value == _allCategories ? 'all' : value,
              ),
            ),
          ),
        ),
      if (controller.canCreate)
        BentoSection(
          child: QuickActionTile(
            key: PharmacyKeys.addDrug,
            icon: Icons.add_rounded,
            label: 'Add a drug',
            onTap: () => Get.toNamed<void>(PharmacyRoutes.drugForm),
          ),
        ),
      if (shelf.isEmpty)
        BentoSection(
          child: EmptyState(
            key: PharmacyKeys.inventoryEmpty,
            icon: Icons.inventory_2_outlined,
            title: controller.isFiltered
                ? 'Nothing on the shelf matches'
                : 'The catalogue is empty',
            message: controller.isFiltered
                ? 'Try a different name, or clear the filter.'
                : 'A drug has to be in the catalogue before it can be '
                    'prescribed or sold.',
            actionLabel: controller.isFiltered ? 'Clear filters' : null,
            onAction: controller.isFiltered ? controller.clearFilters : null,
          ),
        )
      else
        BentoSection(
          child: BentoCard(
            key: PharmacyKeys.inventoryList,
            padding: const EdgeInsets.symmetric(
              vertical: BentoSpace.listCardPad,
            ),
            child: Column(
              children: [
                for (var i = 0; i < shelf.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  DrugRow(
                    key: PharmacyKeys.drug(shelf[i].id),
                    drug: shelf[i],
                    onTap: controller.canUpdate
                        ? () => Get.toNamed<void>(
                              PharmacyRoutes.drugForm,
                              arguments: {'drug': shelf[i]},
                            )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  // ── Sales ─────────────────────────────────────────────────────────────────

  List<Widget> _salesSlivers(BuildContext context) {
    final today = controller.sales;

    return [
      BentoSection(
        child: DateField(
          fieldKey: PharmacyKeys.salesDate,
          label: 'Sales on',
          value: controller.salesDate.value,
          format: SettingsService.to.date,
          onChanged: controller.showSalesFor,
        ),
      ),
      if (controller.canCreate)
        BentoSection(
          child: QuickActionTile(
            key: PharmacyKeys.newSale,
            icon: Icons.point_of_sale_outlined,
            label: 'Over-the-counter sale',
            onTap: () => Get.toNamed<void>(PharmacyRoutes.saleForm),
          ),
        ),
      if (today.isEmpty)
        const BentoSection(
          child: EmptyState(
            key: PharmacyKeys.salesEmpty,
            icon: Icons.receipt_long_outlined,
            title: 'Nothing has gone over the counter',
            message: 'Sales rung up on this day will be listed here with '
                'their receipts.',
          ),
        )
      else
        BentoSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Receipts',
                actionLabel: SettingsService.to.money(controller.salesTotal),
              ),
              BentoCard(
                key: PharmacyKeys.salesList,
                padding: const EdgeInsets.symmetric(
                  vertical: BentoSpace.listCardPad,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < today.length; i++) ...[
                      if (i > 0) const Hairline(indent: BentoSpace.listPad),
                      SaleRow(
                        key: PharmacyKeys.sale(today[i].id),
                        sale: today[i],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  void _openPrescription(Prescription prescription) {
    Get.toNamed<void>(
      PharmacyRoutes.prescriptionDetailFor(prescription.id),
      // Handed over rather than looked up: there is no `GET
      // /prescriptions/:id`, so the alternative is fetching the whole
      // collection to find the row this screen is already holding.
      arguments: {'prescription': prescription},
    );
  }

  static const String _allCategories = '';

  static String _counterLabel(PharmacyCounter counter) => switch (counter) {
        PharmacyCounter.dispense => 'To dispense',
        PharmacyCounter.inventory => 'Inventory',
        PharmacyCounter.sales => 'Sales',
      };
}

/// The colour a prescription's dispensing state earns.
///
/// Resolved here rather than through `CaseStatus`, which reads the two
/// dispensing states as "routine" — they are not routine, they are the
/// difference between a patient who has their drugs and one who does not.
/// Nothing here is red: a prescription nobody has handed over yet is an
/// administrative state, and red on this app means a patient is deteriorating.
Color prescriptionTone(String status) => switch (status.trim().toLowerCase()) {
      'pending' => AppColors.acuityReview,
      'partially_dispensed' => AppColors.warning,
      'fully_dispensed' => AppColors.acuityStable,
      'cancelled' => AppColors.acuityDischarged,
      _ => AppColors.acuityRoutine,
    };

/// Amber for a shelf that needs attention, and null — the row's own ink — for
/// one that does not.
///
/// **Never red.** This is the rule the pharmacy exists to test: a drug that has
/// run out is somebody's afternoon, not somebody's emergency.
Color? stockTone(Drug drug) =>
    drug.isOutOfStock || drug.isLowStock ? AppColors.warning : null;

/// What a stock figure is called, so the colour is never carrying it alone.
String stockWord(Drug drug) {
  if (drug.isOutOfStock) return 'Out of stock';
  if (drug.isLowStock) return 'Low · reorder at ${drug.reorderLevel}';
  if (drug.reorderLevel > 0) return 'Reorder at ${drug.reorderLevel}';
  return 'In stock';
}

/// One prescription waiting at the counter.
///
/// Shared with the prescription screen's header, so a script reads the same
/// wherever it appears.
class PrescriptionRow extends StatelessWidget {
  const PrescriptionRow({
    super.key,
    required this.prescription,
    this.onTap,
  });

  final Prescription prescription;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final items = prescription.itemSummary;
    final mrn = prescription.patient.mrn;
    return PersonRow(
      name: prescription.patient.displayName,
      // The MRN leads the subtitle rather than sitting in the trailing detail
      // column. That column is capped so the name can breathe, and at 1.3×
      // text the cap cut the MRN to "MRN 104…" — ellipsising the identifier a
      // pharmacist checks the patient against, which is the one thing a
      // clinical row may never do. Here it is first in the line, so what runs
      // out of room is the drug list, which the detail screen carries in full.
      subtitle: [
        if (mrn.isNotEmpty) 'MRN $mrn',
        if (items.isNotEmpty) items else 'No drugs on this prescription',
      ].join(' · '),
      onTap: onTap,
      trailing: StatusPill(
        status: prescription.status,
        color: prescriptionTone(prescription.status),
      ),
    );
  }
}

/// One drug on the shelf, with its stock read against its reorder level.
///
/// The bar is the point: "12 left" means nothing without knowing the product,
/// and a bar that is short of full says "below the line somebody set" at a
/// glance. Full means at or above the reorder level; there is no bar at all
/// where the site never set one, because there is then nothing to be short of.
class DrugRow extends StatelessWidget {
  const DrugRow({super.key, required this.drug, this.onTap});

  final Drug drug;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = stockTone(drug);
    final facts = [
      if ((drug.drugCategory ?? '').isNotEmpty)
        Formatters.label(drug.drugCategory),
      if ((drug.genericName ?? '').isNotEmpty) drug.genericName!,
      if ((drug.storageLocation ?? '').isNotEmpty) drug.storageLocation!,
    ].join(' · ');

    return BentoRow(
      title: drug.displayName,
      subtitle: facts.isEmpty ? null : facts,
      onTap: onTap,
      showChevron: onTap != null,
      trailing: SizedBox(
        key: PharmacyKeys.drugStock(drug.id),
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            VitalFigure(
              value: '${drug.quantityInStock}',
              unit: drug.unitOfMeasure,
              size: 15,
              tone: tone,
            ),
            const SizedBox(height: 3),
            Text(
              stockWord(drug),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppFonts.text(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tone == null
                    ? tertiaryLabelColor(context)
                    : semanticInk(context, tone),
              ),
            ),
            if (drug.reorderLevel > 0) ...[
              const SizedBox(height: 6),
              UsedBar(
                fraction: (drug.quantityInStock / drug.reorderLevel).clamp(0, 1),
                color: tone ?? AppColors.acuityRoutine,
                height: 4,
              ),
            ],
            if (drug.expiringStock()) ...[
              const SizedBox(height: 4),
              Text(
                'Batch expired',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isDark
                    ? AppTextStyles.darkCaption2()
                    : AppTextStyles.lightCaption2(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One receipt.
class SaleRow extends StatelessWidget {
  const SaleRow({super.key, required this.sale});

  final PharmacySale sale;

  @override
  Widget build(BuildContext context) {
    final patient = sale.patient.isEmpty ? 'Walk-in' : sale.patient.displayName;
    return DocumentRow(
      number: sale.receiptNumber,
      title: patient,
      amount: SettingsService.to.money(sale.totalAmount),
      subtitle: [
        '${sale.itemCount} ${sale.itemCount == 1 ? 'line' : 'lines'}',
        if ((sale.paymentMethod ?? '').isNotEmpty)
          Formatters.label(sale.paymentMethod),
        SettingsService.to.time(sale.saleDate),
      ].join(' · '),
      status: CaseStatus.labelOf(sale.paymentStatus),
      statusColor: sale.isPaid ? AppColors.acuityStable : AppColors.warning,
    );
  }
}

class _PharmacySkeleton extends StatelessWidget {
  const _PharmacySkeleton({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BentoScreen(
      bottomClearance: false,
      ground: !embedded,
      slivers: const [
        BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 3)),
        BentoSection(child: BentoSkeleton(rows: 5)),
      ],
    );
  }
}
