import 'dart:convert';

import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// The imaging department, in fixtures.
///
/// Registered from `world.dart` so every flow sees the same eight orders, and
/// installable on its own through `AppHarness.bootSignedIn(overrides:)` — later
/// registrations win either way.
///
/// The routes here **hold state**: a PATCH to an order changes what the next
/// GET of that order answers with. A flow that schedules a study and then reads
/// the screen back is asserting the app's own round trip, and a fixture that
/// answered the same canned order every time would pass that test while the
/// app sent nothing at all.
void installRadiologyFixtures(FakeApi api) {
  final exams = <String, Map<String, Object?>>{
    for (final exam in _exams()) exam['id']! as String: exam,
  };
  final orders = <String, Map<String, Object?>>{
    for (final order in _orders()) order['id']! as String: order,
  };
  final reports = <String, Map<String, Object?>>{
    for (final report in _reports()) report['id']! as String: report,
  };

  // The report each order carries, as `ORDER_INCLUDE` embeds it.
  Map<String, Object?> withReport(Map<String, Object?> order) {
    final report = reports.values.firstWhere(
      (r) => r['orderId'] == order['id'],
      orElse: () => const {},
    );
    return {...order, 'report': report.isEmpty ? null : report};
  }

  var created = 0;

  // ── Stats ─────────────────────────────────────────────────────────────────
  //
  // Derived from the orders rather than hand-counted: a figure that disagrees
  // with the list under it is the first thing a screenshot review catches, and
  // the second thing somebody "fixes" by changing the wrong number.
  api.on('GET', '/api/radiology/stats/summary', (_) {
    int counted(String status) =>
        orders.values.where((o) => o['status'] == status).length;
    return FakeResponse.ok({
      'pending': counted('pending'),
      'inProgress': counted('in_progress'),
      'completedToday': counted('completed'),
      'criticalFindings': reports.values
          .where((r) => r['hasCriticalFindings'] == true && r['verifiedAt'] == null)
          .length,
      'totalExams': exams.length,
    });
  });

  // ── Orders ────────────────────────────────────────────────────────────────

  api.on('GET', '/api/radiology/orders', (request) {
    final status = request.query['status'];
    final urgency = request.query['urgency'];
    final patientId = request.query['patientId'];
    final search = (request.query['search'] ?? '').toLowerCase();

    final rows = orders.values.where((order) {
      if (status != null && order['status'] != status) return false;
      if (urgency != null && order['urgency'] != urgency) return false;
      if (patientId != null && order['patientId'] != patientId) return false;
      if (search.isEmpty) return true;
      final patient = order['patient']! as Map<String, Object?>;
      return [
        order['orderNumber'],
        patient['firstName'],
        patient['lastName'],
        patient['mrn'],
      ].join(' ').toLowerCase().contains(search);
    }).map(withReport).toList()
      // `orderDate desc`, which is what the route's own `orderBy` does. A
      // fixture in insertion order would let a sort regression through.
      ..sort((a, b) =>
          (b['orderDate']! as String).compareTo(a['orderDate']! as String));

    // The app always sends `page`, so the paged shape is what it always gets —
    // `RadiologyOrderListQueryDto` switches on the parameter being present.
    return FakeResponse.page(rows);
  });

  api.on('GET', '/api/radiology/orders/:id', (request) {
    final order = orders[request.pathParams['id']];
    if (order == null) return FakeResponse.fail(404, 'Not found');
    return FakeResponse.ok(withReport(order));
  });

  api.on('POST', '/api/radiology/orders', (request) {
    final body = request.jsonBody;
    final id = 'ro-new-${++created}';
    final exam = exams[body['examId']] ?? exams.values.first;
    final order = <String, Object?>{
      'id': id,
      'organizationId': 'o-1',
      'patientId': body['patientId'],
      'examId': body['examId'],
      'orderNumber': 'RAD90${created.toString().padLeft(2, '0')}',
      'orderDate': _now(),
      'clinicalIndication': body['clinicalIndication'],
      'provisionalDiagnosis': body['provisionalDiagnosis'],
      'relevantHistory': body['relevantHistory'],
      'notes': body['notes'],
      'urgency': body['urgency'] ?? 'routine',
      'status': 'pending',
      'requestedById': 'u-8',
      'createdAt': _now(),
      'updatedAt': _now(),
      'patient': _patientOf('${body['patientId']}'),
      'exam': exam,
    };
    orders[id] = order;
    return FakeResponse.ok(withReport(order));
  });

  api.on('PATCH', '/api/radiology/orders/:id', (request) {
    final id = request.pathParams['id']!;
    final order = orders[id];
    if (order == null) return FakeResponse.fail(404, 'Not found');
    // Merged, not replaced: the app PATCHes two or three keys and the screen
    // reads the whole record back.
    orders[id] = {...order, ...request.jsonBody, 'updatedAt': _now()};
    return FakeResponse.ok(withReport(orders[id]!));
  });

  // ── Exams ─────────────────────────────────────────────────────────────────
  //
  // A bare array with no meta, which is what this route answers however it is
  // asked — it has no pagination DTO at all.

  api.on('GET', '/api/radiology/exams', (request) {
    final category = request.query['category'];
    final rows = exams.values
        .where((exam) => category == null || exam['examCategory'] == category)
        .toList();
    return FakeResponse.ok(rows);
  });

  api.on('GET', '/api/radiology/exams/:id', (request) {
    final exam = exams[request.pathParams['id']];
    if (exam == null) return FakeResponse.fail(404, 'Not found');
    return FakeResponse.ok(exam);
  });

  api.on('POST', '/api/radiology/exams', (request) {
    final id = 're-new-${++created}';
    final exam = <String, Object?>{
      'id': id,
      'organizationId': 'o-1',
      'isActive': true,
      'contrastRequired': false,
      'createdAt': _now(),
      'updatedAt': _now(),
      ...request.jsonBody,
    };
    exams[id] = exam;
    return FakeResponse.ok(exam);
  });

  api.on('PATCH', '/api/radiology/exams/:id', (request) {
    final id = request.pathParams['id']!;
    final exam = exams[id];
    if (exam == null) return FakeResponse.fail(404, 'Not found');
    exams[id] = {...exam, ...request.jsonBody, 'updatedAt': _now()};
    return FakeResponse.ok(exams[id]);
  });

  // ── Reports ───────────────────────────────────────────────────────────────

  api.on('GET', '/api/radiology/reports', (request) {
    final orderId = request.query['orderId'];
    final rows = reports.values
        .where((report) => orderId == null || report['orderId'] == orderId)
        .toList();
    return FakeResponse.ok(rows);
  });

  api.on('GET', '/api/radiology/reports/:id', (request) {
    final report = reports[request.pathParams['id']];
    if (report == null) return FakeResponse.fail(404, 'Not found');
    return FakeResponse.ok(report);
  });

  api.on('POST', '/api/radiology/reports', (request) {
    final body = request.jsonBody;
    final id = 'rr-new-${++created}';
    final orderId = '${body['orderId']}';
    final report = <String, Object?>{
      'id': id,
      'organizationId': 'o-1',
      'hasCriticalFindings': false,
      'comparedWithPrevious': false,
      // A JSON array inside a text column, which is what the app has to parse.
      'images': '[]',
      'reportedById': 'u-8',
      'reportedAt': _now(),
      'verifiedAt': null,
      'createdAt': _now(),
      'updatedAt': _now(),
      ...body,
      // The server writes this one itself and ignores anything sent for it.
      'status': 'draft',
    };
    reports[id] = report;

    // The real route moves the order to `reported` as a side effect, and a
    // fixture that did not would let a screen pass that never notices.
    final order = orders[orderId];
    if (order != null) {
      orders[orderId] = {
        ...order,
        'status': 'reported',
        'reportCreatedAt': _now(),
        'reportedById': 'u-8',
      };
    }
    return FakeResponse.ok(report);
  });

  api.on('PATCH', '/api/radiology/reports/:id', (request) {
    final id = request.pathParams['id']!;
    final report = reports[id];
    if (report == null) return FakeResponse.fail(404, 'Not found');
    final body = request.jsonBody;
    reports[id] = {
      ...report,
      ...body,
      // Stamped by the server when a signed report is changed.
      if (body['status'] == 'amended') ...{
        'amendedAt': _now(),
        'amendedById': 'u-8',
      },
      'updatedAt': _now(),
    };
    return FakeResponse.ok(reports[id]);
  });

  // ── Upload ────────────────────────────────────────────────────────────────
  //
  // Multipart, under the field name `file`. The response is `{url}` and
  // nothing else — the server files the object and leaves attaching it to the
  // PATCH that follows, which is the two-step the app has to get right.
  api.on('POST', '/api/radiology/upload', (request) {
    final filename = request.formFiles['file'];
    if (filename == null) {
      // Exactly what the route does when the part is named anything else: the
      // interceptor sees no file and the handler refuses. Without this the
      // fixture would happily accept `image` or `upload` and the app would
      // only find out on a ward.
      return FakeResponse.fail(400, 'No file uploaded');
    }
    return FakeResponse.ok({
      'url': 'https://files.example.org/o-1/radiology/$filename',
    });
  });
}

// ── The department ───────────────────────────────────────────────────────────

/// Ten exams across five modalities, two of which need contrast.
List<Map<String, Object?>> _exams() => [
      _exam('re-1', 'Chest X-Ray PA', 'CXR-PA', 'x-ray', 'Chest', 'DR', 450, 10),
      _exam('re-2', 'Chest X-Ray Lateral', 'CXR-LAT', 'x-ray', 'Chest', 'DR', 450, 10),
      _exam('re-3', 'Abdominal X-Ray', 'AXR', 'x-ray', 'Abdomen', 'DR', 500, 10),
      _exam('re-4', 'CT Head', 'CT-HEAD', 'ct', 'Head', 'CT', 3200, 20),
      _exam(
        're-5',
        'CT Abdomen with contrast',
        'CT-ABDO-C',
        'ct',
        'Abdomen',
        'CT',
        5400,
        30,
        contrast: true,
        preparation: 'Nil by mouth for four hours. Check renal function and '
            'consent before the patient is sent.',
      ),
      _exam('re-6', 'MRI Brain', 'MRI-BRAIN', 'mri', 'Head', 'MRI', 8800, 45),
      _exam(
        're-7',
        'MRI Spine with contrast',
        'MRI-SPINE-C',
        'mri',
        'Spine',
        'MRI',
        11200,
        60,
        contrast: true,
        preparation: 'No metal. Confirm no pacemaker or implants.',
      ),
      _exam('re-8', 'Ultrasound Abdomen', 'US-ABDO', 'ultrasound', 'Abdomen', 'US', 1400, 20),
      _exam('re-9', 'Ultrasound Obstetric', 'US-OB', 'ultrasound', 'Pelvis', 'US', 1600, 25),
      _exam('re-10', 'Mammogram bilateral', 'MG-BIL', 'mammography', 'Breast', 'MG', 2600, 20),
    ];

Map<String, Object?> _exam(
  String id,
  String name,
  String code,
  String category,
  String bodyPart,
  String modality,
  num price,
  int minutes, {
  bool contrast = false,
  String? preparation,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'examName': name,
      'examCode': code,
      'examCategory': category,
      'bodyPart': bodyPart,
      'modality': modality,
      'price': price,
      'estimatedDuration': minutes,
      'contrastRequired': contrast,
      'preparationInstructions': preparation,
      'isActive': true,
      'createdAt': _dayOffset(-90),
      'updatedAt': _dayOffset(-90),
    };

/// Eight orders, covering every state the backend's enum holds.
List<Map<String, Object?>> _orders() => [
      _order('ro-1', 'RAD9001', 'p-1', 're-1', 'pending', 'routine', -0),
      _order('ro-2', 'RAD9002', 'p-2', 're-4', 'pending', 'stat', -0,
          indication: 'Head injury, GCS 13 on arrival.'),
      _order('ro-3', 'RAD9003', 'p-3', 're-8', 'scheduled', 'urgent', -1,
          scheduled: 0),
      _order('ro-4', 'RAD9004', 'p-4', 're-5', 'in_progress', 'urgent', -1,
          scheduled: -1),
      _order('ro-5', 'RAD9005', 'p-5', 're-3', 'completed', 'routine', -2,
          scheduled: -2, performed: -2),
      // The read that found something. Its report is `rr-1`.
      _order('ro-6', 'RAD9006', 'p-2', 're-1', 'reported', 'stat', -2,
          scheduled: -2, performed: -2, reported: -2),
      _order('ro-7', 'RAD9007', 'p-6', 're-6', 'reported', 'routine', -3,
          scheduled: -3, performed: -3, reported: -3),
      _order('ro-8', 'RAD9008', 'p-7', 're-10', 'cancelled', 'routine', -4,
          cancelledBecause: 'Patient did not attend.'),
    ];

Map<String, Object?> _order(
  String id,
  String number,
  String patientId,
  String examId,
  String status,
  String urgency,
  int orderedDaysAgo, {
  int? scheduled,
  int? performed,
  int? reported,
  String? indication,
  String? cancelledBecause,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'patientId': patientId,
      'examId': examId,
      'orderNumber': number,
      'orderDate': _dayOffset(orderedDaysAgo),
      'clinicalIndication': indication ?? 'Persistent symptoms, imaging '
          'requested by the admitting team.',
      'provisionalDiagnosis': null,
      'relevantHistory': null,
      'notes': null,
      'urgency': urgency,
      'status': status,
      'scheduledDate': scheduled == null ? null : _dayOffset(scheduled),
      'examPerformedAt': performed == null ? null : _dayOffset(performed),
      'performedById': performed == null ? null : 'u-8',
      'reportCreatedAt': reported == null ? null : _dayOffset(reported),
      'reportedById': reported == null ? null : 'u-8',
      'reportVerifiedAt': null,
      'verifiedById': null,
      'cancellationReason': cancelledBecause,
      'requestedById': 'd-1',
      'createdAt': _dayOffset(orderedDaysAgo),
      'updatedAt': _dayOffset(orderedDaysAgo),
      'patient': _patientOf(patientId),
      'exam': _exams().firstWhere((exam) => exam['id'] == examId),
    };

/// Two reads. One of them found something the ward has to hear about, and one
/// of them is signed — which is what makes the amendment rule testable.
List<Map<String, Object?>> _reports() => [
      {
        'id': 'rr-1',
        'organizationId': 'o-1',
        'orderId': 'ro-6',
        'technique': 'PA chest radiograph, erect.',
        'findings': 'Large left-sided pneumothorax with mediastinal shift to '
            'the right.',
        'impression': 'Tension pneumothorax. Immediate decompression '
            'required.',
        'recommendations': '1. Immediate needle decompression\n'
            '2. Chest drain\n'
            '3. Repeat film after drain insertion',
        'hasCriticalFindings': true,
        'criticalFindings': 'Tension pneumothorax',
        'criticalNotifiedTo': 'Dr Amara Okonkwo',
        'criticalNotifiedAt': _minutesAgo(35),
        'comparedWithPrevious': false,
        'comparisonNotes': null,
        // A JSON **string**, as the text column stores it. The app parses this
        // shape; a real array here would test a parser the server never feeds.
        'images': jsonEncode([
          {'url': 'https://files.example.org/o-1/radiology/cxr-pa.jpg',
            'caption': 'PA erect', 'view': 'AP'},
        ]),
        'status': 'final',
        'reportedById': 'u-8',
        'reportedAt': _dayOffset(-2),
        'verifiedById': null,
        'verifiedAt': null,
        'amendmentReason': null,
        'createdAt': _dayOffset(-2),
        'updatedAt': _dayOffset(-2),
      },
      {
        'id': 'rr-2',
        'organizationId': 'o-1',
        'orderId': 'ro-7',
        'technique': 'Multiplanar MRI of the brain without contrast.',
        'findings': 'No acute infarct, haemorrhage or mass lesion.',
        'impression': 'Normal study.',
        'recommendations': null,
        'hasCriticalFindings': false,
        'criticalFindings': null,
        'criticalNotifiedTo': null,
        'criticalNotifiedAt': null,
        'comparedWithPrevious': true,
        'comparisonNotes': 'Unchanged from the study of two years ago.',
        'images': '[]',
        'status': 'draft',
        'reportedById': 'u-8',
        'reportedAt': _dayOffset(-3),
        'verifiedById': null,
        'verifiedAt': null,
        'amendmentReason': null,
        'createdAt': _dayOffset(-3),
        'updatedAt': _dayOffset(-3),
      },
    ];

/// The same seven patients the rest of the world holds, so a study opened from
/// imaging names somebody the queue and the ward also know about.
Map<String, Object?> _patientOf(String id) {
  const people = <String, List<String>>{
    'p-1': ['10421', 'Ifeoma', 'Balogun', 'Female', '1991-04-12'],
    'p-2': ['10422', 'Tom', 'Whitfield', 'Male', '1958-11-02'],
    'p-3': ['10423', 'Sana', 'Qureshi', 'Female', '2019-07-30'],
    'p-4': ['10424', 'Grace', 'Mwangi', 'Female', '1976-01-19'],
    'p-5': ['10425', 'Henrik', 'Nilsen', 'Male', '2002-09-08'],
    'p-6': ['10426', 'Yusuf', 'Adeyemi', 'Male', '1984-03-25'],
    'p-7': ['10427', 'Margaret', 'Okafor', 'Female', '1941-06-14'],
  };
  final person = people[id] ?? const ['00000', 'Unknown', 'Patient', '', ''];
  return {
    'id': id,
    'mrn': person[0],
    'firstName': person[1],
    'lastName': person[2],
    'gender': person[3],
    'dateOfBirth': person[4].isEmpty ? null : '${person[4]}T00:00:00.000Z',
  };
}

// Every timestamp comes off `AppClock`, which the harness freezes. Wall-clock
// time here is silently wrong in both directions against a frozen clock, and
// the symptom is a screen whose dates are all "in 3 days".
String _now() => AppClock.now().toUtc().toIso8601String();

String _dayOffset(int days) {
  final moment = AppClock.now().toUtc().add(Duration(days: days));
  return DateTime.utc(moment.year, moment.month, moment.day, 9, 30)
      .toIso8601String();
}

String _minutesAgo(int minutes) =>
    AppClock.now().toUtc().subtract(Duration(minutes: minutes)).toIso8601String();
