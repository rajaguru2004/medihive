/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — invoice arithmetic
///
/// Pure functions, no Flutter, no network. Everything the invoice form shows
/// and everything it posts comes from here, because the two have to be the same
/// number: a client that renders one total and sends the parts of another
/// produces a bill somebody has to explain at a counter.
///
/// ## The order the server applies, verified against the source
///
/// `hms_v2/src/modules/billing/billing.service.ts`, `createInvoice`:
///
/// ```ts
/// const subtotal       = dto.items.reduce((s, i) => s + i.total, 0);
/// const taxAmount      = dto.items.reduce((s, i) => s + (i.tax ?? 0), 0);
/// const discountAmount = dto.discountAmount ?? 0;
/// const totalAmount    = subtotal - discountAmount + taxAmount;
/// ```
///
/// So, in words, and this is the whole contract:
///
///   1. **A line's discount comes off before its tax.** Tax is charged on what
///      the line actually costs after its own discount, never on the list
///      price.
///   2. **`items[].total` is the line NET — excluding tax.** The server adds
///      `taxAmount` on top of `subtotal`, so a client that folds tax into
///      `total` has the server charge it twice.
///   3. **The invoice-level discount comes off the pre-tax subtotal, and does
///      not reduce tax.** `subtotal − discount + tax`, in that order.
///
/// Point 2 is the one worth stating twice, because the web console gets it
/// wrong. `frontend/src/features/billing/components/invoices/
/// CreateInvoiceDialog.tsx` posts `total: itemSubtotal - disc + tx` — tax
/// inside the line — and the stored `totalAmount` therefore carries the tax
/// twice while the dialog displays it once. The seed
/// (`hms_v2/prisma/seed-mobile-demo.ts`) is the one that agrees with the
/// service, and says so in a comment: *"subtotal is the sum of the pre-tax line
/// totals, `taxAmount` the sum of the line taxes."* This file follows the
/// service and the seed.
///
/// ## `discountPercentage` is stored and never used
///
/// The DTO accepts it, the column keeps it, and `createInvoice` reads only
/// `discountAmount`. A percentage is therefore resolved to money **here** and
/// both keys are sent — the amount so the total is right, the percentage so the
/// document still records what was agreed.
///
/// The percentage is taken on the **subtotal** — after line discounts, before
/// tax — because that is the figure sitting above it in the totals pane, and
/// "10% off" that is not ten percent of the number beside it is a support call.
/// (The console takes it on the gross instead; since the server ignores the
/// field entirely there is no third party to disagree with.)
///
/// ## Rounding
///
/// Every intermediate is rounded to the site's `centPrecision` before it is
/// summed, which is what the seed's `money()` helper does
/// (`Math.round(n * 100) / 100`). Summing at full precision and rounding once
/// at the end drifts by a cent on about one invoice in six.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../models/drafts/billing_drafts.dart';

/// One line of an invoice being built.
///
/// Immutable: the form replaces a line rather than mutating it, so an `Obx`
/// watching the list sees the change. [serviceId] is null for a custom line —
/// something billed that is not in the catalogue.
class InvoiceLine {
  const InvoiceLine({
    required this.description,
    this.serviceId,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discount = 0,
    this.taxPercentage = 0,
    this.type = 'service',
  });

  /// The catalogue entry this line bills, when it came from one. Sent as the
  /// item's `referenceId`, which is what links a charge back to what was done.
  final String? serviceId;

  final String description;

  /// Whole units. The DTO declares `@Min(1)`, so zero is a 400 rather than a
  /// free line.
  final int quantity;

  final double unitPrice;

  /// Money off this line, not a percentage — the DTO's `discount` is an
  /// amount.
  final double discount;

  /// Percent, not a fraction: `18`, not `0.18`. Carried on the line rather
  /// than looked up at send time because a catalogue price can change between
  /// the line being added and the invoice being raised, and the bill is the
  /// one the patient was quoted.
  final double taxPercentage;

  /// `service`, `lab`, `radiology`, `pharmacy`, `bed`. Free text on the
  /// backend.
  final String type;

  InvoiceLine copyWith({
    String? serviceId,
    String? description,
    int? quantity,
    double? unitPrice,
    double? discount,
    double? taxPercentage,
    String? type,
  }) =>
      InvoiceLine(
        serviceId: serviceId ?? this.serviceId,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        discount: discount ?? this.discount,
        taxPercentage: taxPercentage ?? this.taxPercentage,
        type: type ?? this.type,
      );

  /// Clears the catalogue link. `copyWith` cannot: passing null there means
  /// "leave it alone", which is the behaviour every other field needs.
  InvoiceLine asCustomLine() => InvoiceLine(
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        discount: discount,
        taxPercentage: taxPercentage,
        type: type,
      );
}

/// What one line comes to, at the site's precision.
class LineTotals {
  const LineTotals({required this.net, required this.tax});

  /// `quantity × unitPrice − discount`. **Pre-tax** — this is what goes in the
  /// item's `total`, because the server sums these into `subtotal` and then
  /// adds the taxes separately.
  final double net;

  /// The line's own tax, charged on [net].
  final double tax;

  /// What this line adds to the bill, tax included. For display only: sending
  /// it as the item's `total` is the console's bug.
  double get gross => net + tax;

  static const LineTotals zero = LineTotals(net: 0, tax: 0);
}

/// The four figures in the totals pane, and the four the server will store.
class InvoiceTotals {
  const InvoiceTotals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  /// Sum of the pre-tax line nets.
  final double subtotal;

  /// The invoice-level discount as money, whether it was entered as money or
  /// as a percentage. Clamped to [subtotal].
  final double discount;

  /// Sum of the line taxes. An invoice-level discount does not reduce it —
  /// the server adds this to `subtotal − discount` untouched.
  final double tax;

  /// `subtotal − discount + tax`.
  final double total;

  static const InvoiceTotals zero =
      InvoiceTotals(subtotal: 0, discount: 0, tax: 0, total: 0);

  bool get isEmpty => subtotal == 0 && tax == 0 && total == 0;

  @override
  bool operator ==(Object other) =>
      other is InvoiceTotals &&
      other.subtotal == subtotal &&
      other.discount == discount &&
      other.tax == tax &&
      other.total == total;

  @override
  int get hashCode => Object.hash(subtotal, discount, tax, total);

  @override
  String toString() => 'InvoiceTotals(subtotal: $subtotal, '
      'discount: $discount, tax: $tax, total: $total)';
}

/// The arithmetic of an invoice, in one place with no widgets in it.
abstract final class InvoiceMath {
  /// The largest discount percentage that means anything. Above it the line is
  /// free and the arithmetic goes negative; the console's schema caps at the
  /// same number.
  static const double maxDiscountPercentage = 100;

  /// Rounds to the site's `centPrecision` — `MoneyFormat.precision`.
  ///
  /// Half away from zero, which is what the server's `Math.round(n * 100) / 100`
  /// does for the positive amounts an invoice is made of.
  ///
  /// A precision of zero is a real setting: several currencies this product
  /// ships to have no minor unit, and a bill in them that carries two decimals
  /// is a bill nobody can pay exactly.
  static double round(double value, {int precision = 2}) {
    if (!value.isFinite) return 0;
    if (precision <= 0) return value.roundToDouble();
    final factor = _factor(precision);
    return (value * factor).round() / factor;
  }

  /// One line's net and tax.
  ///
  /// The discount is clamped to the line's gross: a discount larger than the
  /// line is a typo, and letting it through makes the line negative and the
  /// invoice's tax negative with it.
  static LineTotals line(InvoiceLine line, {int precision = 2}) {
    final gross = round(line.unitPrice * line.quantity, precision: precision);
    if (gross <= 0) return LineTotals.zero;

    final discount =
        round(line.discount.clamp(0, gross).toDouble(), precision: precision);
    final net = round(gross - discount, precision: precision);

    // Percent, not a fraction, and negative is not a rebate.
    final rate = line.taxPercentage <= 0 ? 0.0 : line.taxPercentage;
    final tax = round(net * rate / 100, precision: precision);

    return LineTotals(net: net, tax: tax);
  }

  /// The invoice-level discount as money.
  ///
  /// [percentage] wins when it is given and above zero, matching the console —
  /// where entering a percentage disables the amount field. Capped at
  /// [maxDiscountPercentage] and then at [subtotal], so a total can never go
  /// below the tax on it.
  static double discount(
    double subtotal, {
    double amount = 0,
    double? percentage,
    int precision = 2,
  }) {
    if (subtotal <= 0) return 0;

    final pct = percentage ?? 0;
    final raw = pct > 0
        ? subtotal * pct.clamp(0, maxDiscountPercentage) / 100
        : amount;

    if (raw <= 0) return 0;
    return round(raw.clamp(0, subtotal).toDouble(), precision: precision);
  }

  /// Every figure on the invoice, in the server's own order.
  ///
  /// An empty invoice answers [InvoiceTotals.zero] rather than throwing: the
  /// form shows the pane before the first line is added, and a totals pane that
  /// renders an error where the total goes is worse than one that reads zero.
  static InvoiceTotals totals(
    Iterable<InvoiceLine> lines, {
    double discountAmount = 0,
    double? discountPercentage,
    int precision = 2,
  }) {
    var subtotal = 0.0;
    var tax = 0.0;
    for (final row in lines) {
      final totals = line(row, precision: precision);
      subtotal += totals.net;
      tax += totals.tax;
    }
    subtotal = round(subtotal, precision: precision);
    tax = round(tax, precision: precision);

    final off = discount(
      subtotal,
      amount: discountAmount,
      percentage: discountPercentage,
      precision: precision,
    );

    return InvoiceTotals(
      subtotal: subtotal,
      discount: off,
      tax: tax,
      // The server's expression, character for character.
      total: round(subtotal - off + tax, precision: precision),
    );
  }

  /// One line as the DTO wants it.
  ///
  /// `total` is the **net**, and that is the whole reason this lives beside the
  /// arithmetic rather than in the controller: it is one keystroke from the
  /// console's double-charge, and a reviewer reading the controller would have
  /// no way to tell which one it was.
  static InvoiceItemDraft itemDraft(InvoiceLine row, {int precision = 2}) {
    final totals = line(row, precision: precision);
    return InvoiceItemDraft(
      type: row.type,
      referenceId: row.serviceId,
      description: row.description.trim(),
      quantity: row.quantity,
      unitPrice: round(row.unitPrice, precision: precision),
      discount: round(
        row.discount.clamp(0, double.maxFinite).toDouble(),
        precision: precision,
      ),
      tax: totals.tax,
      total: totals.net,
    );
  }

  static double _factor(int precision) {
    var factor = 1.0;
    for (var i = 0; i < precision; i++) {
      factor *= 10;
    }
    return factor;
  }
}
