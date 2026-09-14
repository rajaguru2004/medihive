import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/billing_invoice_detail_keys.dart';
import 'package:medihive/app/core/keys/billing_invoice_form_keys.dart';
import 'package:medihive/app/core/keys/billing_keys.dart';
import 'package:medihive/app/core/keys/billing_payment_form_keys.dart';
import 'package:medihive/app/core/keys/billing_services_keys.dart';
import 'package:medihive/app/data/services/settings_service.dart';
import 'package:medihive/app/data/utils/invoice_math.dart';
import 'package:medihive/app/modules/billing/billing_routes.dart';
import 'package:medihive/app/modules/billing/bindings/billing_binding.dart';
import 'package:medihive/app/modules/billing/controllers/billing_controller.dart';
import 'package:medihive/app/modules/billing/views/billing_view.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// Billing: the ledger, one invoice, the invoice form, the payment form and the
/// service catalogue.
///
/// One robot for five screens because they are one job — a bill is raised,
/// read, paid and reconciled — and a finder for an invoice number has to mean
/// the same thing on the row and on the detail it opens.
final class BillingRobot extends Robot {
  BillingRobot(super.harness);

  @override
  Key get anchor => BillingKeys.screen;

  @override
  String? get route => BillingRoutes.list;

  /// Whether this isolate has already handed billing's pages to GetX.
  ///
  /// `ParseRouteTree.addRoutes` appends without checking, and the tree lives
  /// for the process rather than for the test, so a second registration is a
  /// second copy of every route.
  static bool _pagesRegistered = false;

  // ── Getting there ─────────────────────────────────────────────────────────

  /// Opens the ledger.
  ///
  /// Two things are going on here, and both are about the route table being
  /// owned by another stream:
  ///
  ///   * the **sub-routes** are added to GetX's tree, because nothing has
  ///     registered them yet. Once the table does, these become harmless
  ///     duplicates — `ParseRouteTree._findRoute` takes the first match, and
  ///     both point at the same page.
  ///   * the **root** is pushed with `Get.to` rather than by name, because
  ///     `/billing` is still the shared table's placeholder screen and first
  ///     registration wins. `Get.to` names the route it pushes, so
  ///     `Get.currentRoute` — and therefore [assertVisible] — still reads
  ///     `/billing`.
  ///
  /// `Get.to` is fired and **not awaited**: its future completes when the route
  /// is *popped*, so awaiting it here would wait for something this flow has
  /// not done yet and never return.
  Future<void> open() async {
    if (!_pagesRegistered) {
      Get.addPages(BillingPages.pages);
      _pagesRegistered = true;
    }

    unawaited(
      Get.to<void>(
            () => const BillingView(embedded: false),
            binding: BillingBinding(),
            routeName: BillingRoutes.list,
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(BillingKeys.screen));
    await settle();
  }

  Future<void> assertOnLedger() async {
    await assertVisible();
    seeNoErrorBanner();
    expect(
      find.byKey(BillingKeys.stats),
      findsOneWidget,
      reason: 'the ledger opened without its figures',
    );
  }

  // ── The ledger ────────────────────────────────────────────────────────────

  /// Switches between the two halves of the ledger.
  Future<void> showTab(BillingTab tab) async {
    await tester.tapKey(BillingKeys.tab(tab.name));
    await settle();
  }

  /// Narrows the list to one status. Tapping the same chip again clears it,
  /// which is the control's own behaviour rather than this robot's.
  Future<void> filterByStatus(String status) async {
    await tester.tapKey(BillingKeys.statusChip(status));
    await settle();
  }

  /// The invoice ids on screen, in the order the list lays them out.
  List<String> invoiceIdsInOrder() {
    const prefix = 'billing_invoice_';
    final rows = <({double top, String id})>[
      for (final element in find
          .byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(prefix),
          )
          .evaluate())
        (
          top: (element.renderObject! as RenderBox)
              .localToGlobal(Offset.zero)
              .dy,
          id: ((element.widget.key! as ValueKey<String>).value)
              .substring(prefix.length),
        ),
    ]..sort((a, b) => a.top.compareTo(b.top));
    return [for (final row in rows) row.id];
  }

  int get invoiceCount => invoiceIdsInOrder().length;

  void seeInvoice(String id) => expect(
        find.byKey(BillingKeys.invoice(id)),
        findsOneWidget,
        reason: 'expected invoice $id on the ledger',
      );

  void seeNoInvoice(String id) =>
      expect(find.byKey(BillingKeys.invoice(id)), findsNothing);

  /// The **colour** of an invoice row's status pill.
  ///
  /// Colour rather than label on purpose. `.agents/RULES.md` §0 rule 1 is about
  /// what a reader sees across a corridor, and a test that read the word
  /// "Overdue" would pass just as happily if somebody had painted the pill
  /// `acuityCritical` — which is the regression the rule exists to prevent.
  ///
  /// A row carries exactly one `StatusPill`, so this is unambiguous by
  /// construction.
  Color statusColourOf(String invoiceId) {
    final pill = find.descendant(
      of: find.byKey(BillingKeys.invoice(invoiceId)),
      matching: find.byType(StatusPill),
    );
    expect(
      pill,
      findsOneWidget,
      reason: 'invoice $invoiceId should carry exactly one status pill',
    );
    final colour = tester.widget<StatusPill>(pill).color;
    expect(
      colour,
      isNotNull,
      reason: 'the ledger must name a status colour rather than letting '
          'CaseStatus resolve a billing word through the acuity ramp',
    );
    return colour!;
  }

  /// The words on an invoice row's status pill. Paired with [statusColourOf]:
  /// a state is colour *and* word, never either alone.
  String statusLabelOf(String invoiceId) {
    final pill = find.descendant(
      of: find.byKey(BillingKeys.invoice(invoiceId)),
      matching: find.byType(StatusPill),
    );
    final widget = tester.widget<StatusPill>(pill);
    return widget.label ?? widget.status;
  }

  Future<void> openInvoice(String id) async {
    await tester.tapKey(BillingKeys.invoice(id));
    await tester.pumpUntilFound(find.byKey(InvoiceDetailKeys.screen));
    await settle();
  }

  Future<void> tapNewInvoice() async {
    await tester.tapKey(BillingKeys.newInvoice);
    await tester.pumpUntilFound(find.byKey(InvoiceFormKeys.screen));
    await settle();
  }

  void seeNewInvoiceAction() =>
      expect(find.byKey(BillingKeys.newInvoice), findsWidgets);

  void seeNoNewInvoiceAction() => expect(
        find.byKey(BillingKeys.newInvoice),
        findsNothing,
        reason: 'a control this account may not use is absent, not disabled',
      );

  /// The locked panel a role without billing gets. No retry and no red on it.
  void seeNoAccess() {
    expect(
      find.byKey(BillingKeys.noAccess),
      findsOneWidget,
      reason: 'expected the billing no-access state',
    );
    seeNoErrorBanner();
    expect(
      find.byKey(BillingKeys.invoiceList),
      findsNothing,
      reason: 'a refused account must not see the ledger behind the panel',
    );
  }

  // ── The catalogue ─────────────────────────────────────────────────────────

  Future<void> openCatalogue() async {
    await tester.tapKey(BillingKeys.openServices);
    await tester.pumpUntilFound(find.byKey(BillingServicesKeys.screen));
    await settle();
  }

  void seeService(String id) =>
      expect(find.byKey(BillingServicesKeys.service(id)), findsOneWidget);

  // ── The invoice form ──────────────────────────────────────────────────────

  Future<void> assertOnInvoiceForm() async {
    await tester.pumpUntilFound(find.byKey(InvoiceFormKeys.screen));
    expect(find.byKey(InvoiceFormKeys.totals), findsOneWidget);
  }

  /// Chooses the patient through the picker's own search sheet.
  Future<void> pickPatient(String name) async {
    await tester.tapKeyWithoutKeyboard(InvoiceFormKeys.patientPicker);
    await tester.pumpUntilRouteSettled();
    await pickFromSheet(name);
  }

  /// Adds a catalogue line by the service's name.
  Future<void> addService(String name) async {
    await tester.tapKeyWithoutKeyboard(InvoiceFormKeys.addFromCatalogue);
    await tester.pumpUntilRouteSettled();
    await pickFromSheet(name);
  }

  Future<void> addCustomLine() async {
    await tester.tapKey(InvoiceFormKeys.addCustomLine);
    await settle();
  }

  Future<void> setLineDescription(int index, String text) async {
    await tester.enterTextByKey(InvoiceFormKeys.lineDescription(index), text);
    await settle();
  }

  Future<void> setLineQuantity(int index, String quantity) async {
    await tester.enterTextByKey(InvoiceFormKeys.lineQuantity(index), quantity);
    await settle();
  }

  Future<void> setLineUnitPrice(int index, String price) async {
    await tester.enterTextByKey(InvoiceFormKeys.lineUnitPrice(index), price);
    await settle();
  }

  Future<void> setLineTax(int index, String percent) async {
    await tester.enterTextByKey(InvoiceFormKeys.lineTax(index), percent);
    await settle();
  }

  Future<void> setInvoiceDiscount(String amount) async {
    await tester.enterTextByKey(InvoiceFormKeys.discountAmount, amount);
    await settle();
  }

  int get lineCount => find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('invoice_form_line_') &&
            RegExp(r'^invoice_form_line_\d+$')
                .hasMatch((widget.key! as ValueKey<String>).value),
      )
      .evaluate()
      .length;

  void seeLinesEmptyState() =>
      expect(find.byKey(InvoiceFormKeys.linesEmpty), findsOneWidget);

  /// The four figures in the totals pane, read off the screen as strings.
  ///
  /// Strings rather than numbers, deliberately: what is being asserted is that
  /// the pane renders the site's own money convention over `InvoiceMath`'s
  /// output, and re-parsing them here would let a formatting regression pass.
  ({String subtotal, String discount, String tax, String total})
      totalsOnScreen() => (
            subtotal: _factValue(InvoiceFormKeys.subtotal),
            discount: _factValue(InvoiceFormKeys.discountTotal),
            tax: _factValue(InvoiceFormKeys.taxTotal),
            total: tester
                .widget<MoneyFigure>(find.byKey(InvoiceFormKeys.total))
                .amount,
          );

  /// "The pane shows exactly what `InvoiceMath` computed, in the site's own
  /// money convention."
  void seeTotals(InvoiceTotals expected) {
    final money = SettingsService.to.settings.money;
    final shown = totalsOnScreen();

    expect(shown.subtotal, money(expected.subtotal), reason: 'subtotal');
    expect(
      shown.discount,
      expected.discount > 0 ? '−${money(expected.discount)}' : money(0),
      reason: 'discount',
    );
    expect(shown.tax, money(expected.tax), reason: 'tax');
    expect(shown.total, money(expected.total), reason: 'total');
  }

  /// One line's own total, as the card shows it.
  String lineTotalOnScreen(int index) =>
      _factValue(InvoiceFormKeys.lineTotal(index));

  Future<void> saveInvoice() async {
    await tester.tapKeyWithoutKeyboard(InvoiceFormKeys.save);
    await settle();
  }

  // ── The invoice detail ────────────────────────────────────────────────────

  Future<void> assertOnInvoiceDetail() async {
    await tester.pumpUntilFound(find.byKey(InvoiceDetailKeys.screen));
    expect(find.byKey(InvoiceDetailKeys.header), findsOneWidget);
  }

  /// What is still owed, as the detail's totals block shows it.
  String outstandingOnScreen() => _factValue(InvoiceDetailKeys.outstanding);

  /// Waits for the balance to become [expected].
  ///
  /// A wait rather than a bare `expect`, because the reload that moves it is
  /// announced on the `DataBus` and runs `silent: true` — no spinner, nothing
  /// for `pumpUntilRouteSettled` to converge on. Asserting immediately after
  /// the pop would be a race that passes on a fast machine and fails on a
  /// loaded one, which is the worst kind of test to own.
  Future<void> seeOutstanding(String expected) async {
    await tester.pumpUntil(
      () =>
          find.byKey(InvoiceDetailKeys.outstanding).evaluate().isNotEmpty &&
          outstandingOnScreen() == expected,
      reason: 'the outstanding balance never reached $expected — it reads '
          '${find.byKey(InvoiceDetailKeys.outstanding).evaluate().isEmpty ? '(nothing)' : outstandingOnScreen()}',
    );
  }

  /// Waits for the payment history to hold [expected] receipts.
  Future<void> seePaymentCount(int expected) => tester.pumpUntil(
        () => paymentCount == expected,
        reason: 'expected $expected payments on this invoice, found '
            '$paymentCount',
      );

  int get paymentCount => find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('invoice_detail_payment_'),
      )
      .evaluate()
      .length;

  void seeNoPayments() =>
      expect(find.byKey(InvoiceDetailKeys.paymentsEmpty), findsOneWidget);

  void seeRecordPaymentAction() =>
      expect(find.byKey(InvoiceDetailKeys.recordPayment), findsOneWidget);

  void seeNoRecordPaymentAction() => expect(
        find.byKey(InvoiceDetailKeys.recordPayment),
        findsNothing,
        reason: 'a settled or cancelled invoice offers nothing to pay',
      );

  void seeMarkSentAction() =>
      expect(find.byKey(InvoiceDetailKeys.markSent), findsOneWidget);

  void seeCancelAction() =>
      expect(find.byKey(InvoiceDetailKeys.cancel), findsOneWidget);

  void seeNoCancelAction() => expect(
        find.byKey(InvoiceDetailKeys.cancel),
        findsNothing,
        reason: 'an invoice with money against it cannot be cancelled — the '
            'money would have to be refunded first',
      );

  Future<void> markSent() async {
    await tester.tapKey(InvoiceDetailKeys.markSent);
    await settle();
  }

  /// Cancels through the sheet and the confirmation behind it.
  ///
  /// Two taps, and they are two deliberately: the reason is asked for first
  /// because a confirm dialog that then asks for one is a dialog somebody
  /// dismisses, and an invoice cancelled with no reason on it is a number the
  /// next person reconstructs from an audit log.
  Future<void> cancelInvoice(String reason) async {
    await tester.tapKey(InvoiceDetailKeys.cancel);
    await tester.pumpUntilRouteSettled();
    await tester.enterTextByKey(InvoiceDetailKeys.cancelReason, reason);
    await tester.tapKeyWithoutKeyboard(InvoiceDetailKeys.cancelConfirm);

    // The sheet closes and the dialog opens in its place — raising a dialog
    // from inside a sheet dismisses it with the sheet, so the screen does it
    // the other way round.
    await tester.pumpUntilFound(
      find.byKey(InvoiceDetailKeys.cancelDialogConfirm),
    );
    await tester.tapKey(InvoiceDetailKeys.cancelDialogConfirm);
    await tester.pumpUntilRouteSettled();
  }

  void seeCancelledNotice() =>
      expect(find.byKey(InvoiceDetailKeys.cancelledNotice), findsOneWidget);

  Future<void> tapRecordPayment() async {
    await tester.tapKey(InvoiceDetailKeys.recordPayment);
    await tester.pumpUntilFound(find.byKey(PaymentFormKeys.screen));
    await settle();
  }

  // ── The payment form ──────────────────────────────────────────────────────

  Future<void> assertOnPaymentForm() async {
    await tester.pumpUntilFound(find.byKey(PaymentFormKeys.screen));
    expect(find.byKey(PaymentFormKeys.outstanding), findsOneWidget);
  }

  /// What the amount field holds. Pre-filled with the balance, because that is
  /// what happens at a counter nine times out of ten.
  String amountOnScreen() => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(PaymentFormKeys.amount),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  Future<void> enterAmount(String amount) async {
    await tester.enterTextByKey(PaymentFormKeys.amount, amount);
    await settle();
  }

  Future<void> pickMethod(String label) async {
    await tester.tapKeyWithoutKeyboard(PaymentFormKeys.method);
    await tester.pumpUntilRouteSettled();
    await pickFromSheet(label);
  }

  /// Which conditional fields the chosen method put on screen.
  void seeConditionalFields({
    bool provider = false,
    bool bank = false,
    bool chequeNumber = false,
    bool chequeDate = false,
  }) {
    void check(Key key, bool expected, String what) => expect(
          find.byKey(key),
          expected ? findsOneWidget : findsNothing,
          reason: expected
              ? 'expected the $what field for this method'
              : 'the $what field does not belong to this method, and a field '
                  'that does not apply is absent rather than greyed out',
        );

    check(PaymentFormKeys.provider, provider, 'mobile money provider');
    check(PaymentFormKeys.bankName, bank, 'bank');
    check(PaymentFormKeys.chequeNumber, chequeNumber, 'cheque number');
    check(PaymentFormKeys.chequeDate, chequeDate, 'cheque date');
  }

  Future<void> enterProvider(String value) async {
    await tester.enterTextByKey(PaymentFormKeys.provider, value);
    await settle();
  }

  Future<void> enterBank(String value) async {
    await tester.enterTextByKey(PaymentFormKeys.bankName, value);
    await settle();
  }

  Future<void> enterReference(String value) async {
    await tester.enterTextByKey(PaymentFormKeys.reference, value);
    await settle();
  }

  Future<void> savePayment() async {
    await tester.tapKeyWithoutKeyboard(PaymentFormKeys.save);
    await settle();
  }

  /// "The screen refused, and said this."
  ///
  /// A banner rather than a toast: a refused write is something somebody has to
  /// do differently, and three seconds is not long enough to read why.
  void seeRefusal({required String naming}) {
    expect(
      find.byType(NoticeBanner),
      findsWidgets,
      reason: 'expected the refusal to stay on screen',
    );
    expect(
      find.textContaining(naming),
      findsWidgets,
      reason: 'the refusal has to name $naming, not just say no',
    );
  }

  /// "This screen is still the payment form" — i.e. the refusal did not
  /// navigate.
  void seeStillOnPaymentForm() =>
      expect(find.byKey(PaymentFormKeys.screen), findsOneWidget);

  // ── Shared ────────────────────────────────────────────────────────────────

  /// A `FactRow`'s value, which is where most of this module's money lands.
  String _factValue(Key key) => tester.widget<FactRow>(find.byKey(key)).value;
}
