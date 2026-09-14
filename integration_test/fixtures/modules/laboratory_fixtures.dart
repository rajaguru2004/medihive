import 'dart:convert';

import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the laboratory, in fixtures
///
/// Ten orders across every status the API's `@IsIn` accepts, fifteen catalogue
/// entries and five results — three of them abnormal, and exactly one critical
/// **and unverified**, which is the state the stats route counts and the
/// detail screen raises a banner for.
///
/// Deliberately **stateful**. The laboratory's whole product is a chain —
/// order, collect the sample, enter a result, verify it, complete the order —
/// and a fixture that answers every request with the same frozen page can only
/// test the first link. So the writes here mutate the same maps the reads
/// serve, and they mirror the two things the real service does behind the
/// caller's back:
///
///   * it **mints its own accession number** on the move to
///     `sample_collected`, ignoring whatever the client sent;
///   * it **completes an order** once every result on it has been verified.
///
/// A fake that did neither would let a screen pass its test and then be wrong
/// on a ward.
/// ─────────────────────────────────────────────────────────────────────────────
void installLaboratoryFixtures(FakeApi api) {
  final tests = <String, Map<String, Object?>>{
    for (final test in _catalogue) test['id']! as String: {...test},
  };
  final orders = <String, Map<String, Object?>>{
    for (final order in _orders) order['id']! as String: {...order},
  };
  final results = <String, Map<String, Object?>>{
    for (final result in _results) result['id']! as String: {...result},
  };

  var createdOrders = 0;
  var createdResults = 0;
  var createdTests = 0;

  /// The order as a route that populates it answers: the patient block, and
  /// the results with their catalogue entry on each.
  Map<String, Object?> populated(Map<String, Object?> order) => {
        ...order,
        'results': [
          for (final result in results.values)
            if (result['orderId'] == order['id'])
              {...result, 'test': tests[result['testId']]},
        ],
      };

  // ── Stats ─────────────────────────────────────────────────────────────────
  //
  // Counted off the same maps the lists serve rather than hard-coded, so the
  // header and the rows under it cannot disagree — which is the one thing a
  // figure on a board must never do.
  api.on('GET', '/api/laboratory/stats', (_) {
    int withStatus(String status) =>
        orders.values.where((o) => o['status'] == status).length;

    return FakeResponse.ok({
      'pending': withStatus('pending'),
      'sampleCollected': withStatus('sample_collected'),
      'inProgress': withStatus('in_progress'),
      'completedToday': withStatus('completed'),
      'criticalResults': results.values
          .where((r) => r['isCritical'] == true && r['verifiedAt'] == null)
          .length,
      'totalTests': tests.values.where((t) => t['isActive'] == true).length,
    });
  });

  // ── Orders ────────────────────────────────────────────────────────────────

  api.on('GET', '/api/laboratory/orders', (request) {
    final status = request.query['status'];
    final priority = request.query['priority'];
    final patientId = request.query['patientId'];
    final search = (request.query['search'] ?? '').trim().toLowerCase();
    final page = int.tryParse(request.query['page'] ?? '1') ?? 1;
    final limit = int.tryParse(request.query['limit'] ?? '20') ?? 20;

    final rows = orders.values.where((order) {
      if (status != null && status.isNotEmpty && order['status'] != status) {
        return false;
      }
      if (priority != null &&
          priority.isNotEmpty &&
          order['priority'] != priority) {
        return false;
      }
      if (patientId != null &&
          patientId.isNotEmpty &&
          order['patientId'] != patientId) {
        return false;
      }
      if (search.isEmpty) return true;

      // The same four columns the service searches: the order number, the
      // accession, and the patient's name and MRN.
      final patient = (order['patient'] as Map?) ?? const {};
      final haystack = [
        order['orderNumber'],
        order['accessionNumber'] ?? '',
        patient['firstName'] ?? '',
        patient['lastName'] ?? '',
        patient['mrn'] ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(search);
    }).toList()
      // `orderDate: 'desc'`, exactly as the repository asks for it — and with
      // no priority in it, which is why the worklist sorts STAT to the top
      // itself.
      ..sort((a, b) =>
          '${b['orderDate']}'.compareTo('${a['orderDate']}'));

    final start = (page - 1) * limit;
    final slice = start >= rows.length
        ? const <Map<String, Object?>>[]
        : rows.skip(start).take(limit).toList();

    return FakeResponse.page(
      [for (final order in slice) populated(order)],
      page: page,
      limit: limit,
      total: rows.length,
    );
  });

  api.on('POST', '/api/laboratory/orders', (request) {
    final body = request.jsonBody;
    createdOrders++;
    final id = 'o-new-$createdOrders';
    final order = <String, Object?>{
      'id': id,
      'organizationId': 'o-1',
      'patientId': body['patientId'],
      'consultationId': body['consultationId'],
      'requestedById': 'u-7',
      'orderDate': _minutesAgo(0),
      'orderNumber': 'LAB90000$createdOrders',
      // A JSON **string**, the way the column stores it. A fixture that sent a
      // real list here would test a shape this backend never sends.
      'tests': jsonEncode(body['tests'] ?? const []),
      'clinicalIndication': body['clinicalIndication'],
      'provisionalDiagnosis': body['provisionalDiagnosis'],
      'priority': body['priority'] ?? 'routine',
      'status': 'pending',
      'notes': body['notes'],
      'patient': _patientOf('${body['patientId']}'),
      'createdAt': _minutesAgo(0),
      'updatedAt': _minutesAgo(0),
    };
    orders[id] = order;
    return FakeResponse.ok(populated(order));
  });

  api.on('PATCH', '/api/laboratory/orders/:id', (request) {
    final id = request.pathParams['id']!;
    final order = orders[id];
    if (order == null) return FakeResponse.fail(404, 'Not found');

    final body = request.jsonBody;
    final updates = <String, Object?>{...body};

    if (body['status'] == 'sample_collected') {
      // What the service does: mints its own accession when the order has
      // none and drops the client's value when it already has one. Never the
      // number that was typed.
      updates.remove('accessionNumber');
      if ((order['accessionNumber'] ?? '') == '') {
        updates['accessionNumber'] = 'ACC-E2E0042';
      }
    } else {
      updates.remove('accessionNumber');
    }

    if (body['status'] == 'completed') {
      updates['resultsReportedAt'] = _minutesAgo(0);
    }

    order.addAll(updates);
    order['updatedAt'] = _minutesAgo(0);
    return FakeResponse.ok(populated(order));
  });

  // ── Results ───────────────────────────────────────────────────────────────

  api.on('GET', '/api/laboratory/results', (request) {
    final orderId = request.query['orderId'];
    final rows = results.values.where((result) {
      if (orderId == null || orderId.isEmpty) return true;
      return result['orderId'] == orderId;
    });
    // A bare array with no `meta`, which is what this route answers with.
    return FakeResponse.ok([
      for (final result in rows) {...result, 'test': tests[result['testId']]},
    ]);
  });

  api.on('POST', '/api/laboratory/results', (request) {
    final body = request.jsonBody;
    createdResults++;
    final id = 'r-new-$createdResults';
    final result = <String, Object?>{
      'id': id,
      'organizationId': 'o-1',
      'orderId': body['orderId'],
      'testId': body['testId'],
      'resultValue': body['resultValue'],
      'resultUnit': body['resultUnit'],
      'isAbnormal': body['isAbnormal'] ?? false,
      'isCritical': body['isCritical'] ?? false,
      'flag': body['flag'],
      'comment': body['comment'],
      'enteredById': 'u-7',
      'enteredAt': _minutesAgo(0),
      'verifiedAt': null,
      'verifiedById': null,
    };
    results[id] = result;

    // The service moves the order on as soon as a result lands against it.
    final order = orders['${body['orderId']}'];
    if (order != null) {
      order['status'] = 'in_progress';
      order['resultsEnteredAt'] = _minutesAgo(0);
      order['resultsEnteredById'] = 'u-7';
    }

    return FakeResponse.ok({...result, 'test': tests[result['testId']]});
  });

  api.on('PATCH', '/api/laboratory/results/:id', (request) {
    final id = request.pathParams['id']!;
    final result = results[id];
    if (result == null) return FakeResponse.fail(404, 'Not found');

    result.addAll(request.jsonBody);
    if (request.jsonBody['verifiedAt'] != null) {
      result['verifiedById'] = 'u-7';

      // And the other half: an order whose every result is verified is a
      // completed order, without anybody pressing Complete.
      final orderId = '${result['orderId']}';
      final siblings =
          results.values.where((r) => r['orderId'] == orderId).toList();
      if (siblings.every((r) => r['verifiedAt'] != null)) {
        final order = orders[orderId];
        if (order != null) {
          order['status'] = 'completed';
          order['resultsVerifiedAt'] = _minutesAgo(0);
          order['resultsReportedAt'] = _minutesAgo(0);
        }
      }
    }

    return FakeResponse.ok({...result, 'test': tests[result['testId']]});
  });

  // ── Catalogue ─────────────────────────────────────────────────────────────

  api.on('GET', '/api/laboratory/tests', (request) {
    final category = request.query['category'];
    final rows = tests.values.where((test) {
      if (test['isActive'] != true) return false;
      if (category == null || category.isEmpty) return true;
      return test['testCategory'] == category;
    }).toList()
      ..sort((a, b) => '${a['testCategory']}${a['testName']}'
          .compareTo('${b['testCategory']}${b['testName']}'));
    return FakeResponse.ok(rows);
  });

  api.on('POST', '/api/laboratory/tests', (request) {
    final body = request.jsonBody;
    createdTests++;
    final id = 't-new-$createdTests';
    final test = <String, Object?>{
      'id': id,
      'organizationId': 'o-1',
      ...body,
      'isActive': true,
      'createdAt': _minutesAgo(0),
    };
    tests[id] = test;
    return FakeResponse.ok(test);
  });

  api.on('PATCH', '/api/laboratory/tests/:id', (request) {
    final id = request.pathParams['id']!;
    final test = tests[id];
    if (test == null) return FakeResponse.fail(404, 'Not found');
    test.addAll(request.jsonBody);
    return FakeResponse.ok(test);
  });

  api.on('DELETE', '/api/laboratory/tests/:id', (request) {
    final id = request.pathParams['id']!;
    final test = tests[id];
    if (test == null) return FakeResponse.fail(404, 'Not found');
    // Soft, as the service does it: the row keeps its id and drops out of
    // `isActive`, which is what keeps every order that already names it
    // readable.
    test['isActive'] = false;
    return FakeResponse.ok(test);
  });
}

// ── The department ──────────────────────────────────────────────────────────

/// The ids the flow tests name.
abstract final class LabFixtureIds {
  /// The one STAT order. Not the newest, so a worklist that sorts by request
  /// time alone leaves it in the middle and the assertion catches it.
  static const String statOrder = 'o-1';

  /// In progress, and carrying the critical unverified potassium.
  static const String criticalOrder = 'o-5';

  /// The critical result itself.
  static const String criticalResult = 'r-1';

  /// Pending, with one test on it and no sample taken — what the collect →
  /// result → verify chain is walked on.
  static const String pendingOrder = 'o-2';

  /// The test on [pendingOrder].
  static const String pendingOrderTest = 't-cbc';

  static const String catalogueTest = 't-k';

  /// What the fake mints on the move to `sample_collected`, the way the real
  /// service mints its own and throws the client's value away.
  static const String mintedAccession = 'ACC-E2E0042';

  /// The first order and the first result a flow creates.
  static const String firstCreatedOrder = 'o-new-1';
  static const String firstCreatedResult = 'r-new-1';
}

Map<String, Object?> _patient(
  String id,
  String mrn,
  String first,
  String last,
  String gender,
  String dob,
) =>
    {
      'id': id,
      'mrn': mrn,
      'firstName': first,
      'lastName': last,
      'gender': gender,
      'dateOfBirth': '${dob}T00:00:00.000Z',
    };

/// The same seven patients the rest of the world holds, so an order opened
/// from the worklist names somebody the queue and the ward also know.
final Map<String, Map<String, Object?>> _patients = {
  'p-1': _patient('p-1', '10421', 'Ifeoma', 'Balogun', 'Female', '1991-04-12'),
  'p-2': _patient('p-2', '10422', 'Tom', 'Whitfield', 'Male', '1958-11-02'),
  'p-3': _patient('p-3', '10423', 'Sana', 'Qureshi', 'Female', '2019-07-30'),
  'p-4': _patient('p-4', '10424', 'Grace', 'Mwangi', 'Female', '1976-01-19'),
  'p-5': _patient('p-5', '10425', 'Henrik', 'Nilsen', 'Male', '2002-09-08'),
  'p-6': _patient('p-6', '10426', 'Yusuf', 'Adeyemi', 'Male', '1984-03-25'),
  'p-7': _patient('p-7', '10427', 'Margaret', 'Okafor', 'Female', '1941-06-14'),
};

Map<String, Object?> _patientOf(String id) =>
    _patients[id] ?? _patients['p-1']!;

Map<String, Object?> _test({
  required String id,
  required String name,
  required String code,
  required String category,
  required String specimen,
  String type = 'quantitative',
  String resultType = 'numeric',
  String unit = '',
  String ranges = '',
  double price = 0,
  int turnaround = 24,
  String preparation = '',
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'testName': name,
      'testCode': code,
      'testCategory': category,
      'testType': type,
      'specimenType': specimen,
      'resultType': resultType,
      'unit': unit.isEmpty ? null : unit,
      // A JSON **string**, as the column holds it and the write DTO types it.
      'referenceRanges': ranges.isEmpty ? null : ranges,
      'price': price,
      'turnaroundTime': turnaround,
      'preparationInstructions': preparation.isEmpty ? null : preparation,
      'isActive': true,
    };

/// Fifteen entries, across the four categories the backend's own examples use.
final List<Map<String, Object?>> _catalogue = [
  _test(
    id: 't-cbc',
    name: 'Complete Blood Count',
    code: 'CBC',
    category: 'hematology',
    specimen: 'blood',
    unit: 'x10⁹/L',
    ranges: '{"male": {"min": 4.0, "max": 11.0}, '
        '"female": {"min": 4.0, "max": 11.0}}',
    price: 350,
    turnaround: 4,
  ),
  _test(
    id: 't-hb',
    name: 'Haemoglobin',
    code: 'HB',
    category: 'hematology',
    specimen: 'blood',
    unit: 'g/dL',
    ranges: '{"male": {"min": 13.5, "max": 17.5}, '
        '"female": {"min": 12.0, "max": 15.5}}',
    price: 180,
    turnaround: 2,
  ),
  _test(
    id: 't-esr',
    name: 'Erythrocyte Sedimentation Rate',
    code: 'ESR',
    category: 'hematology',
    specimen: 'blood',
    unit: 'mm/hr',
    ranges: '[{"label": "adult", "min": 0, "max": 20}]',
    price: 150,
    turnaround: 6,
  ),
  _test(
    id: 't-plt',
    name: 'Platelet Count',
    code: 'PLT',
    category: 'hematology',
    specimen: 'blood',
    unit: 'x10⁹/L',
    ranges: '[{"label": "", "min": 150, "max": 400}]',
    price: 200,
    turnaround: 4,
  ),
  _test(
    id: 't-k',
    name: 'Potassium',
    code: 'K',
    category: 'chemistry',
    specimen: 'serum',
    unit: 'mmol/L',
    ranges: '[{"label": "", "min": 3.5, "max": 5.1}]',
    price: 120,
    turnaround: 2,
  ),
  _test(
    id: 't-na',
    name: 'Sodium',
    code: 'NA',
    category: 'chemistry',
    specimen: 'serum',
    unit: 'mmol/L',
    ranges: '[{"label": "", "min": 135, "max": 145}]',
    price: 120,
    turnaround: 2,
  ),
  _test(
    id: 't-crea',
    name: 'Creatinine',
    code: 'CREA',
    category: 'chemistry',
    specimen: 'serum',
    unit: 'µmol/L',
    ranges: '{"male": {"min": 59, "max": 104}, '
        '"female": {"min": 45, "max": 84}}',
    price: 160,
    turnaround: 4,
  ),
  _test(
    id: 't-ue',
    name: 'Urea and Electrolytes',
    code: 'UE',
    category: 'chemistry',
    specimen: 'serum',
    unit: 'mmol/L',
    ranges: '[{"label": "urea", "min": 2.5, "max": 7.8}]',
    price: 420,
    turnaround: 4,
  ),
  _test(
    id: 't-glu',
    name: 'Fasting Glucose',
    code: 'GLU',
    category: 'chemistry',
    specimen: 'plasma',
    unit: 'mmol/L',
    ranges: '[{"label": "fasting", "min": 3.9, "max": 5.5}]',
    price: 140,
    turnaround: 2,
    preparation: 'Fasting for eight hours.',
  ),
  _test(
    id: 't-a1c',
    name: 'HbA1c',
    code: 'A1C',
    category: 'chemistry',
    specimen: 'blood',
    unit: 'mmol/mol',
    ranges: '[{"label": "", "min": 20, "max": 42}]',
    price: 600,
    turnaround: 24,
  ),
  _test(
    id: 't-lipid',
    name: 'Lipid Profile',
    code: 'LIPID',
    category: 'chemistry',
    specimen: 'serum',
    unit: 'mmol/L',
    ranges: '[{"label": "LDL", "max": 3.0}]',
    price: 780,
    turnaround: 12,
    preparation: 'Fasting for twelve hours.',
  ),
  _test(
    id: 't-trop',
    name: 'Troponin I',
    code: 'TROP',
    category: 'chemistry',
    specimen: 'serum',
    unit: 'ng/L',
    ranges: '[{"label": "", "max": 14}]',
    price: 950,
    turnaround: 1,
  ),
  _test(
    id: 't-ucult',
    name: 'Urine Culture',
    code: 'UCULT',
    category: 'microbiology',
    specimen: 'urine',
    type: 'qualitative',
    resultType: 'text',
    ranges: '[{"label": "", "text": "No growth"}]',
    price: 540,
    turnaround: 48,
    preparation: 'Midstream specimen.',
  ),
  _test(
    id: 't-bcult',
    name: 'Blood Culture',
    code: 'BCULT',
    category: 'microbiology',
    specimen: 'blood',
    type: 'qualitative',
    resultType: 'text',
    ranges: '[{"label": "", "text": "No growth"}]',
    price: 860,
    turnaround: 72,
  ),
  _test(
    id: 't-tsh',
    name: 'Thyroid Stimulating Hormone',
    code: 'TSH',
    category: 'serology',
    specimen: 'serum',
    unit: 'mIU/L',
    ranges: '[{"label": "", "min": 0.4, "max": 4.0}]',
    price: 480,
    turnaround: 24,
  ),
];

Map<String, Object?> _order({
  required String id,
  required String number,
  required String patientId,
  required String status,
  required String priority,
  required int minutesAgo,
  required List<Map<String, Object?>> tests,
  String indication = '',
  String? accession,
  String? rejectionReason,
  int? collectedMinutesAgo,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'patientId': patientId,
      'requestedById': 'd-1',
      'orderDate': _minutesAgo(minutesAgo),
      'orderNumber': number,
      // The JSON string this column actually holds. A model that reads it with
      // `value is List` sees a String, returns empty, and the screen shows an
      // order with no tests on it against a perfectly good 200.
      'tests': jsonEncode(tests),
      'clinicalIndication': indication.isEmpty ? null : indication,
      'priority': priority,
      'status': status,
      'accessionNumber': accession,
      'sampleCollectedAt':
          collectedMinutesAgo == null ? null : _minutesAgo(collectedMinutesAgo),
      'sampleCollectedById': collectedMinutesAgo == null ? null : 'u-7',
      'rejectionReason': rejectionReason,
      'patient': _patientOf(patientId),
      'createdAt': _minutesAgo(minutesAgo),
      'updatedAt': _minutesAgo(minutesAgo),
    };

Map<String, Object?> _orderedTest(String id, String name, String code,
        [String urgency = 'routine']) =>
    {'testId': id, 'testName': name, 'testCode': code, 'urgency': urgency};

/// Ten orders, one in each of the six statuses and then some.
///
/// The STAT order is deliberately **not** the newest: the route orders by
/// request time and nothing else, so a worklist that forgot to sort would
/// leave `o-1` fifth and the flow test would catch it.
final List<Map<String, Object?>> _orders = [
  _order(
    id: 'o-9',
    number: 'LAB1000009',
    patientId: 'p-5',
    status: 'cancelled',
    priority: 'routine',
    minutesAgo: 12,
    tests: [_orderedTest('t-tsh', 'Thyroid Stimulating Hormone', 'TSH')],
    indication: 'Fatigue',
  ),
  _order(
    id: 'o-2',
    number: 'LAB1000002',
    patientId: 'p-1',
    status: 'pending',
    priority: 'routine',
    minutesAgo: 24,
    tests: [_orderedTest('t-cbc', 'Complete Blood Count', 'CBC')],
    indication: 'Routine anaemia screen',
  ),
  _order(
    id: 'o-3',
    number: 'LAB1000003',
    patientId: 'p-4',
    status: 'sample_collected',
    priority: 'urgent',
    minutesAgo: 38,
    accession: 'ACC-3H2K9Q1M',
    collectedMinutesAgo: 20,
    tests: [
      _orderedTest('t-ue', 'Urea and Electrolytes', 'UE', 'urgent'),
      _orderedTest('t-crea', 'Creatinine', 'CREA', 'urgent'),
    ],
    indication: 'Falling urine output',
  ),
  _order(
    id: 'o-10',
    number: 'LAB1000010',
    patientId: 'p-4',
    status: 'rejected',
    priority: 'routine',
    minutesAgo: 52,
    tests: [_orderedTest('t-cbc', 'Complete Blood Count', 'CBC')],
    indication: 'Pre-operative screen',
    rejectionReason: 'Haemolysed sample — please resend.',
  ),
  _order(
    id: 'o-1',
    number: 'LAB1000001',
    patientId: 'p-2',
    status: 'pending',
    priority: 'stat',
    minutesAgo: 66,
    tests: [
      _orderedTest('t-trop', 'Troponin I', 'TROP', 'stat'),
      _orderedTest('t-ue', 'Urea and Electrolytes', 'UE', 'stat'),
    ],
    indication: 'Central chest pain, ECG changes',
  ),
  _order(
    id: 'o-5',
    number: 'LAB1000005',
    patientId: 'p-7',
    status: 'in_progress',
    priority: 'urgent',
    minutesAgo: 80,
    accession: 'ACC-7YR4B2XD',
    collectedMinutesAgo: 62,
    tests: [
      _orderedTest('t-k', 'Potassium', 'K', 'urgent'),
      _orderedTest('t-na', 'Sodium', 'NA', 'urgent'),
    ],
    indication: 'Acute kidney injury',
  ),
  _order(
    id: 'o-4',
    number: 'LAB1000004',
    patientId: 'p-5',
    status: 'sample_collected',
    priority: 'routine',
    minutesAgo: 96,
    accession: 'ACC-9PL2M4WQ',
    collectedMinutesAgo: 70,
    tests: [_orderedTest('t-lipid', 'Lipid Profile', 'LIPID')],
    indication: 'Cardiovascular risk assessment',
  ),
  _order(
    id: 'o-6',
    number: 'LAB1000006',
    patientId: 'p-3',
    status: 'in_progress',
    priority: 'routine',
    minutesAgo: 120,
    accession: 'ACC-2QW8E5RT',
    collectedMinutesAgo: 100,
    tests: [
      _orderedTest('t-hb', 'Haemoglobin', 'HB'),
      _orderedTest('t-esr', 'Erythrocyte Sedimentation Rate', 'ESR'),
    ],
    indication: 'Pallor and lethargy',
  ),
  _order(
    id: 'o-7',
    number: 'LAB1000007',
    patientId: 'p-6',
    status: 'completed',
    priority: 'routine',
    minutesAgo: 180,
    accession: 'ACC-5TG7H3JK',
    collectedMinutesAgo: 160,
    tests: [
      _orderedTest('t-lipid', 'Lipid Profile', 'LIPID'),
      _orderedTest('t-glu', 'Fasting Glucose', 'GLU'),
    ],
    indication: 'Annual review',
  ),
  _order(
    id: 'o-8',
    number: 'LAB1000008',
    patientId: 'p-1',
    status: 'completed',
    priority: 'routine',
    minutesAgo: 240,
    accession: 'ACC-8NM1C6VB',
    collectedMinutesAgo: 220,
    tests: [_orderedTest('t-a1c', 'HbA1c', 'A1C')],
    indication: 'Diabetes review',
  ),
];

Map<String, Object?> _result({
  required String id,
  required String orderId,
  required String testId,
  required String value,
  required String unit,
  required String flag,
  required bool abnormal,
  bool critical = false,
  bool verified = true,
  double? min,
  double? max,
  String comment = '',
  int minutesAgo = 30,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'orderId': orderId,
      'testId': testId,
      'resultValue': value,
      'resultUnit': unit,
      'isAbnormal': abnormal,
      'isCritical': critical,
      'flag': flag,
      'referenceRangeMin': min,
      'referenceRangeMax': max,
      'comment': comment.isEmpty ? null : comment,
      'enteredById': 'u-7',
      'enteredAt': _minutesAgo(minutesAgo),
      'verifiedById': verified ? 'd-1' : null,
      'verifiedAt': verified ? _minutesAgo(minutesAgo - 5) : null,
    };

/// Five results: three abnormal and verified, one normal, and **one critical
/// that nobody has signed off** — the row the stats route counts and the order
/// screen raises its banner for.
final List<Map<String, Object?>> _results = [
  _result(
    id: 'r-1',
    orderId: 'o-5',
    testId: 't-k',
    value: '7.2',
    unit: 'mmol/L',
    flag: 'H',
    abnormal: true,
    critical: true,
    verified: false,
    min: 3.5,
    max: 5.1,
    comment: 'Repeat sample requested. Telephone the ward.',
    minutesAgo: 18,
  ),
  _result(
    id: 'r-2',
    orderId: 'o-6',
    testId: 't-hb',
    value: '9.1',
    unit: 'g/dL',
    flag: 'L',
    abnormal: true,
    min: 12.0,
    max: 15.5,
    minutesAgo: 40,
  ),
  _result(
    id: 'r-3',
    orderId: 'o-7',
    testId: 't-lipid',
    value: '5.6',
    unit: 'mmol/L',
    flag: 'H',
    abnormal: true,
    max: 3.0,
    comment: 'LDL fraction.',
    minutesAgo: 150,
  ),
  _result(
    id: 'r-4',
    orderId: 'o-7',
    testId: 't-glu',
    value: '5.1',
    unit: 'mmol/L',
    flag: 'N',
    abnormal: false,
    min: 3.9,
    max: 5.5,
    minutesAgo: 150,
  ),
  _result(
    id: 'r-5',
    orderId: 'o-8',
    testId: 't-a1c',
    value: '68',
    unit: 'mmol/mol',
    flag: 'H',
    abnormal: true,
    min: 20,
    max: 42,
    minutesAgo: 210,
  ),
];

/// Every timestamp comes off `AppClock`, which the harness freezes.
///
/// Wall-clock time here would be silently wrong in both directions: "18
/// minutes ago" computed at `DateTime.now()` is in the *future* relative to a
/// frozen clock, and every elapsed figure on the board would render as 0m.
String _minutesAgo(int minutes) => AppClock.now()
    .toUtc()
    .subtract(Duration(minutes: minutes))
    .toIso8601String();
