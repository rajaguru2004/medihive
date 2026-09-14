import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// The instrument link, in fixtures.
///
/// Registered from `world.dart` so every flow sees the same five devices, and
/// installable on its own through `AppHarness.bootSignedIn(overrides:)` — later
/// registrations win either way.
///
/// The routes here **hold state**: a PATCH to a device changes what the next
/// GET answers with, a DELETE takes its queued results with it the way the
/// cascade does, and an upload genuinely appends rows to the queue. A flow that
/// sends a file and then reads the queue back is asserting the app's own round
/// trip, and a fixture that answered the same canned queue every time would
/// pass that test while the app sent nothing at all.
///
/// Two refusals are modelled deliberately, because both are silent failures
/// otherwise:
///
///   * **an undeclared query parameter is a 400.** The API runs
///     `forbidNonWhitelisted`, and neither list route declares `page` or
///     `limit` — so a screen that paged this collection would show an error
///     against a fixture that shrugged.
///   * **`machineType` and `connectionType` on a PATCH are a 400.**
///     `UpdateMachineDto` declares neither, so an edit form that sent them
///     would lose the rename in the same request.
void installIntegrationsFixtures(FakeApi api) {
  final machines = <String, Map<String, Object?>>{
    for (final machine in _machines()) machine['id']! as String: machine,
  };
  final queue = <String, Map<String, Object?>>{
    for (final row in _queue()) row['id']! as String: row,
  };

  var created = 0;

  /// How many results are still waiting against one device, as the route's
  /// `_count` block reports it.
  Map<String, Object?> withCount(Map<String, Object?> machine) => {
        ...machine,
        '_count': {
          'resultsQueue': queue.values
              .where((row) =>
                  row['machineIntegrationId'] == machine['id'] &&
                  row['status'] == 'pending')
              .length,
        },
      };

  // ── Devices ───────────────────────────────────────────────────────────────

  api.on('GET', '/api/integrations/machines', (request) {
    final rejected = _rejectUndeclared(request.query.keys, _machineQueryKeys);
    if (rejected != null) return rejected;

    final type = request.query['machineType'];
    final department = request.query['department'];
    final status = request.query['status'];

    final rows = machines.values.where((machine) {
      if (type != null && machine['machineType'] != type) return false;
      if (department != null && machine['department'] != department) {
        return false;
      }
      if (status != null && machine['connectionStatus'] != status) return false;
      return true;
    }).map(withCount).toList()
      // `createdAt desc`, which is what the route's own `orderBy` does. A
      // fixture in insertion order would let a sort regression through.
      ..sort((a, b) =>
          (b['createdAt']! as String).compareTo(a['createdAt']! as String));

    // A bare array with no meta. This route has no pagination DTO at all.
    return FakeResponse.ok(rows);
  });

  api.on('GET', '/api/integrations/machines/:id', (request) {
    final machine = machines[request.pathParams['id']];
    if (machine == null) return FakeResponse.fail(404, 'Machine not found');
    return FakeResponse.ok(withCount(machine));
  });

  api.on('POST', '/api/integrations/machines', (request) {
    final body = request.jsonBody;
    final rejected = _rejectUndeclared(body.keys, _createMachineKeys);
    if (rejected != null) return rejected;

    for (final required in const ['machineName', 'machineType', 'connectionType']) {
      if ((body[required] ?? '').toString().trim().isEmpty) {
        return FakeResponse.fail(
          400,
          '$required should not be empty',
          errorCode: 'VALIDATION_ERROR',
        );
      }
    }

    final id = 'mi-new-${++created}';
    final machine = <String, Object?>{
      'id': id,
      'organizationId': _organizationId,
      'manufacturer': null,
      'model': null,
      'serialNumber': null,
      'department': null,
      'connectionDetails': const <String, Object?>{},
      'testMapping': const <String, Object?>{},
      ...body,
      // The service writes all three itself and ignores anything sent for them.
      'isActive': true,
      'connectionStatus': 'disconnected',
      'lastConnectedAt': null,
      'lastResultReceivedAt': null,
      'createdAt': _now(),
      'updatedAt': _now(),
      'createdById': 'u-1',
    };
    machines[id] = machine;
    return FakeResponse.ok(withCount(machine));
  });

  api.on('PATCH', '/api/integrations/machines/:id', (request) {
    final id = request.pathParams['id']!;
    final machine = machines[id];
    if (machine == null) return FakeResponse.fail(404, 'Machine not found');

    final body = request.jsonBody;
    final rejected = _rejectUndeclared(body.keys, _updateMachineKeys);
    if (rejected != null) return rejected;

    // Merged, not replaced: the app PATCHes the keys somebody changed and the
    // screen reads the whole record back.
    machines[id] = {...machine, ...body, 'updatedAt': _now()};
    return FakeResponse.ok(withCount(machines[id]!));
  });

  api.on('DELETE', '/api/integrations/machines/:id', (request) {
    final id = request.pathParams['id']!;
    if (machines.remove(id) == null) {
      return FakeResponse.fail(404, 'Machine not found');
    }
    // `onDelete: Cascade` on the queue's relation. Leaving the rows behind
    // would let a screen pass that shows results from a device that is gone.
    queue.removeWhere((_, row) => row['machineIntegrationId'] == id);
    // A body, not a 204 — this is the one delete in the app that answers with
    // `{success: true}`.
    return FakeResponse.ok({'success': true});
  });

  // ── The results queue ─────────────────────────────────────────────────────

  api.on('GET', '/api/integrations/results-queue', (request) {
    final rejected = _rejectUndeclared(request.query.keys, _queueQueryKeys);
    if (rejected != null) return rejected;

    final status = request.query['status'];
    final machineId = request.query['machineId'];

    final rows = queue.values.where((row) {
      if (status != null && row['status'] != status) return false;
      if (machineId != null && row['machineIntegrationId'] != machineId) {
        return false;
      }
      return true;
    }).toList()
      // `receivedAt desc`, as the route sorts it.
      ..sort((a, b) =>
          (b['receivedAt']! as String).compareTo(a['receivedAt']! as String));

    return FakeResponse.ok(rows);
  });

  // ── The import ────────────────────────────────────────────────────────────
  //
  // Multipart, under the field name `file`. The response is a summary of what
  // the parser and the matcher made of it, and the rows it describes are really
  // appended to the queue above — which is what lets a flow prove the import
  // arrived rather than that the button was tappable.
  api.on('POST', '/api/integrations/results/upload', (request) {
    final filename = request.formFiles['file'];
    if (filename == null || filename.isEmpty) {
      // Exactly what the route does when the part is named anything else: the
      // interceptor sees no file and the handler files an empty import.
      return FakeResponse.fail(400, 'No file uploaded');
    }

    // The service upserts a per-site device for an unattributed import rather
    // than refusing one, so the queue still says where every row came from.
    final attributed = request.formFields['machineIntegrationId'];
    final machineId = attributed == null || attributed.isEmpty
        ? 'machine-manual-upload-$_organizationId'
        : attributed;
    machines.putIfAbsent(
      machineId,
      () => _machine(
        id: machineId,
        name: 'Manual File Upload',
        type: 'lab_analyzer',
        connection: 'file_upload',
        status: 'connected',
        createdDaysAgo: 0,
      ),
    );
    machines[machineId] = {
      ...machines[machineId]!,
      'lastResultReceivedAt': _now(),
    };

    // Two analytes for one sample: one the matcher placed, one it could not.
    // Both, because an import that only ever succeeded would never exercise the
    // half of this screen that exists for the other case.
    final stamp = ++created;
    final rows = <Map<String, Object?>>[
      _queueRow(
        id: 'rq-import-$stamp-a',
        machineId: machineId,
        machineName: machines[machineId]!['machineName']! as String,
        status: 'matched',
        identifier: '10421',
        patientId: 'p-1',
        analytes: const [
          ('WBC', 'White cell count', '7.4', '10^9/L'),
        ],
        minutesAgo: 0,
      ),
      _queueRow(
        id: 'rq-import-$stamp-b',
        machineId: machineId,
        machineName: machines[machineId]!['machineName']! as String,
        status: 'manual_review',
        identifier: 'SAMPLE-001',
        error: 'Multiple matches found, requires manual review',
        analytes: const [
          ('HGB', 'Haemoglobin', '13.9', 'g/dL'),
        ],
        minutesAgo: 0,
      ),
    ];
    for (final row in rows) {
      queue[row['id']! as String] = row;
    }

    return FakeResponse.ok({
      'success': true,
      'fileName': filename,
      'totalRows': rows.length,
      'parsedRows': rows.length,
      'parseErrors': const <String>[],
      'matchedCount': const {'success': 1, 'failed': 0, 'pending': 1},
      'queuedResults': rows.length,
    });
  });
}

// ── The department ───────────────────────────────────────────────────────────

const String _organizationId = 'o-1';

/// The keys each DTO declares. Anything else is a 400, because the API runs
/// `forbidNonWhitelisted` and a fixture that tolerated more than the server
/// does is a fixture that green-lights a request the ward gets a 400 for.
const Set<String> _machineQueryKeys = {
  'organizationId',
  'machineType',
  'department',
  'status',
};

const Set<String> _queueQueryKeys = {'organizationId', 'status', 'machineId'};

const Set<String> _createMachineKeys = {
  'organizationId',
  'machineName',
  'machineType',
  'manufacturer',
  'model',
  'serialNumber',
  'department',
  'connectionType',
  'connectionDetails',
  'testMapping',
};

/// Note what is **not** here: `machineType` and `connectionType`. A device that
/// turns out to be a different machine is a different machine.
const Set<String> _updateMachineKeys = {
  'machineName',
  'manufacturer',
  'model',
  'serialNumber',
  'department',
  'connectionDetails',
  'testMapping',
  'isActive',
  'connectionStatus',
};

FakeResponse? _rejectUndeclared(Iterable<String> keys, Set<String> allowed) {
  final extra = keys.where((key) => !allowed.contains(key)).toList()..sort();
  if (extra.isEmpty) return null;
  return FakeResponse.fail(
    400,
    extra.map((key) => 'property $key should not exist').join(', '),
    errorCode: 'VALIDATION_ERROR',
  );
}

/// Five devices, covering every state the board has to draw: talking, silent,
/// faulty, deliberately switched off, and one that has never called in at all.
List<Map<String, Object?>> _machines() => [
      _machine(
        id: 'mi-1',
        name: 'Sysmex XN-1000',
        type: 'lab_analyzer',
        connection: 'hl7',
        status: 'connected',
        manufacturer: 'Sysmex',
        model: 'XN-1000',
        serial: 'SN-118420',
        department: 'laboratory',
        host: '192.168.1.50',
        port: 5000,
        connectedMinutesAgo: 4,
        resultMinutesAgo: 12,
        createdDaysAgo: -40,
      ),
      _machine(
        id: 'mi-2',
        name: 'Cobas c311',
        type: 'lab_analyzer',
        connection: 'astm',
        status: 'disconnected',
        manufacturer: 'Roche',
        model: 'c311',
        serial: 'SN-770213',
        department: 'laboratory',
        host: '192.168.1.51',
        port: 5100,
        connectedMinutesAgo: 60 * 30,
        resultMinutesAgo: 60 * 31,
        createdDaysAgo: -38,
      ),
      _machine(
        id: 'mi-3',
        name: 'Acuson Sequoia',
        type: 'radiology_equipment',
        connection: 'rest_api',
        status: 'error',
        manufacturer: 'Siemens',
        model: 'Sequoia',
        department: 'radiology',
        host: 'acuson.imaging.local',
        port: 8443,
        connectedMinutesAgo: 95,
        createdDaysAgo: -30,
      ),
      _machine(
        id: 'mi-4',
        name: 'IntelliVue MX450',
        type: 'vital_signs_monitor',
        connection: 'serial',
        // Reads as "switched off" on the board whatever this says, which is the
        // point of having one: a machine somebody took out of service is not a
        // machine that has stopped talking.
        status: 'connected',
        manufacturer: 'Philips',
        model: 'MX450',
        department: 'icu',
        isActive: false,
        connectedMinutesAgo: 60 * 24 * 3,
        createdDaysAgo: -20,
      ),
      _machine(
        id: 'mi-5',
        name: 'Mindray BC-5150',
        type: 'lab_analyzer',
        connection: 'file_upload',
        status: 'disconnected',
        manufacturer: 'Mindray',
        model: 'BC-5150',
        department: 'laboratory',
        createdDaysAgo: -2,
      ),
    ];

Map<String, Object?> _machine({
  required String id,
  required String name,
  required String type,
  required String connection,
  required String status,
  required int createdDaysAgo,
  String? manufacturer,
  String? model,
  String? serial,
  String? department,
  String? host,
  int? port,
  bool isActive = true,
  int? connectedMinutesAgo,
  int? resultMinutesAgo,
}) =>
    {
      'id': id,
      'organizationId': _organizationId,
      'machineName': name,
      'machineType': type,
      'manufacturer': manufacturer,
      'model': model,
      'serialNumber': serial,
      'department': department,
      'connectionType': connection,
      // The integrations service parses both before answering — the settings
      // route does not, and the model reads either. Sent parsed here, because
      // this is the route that parses.
      'connectionDetails': <String, Object?>{
        'ip_address': ?host,
        'port': ?port,
      },
      'testMapping': const <String, Object?>{},
      'isActive': isActive,
      'connectionStatus': status,
      'lastConnectedAt':
          connectedMinutesAgo == null ? null : _minutesAgo(connectedMinutesAgo),
      'lastResultReceivedAt':
          resultMinutesAgo == null ? null : _minutesAgo(resultMinutesAgo),
      'createdAt': _dayOffset(createdDaysAgo),
      'updatedAt': _dayOffset(createdDaysAgo),
      'createdById': 'u-1',
    };

/// Three results: one the analyser matched to a patient, one nobody could be
/// found for, and one with more than one candidate.
List<Map<String, Object?>> _queue() => [
      _queueRow(
        id: 'rq-1',
        machineId: 'mi-1',
        machineName: 'Sysmex XN-1000',
        status: 'matched',
        identifier: '10422',
        patientId: 'p-2',
        analytes: const [
          ('WBC', 'White cell count', '11.8', '10^9/L'),
          ('HGB', 'Haemoglobin', '9.4', 'g/dL'),
          ('PLT', 'Platelets', '188', '10^9/L'),
        ],
        minutesAgo: 18,
      ),
      _queueRow(
        id: 'rq-2',
        machineId: 'mi-2',
        machineName: 'Cobas c311',
        status: 'failed',
        // What the bench typed onto the tube. It matched nobody, which is the
        // whole reason this queue exists rather than the result being dropped.
        identifier: 'TUBE-88213',
        error: 'Patient not found: TUBE-88213',
        analytes: const [
          ('NA', 'Sodium', '139', 'mmol/L'),
          ('K', 'Potassium', '4.1', 'mmol/L'),
        ],
        minutesAgo: 46,
      ),
      _queueRow(
        id: 'rq-3',
        machineId: 'mi-1',
        machineName: 'Sysmex XN-1000',
        status: 'pending',
        identifier: '10425',
        analytes: const [
          ('CRP', 'C-reactive protein', '62', 'mg/L'),
        ],
        minutesAgo: 3,
      ),
    ];

Map<String, Object?> _queueRow({
  required String id,
  required String machineId,
  required String machineName,
  required String status,
  required String identifier,
  required List<(String, String, String, String)> analytes,
  required int minutesAgo,
  String? patientId,
  String? error,
}) {
  final results = [
    for (final (code, name, value, unit) in analytes)
      {
        'testCode': code,
        'testName': name,
        'value': value,
        'unit': unit,
        'referenceRange': null,
        'timestamp': _minutesAgo(minutesAgo),
      },
  ];

  return {
    'id': id,
    'organizationId': _organizationId,
    'machineIntegrationId': machineId,
    'rawData': 'MSH|^~\\&|$machineName|LAB|||||ORU^R01',
    'parsedData': {'patientId': identifier},
    'patientIdentifier': identifier,
    'matchedPatientId': patientId,
    // A JSON array inside a text column, which is what the app has to parse. A
    // real array here would test a parser the server never feeds.
    'testResults': results,
    'status': status,
    'errorMessage': error,
    'receivedAt': _minutesAgo(minutesAgo),
    'processedAt': patientId == null ? null : _minutesAgo(minutesAgo),
    'machineIntegration': {
      'id': machineId,
      'machineName': machineName,
      'machineType': 'lab_analyzer',
    },
    'patient': patientId == null ? null : _patientOf(patientId),
  };
}

/// The same patients the rest of the world holds, so a result matched here
/// names somebody the queue and the ward also know about.
Map<String, Object?> _patientOf(String id) {
  const people = <String, List<String>>{
    'p-1': ['10421', 'Ifeoma', 'Balogun'],
    'p-2': ['10422', 'Tom', 'Whitfield'],
    'p-3': ['10423', 'Sana', 'Qureshi'],
    'p-5': ['10425', 'Henrik', 'Nilsen'],
  };
  final person = people[id] ?? const ['00000', 'Unknown', 'Patient'];
  return {
    'id': id,
    'mrn': person[0],
    'firstName': person[1],
    'lastName': person[2],
  };
}

// Every timestamp comes off `AppClock`, which the harness freezes. Wall-clock
// time here is silently wrong in both directions against a frozen clock, and
// the symptom is a board whose devices were all last heard from "in 3 days".
String _now() => AppClock.now().toUtc().toIso8601String();

String _minutesAgo(int minutes) =>
    AppClock.now().toUtc().subtract(Duration(minutes: minutes)).toIso8601String();

String _dayOffset(int days) {
  final moment = AppClock.now().toUtc().add(Duration(days: days));
  return DateTime.utc(moment.year, moment.month, moment.day, 9, 30)
      .toIso8601String();
}
