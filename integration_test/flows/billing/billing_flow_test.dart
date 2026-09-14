import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/data/services/settings_service.dart';
import 'package:medihive/app/data/utils/invoice_math.dart';
import 'package:medihive/app/modules/billing/billing_status.dart';
import 'package:medihive/app/modules/billing/controllers/billing_controller.dart';
import 'package:medihive/app/theme/theme.dart';

import '../../fixtures/world_roles.dart';
import '../../robots/billing_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerBillingFlows();
}

/// Billing: raising a bill, taking money against it, and who may do either.
///
/// The ledger comes from `installBillingFixtures`, which `World.install` calls
/// — so the eight bills here are the same eight every other flow and every
/// screenshot sees, and a figure asserted on this screen is the figure the rest
/// of the suite is looking at.
void registerBillingFlows() {
  group('the ledger', () {
    testWidgets('an overdue invoice is amber, never the acuity red',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.billingStaff,
      );
      final billing = BillingRobot(harness);

      await billing.open();
      await billing.assertOnLedger();

      // The colour, not the label. `.agents/RULES.md` §0 rule 1 is about what
      // a reader sees across a corridor: a clinician scans for red and every
      // red that is not a deteriorating patient costs that scan its meaning.
      // An assertion on the word "Overdue" would pass just as happily against
      // a pill somebody had painted `acuityCritical`, which is precisely the
      // regression this test exists to catch.
      final overdue = billing.statusColourOf('inv-3');

      expect(
        overdue,
        AppColors.warning,
        reason: 'an overdue invoice is amber — an administrative problem, the '
            'same as a missed appointment',
      );
      expect(
        overdue,
        isNot(AppColors.acuityCritical),
        reason: 'red belongs to a deteriorating patient and to nothing else',
      );
      expect(overdue, isNot(AppColors.error));
      // And the word beside it, because a state is colour *and* word.
      expect(billing.statusLabelOf('inv-3'), 'Overdue');

      // The rest of the vocabulary, so a change to one status cannot quietly
      // take the others with it.
      expect(billing.statusColourOf('inv-6'), AppColors.acuityStable);
      expect(
        billing.statusColourOf('inv-2'),
        isNot(AppColors.acuityCritical),
        reason: 'a draft is neutral, not an alarm',
      );

      // The status filter narrows the ledger to the one row that is late.
      await billing.filterByStatus(InvoiceStatus.overdue);
      expect(billing.invoiceIdsInOrder(), ['inv-3']);
      billing.seeNoInvoice('inv-1');
    });

    testWidgets('billing staff may raise an invoice and a nurse may not',
        (tester) async {
      final asBilling = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.billingStaff,
      );
      final billing = BillingRobot(asBilling);

      await billing.open();
      await billing.assertOnLedger();
      expect(billing.invoiceCount, 8, reason: 'eight bills in this ledger');
      billing.seeNewInvoiceAction();

      // The catalogue is the other half of the same screen.
      await billing.showTab(BillingTab.services);
      await billing.openCatalogue();
      billing.seeService('svc-1');
    });

    testWidgets('a nurse gets the locked panel, not an error', (tester) async {
      // A nurse holds no billing grant at all — see `world_roles.dart`. The
      // controller therefore never asks the server, and the screen shows a
      // locked panel rather than a retry: nothing is broken, and "something
      // went wrong" over a ward's billing tab sends her to IT for a role she
      // was never meant to have.
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
      );
      final billing = BillingRobot(harness);

      await billing.open();
      billing.seeNoAccess();
      billing.seeNoNewInvoiceAction();
      billing.seeNoToast();
    });
  });

  group('raising an invoice', () {
    testWidgets('the totals pane agrees with InvoiceMath, and so does the POST',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.billingStaff,
      );
      final billing = BillingRobot(harness);

      await billing.open();
      await billing.tapNewInvoice();
      await billing.assertOnInvoiceForm();
      billing.seeLinesEmptyState();

      await billing.pickPatient('Ifeoma Balogun');

      // A catalogue line: ₹1,800 at 18%, taken twice.
      await billing.addService('Ultrasound Abdomen');
      await billing.setLineQuantity(0, '2');

      // And a custom one, untaxed, for something the catalogue does not carry.
      await billing.addCustomLine();
      await billing.setLineDescription(1, 'Crutches, hire');
      await billing.setLineUnitPrice(1, '800');

      await billing.setInvoiceDiscount('500');
      expect(billing.lineCount, 2);

      // The same call the screen makes, run independently here. Subtotal
      // 3,600 + 800 = 4,400; tax 648 on the imaging only; total
      // 4,400 − 500 + 648 = 4,548 — discount off the pre-tax subtotal, tax
      // added after it, exactly as `BillingService.createInvoice` does.
      final expected = InvoiceMath.totals(
        const [
          InvoiceLine(
            serviceId: 'svc-10',
            description: 'Ultrasound Abdomen',
            quantity: 2,
            unitPrice: 1800,
            taxPercentage: 18,
          ),
          InvoiceLine(description: 'Crutches, hire', unitPrice: 800),
        ],
        discountAmount: 500,
      );
      expect(expected.subtotal, 4400);
      expect(expected.tax, 648);
      expect(expected.total, 4548);

      billing.seeTotals(expected);

      await billing.saveInvoice();

      // The wire body, and the server's own arithmetic run over it. This is the
      // half a screenshot cannot check: a pane that reads 4,548 while the POST
      // carries lines that sum to something else is a bill somebody has to
      // explain at a counter.
      final posted = harness.api.requireCall('POST', '/api/billing/invoices');
      final body = posted.jsonBody;
      final items = (body['items'] as List).cast<Map<String, dynamic>>();

      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + (item['total'] as num).toDouble(),
      );
      final tax = items.fold<double>(
        0,
        (sum, item) => sum + (item['tax'] as num? ?? 0).toDouble(),
      );
      final discount = (body['discountAmount'] as num).toDouble();

      expect(subtotal, expected.subtotal, reason: 'sum of the line NETs');
      expect(
        tax,
        expected.tax,
        reason: 'tax travels beside the lines, never inside their totals — '
            'the server adds it to the subtotal a second time if it does',
      );
      expect(discount, expected.discount);
      expect(subtotal - discount + tax, expected.total);

      // And the catalogue link survived, so the charge can be traced back to
      // what was done.
      expect(items.first['referenceId'], 'svc-10');
      expect(items.first['quantity'], 2);

      billing.seeToast(containing: 'MOB-INV-0009');
      await billing.letToastsExpire();
    });

    testWidgets('an invoice with no lines on it is refused', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.billingStaff,
      );
      final billing = BillingRobot(harness);

      await billing.open();
      await billing.tapNewInvoice();
      await billing.pickPatient('Tom Whitfield');
      await billing.saveInvoice();

      billing.seeRefusal(naming: 'at least one line');
      harness.api.requireNoCall('POST', '/api/billing/invoices');
    });
  });

  group('taking money', () {
    testWidgets('a payment over the balance is refused, and the message names '
        'the balance', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.billingStaff,
      );
      final billing = BillingRobot(harness);

      await billing.open();
      // inv-4: part paid, so there is a real balance rather than the whole
      // total to overshoot.
      await billing.openInvoice('inv-4');
      await billing.assertOnInvoiceDetail();
      billing.seeRecordPaymentAction();

      await billing.tapRecordPayment();
      await billing.assertOnPaymentForm();

      // Pre-filled with the balance, because that is what happens at a counter
      // nine times out of ten. Read through the site's own convention rather
      // than spelled out: the seeded demo is India-first, and a test that
      // hard-coded a rupee symbol would be asserting the fixture rather than
      // the screen.
      final money = SettingsService.to.settings.money;
      expect(billing.amountOnScreen(), money.editable(1512));

      await billing.enterAmount('9000');
      await billing.savePayment();

      // Not a bare "too much": the number a person needs is the one they are
      // allowed to type, and they are standing at a counter with a patient in
      // front of them.
      billing.seeRefusal(naming: 'still owed');
      billing.seeRefusal(naming: money(1512));
      billing.seeStillOnPaymentForm();
      harness.api.requireNoCall('POST', '/api/billing/payments');
    });

    testWidgets('a method brings its own fields with it', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.billingStaff,
      );
      final billing = BillingRobot(harness);

      await billing.open();
      await billing.openInvoice('inv-4');
      await billing.tapRecordPayment();
      await billing.assertOnPaymentForm();

      // Cash asks for nothing beyond the amount.
      billing.seeConditionalFields();

      await billing.pickMethod('Mobile money');
      billing.seeConditionalFields(provider: true);

      await billing.pickMethod('Cheque');
      billing.seeConditionalFields(
        bank: true,
        chequeNumber: true,
        chequeDate: true,
      );

      await billing.pickMethod('Bank transfer');
      billing.seeConditionalFields(bank: true);

      // Switching away clears what no longer applies, so a cheque number does
      // not travel on a cash payment.
      await billing.pickMethod('Cash');
      billing.seeConditionalFields();
    });

    testWidgets('recording a payment moves the invoice', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.billingStaff,
      );
      final billing = BillingRobot(harness);

      await billing.open();
      await billing.openInvoice('inv-4');
      await billing.assertOnInvoiceDetail();

      final money = SettingsService.to.settings.money;
      expect(billing.outstandingOnScreen(), money(1512));
      expect(billing.paymentCount, 1, reason: 'one cash payment so far');

      await billing.tapRecordPayment();
      await billing.assertOnPaymentForm();

      await billing.enterAmount('500');
      await billing.pickMethod('Bank transfer');
      await billing.enterBank('State Bank of India');
      await billing.enterReference('NEFT-99120045');
      await billing.savePayment();

      final posted = harness.api.requireCall('POST', '/api/billing/payments');
      expect(posted.jsonBody['amount'], 500);
      expect(posted.jsonBody['paymentMethod'], 'bank_transfer');
      expect(posted.jsonBody['bankName'], 'State Bank of India');
      expect(
        posted.jsonBody.containsKey('chequeNumber'),
        isFalse,
        reason: 'a key the method does not use is dropped, not sent empty — '
            'the DTO runs forbidNonWhitelisted',
      );

      billing.seeToast(containing: 'MOB-RCP');
      await billing.letToastsExpire();

      // The bill behind the form has caught up: the payment announced itself
      // on the DataBus and the detail reloaded. Nothing here reached into a
      // sibling controller to make that happen — which is why this waits for
      // the balance rather than asserting it on the frame after the pop.
      await billing.assertOnInvoiceDetail();
      await billing.seeOutstanding(money(1012));
      await billing.seePaymentCount(2);
    });

    testWidgets('a settled bill offers nothing to pay, and a part-paid one '
        'cannot be cancelled', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.billingStaff,
      );
      final billing = BillingRobot(harness);

      await billing.open();

      // Settled: no payment action, because the server would refuse the write
      // and an app that offers it collects a receipt number and loses it.
      await billing.openInvoice('inv-6');
      await billing.assertOnInvoiceDetail();
      billing.seeNoRecordPaymentAction();
      await billing.back();

      // Part paid: cancelling is off, because the money would have to be
      // refunded first and this app has no refund route.
      await billing.openInvoice('inv-4');
      await billing.assertOnInvoiceDetail();
      billing.seeNoCancelAction();
      await billing.back();

      // A draft with nothing against it can be both sent and cancelled.
      await billing.openInvoice('inv-2');
      await billing.assertOnInvoiceDetail();
      billing.seeMarkSentAction();
      billing.seeCancelAction();
      billing.seeNoPayments();

      await billing.cancelInvoice('Raised against the wrong patient');
      billing.seeCancelledNotice();
      billing.seeToast(containing: 'cancelled');
      await billing.letToastsExpire();

      final patched = harness.api.requireCall(
        'PATCH',
        '/api/billing/invoices/:id',
      );
      expect(patched.jsonBody['status'], 'cancelled');
      expect(
        patched.jsonBody['cancellationReason'],
        'Raised against the wrong patient',
        reason: 'a cancelled invoice with no reason on it is a number the next '
            'person reconstructs from an audit log',
      );
    });
  });
}
