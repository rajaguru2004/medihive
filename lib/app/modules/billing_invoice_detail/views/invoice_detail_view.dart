import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/billing_invoice_detail_keys.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/settings_service.dart';
import '../../../theme/theme.dart';
import '../../billing/billing_routes.dart';
import '../../billing/billing_status.dart';
import '../controllers/invoice_detail_controller.dart';

/// One bill: what it is for, what it comes to, what has been paid against it,
/// and the three things that can be done to it next.
///
/// A `StatefulWidget` rather than a `GetView` because the controller is tagged
/// by invoice id: a tablet shows this beside the ledger, so two bills can be
/// on screen in one session and a single untagged controller would answer for
/// both.
class InvoiceDetailView extends StatefulWidget {
  const InvoiceDetailView({super.key, this.invoiceId, this.embedded = false});

  /// Null when this is the routed screen, which takes the id from the path.
  /// Set when it is the ledger's detail pane.
  final String? invoiceId;

  /// True in the ledger's second pane, which already has a header above it.
  final bool embedded;

  @override
  State<InvoiceDetailView> createState() => _InvoiceDetailViewState();
}

class _InvoiceDetailViewState extends State<InvoiceDetailView> {
  late final String _id;
  late final InvoiceDetailController _controller;

  /// Whether this widget created the controller, and therefore owes it a
  /// disposal. The routed copy is created by the binding and torn down with
  /// the route; the pane's is not.
  late final bool _owns;

  @override
  void initState() {
    super.initState();
    _id = widget.invoiceId ?? InvoiceDetailController.routeInvoiceId();
    _owns = !(Get.isRegistered<InvoiceDetailController>(tag: _id) ||
        Get.isPrepared<InvoiceDetailController>(tag: _id));
    _controller = InvoiceDetailController.forInvoice(_id);
  }

  @override
  void dispose() {
    if (_owns) {
      final id = _id;
      // After this frame. Deleting a controller while an `Obx` above is still
      // being torn down throws from inside a dispose nobody is holding, and
      // the message names the overlay rather than this screen.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Get.delete<InvoiceDetailController>(tag: id),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      if (_controller.hasNoAccess) {
        return const BentoScreen(
          bottomClearance: false,
          ground: false,
          slivers: [
            BentoSection(
              top: BentoSpace.page,
              child: EmptyState(
                key: InvoiceDetailKeys.noAccess,
                icon: Icons.lock_outline_rounded,
                title: 'Billing is not available to your role',
                message: 'Ask an administrator if you need to see invoices.',
              ),
            ),
          ],
        );
      }

      if (_controller.isLoading && _controller.rxFirstLoad.value) {
        return const BentoScreen(
          bottomClearance: false,
          ground: false,
          slivers: [
            BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 6)),
          ],
        );
      }

      if (_controller.hasLoadError) {
        return BentoScreen(
          bottomClearance: false,
          ground: false,
          slivers: [
            BentoSection(
              top: BentoSpace.page,
              child: ErrorRetryBanner(
                message: _controller.rxLoadError.value!,
                onRetry: _controller.load,
              ),
            ),
          ],
        );
      }

      final invoice = _controller.invoice.value;
      if (invoice.isEmpty) {
        return const BentoScreen(
          bottomClearance: false,
          ground: false,
          slivers: [
            BentoSection(
              top: BentoSpace.page,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'That invoice is gone',
                message: 'It may have been deleted since this link was made.',
              ),
            ),
          ],
        );
      }

      return BentoScreen(
        // The pane has no Scaffold of its own, so the anchor lives here when
        // it is embedded and on the Scaffold when it is pushed.
        key: widget.embedded ? InvoiceDetailKeys.screen : null,
        onRefresh: _controller.reload,
        bottomClearance: false,
        ground: false,
        slivers: [
          BentoSection(
            top: BentoSpace.page,
            bottom: BentoSpace.header,
            child: _Header(controller: _controller),
          ),

          // A refused write, in the server's own words, where it can be read.
          Obx(() {
            final error = _controller.actionError.value;
            if (error == null) return const SliverToBoxAdapter();
            return BentoSection(
              bottom: BentoSpace.header,
              child: NoticeBanner(
                message: error,
                icon: Icons.error_outline_rounded,
                tint: AppColors.error,
              ),
            );
          }),

          if (invoice.isCancelled)
            BentoSection(
              bottom: BentoSpace.header,
              child: NoticeBanner(
                key: InvoiceDetailKeys.cancelledNotice,
                message: (invoice.cancellationReason ?? '').trim().isEmpty
                    ? 'This invoice was cancelled.'
                    : 'Cancelled — ${invoice.cancellationReason!.trim()}',
                icon: Icons.block_rounded,
                // Neutral. A cancelled bill is a document that is out of play,
                // not a fault and not an emergency.
                tint: AppColors.acuityDischarged,
              ),
            ),

          // What somebody opened this bill to *do*, above what it is made of.
          // The actions used to close the screen, under the lines, the totals
          // and the payment history — which on a phone is two screens of
          // scrolling before the one button a collector came for. The header
          // above already says what is owed; this says what can be done about
          // it.
          BentoSection(
            bottom: BentoSpace.header,
            child: _Actions(controller: _controller),
          ),

          BentoSection(
            bottom: BentoSpace.header,
            child: _Items(controller: _controller),
          ),

          BentoSection(
            bottom: BentoSpace.header,
            child: _Totals(controller: _controller),
          ),

          BentoSection(child: _Payments(controller: _controller)),
        ],
      );
    });

    if (widget.embedded) return body;

    return Scaffold(
      key: InvoiceDetailKeys.screen,
      appBar: DetailHeader(
        title: 'Invoice',
        subtitle: _controller.invoice.value.invoiceNumber.isEmpty
            ? null
            : _controller.invoice.value.invoiceNumber,
      ),
      body: MaxWidthBody(child: body),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final InvoiceDetailController controller;

  @override
  Widget build(BuildContext context) {
    final invoice = controller.invoice.value;
    final status = controller.status;
    final money = controller.money;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecordHeader(
          key: InvoiceDetailKeys.header,
          title: invoice.patient.displayName,
          subtitle: _subtitle(invoice),
          amount: money(invoice.totalAmount),
          amountLabel: 'Invoice total',
          status: InvoiceStatus.labelOf(status),
          // Amber for overdue, green for paid, neutral for cancelled — one
          // vocabulary, resolved in `InvoiceStatus` and nowhere else.
          statusColor: InvoiceStatus.colorOf(status),
          secondaryStatus:
              InvoicePaymentStatus.labelOf(invoice.paymentStatus),
          secondaryStatusColor:
              InvoicePaymentStatus.colorOf(invoice.paymentStatus),
        ),
        const SizedBox(height: BentoSpace.action),
        BentoCard(
          key: InvoiceDetailKeys.paidBar,
          child: RatioBar(
            fraction: controller.paidFraction,
            filledLabel: '${money(invoice.amountPaid)} paid',
            remainderLabel: '${money(controller.outstanding)} outstanding',
            // The remainder is amber only while something is actually owed: a
            // settled bill with an amber legend on it is a bill somebody
            // chases for no reason.
            remainderColor: controller.outstanding > 0
                ? AppColors.warning
                : tertiaryLabelColor(context),
          ),
        ),
      ],
    );
  }

  String? _subtitle(Invoice invoice) {
    final parts = <String>[
      invoice.invoiceNumber,
      if (invoice.invoiceDate != null)
        'Raised ${SettingsService.to.date(invoice.invoiceDate)}',
      if (invoice.dueDate != null)
        'Due ${SettingsService.to.date(invoice.dueDate)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

// ── Lines ───────────────────────────────────────────────────────────────────

class _Items extends StatelessWidget {
  const _Items({required this.controller});

  final InvoiceDetailController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.invoice.value.items;
    final money = controller.money;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'What was billed (${items.length})'),
        BentoCard(
          key: InvoiceDetailKeys.items,
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(BentoSpace.listPad),
                  child: EmptyState(
                    icon: Icons.list_alt_outlined,
                    title: 'No lines on this invoice',
                    compact: true,
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const Hairline(indent: BentoSpace.listPad),
                      BentoRow(
                        key: InvoiceDetailKeys.item(i),
                        title: items[i].description,
                        subtitle: _lineSubtitle(items[i], money),
                        showChevron: false,
                        trailing: Text(
                          // The line's stored total — pre-tax, the way the
                          // server sums it into the subtotal. Never recomputed
                          // here: the document is what the patient was handed.
                          money(items[i].total),
                          style: numeralStyle(context, size: 17),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  String _lineSubtitle(InvoiceItem item, MoneyFormat money) {
    final parts = <String>[
      '${item.quantity} × ${money(item.unitPrice)}',
      if (item.discount > 0) '−${money(item.discount)} off',
      if (item.tax > 0) '+${money(item.tax)} tax',
    ];
    return parts.join(' · ');
  }
}

// ── Totals ──────────────────────────────────────────────────────────────────

class _Totals extends StatelessWidget {
  const _Totals({required this.controller});

  final InvoiceDetailController controller;

  @override
  Widget build(BuildContext context) {
    final invoice = controller.invoice.value;
    final money = controller.money;

    return BentoCard(
      key: InvoiceDetailKeys.totals,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow(
            label: 'Subtotal',
            value: money(invoice.subtotal),
            inset: false,
          ),
          if (invoice.discountAmount > 0)
            FactRow(
              label: invoice.discountPercentage > 0
                  ? 'Discount (${_percent(invoice.discountPercentage)}%)'
                  : 'Discount',
              value: '−${money(invoice.discountAmount)}',
              inset: false,
            ),
          if (invoice.taxAmount > 0)
            FactRow(label: 'Tax', value: money(invoice.taxAmount), inset: false),
          const Hairline(),
          FactRow(
            label: 'Total',
            value: money(invoice.totalAmount),
            inset: false,
          ),
          FactRow(
            key: InvoiceDetailKeys.outstanding,
            label: 'Outstanding',
            value: money(controller.outstanding),
            valueColor: controller.outstanding > 0
                ? semanticInk(context, AppColors.warning)
                : semanticInk(context, AppColors.acuityStable),
            inset: false,
          ),
        ],
      ),
    );
  }

  static String _percent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

// ── Payments ────────────────────────────────────────────────────────────────

class _Payments extends StatelessWidget {
  const _Payments({required this.controller});

  final InvoiceDetailController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _section(context));

  /// Its own `Obx`: the history is reloaded by a `DataBus` tick, and a child
  /// built inside another `Obx` closure is not inside that closure's reactive
  /// scope.
  Widget _section(BuildContext context) {
    final payments = controller.payments;
    final money = controller.money;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Payments (${payments.length})'),
        BentoCard(
          key: InvoiceDetailKeys.payments,
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: payments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(BentoSpace.listPad),
                  child: EmptyState(
                    key: InvoiceDetailKeys.paymentsEmpty,
                    icon: Icons.receipt_outlined,
                    title: 'Nothing received yet',
                    compact: true,
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < payments.length; i++) ...[
                      if (i > 0) const Hairline(indent: BentoSpace.listPad),
                      _PaymentRow(
                        key: InvoiceDetailKeys.payment(payments[i].id),
                        payment: payments[i],
                        money: money,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    super.key,
    required this.payment,
    required this.money,
  });

  final Payment payment;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (payment.receiptNumber.isNotEmpty) payment.receiptNumber,
      if (payment.paymentDate != null)
        SettingsService.to.date(payment.paymentDate),
      if ((payment.paymentReference ?? '').trim().isNotEmpty)
        payment.paymentReference!.trim(),
    ];

    return BentoRow(
      title: PaymentMethod.labelOf(payment.paymentMethod),
      subtitle: parts.isEmpty ? null : parts.join(' · '),
      icon: PaymentMethod.iconOf(payment.paymentMethod),
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (payment.isRefund) ...[
            const StatusPill(
              status: 'refunded',
              // Neutral: a refund is a correction, not a failure.
              color: AppColors.acuityDischarged,
              label: 'Refund',
              compact: true,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            money(payment.signedAmount),
            style: numeralStyle(context, size: 17),
          ),
        ],
      ),
    );
  }
}

// ── Actions ─────────────────────────────────────────────────────────────────

/// Each control is **absent** when this account may not use it, never greyed
/// out: a disabled button is an invitation to ask why, and the answer is a
/// permission nobody on this screen can grant.
class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final InvoiceDetailController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _bar(context));

  Widget _bar(BuildContext context) {
    final invoice = controller.invoice.value;

    final actions = <Widget>[
      if (controller.canRecordPayment)
        PrimaryBar(
          key: InvoiceDetailKeys.recordPayment,
          label: 'Record payment',
          icon: Icons.payments_outlined,
          busy: controller.isSaving.value,
          onPressed: () => Get.toNamed<void>(
            BillingRoutes.pay(invoice.id),
            arguments: {'invoiceId': invoice.id},
          ),
        ),
      if (controller.canMarkSent)
        SecondaryBar(
          key: InvoiceDetailKeys.markSent,
          label: 'Mark sent',
          icon: Icons.outgoing_mail,
          onPressed: () async {
            final moved = await controller.markSent();
            if (moved) {
              showBentoToast('${invoice.invoiceNumber} marked sent.');
            }
          },
        ),
      if (controller.canCancel)
        SecondaryBar(
          key: InvoiceDetailKeys.cancel,
          label: 'Cancel invoice',
          icon: Icons.block_rounded,
          destructive: true,
          onPressed: () => _openCancelSheet(context, controller),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: BentoSpace.action),
          actions[i],
        ],
      ],
    );
  }
}

/// Cancelling asks for the reason before it asks for the confirmation.
///
/// The reason is required and it is asked for **first**: a confirm dialog that
/// then asks for a reason is one somebody dismisses, and an invoice cancelled
/// with no reason on it is a number the next person has to reconstruct from an
/// audit log.
Future<void> _openCancelSheet(
  BuildContext context,
  InvoiceDetailController controller,
) async {
  final reason = TextEditingController();
  final invoice = controller.invoice.value;

  await Get.bottomSheet<void>(
    SheetShell(
      title: 'Cancel ${invoice.invoiceNumber}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSection(
            bottom: BentoSpace.section,
            child: BentoInput(
              fieldKey: InvoiceDetailKeys.cancelReason,
              label: 'Why is it being cancelled?',
              controller: reason,
              required: true,
              maxLines: 3,
              hint: 'It stays on the record and on the audit trail.',
            ),
          ),
          SheetSection(
            bottom: BentoSpace.section,
            child: PrimaryBar(
              key: InvoiceDetailKeys.cancelConfirm,
              label: 'Cancel this invoice',
              icon: Icons.block_rounded,
              onPressed: () async {
                final text = reason.text.trim();
                if (text.isEmpty) {
                  showBentoToast(
                    'Say why this invoice is being cancelled.',
                    tone: ToastTone.failure,
                  );
                  return;
                }

                Get.back<void>();
                final confirmed = await ConfirmDialog.show(
                  context,
                  title: 'Cancel ${invoice.invoiceNumber}?',
                  message: 'The bill stops being collectable. Nothing is '
                      'deleted, and a new invoice can be raised in its place.',
                  confirmLabel: 'Cancel invoice',
                  cancelLabel: 'Keep it',
                  destructive: true,
                  confirmKey: InvoiceDetailKeys.cancelDialogConfirm,
                  cancelKey: InvoiceDetailKeys.cancelDialogDismiss,
                );
                if (!confirmed) return;

                final cancelled = await controller.cancel(text);
                if (cancelled) {
                  showBentoToast('${invoice.invoiceNumber} cancelled.');
                }
              },
            ),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );

  reason.dispose();
}
