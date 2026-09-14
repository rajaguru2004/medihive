import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// The patient register, and everything the hub hangs off one patient.
///
/// Twelve people who could plausibly be on one small hospital's books on one
/// afternoon: a spread of ages from a six-year-old to a grandmother, one
/// record deactivated, one carrying allergies and two chronic conditions, one
/// insured and one whose cover has run out.
///
/// The first seven reuse the ids and MRNs `world.dart` already hands to the
/// queue, the clinic board and the ward — `p-1` is the same Ifeoma Balogun in
/// all of them — so a flow that walks from the board into a record sees one
/// department rather than two that happen to share a name.
///
/// **This file re-registers `/api/appointments` and `/api/consultations`.**
/// Neither route honours `patientId` in `world.dart`, and the hub's Visits tab
/// is nothing but that filter. The unfiltered answer is kept identical in
/// shape and in its today-rows, so the clinic board and its figures do not
/// move; the extra rows are dated in the past and only surface when the hub
/// asks for one patient. Registration order therefore matters: install this
/// after `World._appointments`.
/// ─────────────────────────────────────────────────────────────────────────────
void installPatientsFixtures(FakeApi api) {
  _register(api);
  _visits(api);
  _diagnostics(api);
  _pharmacyAndBilling(api);
}

// ── The register ────────────────────────────────────────────────────────────

void _register(FakeApi api) {
  api.on('GET', '/api/patients', (request) {
    final rows = _matching(
      search: request.query['search'],
      status: request.query['status'],
    );

    final page = int.tryParse(request.query['page'] ?? '1') ?? 1;
    // Capped, and deliberately low. The real server caps `limit` at 100; this
    // caps at six so that twelve patients are two pages, because a fixture
    // that never paginates cannot prove the list asks for page two — and a
    // list that silently stops after its first page looks exactly like a
    // hospital with twelve patients.
    final limit = (int.tryParse(request.query['limit'] ?? '20') ?? 20).clamp(1, 6);

    final from = (page - 1) * limit;
    final slice = from >= rows.length
        ? const <Map<String, Object?>>[]
        : rows.sublist(from, (from + limit).clamp(0, rows.length));

    return FakeResponse.page(
      slice,
      page: page,
      limit: limit,
      total: rows.length,
    );
  });

  api.on('GET', '/api/patients/:id', (request) {
    final id = request.pathParams['id'];
    final patient = _patients.where((row) => row['id'] == id).firstOrNull;
    return patient == null
        ? FakeResponse.fail(404, 'Patient not found', errorCode: 'NOT_FOUND')
        : FakeResponse.ok(patient);
  });

  // The created record comes back with the MRN the server minted, because the
  // toast says it out loud and a front desk writes it on a wristband.
  api.on(
    'POST',
    '/api/patients',
    (request) => FakeResponse.ok({
      ..._patient(
        id: 'p-new',
        mrn: '10433',
        first: 'New',
        last: 'Patient',
        sex: 'female',
        born: '1990-01-01',
      ),
      ...request.body is Map ? request.jsonBody : const <String, Object?>{},
      'id': 'p-new',
      'mrn': '10433',
    }),
  );

  // PUT, not PATCH. `Endpoints.patients` carries `updateVerb: put`, and an
  // edit written against PATCH 404s on a route that exists.
  api.on('PUT', '/api/patients/:id', (request) {
    final id = request.pathParams['id'];
    final existing =
        _patients.where((row) => row['id'] == id).firstOrNull ?? _patients.first;
    return FakeResponse.ok({
      ...existing,
      ...request.body is Map ? request.jsonBody : const <String, Object?>{},
      'id': id,
    });
  });

  // 204, with no body — which `ApiEnvelope` reads as a success rather than as
  // the failure it used to.
  api.on('DELETE', '/api/patients/:id', (_) => const FakeResponse(204, null));
}

/// The register as the server narrows it: `search` across first name, last
/// name, MRN and phone; `status` across the soft-delete flag.
List<Map<String, Object?>> _matching({String? search, String? status}) {
  var rows = _patients.toList();

  if (status == 'active') {
    rows = rows.where((row) => row['isActive'] == true).toList();
  } else if (status == 'inactive') {
    rows = rows.where((row) => row['isActive'] == false).toList();
  }

  final term = (search ?? '').trim().toLowerCase();
  if (term.isEmpty) return rows;

  return rows.where((row) {
    final haystack = [
      row['firstName'],
      row['lastName'],
      row['mrn'],
      row['phonePrimary'],
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(term);
  }).toList();
}

// ── Visits ──────────────────────────────────────────────────────────────────

void _visits(FakeApi api) {
  api.on('GET', '/api/appointments', (request) {
    final patientId = request.query['patientId'];
    final rows = patientId == null
        ? _appointments
        : _appointments.where((row) => row['patientId'] == patientId).toList();
    return FakeResponse.page(rows);
  });

  api.on('GET', '/api/consultations', (request) {
    final patientId = request.query['patientId'];
    final rows = patientId == null
        ? _consultations
        : _consultations.where((row) => row['patientId'] == patientId).toList();
    return FakeResponse.page(rows);
  });
}

// ── Laboratory and radiology ────────────────────────────────────────────────

void _diagnostics(FakeApi api) {
  api.on('GET', '/api/laboratory/orders', (request) {
    final patientId = request.query['patientId'];
    final rows = patientId == null
        ? _labOrders
        : _labOrders.where((row) => row['patientId'] == patientId).toList();
    return FakeResponse.page(rows);
  });

  api.on('GET', '/api/radiology/orders', (request) {
    final patientId = request.query['patientId'];
    final rows = patientId == null
        ? _radiologyOrders
        : _radiologyOrders
            .where((row) => row['patientId'] == patientId)
            .toList();
    return FakeResponse.page(rows);
  });
}

// ── Pharmacy and billing ────────────────────────────────────────────────────

void _pharmacyAndBilling(FakeApi api) {
  api.on('GET', '/api/pharmacy/prescriptions', (request) {
    final patientId = request.query['patientId'];
    final rows = patientId == null
        ? _prescriptions
        : _prescriptions.where((row) => row['patientId'] == patientId).toList();
    return FakeResponse.page(rows);
  });

  api.on('GET', '/api/billing/invoices', (request) {
    final patientId = request.query['patientId'];
    final rows = patientId == null
        ? _invoices
        : _invoices.where((row) => row['patientId'] == patientId).toList();
    return FakeResponse.page(rows);
  });
}

// ── The people ──────────────────────────────────────────────────────────────

/// The patient every hub assertion is about.
///
/// Tom Whitfield is the world's P1 in the queue and its admitted patient, he
/// is allergic to two things, and his latest observations are outside their
/// ranges in both directions — so one record exercises the identity band's
/// acuity, the summary's allergy warning, the vitals banner and the critical
/// result at once.
const String kHubPatientId = 'p-2';

/// The deactivated record, for the status filter and the inactive pill.
const String kInactivePatientId = 'p-10';

/// The record with no allergies, no orders and no invoices — the empty states.
const String kQuietPatientId = 'p-11';

final List<Map<String, Object?>> _patients = [
  _patient(
    id: 'p-1',
    mrn: '10421',
    first: 'Ifeoma',
    last: 'Balogun',
    sex: 'female',
    born: '1991-04-12',
    phone: '+251911100421',
    bloodGroup: 'O+',
  ),
  _patient(
    id: 'p-2',
    mrn: '10422',
    first: 'Tom',
    last: 'Whitfield',
    sex: 'male',
    born: '1958-11-02',
    phone: '+251911100422',
    bloodGroup: 'A+',
    allergies: const ['Penicillin', 'Sulfa drugs'],
    conditions: const ['Hypertension', 'Type 2 diabetes'],
    medications: const ['Lisinopril 10mg', 'Metformin 500mg'],
    emergencyName: 'Susan Whitfield',
    emergencyPhone: '+251911100522',
    emergencyRelationship: 'Spouse',
  ),
  _patient(
    id: 'p-3',
    mrn: '10423',
    first: 'Sana',
    last: 'Qureshi',
    sex: 'female',
    born: '2019-07-30',
    phone: '+251911100423',
  ),
  _patient(
    id: 'p-4',
    mrn: '10424',
    first: 'Grace',
    last: 'Mwangi',
    sex: 'female',
    born: '1976-01-19',
    phone: '+251911100424',
    bloodGroup: 'B+',
  ),
  _patient(
    id: 'p-5',
    mrn: '10425',
    first: 'Henrik',
    last: 'Nilsen',
    sex: 'male',
    born: '2002-09-08',
    phone: '+251911100425',
  ),
  _patient(
    id: 'p-6',
    mrn: '10426',
    first: 'Yusuf',
    last: 'Adeyemi',
    sex: 'male',
    born: '1984-03-25',
    phone: '+251911100426',
    bloodGroup: 'AB-',
  ),
  _patient(
    id: 'p-7',
    mrn: '10427',
    first: 'Margaret',
    last: 'Okafor',
    sex: 'female',
    born: '1941-06-14',
    phone: '+251911100427',
    conditions: const ['Atrial fibrillation', 'Osteoarthritis'],
    medications: const ['Apixaban 5mg'],
  ),
  _patient(
    id: 'p-8',
    mrn: '10428',
    first: 'Daniel',
    last: 'Okoro',
    sex: 'male',
    born: '1995-02-28',
    phone: '+251911100428',
  ),
  _patient(
    id: 'p-9',
    mrn: '10429',
    first: 'Aster',
    last: 'Kebede',
    sex: 'female',
    born: '1988-12-05',
    phone: '+251911100429',
    hasInsurance: true,
    insuranceProvider: 'CBHI',
    insuranceId: 'POL-998877',
    // In the future relative to the harness's frozen clock, so the summary's
    // "cover expired" branch is exercised by p-10 and not by this one.
    insuranceExpiry: '2027-12-31',
  ),
  _patient(
    id: 'p-10',
    mrn: '10430',
    first: 'Lucas',
    last: 'Fernandes',
    sex: 'male',
    born: '1969-08-17',
    phone: '+251911100430',
    isActive: false,
    hasInsurance: true,
    insuranceProvider: 'Nyala',
    insuranceId: 'POL-100301',
    insuranceExpiry: '2024-06-30',
  ),
  _patient(
    id: 'p-11',
    mrn: '10431',
    first: 'Nadia',
    last: 'Haddad',
    sex: 'female',
    born: '2011-03-09',
    phone: '+251911100431',
  ),
  _patient(
    id: 'p-12',
    mrn: '10432',
    first: 'Kwame',
    last: 'Mensah',
    sex: 'male',
    born: '1953-05-21',
    phone: '+251911100432',
    bloodGroup: 'O-',
    conditions: const ['Chronic kidney disease'],
  ),
];

Map<String, Object?> _patient({
  required String id,
  required String mrn,
  required String first,
  required String last,
  required String sex,
  required String born,
  String? phone,
  String? bloodGroup,
  List<String> allergies = const [],
  List<String> conditions = const [],
  List<String> medications = const [],
  String? emergencyName,
  String? emergencyPhone,
  String? emergencyRelationship,
  bool isActive = true,
  bool hasInsurance = false,
  String? insuranceProvider,
  String? insuranceId,
  String? insuranceExpiry,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'mrn': mrn,
      'firstName': first,
      'lastName': last,
      'gender': sex,
      'dateOfBirth': '${born}T00:00:00.000Z',
      'bloodGroup': bloodGroup,
      'phonePrimary': phone,
      'email': null,
      'region': 'Addis Ababa',
      'zone': 'Bole',
      'woreda': 'Woreda 03',
      'kebele': 'Kebele 10',
      'houseNumber': '1024',
      'addressDescription': 'Near Bole Medhanialem',
      'emergencyContactName': emergencyName,
      'emergencyContactPhone': emergencyPhone,
      'emergencyContactRelationship': emergencyRelationship,
      // Arrays, which is what the service hands back after parsing its own
      // JSON text column. `asStringList` reads the string form too, so a
      // fixture in either dialect works — this is the one the API sends.
      'allergies': allergies,
      'chronicConditions': conditions,
      'currentMedications': medications,
      'hasInsurance': hasInsurance,
      'insuranceProvider': insuranceProvider,
      'insuranceId': insuranceId,
      'insuranceExpiryDate':
          insuranceExpiry == null ? null : '${insuranceExpiry}T00:00:00.000Z',
      'isActive': isActive,
      'isVip': false,
      'notes': null,
      'createdAt': _minutesAgo(60),
      'updatedAt': _minutesAgo(60),
    };

// ── Appointments ────────────────────────────────────────────────────────────

/// The world's six of today, plus two older ones so the hub has a history to
/// show rather than one row.
final List<Map<String, Object?>> _appointments = [
  _appointment('a-1', 'p-1', '09:15', 'completed', 'Routine review', 0),
  _appointment('a-2', 'p-6', '10:00', 'completed', 'Post-op check', 0),
  _appointment('a-3', 'p-4', '11:30', 'checked_in', 'Persistent cough', 0),
  _appointment('a-4', 'p-2', '14:30', 'confirmed', 'Chest pain follow-up', 0),
  _appointment('a-5', 'p-3', '15:00', 'scheduled', 'Six-year check', 0),
  _appointment('a-6', 'p-5', '15:45', 'cancelled', 'Knee assessment', 0),
  _appointment('a-7', 'p-2', '09:40', 'completed', 'Blood pressure review', -28),
  _appointment('a-8', 'p-7', '11:10', 'no_show', 'Anticoagulant clinic', -14),
];

Map<String, Object?> _appointment(
  String id,
  String patientId,
  String time,
  String status,
  String complaint,
  int dayOffset,
) {
  final patient = _patients.firstWhere((row) => row['id'] == patientId);
  return {
    'id': id,
    'organizationId': 'o-1',
    'patientId': patientId,
    'doctorId': 'd-1',
    'appointmentDate': _dayOffset(dayOffset),
    'appointmentTime': time,
    'durationMinutes': 15,
    'appointmentType': 'follow_up',
    'status': status,
    'chiefComplaint': complaint,
    'notes': '',
    'reminderSent': false,
    'patient': _ref(patient),
    'doctor': const {
      'id': 'd-1',
      'fullName': 'Dr Amara Okonkwo',
      'specialization': 'Emergency medicine',
    },
  };
}

// ── Consultations ───────────────────────────────────────────────────────────

/// `c-4` is the one the Vitals tab is about: four observations outside their
/// ranges, two of them critical, on the patient who is already P1 in the
/// queue. `c-2` is the same patient a month earlier and entirely normal, so
/// the tab has to pick the later one to be right.
final List<Map<String, Object?>> _consultations = [
  _consultation(
    id: 'c-1',
    patientId: 'p-1',
    dayOffset: -3,
    visitType: 'outpatient',
    diagnosis: 'Viral upper respiratory infection',
    plan: 'Rest, fluids, paracetamol as needed.',
  ),
  _consultation(
    id: 'c-2',
    patientId: 'p-2',
    dayOffset: -30,
    visitType: 'followup',
    diagnosis: 'Hypertension, controlled',
    plan: 'Continue lisinopril. Review in a month.',
  ),
  _consultation(
    id: 'c-3',
    patientId: 'p-6',
    dayOffset: -9,
    visitType: 'followup',
    diagnosis: 'Healing well post-appendicectomy',
    plan: 'Wound check in one week.',
  ),
  _consultation(
    id: 'c-4',
    patientId: 'p-2',
    dayOffset: 0,
    visitType: 'emergency',
    diagnosis: 'Unstable angina',
    plan: 'Admitted to AMU. Aspirin loaded, troponin sent.',
    temperature: 39.8,
    systolic: 168,
    diastolic: 96,
    pulse: 132,
    respiratoryRate: 26,
    oxygenSaturation: 91,
  ),
  _consultation(
    id: 'c-5',
    patientId: 'p-7',
    dayOffset: -14,
    visitType: 'outpatient',
    diagnosis: 'Atrial fibrillation, rate controlled',
    plan: 'Continue apixaban. INR not required.',
    pulse: 88,
  ),
];

Map<String, Object?> _consultation({
  required String id,
  required String patientId,
  required int dayOffset,
  required String visitType,
  required String diagnosis,
  required String plan,
  double temperature = 37.2,
  int systolic = 124,
  int diastolic = 78,
  int pulse = 76,
  int respiratoryRate = 16,
  int oxygenSaturation = 98,
}) {
  final patient = _patients.firstWhere((row) => row['id'] == patientId);
  return {
    'id': id,
    'organizationId': 'o-1',
    'patientId': patientId,
    'doctorId': 'd-1',
    'visitDate': _dayOffset(dayOffset),
    'visitType': visitType,
    'temperature': temperature,
    'bloodPressureSystolic': systolic,
    'bloodPressureDiastolic': diastolic,
    'pulseRate': pulse,
    'respiratoryRate': respiratoryRate,
    'oxygenSaturation': oxygenSaturation,
    'weight': 78.4,
    'chiefComplaint': 'See history',
    'diagnosis': diagnosis,
    'treatmentPlan': plan,
    'createdAt': _dayOffset(dayOffset),
    'updatedAt': _dayOffset(dayOffset),
    'isDeleted': false,
    'patient': {..._ref(patient), 'bloodGroup': patient['bloodGroup']},
    'doctor': const {
      'id': 'd-1',
      'fullName': 'Dr Amara Okonkwo',
      'specialization': 'Emergency medicine',
    },
  };
}

// ── Lab orders, with their results inside them ──────────────────────────────

/// Results arrive **on** the order, which is how the real route answers: the
/// laboratory module includes `results.test` in its list query, and
/// `/api/laboratory/results` takes only an `orderId`. The Results tab reads
/// them from here rather than asking again.
final List<Map<String, Object?>> _labOrders = [
  {
    'id': 'lab-1',
    'organizationId': 'o-1',
    'patientId': 'p-2',
    'orderNumber': 'LAB20260312001',
    'orderDate': _minutesAgo(95),
    'priority': 'stat',
    'status': 'completed',
    'clinicalIndication': 'Chest pain, query acute coronary syndrome',
    'tests': const [
      {'testId': 't-1', 'testName': 'Troponin I', 'testCode': 'TROP'},
      {'testId': 't-2', 'testName': 'Full blood count', 'testCode': 'FBC'},
    ],
    'sampleCollectedAt': _minutesAgo(90),
    'resultsEnteredAt': _minutesAgo(40),
    'patient': _ref(_patients[1]),
    'results': [
      _result(
        id: 'lr-1',
        orderId: 'lab-1',
        testId: 't-1',
        testName: 'Troponin I',
        unit: 'ng/L',
        value: '892',
        rangeMax: 14,
        abnormal: true,
        critical: true,
        // Deliberately unsigned: the one row on this screen that earns red,
        // and the whole reason the Results tab says "Critical" in words.
        verifiedAt: null,
      ),
      _result(
        id: 'lr-2',
        orderId: 'lab-1',
        testId: 't-2',
        testName: 'Haemoglobin',
        unit: 'g/dL',
        value: '11.2',
        rangeMin: 13,
        rangeMax: 17,
        abnormal: true,
        verifiedAt: _minutesAgo(35),
      ),
      _result(
        id: 'lr-3',
        orderId: 'lab-1',
        testId: 't-3',
        testName: 'White cell count',
        unit: '10⁹/L',
        value: '7.4',
        rangeMin: 4,
        rangeMax: 11,
        verifiedAt: _minutesAgo(35),
      ),
    ],
  },
  {
    'id': 'lab-2',
    'organizationId': 'o-1',
    'patientId': 'p-1',
    'orderNumber': 'LAB20260310014',
    'orderDate': _dayOffset(-2),
    'priority': 'routine',
    'status': 'completed',
    'tests': const [
      {'testId': 't-4', 'testName': 'Urea and electrolytes', 'testCode': 'U&E'},
    ],
    'patient': _ref(_patients[0]),
    'results': [
      _result(
        id: 'lr-4',
        orderId: 'lab-2',
        testId: 't-4',
        testName: 'Potassium',
        unit: 'mmol/L',
        value: '4.1',
        rangeMin: 3.5,
        rangeMax: 5.1,
        verifiedAt: _dayOffset(-2),
      ),
    ],
  },
  {
    'id': 'lab-3',
    'organizationId': 'o-1',
    'patientId': 'p-7',
    'orderNumber': 'LAB20260312007',
    'orderDate': _minutesAgo(200),
    'priority': 'routine',
    // An order with no results yet, so the Orders tab has something pending
    // on it and the Results tab is not simply the Orders tab again.
    'status': 'sample_collected',
    'tests': const [
      {'testId': 't-5', 'testName': 'Coagulation screen', 'testCode': 'CLOT'},
    ],
    'sampleCollectedAt': _minutesAgo(180),
    'patient': _ref(_patients[6]),
    'results': const <Map<String, Object?>>[],
  },
];

Map<String, Object?> _result({
  required String id,
  required String orderId,
  required String testId,
  required String testName,
  required String unit,
  required String value,
  double? rangeMin,
  double? rangeMax,
  bool abnormal = false,
  bool critical = false,
  String? verifiedAt,
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
      'flag': critical ? 'H' : (abnormal ? 'A' : 'N'),
      'referenceRangeMin': rangeMin,
      'referenceRangeMax': rangeMax,
      'enteredAt': _minutesAgo(40),
      'verifiedAt': verifiedAt,
      'test': {
        'id': testId,
        'testName': testName,
        'unit': unit,
      },
    };

// ── Radiology ───────────────────────────────────────────────────────────────

final List<Map<String, Object?>> _radiologyOrders = [
  {
    'id': 'rad-1',
    'organizationId': 'o-1',
    'patientId': 'p-2',
    'examId': 'x-1',
    'orderNumber': 'RAD20260312002',
    'orderDate': _minutesAgo(88),
    'urgency': 'stat',
    'status': 'completed',
    'clinicalIndication': 'Chest pain',
    'examPerformedAt': _minutesAgo(60),
    'patient': _ref(_patients[1]),
    'exam': const {
      'id': 'x-1',
      'examName': 'Chest X-ray',
      'modality': 'XR',
      'bodyPart': 'Chest',
    },
  },
  {
    'id': 'rad-2',
    'organizationId': 'o-1',
    'patientId': 'p-4',
    'examId': 'x-2',
    'orderNumber': 'RAD20260311009',
    'orderDate': _dayOffset(-1),
    'urgency': 'routine',
    'status': 'pending',
    'patient': _ref(_patients[3]),
    'exam': const {
      'id': 'x-2',
      'examName': 'CT chest with contrast',
      'modality': 'CT',
      'bodyPart': 'Chest',
    },
  },
];

// ── Prescriptions ───────────────────────────────────────────────────────────

final List<Map<String, Object?>> _prescriptions = [
  {
    'id': 'rx-1',
    'organizationId': 'o-1',
    'patientId': 'p-2',
    'doctorId': 'd-1',
    'prescriptionDate': _minutesAgo(50),
    'status': 'pending',
    'items': const [
      {
        'drugId': 'dr-1',
        'drugName': 'Aspirin',
        'dosage': '300mg',
        'frequency': 'Once',
        'duration': 'Stat',
        'quantity': 1,
      },
      {
        'drugId': 'dr-2',
        'drugName': 'Glyceryl trinitrate',
        'dosage': '500mcg',
        'frequency': 'As needed',
        'duration': '7 days',
        'quantity': 14,
      },
    ],
    'patient': _ref(_patients[1]),
    'doctor': const {'id': 'd-1', 'fullName': 'Dr Amara Okonkwo'},
  },
  {
    'id': 'rx-2',
    'organizationId': 'o-1',
    'patientId': 'p-2',
    'doctorId': 'd-1',
    'prescriptionDate': _dayOffset(-30),
    'status': 'fully_dispensed',
    'items': const [
      {
        'drugId': 'dr-3',
        'drugName': 'Lisinopril',
        'dosage': '10mg',
        'frequency': 'Once daily',
        'duration': '28 days',
        'quantity': 28,
      },
    ],
    'dispensedAt': _dayOffset(-30),
    'patient': _ref(_patients[1]),
    'doctor': const {'id': 'd-1', 'fullName': 'Dr Amara Okonkwo'},
  },
  {
    'id': 'rx-3',
    'organizationId': 'o-1',
    'patientId': 'p-1',
    'doctorId': 'd-1',
    'prescriptionDate': _dayOffset(-3),
    'status': 'fully_dispensed',
    'items': const [
      {
        'drugId': 'dr-4',
        'drugName': 'Paracetamol',
        'dosage': '1g',
        'frequency': 'Four times daily',
        'duration': '5 days',
        'quantity': 20,
      },
    ],
    'dispensedAt': _dayOffset(-3),
    'patient': _ref(_patients[0]),
    'doctor': const {'id': 'd-1', 'fullName': 'Dr Amara Okonkwo'},
  },
];

// ── Invoices ────────────────────────────────────────────────────────────────

final List<Map<String, Object?>> _invoices = [
  {
    'id': 'inv-1',
    'organizationId': 'o-1',
    'patientId': 'p-2',
    'invoiceNumber': 'INV-2026-0311',
    'invoiceDate': _minutesAgo(30),
    'dueDate': _dayOffset(14),
    'items': const [
      {
        'type': 'laboratory',
        'description': 'Troponin I',
        'quantity': 1,
        'unitPrice': 420.0,
        'discount': 0.0,
        'tax': 0.0,
        'total': 420.0,
      },
      {
        'type': 'radiology',
        'description': 'Chest X-ray',
        'quantity': 1,
        'unitPrice': 680.0,
        'discount': 0.0,
        'tax': 0.0,
        'total': 680.0,
      },
    ],
    'subtotal': 1100.0,
    'totalAmount': 1100.0,
    'amountPaid': 400.0,
    'balanceDue': 700.0,
    'paymentStatus': 'partial',
    'status': 'issued',
    'patient': _ref(_patients[1]),
    'payments': const <Map<String, Object?>>[],
  },
  {
    'id': 'inv-2',
    'organizationId': 'o-1',
    'patientId': 'p-1',
    'invoiceNumber': 'INV-2026-0298',
    'invoiceDate': _dayOffset(-3),
    'dueDate': _dayOffset(-1),
    'items': const [
      {
        'type': 'consultation',
        'description': 'Outpatient consultation',
        'quantity': 1,
        'unitPrice': 250.0,
        'discount': 0.0,
        'tax': 0.0,
        'total': 250.0,
      },
    ],
    'subtotal': 250.0,
    'totalAmount': 250.0,
    'amountPaid': 250.0,
    'balanceDue': 0.0,
    'paymentStatus': 'paid',
    'status': 'issued',
    'patient': _ref(_patients[0]),
    'payments': const <Map<String, Object?>>[],
  },
];

// ── Builders ────────────────────────────────────────────────────────────────

/// The patient block every other record embeds.
Map<String, Object?> _ref(Map<String, Object?> patient) => {
      'id': patient['id'],
      'mrn': patient['mrn'],
      'firstName': patient['firstName'],
      'lastName': patient['lastName'],
      'gender': patient['gender'],
      'dateOfBirth': patient['dateOfBirth'],
      'phonePrimary': patient['phonePrimary'],
    };

/// Every timestamp comes off `AppClock`, which the harness freezes.
///
/// Wall-clock time here is silently wrong in both directions: a wait of "42
/// minutes ago" computed against `DateTime.now()` is in the *future* relative
/// to a frozen clock, so every elapsed figure renders as zero and every
/// threshold this suite exists to check never fires.
String _dayOffset(int days) {
  final now = AppClock.now().toUtc().add(Duration(days: days));
  return DateTime.utc(now.year, now.month, now.day).toIso8601String();
}

String _minutesAgo(int minutes) => AppClock.now()
    .toUtc()
    .subtract(Duration(minutes: minutes))
    .toIso8601String();
