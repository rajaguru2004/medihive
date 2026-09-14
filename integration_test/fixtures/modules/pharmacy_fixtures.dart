import 'dart:convert';

import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// The pharmacy, in fixtures.
///
/// One shelf, one dispensing queue and one day's takings, and the three agree:
/// the `lowStock` figure on the stats block is the number of rows the shelf
/// actually has at or below their reorder level, and `todaySales` is the sum of
/// the two receipts. A world whose figures disagree with its rows is a world
/// where a screenshot shows a department that could not exist, and a flow that
/// asserts on either half proves nothing about the other.
///
/// Every collection here answers a **bare array**, which is what
/// `/api/pharmacy/*` actually sends. Wrapping them in `{data, meta}` would test
/// a shape this module never receives.
void installPharmacyFixtures(FakeApi api) {
  api.json('GET', PharmacyPaths.stats, stats);

  api.on(
    'GET',
    PharmacyPaths.drugs,
    (request) => FakeResponse.ok(drugsMatching(request)),
  );
  api.on(
    'POST',
    PharmacyPaths.drugs,
    (request) => FakeResponse.ok(_created(request)),
  );
  api.on(
    'PATCH',
    '${PharmacyPaths.drugs}/:id',
    (request) => FakeResponse.ok(_patchedDrug(request)),
  );

  api.on('GET', PharmacyPaths.prescriptions, (request) {
    final status = request.query['status'] ?? '';
    final patientId = request.query['patientId'] ?? '';
    return FakeResponse.ok([
      for (final row in prescriptions)
        if ((status.isEmpty || row['status'] == status) &&
            (patientId.isEmpty || row['patientId'] == patientId))
          row,
    ]);
  });
  api.on(
    'POST',
    PharmacyPaths.prescriptions,
    (request) => FakeResponse.ok(_created(request)),
  );
  api.on(
    'PATCH',
    '${PharmacyPaths.prescriptions}/:id',
    (request) => FakeResponse.ok(_patchedPrescription(request)),
  );

  api.on('GET', PharmacyPaths.sales, (request) {
    // The server widens whatever day it is given to that day's bounds, so a
    // fixture that answered the same two receipts for every date would let a
    // broken date filter pass.
    final asked = request.query['date'];
    final isToday = asked == null || asked == _dayOf(AppClock.now());
    return FakeResponse.ok(isToday ? sales : const <Object?>[]);
  });
  api.on(
    'POST',
    PharmacyPaths.sales,
    (request) => FakeResponse.ok(_rungUp(request)),
  );
}

/// The shelf refusing a dispense it can no longer cover.
///
/// Registered *over* [installPharmacyFixtures] by a flow that wants the
/// insufficient-stock path — later registrations win. The refusal is the
/// server's own: a `409` carrying `INSUFFICIENT_STOCK` and a message that names
/// the drug, which is the only part a pharmacist can act on.
///
/// The shelf moves with it. Before the refusal the catalogue still shows the
/// full count, which is what makes the screen offer the whole prescription in
/// the first place; afterwards it shows [shortDrugRemaining], so the re-read
/// the screen does on a refusal has something true to find. A fixture that
/// showed the reduced figure from the start would never let the dispense be
/// attempted at all.
void stubInsufficientStock(FakeApi api) {
  var refused = false;

  api.on('GET', PharmacyPaths.drugs, (request) {
    return FakeResponse.ok(
      drugsMatching(
        request,
        stock: refused ? const {shortDrugId: shortDrugRemaining} : const {},
      ),
    );
  });

  api.on('POST', PharmacyPaths.sales, (_) {
    refused = true;
    return FakeResponse.fail(
      409,
      'Insufficient stock for drug $shortDrugName. '
      'Available: $shortDrugRemaining, Requested: $shortDrugRequested',
      errorCode: 'INSUFFICIENT_STOCK',
    );
  });
}

/// The drug the refusal above is about, and what is left of it.
const String shortDrugId = 'drug-amox';
const String shortDrugName = 'Amoxicillin';
const int shortDrugRemaining = 2;
const int shortDrugRequested = 21;

/// The two prescriptions waiting at the counter.
///
/// `rx-full` can be covered in full; `rx-partial` cannot, because the shelf
/// holds sixty of a drug ninety of which were written.
const String fullPrescriptionId = 'rx-1';
const String partialPrescriptionId = 'rx-2';

/// The drug `rx-partial` runs short on, and the drug that has run out.
const String cappedDrugId = 'drug-metf';
const int cappedDrugStock = 60;
const int cappedDrugPrescribed = 90;
const String outOfStockDrugId = 'drug-insu';

/// A drug at its reorder level, and one below it. Both are amber, neither red.
const String lowStockDrugId = 'drug-cipro';
const String atReorderDrugId = 'drug-atorv';

/// The paths this module calls, spelled once.
///
/// Not named `Routes`: that is the app's own route table, and a fixture that
/// shadows it reads as though it were registering screens.
abstract final class PharmacyPaths {
  static const String stats = '/api/pharmacy/stats';
  static const String drugs = '/api/pharmacy/drugs';
  static const String prescriptions = '/api/pharmacy/prescriptions';
  static const String sales = '/api/pharmacy/sales';
}

// ── Figures ─────────────────────────────────────────────────────────────────

/// Agrees with the rows below it: fifteen drugs, three at or below their
/// reorder level (one of those at zero), two prescriptions pending, and two
/// receipts adding to 135.
const Map<String, Object?> stats = {
  'totalDrugs': 15,
  'lowStock': 3,
  'outOfStock': 1,
  'pendingPrescriptions': 2,
  'todaySales': 135.0,
};

// ── The shelf ───────────────────────────────────────────────────────────────

/// Fifteen drugs across the categories a district pharmacy actually stocks.
///
/// Three sit at or below their reorder level — `drug-cipro` under it,
/// `drug-atorv` exactly on it, `drug-insu` at zero — so the amber treatment,
/// the boundary case and the empty shelf are all on one screen.
final List<Map<String, Object?>> drugs = [
  // id, name, category, form, strength, stock, reorder, cost, price.
  _drug('drug-amox', 'Amoxicillin', 'antibiotic', 'capsule', '500mg', 120, 40, 4.2, 6.5, generic: 'Amoxicillin trihydrate', code: 'DRG-AMX5', rx: true),
  _drug('drug-amlo', 'Amlodipine', 'cardiovascular', 'tablet', '5mg', 150, 45, 0.9, 2.2, generic: 'Amlodipine besylate', code: 'DRG-AML5', rx: true),
  _drug('drug-atorv', 'Atorvastatin', 'cardiovascular', 'tablet', '20mg', 15, 15, 1.4, 3.4, generic: 'Atorvastatin calcium', code: 'DRG-ATV2', rx: true),
  _drug('drug-cetir', 'Cetirizine', 'antihistamine', 'tablet', '10mg', 140, 40, 0.6, 1.8, generic: 'Cetirizine hydrochloride', code: 'DRG-CTZ1'),
  _drug('drug-cipro', 'Ciprofloxacin', 'antibiotic', 'tablet', '500mg', 8, 20, 3.1, 7.0, generic: 'Ciprofloxacin', code: 'DRG-CIP5', rx: true),
  _drug('drug-ferr', 'Ferrous sulfate', 'supplement', 'tablet', '200mg', 96, 30, 0.4, 1.2, generic: 'Ferrous sulfate', code: 'DRG-FER2'),
  _drug('drug-ibu', 'Ibuprofen', 'analgesic', 'tablet', '400mg', 180, 50, 0.7, 3.0, generic: 'Ibuprofen', code: 'DRG-IBU4'),
  _drug('drug-insu', 'Insulin glargine', 'antidiabetic', 'injection', '100IU/ml', 0, 10, 22.0, 38.0, generic: 'Insulin glargine', code: 'DRG-INS1', rx: true, cold: true),
  _drug('drug-metf', 'Metformin', 'antidiabetic', 'tablet', '500mg', cappedDrugStock, 40, 0.5, 1.6, generic: 'Metformin hydrochloride', code: 'DRG-MET5', rx: true),
  _drug('drug-metr', 'Metronidazole', 'antibiotic', 'tablet', '400mg', 95, 30, 0.8, 2.4, generic: 'Metronidazole', code: 'DRG-MTZ4', rx: true),
  _drug('drug-omep', 'Omeprazole', 'gastrointestinal', 'capsule', '20mg', 210, 60, 0.9, 2.8, generic: 'Omeprazole', code: 'DRG-OMP2', rx: true),
  _drug('drug-ors', 'Oral rehydration salts', 'gastrointestinal', 'sachet', '', 300, 80, 0.3, 1.0, generic: 'Glucose-electrolyte', code: 'DRG-ORS1'),
  _drug('drug-para', 'Paracetamol', 'analgesic', 'tablet', '500mg', 240, 60, 0.4, 2.5, generic: 'Acetaminophen', code: 'DRG-PCM5'),
  _drug('drug-pred', 'Prednisolone', 'respiratory', 'tablet', '5mg', 88, 25, 1.1, 3.2, generic: 'Prednisolone', code: 'DRG-PRD5', rx: true),
  _drug('drug-salb', 'Salbutamol', 'respiratory', 'inhaler', '100mcg', 34, 12, 5.4, 11.0, generic: 'Salbutamol sulfate', code: 'DRG-SAL1', rx: true),
];

/// The shelf as one request asked for it — the server matches `search` against
/// the name, the generic name and the code, and this does the same.
///
/// [stock] replaces a drug's count, for a flow that needs the shelf to move
/// under a screen that is already open.
List<Map<String, Object?>> drugsMatching(
  FakeRequest request, {
  Map<String, int> stock = const {},
}) {
  final category = request.query['category'] ?? '';
  final search = (request.query['search'] ?? '').trim().toLowerCase();

  return [
    for (final row in drugs)
      if ((category.isEmpty || row['drugCategory'] == category) &&
          (search.isEmpty || _matches(row, search)))
        _withStock(row, stock),
  ];
}

bool _matches(Map<String, Object?> row, String search) => [
  row['drugName'],
  row['genericName'],
  row['drugCode'],
].any((field) => '$field'.toLowerCase().contains(search));

Map<String, Object?> _withStock(
  Map<String, Object?> row,
  Map<String, int> stock,
) {
  final override = stock['${row['id']}'];
  if (override == null) return row;
  return {...row, 'quantityInStock': override};
}

// ── The dispensing queue ────────────────────────────────────────────────────

/// Six prescriptions: two pending, two part-dispensed, two finished.
///
/// `items` is a **JSON string**, which is how the backend stores it. A fixture
/// that sent an array would pass while the screen it is for showed a
/// prescription with no drugs on it.
final List<Map<String, Object?>> prescriptions = [
  _prescription(
    fullPrescriptionId,
    'pending',
    'p-1',
    '10421',
    'Ifeoma',
    'Balogun',
    'Female',
    'd-1',
    'Dr Amara Okonkwo',
    [
      _item(
        'drug-amox',
        shortDrugName,
        '500mg',
        'Three times daily',
        '7 days',
        shortDrugRequested,
        instructions: 'Take after food',
      ),
      _item('drug-para', 'Paracetamol', '500mg', 'As needed', '5 days', 20),
    ],
    daysAgo: 0,
  ),
  _prescription(
    partialPrescriptionId,
    'pending',
    'p-2',
    '10422',
    'Tom',
    'Whitfield',
    'Male',
    'd-2',
    'Dr Priya Raman',
    [
      // Ninety written against sixty on the shelf: this is the prescription
      // that can only ever go out in part.
      _item(
        'drug-metf',
        'Metformin',
        '500mg',
        'Twice daily',
        '45 days',
        cappedDrugPrescribed,
      ),
      _item('drug-amlo', 'Amlodipine', '5mg', 'Once daily', '30 days', 30),
    ],
    daysAgo: 0,
  ),
  _prescription(
    'rx-3',
    'partially_dispensed',
    'p-4',
    '10424',
    'Grace',
    'Mwangi',
    'Female',
    'd-1',
    'Dr Amara Okonkwo',
    [
      _item('drug-salb', 'Salbutamol', '100mcg', 'Two puffs as needed', '', 2),
      _item('drug-pred', 'Prednisolone', '5mg', 'Once daily', '5 days', 20),
    ],
    daysAgo: 1,
  ),
  _prescription(
    'rx-4',
    'partially_dispensed',
    'p-6',
    '10426',
    'Yusuf',
    'Adeyemi',
    'Male',
    'd-3',
    'Dr Samuel Achterberg',
    [
      _item(
        'drug-cipro',
        'Ciprofloxacin',
        '500mg',
        'Twice daily',
        '7 days',
        14,
      ),
    ],
    daysAgo: 2,
  ),
  _prescription(
    'rx-5',
    'fully_dispensed',
    'p-5',
    '10425',
    'Henrik',
    'Nilsen',
    'Male',
    'd-3',
    'Dr Samuel Achterberg',
    [
      _item(
        'drug-ibu',
        'Ibuprofen',
        '400mg',
        'Three times daily',
        '10 days',
        30,
      ),
    ],
    daysAgo: 3,
    dispensed: true,
  ),
  _prescription(
    'rx-6',
    'fully_dispensed',
    'p-3',
    '10423',
    'Sana',
    'Qureshi',
    'Female',
    'd-1',
    'Dr Amara Okonkwo',
    [
      _item(
        'drug-ors',
        'Oral rehydration salts',
        '1 sachet',
        'After each loose '
            'stool',
        '3 days',
        6,
      ),
      _item(
        'drug-para',
        'Paracetamol',
        '250mg',
        'Four times daily',
        '3 days',
        12,
      ),
    ],
    daysAgo: 4,
    dispensed: true,
  ),
];

// ── Today's takings ─────────────────────────────────────────────────────────

/// Two receipts adding to the `todaySales` figure above: one walk-in and one
/// against a prescription, so both `saleType`s are on screen.
final List<Map<String, Object?>> sales = [
  _sale('sale-1', 'RCP-2041', 'otc', 45.0, 'cash', [
    _saleItem('drug-para', 'Paracetamol', 10, 2.5),
    _saleItem('drug-cetir', 'Cetirizine', 5, 4.0),
  ], minutesAgo: 95),
  _sale(
    'sale-2',
    'RCP-2042',
    'prescription',
    90.0,
    'mobile_money',
    [_saleItem('drug-ibu', 'Ibuprofen', 30, 3.0)],
    minutesAgo: 20,
    patientId: 'p-5',
    mrn: '10425',
    first: 'Henrik',
    last: 'Nilsen',
    prescriptionId: 'rx-5',
  ),
];

// ── Write echoes ────────────────────────────────────────────────────────────

/// A create, answered with the record the server would have stored.
///
/// `CrudRepository` builds a model out of the response, so a create answered
/// with `null` produces a model with none of the fields the screen just sent.
Map<String, Object?> _created(FakeRequest request) {
  final body = _bodyOf(request);
  return {
    'id': 'new-${AppClock.now().microsecondsSinceEpoch}',
    'organizationId': 'o-1',
    'isActive': true,
    'status': 'pending',
    'createdAt': _iso(AppClock.now()),
    ...body,
  };
}

Map<String, Object?> _patchedDrug(FakeRequest request) {
  final id = request.pathParams['id'] ?? '';
  final existing = drugs.firstWhere(
    (row) => row['id'] == id,
    orElse: () => drugs.first,
  );
  return {...existing, ..._bodyOf(request)};
}

Map<String, Object?> _patchedPrescription(FakeRequest request) {
  final id = request.pathParams['id'] ?? '';
  final existing = prescriptions.firstWhere(
    (row) => row['id'] == id,
    orElse: () => prescriptions.first,
  );
  final patch = _bodyOf(request);
  return {
    ...existing,
    ...patch,
    // `items` on a PATCH arrives as an array and comes back as the stored
    // string, exactly as the service re-encodes it.
    if (patch['items'] is List) 'items': jsonEncode(patch['items']),
  };
}

/// A sale, priced from the lines the app actually sent.
///
/// Totalled here rather than returned as a constant: a screen that sent the
/// wrong line totals would otherwise get a receipt agreeing with the figure it
/// meant to send.
Map<String, Object?> _rungUp(FakeRequest request) {
  final body = _bodyOf(request);
  final items = body['items'] is List
      ? body['items']! as List<Object?>
      : const <Object?>[];
  final subtotal = items.fold<double>(0, (sum, item) => sum + _lineTotal(item));
  final paid = body['paymentStatus'] == 'paid';

  return {
    'id': 'sale-new',
    'organizationId': 'o-1',
    'patientId': body['patientId'],
    'prescriptionId': body['prescriptionId'],
    'servedById': 'u-6',
    'saleDate': _iso(AppClock.now()),
    'saleType': body['prescriptionId'] == null ? 'otc' : 'prescription',
    'items': jsonEncode(items),
    'subtotal': subtotal,
    'discountAmount': 0,
    'taxAmount': 0,
    'totalAmount': subtotal,
    'paymentStatus': body['paymentStatus'] ?? 'pending',
    'paymentMethod': body['paymentMethod'],
    'amountPaid': paid ? subtotal : 0,
    'amountDue': paid ? 0 : subtotal,
    'receiptNumber': 'RCP-2043',
    'createdAt': _iso(AppClock.now()),
  };
}

double _lineTotal(Object? item) {
  if (item is! Map) return 0;
  final total = item['total'];
  return total is num ? total.toDouble() : 0;
}

Map<String, Object?> _bodyOf(FakeRequest request) =>
    request.body is Map ? request.jsonBody : <String, Object?>{};

// ── Builders ────────────────────────────────────────────────────────────────

Map<String, Object?> _drug(
  String id,
  String name,
  String category,
  String form,
  String strength,
  int stock,
  int reorder,
  double cost,
  double price, {
  String? generic,
  String? code,
  bool rx = false,
  bool cold = false,
}) => {
  'id': id,
  'organizationId': 'o-1',
  'drugName': name,
  'genericName': generic,
  'brandName': null,
  'drugCode': code,
  'drugCategory': category,
  'dosageForm': form,
  'strength': strength,
  'quantityInStock': stock,
  // What one of it is, which is what a stock figure is counted in.
  'unitOfMeasure': form.isEmpty ? 'sachet' : form,
  'reorderLevel': reorder,
  'costPrice': cost,
  'sellingPrice': price,
  'storageLocation': cold ? 'Fridge 2' : 'Shelf ${name[0].toUpperCase()}1',
  'requiresPrescription': rx,
  'isActive': true,
  'batches': const <Object?>[],
  'createdAt': _iso(AppClock.now().subtract(const Duration(days: 120))),
  'updatedAt': _iso(AppClock.now().subtract(const Duration(days: 2))),
};

Map<String, Object?> _item(
  String drugId,
  String drugName,
  String dosage,
  String frequency,
  String duration,
  int quantity, {
  String? instructions,
}) => {
  'drugId': drugId,
  'drugName': drugName,
  'dosage': dosage,
  'frequency': frequency,
  'duration': duration,
  'quantity': quantity,
  'instructions': instructions,
};

Map<String, Object?> _prescription(
  String id,
  String status,
  String patientId,
  String mrn,
  String first,
  String last,
  String gender,
  String doctorId,
  String doctorName,
  List<Map<String, Object?>> items, {
  required int daysAgo,
  bool dispensed = false,
}) {
  final written = AppClock.now().subtract(Duration(days: daysAgo));
  return {
    'id': id,
    'organizationId': 'o-1',
    'patientId': patientId,
    'doctorId': doctorId,
    'prescriptionDate': _iso(written),
    // A JSON string, as the column stores it.
    'items': jsonEncode(items),
    'status': status,
    'dispensedById': dispensed ? 'u-6' : null,
    'dispensedAt': dispensed
        ? _iso(written.add(const Duration(hours: 2)))
        : null,
    'notes': null,
    'isRefill': false,
    'refillsAllowed': 0,
    'createdAt': _iso(written),
    'updatedAt': _iso(written),
    'patient': {
      'id': patientId,
      'mrn': mrn,
      'firstName': first,
      'lastName': last,
      'gender': gender,
      // Present, because the identity band shows an age and a fixture without
      // one exercises the absent path on every pharmacy screen.
      'dateOfBirth': '1984-03-25T00:00:00.000Z',
    },
    'doctor': {'id': doctorId, 'fullName': doctorName},
  };
}

Map<String, Object?> _saleItem(
  String drugId,
  String drugName,
  int quantity,
  double unitPrice,
) => {
  'drugId': drugId,
  'drugName': drugName,
  'quantity': quantity,
  'unitPrice': unitPrice,
  'total': unitPrice * quantity,
};

Map<String, Object?> _sale(
  String id,
  String receipt,
  String type,
  double total,
  String method,
  List<Map<String, Object?>> items, {
  required int minutesAgo,
  String? patientId,
  String? mrn,
  String? first,
  String? last,
  String? prescriptionId,
}) {
  final at = AppClock.now().subtract(Duration(minutes: minutesAgo));
  return {
    'id': id,
    'organizationId': 'o-1',
    'patientId': patientId,
    'prescriptionId': prescriptionId,
    'servedById': 'u-6',
    'saleDate': _iso(at),
    'saleType': type,
    'items': jsonEncode(items),
    'subtotal': total,
    'discountAmount': 0,
    'taxAmount': 0,
    'totalAmount': total,
    'paymentStatus': 'paid',
    'paymentMethod': method,
    'amountPaid': total,
    'amountDue': 0,
    'receiptNumber': receipt,
    'createdAt': _iso(at),
    if (patientId != null)
      'patient': {
        'id': patientId,
        'mrn': mrn,
        'firstName': first,
        'lastName': last,
      },
  };
}

/// Every timestamp comes off `AppClock`, which the harness freezes.
///
/// Wall-clock time here would be wrong in both directions: a sale "20 minutes
/// ago" computed at `DateTime.now()` is in the *future* relative to a frozen
/// clock, so today's takings would be filed under tomorrow and the counter
/// would read as empty.
String _iso(DateTime value) => value.toUtc().toIso8601String();

/// `yyyy-MM-dd`, which is what the sales screen sends and the server widens.
String _dayOf(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
