import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/utils/invoice_math.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `InvoiceMath`
///
/// These tests exist because money arithmetic that disagrees with the server by
/// one cent is a bill somebody has to explain at a counter. Each group below
/// pins one half of the contract in `hms_v2/src/modules/billing/
/// billing.service.ts`:
///
/// ```ts
/// const subtotal       = dto.items.reduce((s, i) => s + i.total, 0);
/// const taxAmount      = dto.items.reduce((s, i) => s + (i.tax ?? 0), 0);
/// const discountAmount = dto.discountAmount ?? 0;
/// const totalAmount    = subtotal - discountAmount + taxAmount;
/// ```
///
/// Three things follow, and every test here is about one of them:
///
///   1. a line's discount comes off **before** its tax;
///   2. `items[].total` is the line **net** — the server adds `taxAmount` on
///      top of `subtotal`, so tax inside `total` is charged twice;
///   3. the invoice-level discount comes off the **pre-tax** subtotal and does
///      not reduce tax.
///
/// The last group checks this file against the numbers the seed actually
/// stores, which is the closest thing to a fixture from the server itself.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('round', () {
    test('rounds to the site cent precision, half away from zero', () {
      // The server's own `Math.round(n * 100) / 100`, which for the positive
      // amounts an invoice is made of rounds .5 up.
      expect(InvoiceMath.round(10.005), 10.01);
      expect(InvoiceMath.round(10.004), 10.0);
      expect(InvoiceMath.round(2.675), 2.68);
    });

    test('a precision of zero is a real setting, not a bug', () {
      // Several currencies this product ships to have no minor unit, and a
      // bill in one of them that carries two decimals is a bill nobody can pay
      // exactly.
      expect(InvoiceMath.round(1234.6, precision: 0), 1235);
      expect(InvoiceMath.round(1234.4, precision: 0), 1234);
    });

    test('three decimals, for a site that prices in mills', () {
      expect(InvoiceMath.round(1.2345, precision: 3), 1.235);
    });

    test('an infinite value is zero rather than an exception', () {
      // A quantity field mid-edit can produce one, and a totals pane that
      // throws where the total goes is worse than one that reads zero.
      expect(InvoiceMath.round(double.infinity), 0);
      expect(InvoiceMath.round(double.nan), 0);
    });
  });

  group('line', () {
    test('net is quantity times price, and tax is charged on the net', () {
      const line = InvoiceLine(
        description: 'Consultation',
        quantity: 2,
        unitPrice: 250,
        taxPercentage: 18,
      );
      final totals = InvoiceMath.line(line);

      expect(totals.net, 500);
      expect(totals.tax, 90);
      expect(totals.gross, 590);
    });

    test('the line discount comes off BEFORE the tax is worked out', () {
      // 1000 − 100 = 900, taxed at 18% = 162. Taxing the list price first
      // would give 180 and overcharge the patient by 18.
      const line = InvoiceLine(
        description: 'Procedure',
        quantity: 1,
        unitPrice: 1000,
        discount: 100,
        taxPercentage: 18,
      );
      final totals = InvoiceMath.line(line);

      expect(totals.net, 900);
      expect(totals.tax, 162);
    });

    test('no tax percentage means no tax, and net is the whole line', () {
      const line = InvoiceLine(
        description: 'Consultation',
        quantity: 3,
        unitPrice: 150,
      );
      final totals = InvoiceMath.line(line);

      expect(totals.net, 450);
      expect(totals.tax, 0);
      expect(totals.gross, 450);
    });

    test('a discount bigger than the line is clamped, never negative', () {
      // A typo, and letting it through makes the line negative and the
      // invoice's tax negative with it.
      const line = InvoiceLine(
        description: 'Dressing',
        unitPrice: 100,
        discount: 500,
        taxPercentage: 18,
      );
      final totals = InvoiceMath.line(line);

      expect(totals.net, 0);
      expect(totals.tax, 0);
    });

    test('a zero-quantity line contributes nothing', () {
      // The DTO declares `@Min(1)`, so this never reaches the server — but it
      // is what a half-typed quantity field holds, and the pane renders while
      // it does.
      const line = InvoiceLine(
        description: 'Half typed',
        quantity: 0,
        unitPrice: 250,
        taxPercentage: 18,
      );
      expect(InvoiceMath.line(line).net, 0);
      expect(InvoiceMath.line(line).tax, 0);
    });

    test('a negative tax rate is not a rebate', () {
      const line = InvoiceLine(
        description: 'Odd',
        unitPrice: 100,
        taxPercentage: -18,
      );
      expect(InvoiceMath.line(line).tax, 0);
    });

    test('each line is rounded before it is summed', () {
      // 33.333 × 3 = 99.999, which rounds to 100.00 — not 99.99, which is what
      // summing at full precision and rounding once at the end gives.
      const line = InvoiceLine(
        description: 'Thirds',
        quantity: 3,
        unitPrice: 33.333,
      );
      expect(InvoiceMath.line(line).net, 100);
    });
  });

  group('discount', () {
    test('an amount is taken as given', () {
      expect(InvoiceMath.discount(1000, amount: 150), 150);
    });

    test('a percentage is taken on the subtotal', () {
      // After line discounts and before tax — the figure sitting above it in
      // the totals pane. "10% off" that is not ten percent of the number
      // beside it is a support call.
      expect(InvoiceMath.discount(1000, percentage: 10), 100);
      expect(InvoiceMath.discount(945, percentage: 12.5), 118.13);
    });

    test('a percentage wins over an amount when both are given', () {
      // Matching the console, where entering a percentage disables the amount
      // field.
      expect(InvoiceMath.discount(1000, amount: 999, percentage: 10), 100);
    });

    test('a percentage is capped at a hundred', () {
      expect(InvoiceMath.discount(1000, percentage: 250), 1000);
      expect(InvoiceMath.discount(1000, percentage: 100), 1000);
    });

    test('an amount is capped at the subtotal', () {
      // So a total can never go below the tax charged on it.
      expect(InvoiceMath.discount(500, amount: 900), 500);
    });

    test('nothing to discount discounts nothing', () {
      expect(InvoiceMath.discount(0, amount: 100), 0);
      expect(InvoiceMath.discount(0, percentage: 50), 0);
      expect(InvoiceMath.discount(1000), 0);
      expect(InvoiceMath.discount(1000, amount: -50), 0);
    });
  });

  group('totals — the order the server applies', () {
    test('subtotal is the sum of the pre-tax nets, tax is added on top', () {
      final totals = InvoiceMath.totals(const [
        InvoiceLine(description: 'Consultation', unitPrice: 500),
        InvoiceLine(
          description: 'X-ray',
          unitPrice: 1200,
          taxPercentage: 18,
        ),
      ]);

      expect(totals.subtotal, 1700);
      expect(totals.tax, 216);
      expect(totals.discount, 0);
      expect(totals.total, 1916);
    });

    test('the invoice discount does NOT reduce the tax', () {
      // This is the whole contract: `subtotal − discount + tax`, in that
      // order. Discounting the taxed figure instead would give 1916 − 200 =
      // 1716 here, and the app would render a total the server never stored.
      final totals = InvoiceMath.totals(
        const [
          InvoiceLine(description: 'Consultation', unitPrice: 500),
          InvoiceLine(
            description: 'X-ray',
            unitPrice: 1200,
            taxPercentage: 18,
          ),
        ],
        discountAmount: 200,
      );

      expect(totals.subtotal, 1700);
      expect(totals.discount, 200);
      expect(totals.tax, 216);
      expect(totals.total, 1716);
      expect(totals.total, totals.subtotal - totals.discount + totals.tax);
    });

    test('a percentage discount lands on the same total as its amount', () {
      final byPercent = InvoiceMath.totals(
        const [InvoiceLine(description: 'Bed day', unitPrice: 2000)],
        discountPercentage: 15,
      );
      final byAmount = InvoiceMath.totals(
        const [InvoiceLine(description: 'Bed day', unitPrice: 2000)],
        discountAmount: 300,
      );

      expect(byPercent.discount, 300);
      expect(byPercent.total, byAmount.total);
    });

    test('line discounts and an invoice discount stack, both before tax', () {
      // Line: 1000 − 100 = 900 net, taxed 18% = 162.
      // Invoice: 900 − 50 = 850, plus 162 = 1012.
      final totals = InvoiceMath.totals(
        const [
          InvoiceLine(
            description: 'Procedure',
            unitPrice: 1000,
            discount: 100,
            taxPercentage: 18,
          ),
        ],
        discountAmount: 50,
      );

      expect(totals.subtotal, 900);
      expect(totals.tax, 162);
      expect(totals.total, 1012);
    });

    test('an empty invoice is zero, not an exception', () {
      // The pane renders before the first line is added, and a totals pane
      // that throws where the total goes is worse than one that reads zero.
      final totals = InvoiceMath.totals(const []);

      expect(totals, InvoiceTotals.zero);
      expect(totals.isEmpty, isTrue);
      expect(totals.total, 0);
    });

    test('an empty invoice with a discount on it is still zero', () {
      final totals = InvoiceMath.totals(
        const [],
        discountAmount: 500,
        discountPercentage: 50,
      );
      expect(totals.total, 0);
      expect(totals.discount, 0);
    });

    test('rounds to the site precision, not to two decimals by habit', () {
      final totals = InvoiceMath.totals(
        const [
          InvoiceLine(description: 'Consultation', unitPrice: 333.333),
          InvoiceLine(description: 'Dressing', unitPrice: 166.666),
        ],
        precision: 0,
      );

      expect(totals.subtotal, 500);
      expect(totals.total, 500);
    });

    test('the discount can take the total down to the tax and no further', () {
      final totals = InvoiceMath.totals(
        const [
          InvoiceLine(
            description: 'Procedure',
            unitPrice: 1000,
            taxPercentage: 18,
          ),
        ],
        discountPercentage: 100,
      );

      expect(totals.discount, 1000);
      expect(totals.total, 180);
      expect(totals.total, greaterThanOrEqualTo(0));
    });
  });

  group('itemDraft — what actually goes on the wire', () {
    test('total is the NET, never the gross', () {
      // The one keystroke between this app and the console's double charge:
      // `CreateInvoiceDialog.tsx` posts `itemSubtotal - disc + tx` here, and
      // the server then adds `taxAmount` to a subtotal that already has the
      // tax in it.
      const line = InvoiceLine(
        description: 'X-ray',
        quantity: 2,
        unitPrice: 600,
        discount: 100,
        taxPercentage: 18,
      );
      final draft = InvoiceMath.itemDraft(line).toJson();

      expect(draft['total'], 1100);
      expect(draft['tax'], 198);
      expect(draft['discount'], 100);
      expect(draft['unitPrice'], 600);
      expect(draft['quantity'], 2);
    });

    test('a catalogue line carries its referenceId; a custom one has none', () {
      const fromCatalogue = InvoiceLine(
        serviceId: 'svc-1',
        description: 'Consultation',
        unitPrice: 500,
      );
      const custom = InvoiceLine(description: 'Crutches', unitPrice: 800);

      expect(
        InvoiceMath.itemDraft(fromCatalogue).toJson()['referenceId'],
        'svc-1',
      );
      // Dropped rather than sent as null: the DTO runs `forbidNonWhitelisted`
      // and a null there is a key the server has to decide about.
      expect(
        InvoiceMath.itemDraft(custom).toJson().containsKey('referenceId'),
        isFalse,
      );
    });

    test('the drafted items sum to the totals the pane showed', () {
      const lines = [
        InvoiceLine(description: 'Consultation', unitPrice: 500),
        InvoiceLine(
          description: 'X-ray',
          quantity: 2,
          unitPrice: 600,
          discount: 100,
          taxPercentage: 18,
        ),
      ];
      final totals = InvoiceMath.totals(lines, discountAmount: 150);

      // The server's own arithmetic, run over the bodies this app would post.
      final items = [for (final line in lines) InvoiceMath.itemDraft(line)];
      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + (item.toJson()['total'] as double),
      );
      final tax = items.fold<double>(
        0,
        (sum, item) => sum + (item.toJson()['tax'] as double),
      );

      expect(subtotal, totals.subtotal);
      expect(tax, totals.tax);
      expect(subtotal - totals.discount + tax, totals.total);
    });
  });

  group('against the seeded demo invoices', () {
    test('MOB-INV-0001 — one taxable line at 18% GST', () {
      // `hms_v2/prisma/seed-mobile-demo.ts` builds its lines the way the
      // service expects — `total: lineTotal` pre-tax, `tax` beside it — and
      // its comment says so. If this app ever drifts, this is the test that
      // notices before a patient does.
      final totals = InvoiceMath.totals(const [
        InvoiceLine(
          description: 'Minor Procedure',
          unitPrice: 500,
          taxPercentage: 18,
        ),
      ]);

      expect(totals.subtotal, 500);
      expect(totals.tax, 90);
      expect(totals.total, 590);
    });

    test('a consultation is exempt and a procedure is not', () {
      // The seed leaves consultations untaxed and charges 18% on procedures,
      // which is how an Indian invoice actually reads.
      final totals = InvoiceMath.totals(const [
        InvoiceLine(description: 'General Consultation', unitPrice: 400),
        InvoiceLine(
          description: 'Minor Procedure',
          unitPrice: 500,
          taxPercentage: 18,
        ),
      ]);

      expect(totals.subtotal, 900);
      expect(totals.tax, 90);
      expect(totals.total, 990);
    });
  });
}
