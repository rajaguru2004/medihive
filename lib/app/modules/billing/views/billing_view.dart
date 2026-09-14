import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/billing_keys.dart';
import '../../../core/window_class.dart';
import '../../../data/models/billing_service.dart';
import '../../../data/models/invoice.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../billing_invoice_detail/views/invoice_detail_view.dart';
import '../billing_routes.dart';
import '../billing_status.dart';
import '../controllers/billing_controller.dart';

/// The ledger.
///
/// Five figures, then one of two lists: the bills raised, or the catalogue they
/// are raised from. Both halves are on one screen because they are one job —
/// somebody adding a charge to the price list is the same person raising the
/// invoice that uses it half an hour later.
///
/// **The colours here are load-bearing.** Billing's own colour is
/// `AppColors.accent`, the ledger blue, and an overdue invoice is
/// `AppColors.warning` — amber. Never `acuityCritical`: a clinician scans a
/// ward board for red, and a bill that borrows it costs that scan its meaning.
/// [InvoiceStatus] is the one place that decision is made.
class BillingView extends GetView<BillingController> {
  const BillingView({super.key, this.embedded = true});

  /// False when pushed as its own route rather than shown inside the shell.
  ///
  /// The difference is the header and the bottom clearance, nothing else — a
  /// screen that renders differently depending on where it is mounted is two
  /// screens pretending to be one.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // The root of the build reads `controller` before anything else. A GetView
    // whose build never touches it never constructs its `lazyPut` controller,
    // which means `onReady` never runs and the screen loads nothing — the trap
    // that hung the splash screen for a debugging session.
    final billing = controller;

    final body = Obx(() {
      if (billing.hasNoAccess) return _noAccess(billing);

      if (billing.isLoading && billing.rxFirstLoad.value) {
        return BentoScreen(
          bottomClearance: !embedded,
          ground: !embedded,
          slivers: const [
            BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 5)),
          ],
        );
      }

      return BentoScreen(
        key: BillingKeys.screen,
        onRefresh: billing.reload,
        // The shell has already reserved the floating tab bar's height and
        // painted the ground; a pushed copy owes both itself.
        bottomClearance: !embedded,
        ground: !embedded,
        slivers: [
          if (billing.hasLoadError)
            BentoSection(
              top: BentoSpace.page,
              child: ErrorRetryBanner(
                message: billing.rxLoadError.value!,
                onRetry: billing.load,
              ),
            ),

          BentoSection(
            top: billing.hasLoadError ? 0 : BentoSpace.page,
            bottom: BentoSpace.header,
            child: _Stats(controller: billing),
          ),

          BentoSection(
            bottom: BentoSpace.header,
            child: BentoSegmented<BillingTab>(
              key: BillingKeys.tabs,
              options: BillingTab.values,
              selected: billing.tab.value,
              onSelected: billing.showTab,
              labelOf: (tab) =>
                  tab == BillingTab.invoices ? 'Invoices' : 'Services',
              keyOf: (tab) => BillingKeys.tab(tab.name),
            ),
          ),

          if (billing.tab.value == BillingTab.invoices)
            ..._invoiceSlivers(context, billing)
          else
            ..._serviceSlivers(context, billing),
        ],
      );
    });

    final list = MaxWidthBody(child: body);

    // Side by side once there is room for both. Below expanded the detail is a
    // pushed screen and this renders the list alone, so the same two widgets
    // serve a phone and a ward tablet.
    final adaptive = Obx(
      () => ListDetailScaffold(
        listPaneKey: BillingKeys.listPane,
        detailPaneKey: BillingKeys.detailPane,
        selectedId: billing.selectedId.value,
        list: list,
        detailBuilder: (context, id) =>
            InvoiceDetailView(invoiceId: id, embedded: true),
        placeholder: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No invoice chosen',
          message: 'Pick a bill on the left to see its lines and its payments.',
        ),
      ),
    );

    if (embedded) return adaptive;

    return Scaffold(
      appBar: const DetailHeader(title: 'Billing'),
      body: adaptive,
    );
  }

  // ── The two halves ────────────────────────────────────────────────────────

  List<Widget> _invoiceSlivers(
    BuildContext context,
    BillingController billing,
  ) {
    final rows = billing.rows;

    return [
      BentoSection(
        bottom: BentoSpace.header,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchField(
              fieldKey: BillingKeys.search,
              hint: 'Invoice number, patient or MRN',
              onChanged: billing.search,
            ),
            const SizedBox(height: BentoSpace.action),
            FilterChips<String?>(
              key: BillingKeys.statusFilter,
              options: const [null, ...InvoiceStatus.all],
              selected: billing.statusFilter.value,
              onSelected: billing.filterByStatus,
              labelOf: (status) =>
                  status == null ? 'All' : InvoiceStatus.labelOf(status),
              keyOf: (status) => BillingKeys.statusChip(status ?? 'all'),
            ),
          ],
        ),
      ),

      // Above the ledger, not under it. It used to sit below the rows on the
      // argument that a collector opens this screen to read — but eight bills
      // is already a screen and a half on a phone, and an action nobody can
      // reach without scrolling past the whole ledger is an action that is not
      // there. It is also where imaging and the laboratory put theirs.
      //
      // Absent, not disabled, for an account that may not raise one. A greyed
      // control is an invitation to ask why.
      if (billing.canCreate && rows.isNotEmpty)
        BentoSection(
          bottom: BentoSpace.header,
          child: PrimaryBar(
            key: BillingKeys.newInvoice,
            label: 'New invoice',
            icon: Icons.add_rounded,
            onPressed: _newInvoice,
          ),
        ),

      if (rows.isEmpty)
        BentoSection(
          child: EmptyState(
            key: BillingKeys.invoicesEmpty,
            icon: Icons.receipt_long_outlined,
            title: billing.statusFilter.value == null
                ? 'No invoices yet'
                : 'Nothing ${InvoiceStatus.labelOf(billing.statusFilter.value).toLowerCase()}',
            message: billing.statusFilter.value == null
                ? 'A bill is raised against a patient and the services they '
                    'were given.'
                : 'Clear the filter to see the rest of the ledger.',
            actionLabel: billing.canCreate ? 'New invoice' : null,
            onAction: billing.canCreate ? () => _newInvoice() : null,
            actionKey: BillingKeys.newInvoice,
          ),
        )
      else
        BentoSection(
          child: BentoCard(
            key: BillingKeys.invoiceList,
            padding: const EdgeInsets.symmetric(
              vertical: BentoSpace.listCardPad,
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  _InvoiceRow(
                    key: BillingKeys.invoice(rows[i].id),
                    invoice: rows[i],
                    controller: billing,
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _serviceSlivers(
    BuildContext context,
    BillingController billing,
  ) {
    final groups = billing.servicesByCategory;

    return [
      if (groups.isEmpty)
        const BentoSection(
          child: EmptyState(
            icon: Icons.sell_outlined,
            title: 'Nothing in the catalogue',
            message: 'A service is a thing this site charges for — a '
                'consultation, a procedure, a night on a ward.',
          ),
        )
      else
        for (final entry in groups.entries)
          BentoSection(
            bottom: BentoSpace.header,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: Formatters.label(entry.key)),
                BentoCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: BentoSpace.listCardPad,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0) const Hairline(indent: BentoSpace.listPad),
                        _ServiceRow(
                          service: entry.value[i],
                          controller: billing,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

      BentoSection(
        child: SecondaryBar(
          key: BillingKeys.openServices,
          label: 'Manage the catalogue',
          icon: Icons.tune_rounded,
          onPressed: () => Get.toNamed<void>(BillingRoutes.services),
        ),
      ),
    ];
  }

  Widget _noAccess(BillingController billing) => BentoScreen(
        key: BillingKeys.screen,
        bottomClearance: !embedded,
        ground: !embedded,
        slivers: const [
          BentoSection(
            top: BentoSpace.page,
            // No retry and no red. Nothing is broken: this account was not
            // granted billing, and the only useful next step is a person.
            child: EmptyState(
              key: BillingKeys.noAccess,
              icon: Icons.lock_outline_rounded,
              title: 'Billing is not available to your role',
              message: 'Ask an administrator if you need to see invoices and '
                  'payments.',
            ),
          ),
        ],
      );

  void _newInvoice() => Get.toNamed<void>(BillingRoutes.invoiceNew);
}

// ── Stats ───────────────────────────────────────────────────────────────────

/// What the ledger looks like today.
///
/// Every amount goes through `SettingsService.money`. There is not a currency
/// symbol anywhere in this file: the site chooses its currency, and a symbol
/// concatenated onto a number is how an app ships "₹1,200.00" to a site that
/// writes "1.200,00 kr".
class _Stats extends StatelessWidget {
  const _Stats({required this.controller});

  final BillingController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _card(context));

  /// Its own `Obx`, and every widget in this file that reads an observable is
  /// the same.
  ///
  /// A child constructed inside an `Obx` closure is **not** inside its
  /// reactive scope: the closure only builds the widget object, and Flutter
  /// calls `build` on it later, outside the proxy that records reads. So a
  /// figure that changed while the enclosing list did not would never repaint.
  Widget _card(BuildContext context) {
    final stats = controller.stats.value;
    final money = controller.money;

    return BentoCard(
      key: BillingKeys.stats,
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MoneyFigure(
                  label: 'Collected today',
                  amount: money(stats.collectedToday),
                  caption: 'Across every method',
                ),
              ),
              const SizedBox(width: BentoSpace.action),
              Expanded(
                child: MoneyFigure(
                  label: 'Outstanding',
                  amount: money(stats.outstandingBalance),
                  caption: '${stats.pendingInvoices} unsettled',
                  // Amber on a balance the site is owed, never red. Money
                  // uncollected is an administrative problem.
                  color: stats.outstandingBalance > 0
                      ? semanticInk(context, AppColors.warning)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: BentoSpace.section),
          FigureGrid(
            columns: 2,
            figures: [
              Figure(
                label: 'Revenue today',
                value: money(stats.todayRevenue),
                icon: Icons.trending_up_rounded,
                color: AppColors.accent,
              ),
              Figure(
                label: 'In the catalogue',
                value: '${stats.totalServices}',
                caption: 'Chargeable services',
                icon: Icons.sell_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Rows ────────────────────────────────────────────────────────────────────

/// One bill: its number, who it is for, what it comes to, what is still owed,
/// and where it has got to.
class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    super.key,
    required this.invoice,
    required this.controller,
  });

  final Invoice invoice;
  final BillingController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _row(context));

  Widget _row(BuildContext context) {
    final status = controller.statusOf(invoice);
    final window = WindowClass.of(context);

    return DocumentRow(
      // The server builds the whole number (`MOB-INV-0004`); nothing here
      // reformats it. A document number a person reads back over the phone
      // must be the one stored against the record, character for character.
      number: invoice.invoiceNumber,
      title: invoice.patient.displayName,
      // Never ellipsised into nothing by this widget's own doing: the kit caps
      // the amount at 55% of the row and the patient's name gives way first,
      // which is the right way round — the figure is why the row exists.
      amount: controller.money(invoice.totalAmount),
      subtitle: controller.outstandingHint(invoice),
      status: InvoiceStatus.labelOf(status),
      statusColor: InvoiceStatus.colorOf(status),
      dimmed: invoice.isCancelled,
      selected: controller.selectedId.value == invoice.id,
      onTap: () {
        // On a wide window the row fills the pane beside it; on a phone it
        // pushes. Same row, same detail widget, two layouts.
        if (window.isTwoPane) {
          controller.select(invoice.id);
          return;
        }
        Get.toNamed<void>(BillingRoutes.invoice(invoice.id));
      },
    );
  }
}

/// One catalogue entry: what it is called, what it costs, and whether tax is
/// charged on it.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.controller});

  final BillingService service;
  final BillingController controller;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if ((service.serviceCode ?? '').trim().isNotEmpty) service.serviceCode!,
      if ((service.department ?? '').trim().isNotEmpty)
        Formatters.label(service.department),
      if (service.isTaxable) 'Tax ${_wholePercent(service.taxPercentage)}%',
    ];

    return BentoRow(
      key: BillingKeys.ledgerService(service.id),
      title: service.serviceName,
      subtitle: parts.isEmpty ? null : parts.join(' · '),
      showChevron: false,
      trailing: Text(
        controller.money(service.unitPrice),
        style: numeralStyle(context, size: 17),
      ),
    );
  }
}

/// `18`, not `18.0` — a tax rate with a trailing zero on it reads as a
/// measurement. A rate with real decimals keeps them.
String _wholePercent(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
