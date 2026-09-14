import 'dart:convert';

import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — billing, in fixtures
///
/// One coherent ledger: eight bills against the patients the rest of the world
/// already knows, five receipts across four methods, and a twelve-entry
/// catalogue the invoice form can build from. The figures agree with each
/// other — `stats` is derived from the rows rather than typed beside them, so a
/// screen showing both cannot be caught disagreeing with itself.
///
/// **The arithmetic here follows `BillingService.createInvoice`**, not the web
/// console: `items[].total` is the line **net**, `taxAmount` is the sum of the
/// line taxes, and `totalAmount = subtotal − discountAmount + taxAmount`. A
/// fixture built the console's way — tax folded into `total` — would make the
/// app's totals pane look wrong against its own data and hide the exact bug
/// this module exists to avoid.
///
/// **The ledger is mutable, and per install.** `POST /billing/payments` does
/// what the server does: it credits the invoice, recomputes the balance and
/// moves both statuses. A fixture that answered with a receipt and left the
/// invoice alone would let "record a payment" pass while the thing a collector
/// is actually watching — the balance — never moved. Every row is rebuilt
/// inside [installBillingFixtures], so one flow's payment is not visible to the
/// next flow in the same file.
///
/// India-first, because the seeded demo is: 18% GST on procedures and imaging,
/// consultations exempt. **Nothing in `lib/` knows that** — every figure on
/// screen goes through `SettingsService.money`, and the site chooses the
/// currency.
///
/// The mix is deliberate:
///
///   * three **unpaid**, one of them **overdue** — the row whose pill must be
///     amber and must not be `acuityCritical`;
///   * two **partially paid**, so the paid-against-total bar has something to
///     draw and the ledger's "still owed of" hint has something to say;
///   * three **paid**, so the green pill and a settled balance are both on
///     screen.
/// ─────────────────────────────────────────────────────────────────────────────

/// Registers every billing route the app calls. Called from `World.install`.
void installBillingFixtures(FakeApi api) {
  // Per install, not per library. See the note above: these are written to.
  final services = _buildServices();
  final invoices = _buildInvoices();
  final payments = _buildPayments(invoices);

  // ── Stats ────────────────────────────────────────────────────────────────

  api.on('GET', '/api/billing/stats', (_) {
    final unsettled = invoices.where(
      (i) =>
          i['paymentStatus'] == 'unpaid' ||
          i['paymentStatus'] == 'partially_paid',
    );
    final collected = payments.fold<double>(
      0,
      (sum, payment) => sum + _num(payment['amount']),
    );

    return FakeResponse.ok({
      // The server computes both from the same query — they are one number
      // answered under two keys, and a fixture that made them differ would be
      // testing a disagreement the backend cannot produce.
      'todayRevenue': collected,
      'collectedToday': collected,
      'pendingInvoices': unsettled.length,
      'outstandingBalance': _money(
        unsettled.fold<double>(0, (sum, i) => sum + _num(i['balanceDue'])),
      ),
      'totalServices': services.length,
    });
  });

  // ── The catalogue ────────────────────────────────────────────────────────

  api.on('GET', '/api/billing/services', (request) {
    final category = request.query['category'];
    final rows = category == null || category.isEmpty
        ? services
        : services.where((s) => s['serviceCategory'] == category).toList();
    // A bare array: `GET /billing/services` has no pagination DTO at all and
    // answers one however it is asked. A fixture that paged it here would be
    // testing a shape the server never sends.
    return FakeResponse.ok(rows);
  });

  api.on('POST', '/api/billing/services', (request) {
    final created = <String, Object?>{
      'id': 'svc-new',
      'organizationId': 'o-1',
      'isActive': true,
      'createdAt': _minutesAgo(0),
      ...request.jsonBody,
    };
    services.add(created);
    return FakeResponse.ok(created);
  });

  api.on('PATCH', '/api/billing/services/:id', (request) {
    final index = services.indexWhere(
      (s) => s['id'] == request.pathParams['id'],
    );
    if (index == -1) {
      return FakeResponse.fail(404, 'Billing service not found');
    }
    services[index] = {...services[index], ...request.jsonBody};
    return FakeResponse.ok(services[index]);
  });

  // ── Invoices ─────────────────────────────────────────────────────────────

  api.on('GET', '/api/billing/invoices', (request) {
    var rows = invoices.toList();

    // The patient hub's Billing tab asks for one person's bills through this
    // same route, and it is installed before this one — so without the filter
    // here the hub would show the whole ledger under one patient's name.
    final patientId = request.query['patientId'];
    if (patientId != null && patientId.isNotEmpty) {
      rows = rows.where((i) => i['patientId'] == patientId).toList();
    }

    final status = request.query['status'];
    if (status != null && status.isNotEmpty) {
      rows = rows.where((i) => i['status'] == status).toList();
    }

    final search = request.query['search']?.trim().toLowerCase();
    if (search != null && search.isNotEmpty) {
      rows = rows.where((invoice) {
        final patient = invoice['patient']! as Map<String, Object?>;
        final haystack = [
          invoice['invoiceNumber'],
          patient['firstName'],
          patient['lastName'],
          patient['mrn'],
        ].join(' ').toLowerCase();
        return haystack.contains(search);
      }).toList();
    }

    // Bare array without `page`, `{data, meta}` with it. Both, because both are
    // real: a `PagedQuery` always sends `page`, and a caller that does not gets
    // the array.
    return request.query.containsKey('page')
        ? FakeResponse.page(rows, limit: 50)
        : FakeResponse.ok(rows);
  });

  api.on('GET', '/api/billing/invoices/:id', (request) {
    final id = request.pathParams['id'];
    final invoice = invoices.firstWhere(
      (i) => i['id'] == id,
      orElse: () => const <String, Object?>{},
    );
    if (invoice.isEmpty) return FakeResponse.fail(404, 'Invoice not found');

    // `getInvoiceById` includes the payments, which is why the detail screen
    // costs one request rather than two.
    return FakeResponse.ok({
      ...invoice,
      'payments': payments.where((p) => p['invoiceId'] == id).toList(),
    });
  });

  api.on('POST', '/api/billing/invoices', (request) {
    final body = request.jsonBody;
    final items =
        (body['items'] as List? ?? const []).cast<Map<String, dynamic>>();

    // The server's own arithmetic, run over whatever the app posted. Computed
    // rather than canned, so a flow can assert the totals pane and the stored
    // invoice agree — which is the whole point of `InvoiceMath`.
    final subtotal =
        _money(items.fold<double>(0, (sum, i) => sum + _num(i['total'])));
    final tax = _money(items.fold<double>(0, (sum, i) => sum + _num(i['tax'])));
    final discount = _num(body['discountAmount']);
    final total = _money(subtotal - discount + tax);

    final created = <String, Object?>{
      'id': 'inv-new',
      'organizationId': 'o-1',
      'patientId': body['patientId'],
      'invoiceNumber': 'MOB-INV-0009',
      'invoiceDate': _minutesAgo(0),
      'dueDate': body['dueDate'],
      'items': jsonEncode(items),
      'subtotal': subtotal,
      'discountAmount': discount,
      'discountPercentage': _num(body['discountPercentage']),
      'taxAmount': tax,
      'totalAmount': total,
      'paymentStatus': 'unpaid',
      'amountPaid': 0,
      'balanceDue': total,
      'insuranceClaimAmount': 0,
      'patientCopayAmount': 0,
      'status': 'draft',
      'notes': body['notes'],
      'createdAt': _minutesAgo(0),
      'patient': _patientById('${body['patientId']}'),
    };
    invoices.insert(0, created);
    return FakeResponse.ok(created);
  });

  api.on('PATCH', '/api/billing/invoices/:id', (request) {
    final index = invoices.indexWhere(
      (i) => i['id'] == request.pathParams['id'],
    );
    if (index == -1) return FakeResponse.fail(404, 'Invoice not found');

    final body = Map<String, Object?>.from(request.jsonBody);
    if (body['status'] == 'cancelled') {
      body['cancelledAt'] = _minutesAgo(0);
      body['paymentStatus'] = 'cancelled';
    }
    invoices[index] = {...invoices[index], ...body};
    return FakeResponse.ok(invoices[index]);
  });

  // ── Payments ─────────────────────────────────────────────────────────────

  api.on('GET', '/api/billing/payments', (request) {
    final invoiceId = request.query['invoiceId'];
    final rows = invoiceId == null || invoiceId.isEmpty
        ? payments
        : payments.where((p) => p['invoiceId'] == invoiceId).toList();
    return request.query.containsKey('page')
        ? FakeResponse.page(rows, limit: 100)
        : FakeResponse.ok(rows);
  });

  api.on('GET', '/api/billing/payments/:id', (request) {
    final id = request.pathParams['id'];
    final payment = payments.firstWhere(
      (p) => p['id'] == id,
      orElse: () => const <String, Object?>{},
    );
    return payment.isEmpty
        ? FakeResponse.fail(404, 'Payment record not found')
        : FakeResponse.ok(payment);
  });

  api.on('POST', '/api/billing/payments', (request) {
    final body = request.jsonBody;
    final invoiceId = '${body['invoiceId']}';
    final index = invoices.indexWhere((i) => i['id'] == invoiceId);
    if (index == -1) return FakeResponse.fail(404, 'Invoice not found');

    final amount = _money(_num(body['amount']));
    final payment = <String, Object?>{
      'id': 'pay-${payments.length + 1}',
      'organizationId': 'o-1',
      'invoiceId': invoiceId,
      'patientId': body['patientId'],
      'paymentDate': _minutesAgo(0),
      'receiptNumber': 'MOB-RCP-000${payments.length + 1}',
      'amount': amount,
      'paymentMethod': body['paymentMethod'],
      'paymentReference': body['paymentReference'],
      'cardLastFour': null,
      'mobileMoneyProvider': body['mobileMoneyProvider'],
      'bankName': body['bankName'],
      'chequeNumber': body['chequeNumber'],
      'chequeDate': null,
      'isRefund': false,
      'notes': body['notes'],
      'createdAt': _minutesAgo(0),
    };
    payments.add(payment);

    // Exactly what `createPayment` does next, and the half that matters: a
    // receipt that does not move the balance is a receipt nobody can reconcile.
    final invoice = invoices[index];
    final total = _num(invoice['totalAmount']);
    final paid = _money(_num(invoice['amountPaid']) + amount);
    final settled = paid >= total;
    invoices[index] = {
      ...invoice,
      'amountPaid': paid,
      'balanceDue': _money(total - paid),
      'paymentStatus': settled ? 'paid' : 'partially_paid',
      'status': settled ? 'paid' : 'sent',
    };

    return FakeResponse.ok(payment);
  });
}

// ── The catalogue ───────────────────────────────────────────────────────────

/// Twelve chargeable things, across five categories.
///
/// Tax follows the seeded demo: consultations exempt, everything a machine or a
/// theatre does at 18%. A site elsewhere would configure it differently, and
/// nothing in `lib/` assumes either way.
List<Map<String, Object?>> _buildServices() => [
      _service('svc-1', 'General Consultation', 'SRV-001', 'consultation',
          'Outpatient', 400, taxable: false),
      _service('svc-2', 'Specialist Consultation', 'SRV-002', 'consultation',
          'Outpatient', 900, taxable: false),
      _service('svc-3', 'Follow-up Consultation', 'SRV-003', 'consultation',
          'Outpatient', 250, taxable: false),
      _service('svc-4', 'Minor Procedure', 'SRV-010', 'procedure',
          'Day Surgery', 500),
      _service('svc-5', 'Wound Dressing', 'SRV-011', 'procedure', 'Outpatient',
          350),
      _service('svc-6', 'Suturing', 'SRV-012', 'procedure', 'Emergency', 1200),
      _service('svc-7', 'Full Blood Count', 'SRV-020', 'laboratory',
          'Laboratory', 300),
      _service('svc-8', 'Liver Function Panel', 'SRV-021', 'laboratory',
          'Laboratory', 850),
      _service('svc-9', 'Chest X-ray', 'SRV-030', 'radiology', 'Radiology',
          1200),
      _service('svc-10', 'Ultrasound Abdomen', 'SRV-031', 'radiology',
          'Radiology', 1800),
      _service('svc-11', 'General Ward, per night', 'SRV-040', 'accommodation',
          'Inpatient', 2200, copay: 10),
      // One retired entry, so the catalogue screen has a dimmed row on it and a
      // flow can prove a service is *hidden* rather than deleted.
      _service('svc-12', 'Private Room, per night', 'SRV-041', 'accommodation',
          'Inpatient', 4500, active: false, copay: 20),
    ];

Map<String, Object?> _service(
  String id,
  String name,
  String code,
  String category,
  String department,
  double price, {
  bool taxable = true,
  double taxPercentage = 18,
  bool covered = true,
  double? copay,
  bool active = true,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'serviceName': name,
      'serviceCode': code,
      'serviceCategory': category,
      'department': department,
      'unitPrice': price,
      'isTaxable': taxable,
      'taxPercentage': taxable ? taxPercentage : 0,
      'isCoveredByInsurance': covered,
      'insuranceCopayPercentage': copay,
      'description': null,
      'isActive': active,
      'createdAt': _minutesAgo(60 * 24 * 30),
    };

// ── The ledger ──────────────────────────────────────────────────────────────

/// Eight bills: three unpaid (one of them overdue), two part paid, three paid.
List<Map<String, Object?>> _buildInvoices() => [
      // ── Unpaid ──────────────────────────────────────────────────────────
      _invoice(
        id: 'inv-1',
        number: 'MOB-INV-0001',
        patient: _patients['p-1']!,
        lines: const [
          _Line('General Consultation', 400, taxRate: 0, serviceId: 'svc-1'),
          _Line('Full Blood Count', 300, serviceId: 'svc-7'),
        ],
        status: 'sent',
        paymentStatus: 'unpaid',
        dueInDays: 9,
      ),
      _invoice(
        id: 'inv-2',
        number: 'MOB-INV-0002',
        patient: _patients['p-2']!,
        lines: const [_Line('Chest X-ray', 1200, serviceId: 'svc-9')],
        status: 'draft',
        paymentStatus: 'unpaid',
      ),
      // **The overdue one.** Its pill has to be amber — `AppColors.warning` —
      // and must never be `acuityCritical`: a clinician scans a ward board for
      // red, and an unpaid bill that borrows it costs that scan its meaning.
      _invoice(
        id: 'inv-3',
        number: 'MOB-INV-0003',
        patient: _patients['p-4']!,
        lines: const [
          _Line('Suturing', 1200, serviceId: 'svc-6'),
          _Line('Wound Dressing', 350, quantity: 2, serviceId: 'svc-5'),
        ],
        status: 'overdue',
        paymentStatus: 'unpaid',
        dueInDays: -21,
      ),

      // ── Partially paid ──────────────────────────────────────────────────
      _invoice(
        id: 'inv-4',
        number: 'MOB-INV-0004',
        patient: _patients['p-3']!,
        lines: const [
          _Line('Specialist Consultation', 900, taxRate: 0, serviceId: 'svc-2'),
          _Line('Ultrasound Abdomen', 1800, serviceId: 'svc-10'),
        ],
        status: 'sent',
        paymentStatus: 'partially_paid',
        paidFraction: 0.5,
        dueInDays: 5,
      ),
      _invoice(
        id: 'inv-5',
        number: 'MOB-INV-0005',
        patient: _patients['p-5']!,
        lines: const [
          _Line('General Ward, per night', 2200,
              quantity: 3, serviceId: 'svc-11'),
        ],
        status: 'sent',
        paymentStatus: 'partially_paid',
        paidFraction: 0.4,
        discount: 500,
        dueInDays: 12,
      ),

      // ── Paid ────────────────────────────────────────────────────────────
      _invoice(
        id: 'inv-6',
        number: 'MOB-INV-0006',
        patient: _patients['p-6']!,
        lines: const [_Line('Minor Procedure', 500, serviceId: 'svc-4')],
        status: 'paid',
        paymentStatus: 'paid',
        paidFraction: 1,
        dueInDays: -3,
      ),
      _invoice(
        id: 'inv-7',
        number: 'MOB-INV-0007',
        patient: _patients['p-7']!,
        lines: const [
          _Line('Liver Function Panel', 850, serviceId: 'svc-8'),
          _Line('Follow-up Consultation', 250, taxRate: 0, serviceId: 'svc-3'),
        ],
        status: 'paid',
        paymentStatus: 'paid',
        paidFraction: 1,
        dueInDays: -6,
      ),
      _invoice(
        id: 'inv-8',
        number: 'MOB-INV-0008',
        patient: _patients['p-1']!,
        lines: const [_Line('Wound Dressing', 350, serviceId: 'svc-5')],
        status: 'paid',
        paymentStatus: 'paid',
        paidFraction: 1,
        dueInDays: -14,
      ),
    ];

/// Five receipts across four of the seven methods, so the payment history has
/// more than one shape in it and four method icons are exercised.
///
/// Each amount is read back off the invoice it settles rather than restated, so
/// a payment can never be for a figure its own bill does not recognise.
List<Map<String, Object?>> _buildPayments(
  List<Map<String, Object?>> invoices,
) {
  double paidOn(String id) =>
      _num(invoices.firstWhere((i) => i['id'] == id)['amountPaid']);

  return [
    _payment(
      id: 'pay-1',
      receipt: 'MOB-RCP-0001',
      invoiceId: 'inv-4',
      patientId: 'p-3',
      amount: paidOn('inv-4'),
      method: 'cash',
      minutesAgo: 90,
    ),
    _payment(
      id: 'pay-2',
      receipt: 'MOB-RCP-0002',
      invoiceId: 'inv-5',
      patientId: 'p-5',
      amount: paidOn('inv-5'),
      method: 'bank_transfer',
      bankName: 'State Bank of India',
      reference: 'NEFT-88213004',
      minutesAgo: 140,
    ),
    _payment(
      id: 'pay-3',
      receipt: 'MOB-RCP-0003',
      invoiceId: 'inv-6',
      patientId: 'p-6',
      amount: paidOn('inv-6'),
      method: 'mobile_money',
      provider: 'UPI',
      reference: 'UPI-4471029',
      minutesAgo: 210,
    ),
    _payment(
      id: 'pay-4',
      receipt: 'MOB-RCP-0004',
      invoiceId: 'inv-7',
      patientId: 'p-7',
      amount: paidOn('inv-7'),
      method: 'insurance',
      reference: 'CLM-2026-0417',
      minutesAgo: 280,
    ),
    _payment(
      id: 'pay-5',
      receipt: 'MOB-RCP-0005',
      invoiceId: 'inv-8',
      patientId: 'p-1',
      amount: paidOn('inv-8'),
      method: 'cash',
      minutesAgo: 320,
    ),
  ];
}

// ── Builders ────────────────────────────────────────────────────────────────

/// One line of a bill, before the arithmetic is run over it.
class _Line {
  const _Line(
    this.description,
    this.unitPrice, {
    this.quantity = 1,
    this.taxRate = 18,
    this.serviceId,
  });

  final String description;
  final double unitPrice;
  final int quantity;

  /// Percent. Zero for a consultation, which the seeded site treats as exempt.
  final double taxRate;

  final String? serviceId;
}

/// Builds one invoice the way `BillingService.createInvoice` would have.
///
/// `items[].total` is the **net**; `taxAmount` is the sum of the line taxes;
/// `totalAmount = subtotal − discountAmount + taxAmount`. Getting that order
/// right here is what lets a flow assert the app's totals against its own data.
Map<String, Object?> _invoice({
  required String id,
  required String number,
  required Map<String, Object?> patient,
  required List<_Line> lines,
  required String status,
  required String paymentStatus,
  double paidFraction = 0,
  double discount = 0,
  int? dueInDays,
}) {
  final items = [
    for (final line in lines)
      {
        'type': 'service',
        'referenceId': line.serviceId,
        'description': line.description,
        'quantity': line.quantity,
        'unitPrice': line.unitPrice,
        'discount': 0,
        'tax': _money(line.unitPrice * line.quantity * line.taxRate / 100),
        'total': _money(line.unitPrice * line.quantity),
      },
  ];

  final subtotal =
      _money(items.fold<double>(0, (sum, item) => sum + _num(item['total'])));
  final tax =
      _money(items.fold<double>(0, (sum, item) => sum + _num(item['tax'])));
  final total = _money(subtotal - discount + tax);
  final paid = _money(total * paidFraction);

  return {
    'id': id,
    'organizationId': 'o-1',
    'patientId': patient['id'],
    'invoiceNumber': number,
    'invoiceDate': _minutesAgo(60 * 24 * 2),
    'dueDate': dueInDays == null ? null : _dayOffset(dueInDays),
    // A JSON **string**, which is how the column stores it. `asModelList`
    // decodes it; a fixture that sent a real array would be testing a shape the
    // server never answers with.
    'items': jsonEncode(items),
    'subtotal': subtotal,
    'discountAmount': discount,
    'discountPercentage': 0,
    'taxAmount': tax,
    'totalAmount': total,
    'paymentStatus': paymentStatus,
    'amountPaid': paid,
    'balanceDue': _money(total - paid),
    'insuranceClaimAmount': 0,
    'insuranceClaimStatus': null,
    'patientCopayAmount': 0,
    'status': status,
    'notes': null,
    'termsAndConditions': null,
    'cancelledAt': null,
    'cancelledById': null,
    'cancellationReason': null,
    'createdAt': _minutesAgo(60 * 24 * 2),
    'patient': patient,
  };
}

Map<String, Object?> _payment({
  required String id,
  required String receipt,
  required String invoiceId,
  required String patientId,
  required double amount,
  required String method,
  required int minutesAgo,
  String? provider,
  String? bankName,
  String? reference,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'invoiceId': invoiceId,
      'patientId': patientId,
      'paymentDate': _minutesAgo(minutesAgo),
      'receiptNumber': receipt,
      'amount': _money(amount),
      'paymentMethod': method,
      'paymentReference': reference,
      'cardLastFour': null,
      'mobileMoneyProvider': provider,
      'bankName': bankName,
      'chequeNumber': null,
      'chequeDate': null,
      'isRefund': false,
      'notes': null,
      'createdAt': _minutesAgo(minutesAgo),
    };

/// The same seven patients the rest of the world uses, in the shape
/// `INVOICE_INCLUDE` selects them.
final Map<String, Map<String, Object?>> _patients = {
  'p-1': _patient('p-1', '10421', 'Ifeoma', 'Balogun'),
  'p-2': _patient('p-2', '10422', 'Tom', 'Whitfield'),
  'p-3': _patient('p-3', '10423', 'Sana', 'Qureshi'),
  'p-4': _patient('p-4', '10424', 'Grace', 'Mwangi'),
  'p-5': _patient('p-5', '10425', 'Henrik', 'Nilsen'),
  'p-6': _patient('p-6', '10426', 'Yusuf', 'Adeyemi'),
  'p-7': _patient('p-7', '10427', 'Margaret', 'Okafor'),
};

Map<String, Object?> _patient(
  String id,
  String mrn,
  String first,
  String last,
) =>
    {
      'id': id,
      'mrn': mrn,
      'firstName': first,
      'lastName': last,
      'phonePrimary': null,
      'hasInsurance': false,
      'insuranceProvider': null,
    };

/// The patient block a freshly created invoice comes back with.
///
/// Falls back to the first rather than throwing: a flow that raises an invoice
/// for somebody outside this ledger should see a screen, not a 500.
Map<String, Object?> _patientById(String id) =>
    _patients[id] ?? _patients['p-1']!;

/// The server's `money()` helper: two decimals, half up.
double _money(double value) => (value * 100).round() / 100;

double _num(Object? value) => (value as num?)?.toDouble() ?? 0;

// Every timestamp comes off `AppClock`, which the harness freezes. Wall-clock
// time here would be silently wrong: an invoice "due in nine days" computed
// against `DateTime.now()` is already past due on a clock frozen in 2026, and
// the amber pill this module exists to get right would land on the wrong row.
String _minutesAgo(int minutes) => AppClock.now()
    .toUtc()
    .subtract(Duration(minutes: minutes))
    .toIso8601String();

String _dayOffset(int days) {
  final at = AppClock.now().toUtc().add(Duration(days: days));
  return DateTime.utc(at.year, at.month, at.day).toIso8601String();
}
