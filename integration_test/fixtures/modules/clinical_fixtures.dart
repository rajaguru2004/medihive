import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';
import '../world_roles.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the encounter, in fixtures
///
/// One clinic's day and three write-ups: eight bookings covering **every**
/// status the update DTO's `@IsIn` accepts, and three consultations chosen so
/// that the two things a vitals screen can get wrong are both on the board —
/// one record well outside the adult ranges, one comfortably inside them, and
/// one that was never examined at all.
///
/// That third one is the point of this file. **This backend stores an
/// unobserved numeric vital as `0`**, so a consultation nobody took
/// observations for arrives as 0 °C, 0 bpm, 0/0 mmHg. A screen that judges
/// those as readings paints an empty record red — a red that is not a
/// deteriorating patient, which is the one thing red is not allowed to be.
/// `c-unrecorded` is that record, and it must raise no flag on either screen.
///
/// **Deliberately stateful.** A booking's whole product is the ladder it walks
/// — confirm, check in, start, complete — and a fixture that answers every
/// request with the same frozen row can only test the first step. The writes
/// here mutate the same maps the reads serve, and they stamp the timestamps the
/// real service stamps (`checkedInAt`, `startedAt`, `completedAt`,
/// `cancelledAt`), because the detail screen's timeline reads them.
///
/// ## What this file does *not* register, and why
///
///  * **the `/api/appointments` and `/api/consultations` list routes.** They
///    belong to `world.dart` and to `patients_fixtures.dart`, which serves the
///    `patientId`-aware versions the patient hub needs. Overriding them here
///    would move the clinic board under a stream that has nothing to do with
///    it. The detail screens are reached by id, which is what a deep link does.
///  * **the laboratory and radiology catalogues, and their order routes.**
///    `laboratory_fixtures.dart` and `radiology_fixtures.dart` own those, and
///    theirs are stateful in ways a consultation flow should not restate. A
///    consultation that raises an order writes into their world.
///
/// ## Install order
///
/// Install this **before** `installPharmacyFixtures`. Later registrations win,
/// and the pharmacy owns its own shelf — its stats agree with fifteen rows, and
/// the six here are only what a prescriber needs to write a script. They share
/// their ids, names, strengths and forms with the pharmacy's, so a flow that
/// picks "Amoxicillin" gets `drug-amox` whichever list answered.
/// ─────────────────────────────────────────────────────────────────────────────
void installClinicalFixtures(FakeApi api) {
  _appointments(api);
  _consultations(api);
  _lookups(api);
}

/// The ids, names and readings this world is built from.
///
/// Named constants rather than string literals in the flows, for the same
/// reason the app has a keys file: `find.text('Tom Whitfield')` and
/// `'ap-confirmed'` are both magic until something says what they are.
abstract final class ClinicalWorld {
  // ── Bookings, one per status ──────────────────────────────────────────────
  static const String scheduledAppointment = 'ap-scheduled';
  static const String confirmedAppointment = 'ap-confirmed';
  static const String checkedInAppointment = 'ap-checked-in';
  static const String inProgressAppointment = 'ap-in-progress';
  static const String completedAppointment = 'ap-completed';
  static const String cancelledAppointment = 'ap-cancelled';
  static const String noShowAppointment = 'ap-no-show';
  static const String rescheduledAppointment = 'ap-rescheduled';

  /// The patient on [scheduledAppointment] — the booking every action flow
  /// walks, and the name a confirm dialog has to say out loud.
  static const String scheduledPatient = 'Ifeoma Balogun';

  // ── Consultations ─────────────────────────────────────────────────────────

  /// Every observation comfortably inside its adult range. No banner.
  static const String normalConsultation = 'c-normal';

  /// 39.8 °C, 168/96, pulse 128, 24 breaths, 91% — four flags, one of them
  /// critical.
  static const String flaggedConsultation = 'c-flagged';

  /// Never examined. Every numeric vital stored as `0`, the way this backend
  /// records an absence. Nothing here is a reading, and nothing may be flagged.
  static const String unrecordedConsultation = 'c-unrecorded';

  /// A drug in both this file's list and the pharmacy's, with the same id.
  static const String amoxicillinId = 'drug-amox';
  static const String amoxicillinName = 'Amoxicillin';

  /// The clinician every fixture in this world names.
  static const String doctorId = 'd-1';
  static const String doctorName = 'Dr Amara Okonkwo';
}

// ── Appointments ────────────────────────────────────────────────────────────

void _appointments(FakeApi api) {
  final bookings = <String, Map<String, Object?>>{
    for (final row in _appointmentRows) row['id']! as String: {...row},
  };

  api.on('GET', '/api/appointments/:id', (request) {
    final row = bookings[request.pathParams['id']];
    return row == null
        ? FakeResponse.fail(404, 'Appointment not found', errorCode: 'NOT_FOUND')
        : FakeResponse.ok(row);
  });

  api.on('POST', '/api/appointments', (request) {
    final body = request.body is Map ? request.jsonBody : const {};
    final created = <String, Object?>{
      ..._appointment(
        id: 'ap-new',
        time: '09:00',
        status: 'scheduled',
        patientId: 'p-1',
        mrn: '10421',
        first: 'Ifeoma',
        last: 'Balogun',
        complaint: 'Booked from the app',
      ),
      ...body.cast<String, Object?>(),
      'id': 'ap-new',
    };
    bookings['ap-new'] = created;
    return FakeResponse.ok(created);
  });

  // PUT and PATCH both reach the same handler on this backend, so both reach
  // the same fixture. A screen written against the wrong verb would otherwise
  // pass here and 404 on a ward.
  FakeResponse update(FakeRequest request) {
    final id = request.pathParams['id'] ?? '';
    final row = bookings[id];
    if (row == null) {
      return FakeResponse.fail(404, 'Appointment not found',
          errorCode: 'NOT_FOUND');
    }
    final body = request.body is Map ? request.jsonBody : const {};
    final next = <String, Object?>{...row, ...body.cast<String, Object?>()};

    // The stamps the real service writes when a booking moves. The detail
    // screen's timeline reads them, so a fixture that skipped them would show a
    // ladder that never advances however many times it is driven.
    final status = '${body['status'] ?? ''}';
    final now = _iso(AppClock.now());
    switch (status) {
      case 'checked_in':
        next['checkedInAt'] = now;
      case 'in_progress':
        next['startedAt'] = now;
      case 'completed':
        next['completedAt'] = now;
      case 'cancelled':
        next['cancelledAt'] = now;
    }

    bookings[id] = next;
    return FakeResponse.ok(next);
  }

  api.on('PATCH', '/api/appointments/:id', update);
  api.on('PUT', '/api/appointments/:id', update);

  // 204 with an empty body, which is what the route actually answers — and the
  // shape that used to read as a failure and leave the row on screen.
  api.on('DELETE', '/api/appointments/:id', (request) {
    bookings.remove(request.pathParams['id']);
    return const FakeResponse(204, null);
  });
}

/// One booking per status, through one clinic morning.
final List<Map<String, Object?>> _appointmentRows = [
  _appointment(
    id: ClinicalWorld.scheduledAppointment,
    time: '09:00',
    status: 'scheduled',
    patientId: 'p-1',
    mrn: '10421',
    first: 'Ifeoma',
    last: 'Balogun',
    complaint: 'Persistent headache, three weeks',
  ),
  _appointment(
    id: ClinicalWorld.confirmedAppointment,
    time: '09:30',
    status: 'confirmed',
    patientId: 'p-2',
    mrn: '10422',
    first: 'Tom',
    last: 'Whitfield',
    complaint: 'Chest pain follow-up',
    type: 'follow_up',
  ),
  _appointment(
    id: ClinicalWorld.checkedInAppointment,
    time: '10:00',
    status: 'checked_in',
    patientId: 'p-4',
    mrn: '10424',
    first: 'Grace',
    last: 'Mwangi',
    complaint: 'Persistent cough',
    checkedInAt: _minutesAgo(12),
  ),
  _appointment(
    id: ClinicalWorld.inProgressAppointment,
    time: '10:30',
    status: 'in_progress',
    patientId: 'p-6',
    mrn: '10426',
    first: 'Yusuf',
    last: 'Adeyemi',
    complaint: 'Post-operative wound check',
    type: 'follow_up',
    checkedInAt: _minutesAgo(40),
    startedAt: _minutesAgo(6),
  ),
  _appointment(
    id: ClinicalWorld.completedAppointment,
    time: '11:00',
    status: 'completed',
    patientId: 'p-3',
    mrn: '10423',
    first: 'Sana',
    last: 'Qureshi',
    complaint: 'Six-year check',
    checkedInAt: _minutesAgo(150),
    startedAt: _minutesAgo(130),
    completedAt: _minutesAgo(110),
  ),
  _appointment(
    id: ClinicalWorld.cancelledAppointment,
    time: '11:30',
    status: 'cancelled',
    patientId: 'p-5',
    mrn: '10425',
    first: 'Henrik',
    last: 'Nilsen',
    complaint: 'Knee assessment',
    cancelledAt: _minutesAgo(200),
    cancellationReason: 'Patient telephoned to postpone',
  ),
  _appointment(
    id: ClinicalWorld.noShowAppointment,
    time: '12:00',
    status: 'no_show',
    patientId: 'p-7',
    mrn: '10427',
    first: 'Margaret',
    last: 'Okafor',
    complaint: 'Annual review',
  ),
  _appointment(
    id: ClinicalWorld.rescheduledAppointment,
    time: '13:00',
    status: 'rescheduled',
    patientId: 'p-1',
    mrn: '10421',
    first: 'Ifeoma',
    last: 'Balogun',
    complaint: 'Moved from last Thursday',
    type: 'follow_up',
  ),
];

Map<String, Object?> _appointment({
  required String id,
  required String time,
  required String status,
  required String patientId,
  required String mrn,
  required String first,
  required String last,
  required String complaint,
  String type = 'new_patient',
  String? checkedInAt,
  String? startedAt,
  String? completedAt,
  String? cancelledAt,
  String? cancellationReason,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'patientId': patientId,
      'doctorId': ClinicalWorld.doctorId,
      'appointmentDate': _today,
      'appointmentTime': time,
      'durationMinutes': 30,
      'appointmentType': type,
      'status': status,
      'chiefComplaint': complaint,
      'notes': '',
      'checkedInAt': checkedInAt,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'cancelledAt': cancelledAt,
      'cancellationReason': cancellationReason,
      'reminderSent': false,
      'patient': {
        'id': patientId,
        'mrn': mrn,
        'firstName': first,
        'lastName': last,
        'gender': first == 'Tom' || first == 'Yusuf' || first == 'Henrik'
            ? 'Male'
            : 'Female',
        'dateOfBirth': '1974-03-08T00:00:00.000Z',
      },
      'doctor': {
        'id': ClinicalWorld.doctorId,
        'fullName': ClinicalWorld.doctorName,
        'specialization': 'Emergency medicine',
      },
    };

// ── Consultations ───────────────────────────────────────────────────────────

void _consultations(FakeApi api) {
  final records = <String, Map<String, Object?>>{
    for (final row in _consultationRows) row['id']! as String: {...row},
  };

  api.on('GET', '/api/consultations/:id', (request) {
    final row = records[request.pathParams['id']];
    return row == null
        ? FakeResponse.fail(404, 'Consultation not found',
            errorCode: 'NOT_FOUND')
        : FakeResponse.ok(row);
  });

  api.on('POST', '/api/consultations', (request) {
    final body = request.body is Map ? request.jsonBody : const {};
    final items = body['prescriptionItems'];
    final created = <String, Object?>{
      ..._consultation(
        id: 'c-new',
        patientId: 'p-1',
        mrn: '10421',
        first: 'Ifeoma',
        last: 'Balogun',
        temperature: 0,
        systolic: 0,
        diastolic: 0,
        pulse: 0,
        respiratory: 0,
        saturation: 0,
      ),
      ...body.cast<String, Object?>(),
      'id': 'c-new',
      'prescriptions': [
        if (items is List && items.isNotEmpty)
          _prescription('rx-new', 'c-new', items),
      ],
    }
      // The server writes the script as its own `Prescription` row and does
      // **not** echo `prescriptionItems` back. Dropped here for the same
      // reason: a screen that read the key off the response would pass in the
      // suite and show an empty script on a ward.
      ..remove('prescriptionItems');
    records['c-new'] = created;
    return FakeResponse.ok(created);
  });

  FakeResponse update(FakeRequest request) {
    final id = request.pathParams['id'] ?? '';
    final row = records[id];
    if (row == null) {
      return FakeResponse.fail(404, 'Consultation not found',
          errorCode: 'NOT_FOUND');
    }
    final body = request.body is Map ? request.jsonBody : const {};
    final next = <String, Object?>{...row, ...body.cast<String, Object?>()};
    records[id] = next;
    return FakeResponse.ok(next);
  }

  api.on('PATCH', '/api/consultations/:id', update);
  api.on('PUT', '/api/consultations/:id', update);

  api.on('DELETE', '/api/consultations/:id', (request) {
    records.remove(request.pathParams['id']);
    return const FakeResponse(204, null);
  });
}

final List<Map<String, Object?>> _consultationRows = [
  _consultation(
    id: ClinicalWorld.normalConsultation,
    patientId: 'p-1',
    mrn: '10421',
    first: 'Ifeoma',
    last: 'Balogun',
    temperature: 37.0,
    systolic: 120,
    diastolic: 78,
    pulse: 76,
    respiratory: 16,
    saturation: 98,
    diagnosis: 'Tension-type headache',
    plan: 'Simple analgesia, review in two weeks if no better.',
    prescriptions: [
      _prescription('rx-1', ClinicalWorld.normalConsultation, [
        {
          'drugId': ClinicalWorld.amoxicillinId,
          'drugName': ClinicalWorld.amoxicillinName,
          'dosage': '500mg',
          'frequency': 'Three times daily',
          'duration': '7 days',
          'quantity': 21,
          'instructions': 'After meals',
        },
      ]),
    ],
  ),
  _consultation(
    id: ClinicalWorld.flaggedConsultation,
    patientId: 'p-2',
    mrn: '10422',
    first: 'Tom',
    last: 'Whitfield',
    // Four readings outside the adult range and one of them critical, so the
    // banner has something to say and says it in words.
    temperature: 39.8,
    systolic: 168,
    diastolic: 96,
    pulse: 128,
    respiratory: 24,
    saturation: 91,
    visitType: 'emergency',
    diagnosis: 'Community-acquired pneumonia',
    plan: 'Admit. IV co-amoxiclav, oxygen to keep saturations above 94%.',
    labOrders: [
      {
        'id': 'lo-1',
        'organizationId': 'o-1',
        'patientId': 'p-2',
        'consultationId': ClinicalWorld.flaggedConsultation,
        'orderNumber': 'LAB-40219',
        'orderDate': _today,
        'tests': [
          {'testId': 'lt-fbc', 'testName': 'Full blood count'},
          {'testId': 'lt-crp', 'testName': 'C-reactive protein'},
        ],
        'clinicalIndication': 'Community-acquired pneumonia',
        'priority': 'urgent',
        'status': 'in_progress',
        'results': <Object?>[],
      },
    ],
    radiologyOrders: [
      {
        'id': 'ro-1',
        'organizationId': 'o-1',
        'patientId': 'p-2',
        'consultationId': ClinicalWorld.flaggedConsultation,
        'examId': 'rx-chest',
        'orderNumber': 'RAD-90114',
        'orderDate': _today,
        'urgency': 'urgent',
        'status': 'completed',
        'clinicalIndication': 'Community-acquired pneumonia',
        'exam': {
          'id': 'rx-chest',
          'examName': 'Chest X-ray',
          'bodyPart': 'Chest',
          'modality': 'DR',
          'examCategory': 'x-ray',
        },
      },
    ],
  ),
  _consultation(
    id: ClinicalWorld.unrecordedConsultation,
    patientId: 'p-5',
    mrn: '10425',
    first: 'Henrik',
    last: 'Nilsen',
    // Every vital zero. Not a reading — an absence, which is how this backend
    // stores one. A zero temperature judged as hypothermia is the bug this row
    // exists to catch.
    temperature: 0,
    systolic: 0,
    diastolic: 0,
    pulse: 0,
    respiratory: 0,
    saturation: 0,
    weight: 0,
    height: 0,
    diagnosis: 'Sprained ankle',
    plan: 'Rest, ice, compression. No imaging indicated.',
  ),
];

Map<String, Object?> _consultation({
  required String id,
  required String patientId,
  required String mrn,
  required String first,
  required String last,
  required double temperature,
  required int systolic,
  required int diastolic,
  required int pulse,
  required int respiratory,
  required int saturation,
  double weight = 72.5,
  double height = 174,
  String visitType = 'outpatient',
  String complaint = 'See history',
  String? diagnosis,
  String? plan,
  List<Map<String, Object?>> prescriptions = const [],
  List<Map<String, Object?>> labOrders = const [],
  List<Map<String, Object?>> radiologyOrders = const [],
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'patientId': patientId,
      'doctorId': ClinicalWorld.doctorId,
      'visitDate': _today,
      'visitType': visitType,
      'temperature': temperature,
      'bloodPressureSystolic': systolic,
      'bloodPressureDiastolic': diastolic,
      'pulseRate': pulse,
      'respiratoryRate': respiratory,
      'oxygenSaturation': saturation,
      'weight': weight,
      'height': height,
      'chiefComplaint': complaint,
      'historyOfPresentIllness': 'Reported at the desk on arrival.',
      'physicalExamination': 'Examined. Findings recorded above.',
      'diagnosis': diagnosis,
      // Stored as JSON text, which is what the column holds and what a read
      // hands back — a fixture sending a real array would skip the parsing
      // every live read goes through.
      'icd10Codes': '["J18.9"]',
      'treatmentPlan': plan,
      'followUpInstructions': 'Return if it gets worse.',
      'followUpDate': _today,
      'referredTo': null,
      'referralReason': null,
      'notes': null,
      'createdAt': _today,
      'updatedAt': _today,
      'isDeleted': false,
      'patient': {
        'id': patientId,
        'mrn': mrn,
        'firstName': first,
        'lastName': last,
        'gender': first == 'Tom' || first == 'Henrik' ? 'Male' : 'Female',
        'dateOfBirth': '1974-03-08T00:00:00.000Z',
        'bloodGroup': 'O+',
      },
      'doctor': {
        'id': ClinicalWorld.doctorId,
        'fullName': ClinicalWorld.doctorName,
        'specialization': 'Emergency medicine',
      },
      'prescriptions': prescriptions,
      'labOrders': labOrders,
      'radiologyOrders': radiologyOrders,
    };

/// A script as the server stores it: the items are **JSON text**, not an array.
Map<String, Object?> _prescription(
  String id,
  String consultationId,
  List<Object?> items,
) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'consultationId': consultationId,
      'prescriptionNumber': 'RX-${id.toUpperCase()}',
      'prescriptionDate': _today,
      'status': 'pending',
      'items': items,
    };

// ── Lookups ─────────────────────────────────────────────────────────────────

void _lookups(FakeApi api) {
  // The same three clinicians `world.dart` serves, restated so this file is
  // coherent on its own. Identical content, so which one answers cannot matter.
  api.json('GET', '/api/users/staff', _doctors);

  // A prescriber's shelf: six drugs, sharing their ids and names with
  // `pharmacy_fixtures.dart`. The pharmacy's own fifteen-row shelf is what its
  // figures are counted from — install this file first so that one wins.
  api.on('GET', '/api/pharmacy/drugs', (request) {
    final search = (request.query['search'] ?? '').trim().toLowerCase();
    return FakeResponse.ok([
      for (final drug in _drugs)
        if (search.isEmpty ||
            '${drug['drugName']} ${drug['genericName']}'
                .toLowerCase()
                .contains(search))
          drug,
    ]);
  });
}

const List<Map<String, Object?>> _doctors = [
  {
    'id': ClinicalWorld.doctorId,
    'fullName': ClinicalWorld.doctorName,
    'specialization': 'Emergency medicine',
    'role': 'Consultant',
  },
  {
    'id': 'd-2',
    'fullName': 'Dr Priya Raman',
    'specialization': 'Acute medicine',
    'role': 'Registrar',
  },
  {
    'id': 'd-3',
    'fullName': 'Dr Samuel Achterberg',
    'specialization': 'Orthopaedics',
    'role': 'Consultant',
  },
];

const List<Map<String, Object?>> _drugs = [
  {
    'id': ClinicalWorld.amoxicillinId,
    'organizationId': 'o-1',
    'drugName': ClinicalWorld.amoxicillinName,
    'genericName': 'Amoxicillin trihydrate',
    'drugCategory': 'antibiotic',
    'dosageForm': 'capsule',
    'strength': '500mg',
    'quantityInStock': 120,
    'reorderLevel': 40,
    'sellingPrice': 6.5,
    'requiresPrescription': true,
    'isActive': true,
  },
  {
    'id': 'drug-para',
    'organizationId': 'o-1',
    'drugName': 'Paracetamol',
    'genericName': 'Acetaminophen',
    'drugCategory': 'analgesic',
    'dosageForm': 'tablet',
    'strength': '500mg',
    'quantityInStock': 240,
    'reorderLevel': 60,
    'sellingPrice': 2.5,
    'requiresPrescription': false,
    'isActive': true,
  },
  {
    'id': 'drug-ibu',
    'organizationId': 'o-1',
    'drugName': 'Ibuprofen',
    'genericName': 'Ibuprofen',
    'drugCategory': 'analgesic',
    'dosageForm': 'tablet',
    'strength': '400mg',
    'quantityInStock': 180,
    'reorderLevel': 50,
    'sellingPrice': 3.0,
    'requiresPrescription': false,
    'isActive': true,
  },
  {
    'id': 'drug-omep',
    'organizationId': 'o-1',
    'drugName': 'Omeprazole',
    'genericName': 'Omeprazole',
    'drugCategory': 'gastrointestinal',
    'dosageForm': 'capsule',
    'strength': '20mg',
    'quantityInStock': 210,
    'reorderLevel': 60,
    'sellingPrice': 2.8,
    'requiresPrescription': true,
    'isActive': true,
  },
  {
    'id': 'drug-salb',
    'organizationId': 'o-1',
    'drugName': 'Salbutamol',
    'genericName': 'Salbutamol sulfate',
    'drugCategory': 'respiratory',
    'dosageForm': 'inhaler',
    'strength': '100mcg',
    'quantityInStock': 34,
    'reorderLevel': 12,
    'sellingPrice': 11.0,
    'requiresPrescription': true,
    'isActive': true,
  },
  {
    'id': 'drug-metf',
    'organizationId': 'o-1',
    'drugName': 'Metformin',
    'genericName': 'Metformin hydrochloride',
    'drugCategory': 'antidiabetic',
    'dosageForm': 'tablet',
    'strength': '500mg',
    'quantityInStock': 96,
    'reorderLevel': 40,
    'sellingPrice': 1.6,
    'requiresPrescription': true,
    'isActive': true,
  },
];

// ── The clinic's day ────────────────────────────────────────────────────────

/// Re-writes this site's working hours on **both** routes that carry them.
///
/// The splash screen reads `/api/settings` and `/auth/me` in parallel and both
/// land on the same `SiteSettings`, so a flow that changed one of them would be
/// testing a race rather than a setting. Changing both is what makes "the slots
/// follow the site" an assertion instead of a coincidence.
///
/// Pass it as a harness override:
///
/// ```dart
/// AppHarness.bootSignedIn(
///   tester,
///   overrides: (api) => installClinicHours(api, start: '07:00', end: '09:00',
///       minutes: 20),
/// );
/// ```
void installClinicHours(
  FakeApi api, {
  required String start,
  required String end,
  required int minutes,
  WorldRole role = WorldRole.superAdmin,
}) {
  api.json('GET', '/api/settings', {
    ..._baseSettings,
    'working_hours_start': start,
    'working_hours_end': end,
    'appointment_duration': '$minutes',
  });

  // The same organisation, with only its diary moved. Rebuilt rather than
  // edited in place because the map is const: every other key has to stay
  // identical or the theme is rebuilt a second time, which is a visible flash.
  final organization = <String, Object?>{
    ..._organization,
    'settings': <String, Object?>{
      ...(_organization['settings']! as Map<String, Object?>),
      'scheduling': {
        'workingHours': {'start': start, 'end': end},
        'appointmentDuration': minutes,
      },
    },
  };

  api.json('GET', '/api/settings/organization', organization);
  api.json('GET', '/api/auth/me', {
    'user': {
      'id': role.id,
      'email': role.email,
      'fullName': role.displayName,
      'name': role.displayName,
      'phone': role.phone,
      'role': role.roleName,
      'roles': [role.roleName],
      'permissions': role.permissions,
      'departmentId': role.departmentId,
      'department': {'id': role.departmentId, 'name': role.department},
      'departmentName': role.department,
      'specialization': role.specialization,
      'licenseNumber': role.licenseNumber,
      'employeeId': role.employeeId,
      'avatar': '',
    },
    'access': role.accessBlock,
    'organization': organization,
  });
}

/// Signs [role] in with [modules] taken out of their access map.
///
/// There is no seeded account that can write a consultation and order neither a
/// test nor a scan, so the rule "the orders card is absent for an account that
/// can raise neither" has no role to prove it. This builds one.
///
/// Both `/auth/me` and `/auth/me/access` are rewritten, because
/// `AccessService.load` falls back to the second when the first is unavailable
/// and a fixture that changed one would be testing which path ran.
void installAccessWithout(
  FakeApi api, {
  required List<String> modules,
  WorldRole role = WorldRole.superAdmin,
}) {
  final trimmed = {
    for (final entry in role.accessModules.entries)
      if (!modules.contains(entry.key)) entry.key: entry.value,
  };
  final access = {'modules': trimmed};

  api.json('GET', '/api/auth/me/access', access);
  api.json('GET', '/api/auth/me', {
    'user': {
      'id': role.id,
      'email': role.email,
      'fullName': role.displayName,
      'name': role.displayName,
      'phone': role.phone,
      'role': role.roleName,
      'roles': [role.roleName],
      'permissions': role.permissions,
      'departmentId': role.departmentId,
      'department': {'id': role.departmentId, 'name': role.department},
      'departmentName': role.department,
      'specialization': role.specialization,
      'licenseNumber': role.licenseNumber,
      'employeeId': role.employeeId,
      'avatar': '',
    },
    'access': access,
    'organization': _organization,
  });
}

/// The organisation as `/auth/me` sends it, on this site's documented defaults.
const Map<String, Object?> _organization = {
  'id': WorldRole.organizationId,
  'name': 'St Aidan’s General',
  'slug': 'st-aidans-general',
  'logoUrl': '',
  'logoTextUrl': '',
  'primaryColor': '#0E7C7B',
  'secondaryColor': '#F2A65A',
  'settings': {
    'locale': {
      'currency': 'INR',
      'currencySymbol': '₹',
      'currencyPosition': 'before',
      'decimalSeparator': '.',
      'thousandSeparator': ',',
      'centPrecision': 2,
      'showZeroCents': false,
      'dateFormat': 'DD/MM/YYYY',
      'use24HourClock': true,
      'timezone': 'Asia/Kolkata',
      'language': 'en',
      'calendar': 'gregorian',
    },
    'appearance': {'themePreset': 'default', 'themeFont': 'montserrat'},
    'clinical': {
      'triageScale': 'p1-p5',
      'waitBreachMinutes': 30,
      'showPatientNames': true,
      'sessionLockMinutes': 5,
    },
    'scheduling': {
      'workingHours': {'start': '08:00', 'end': '17:00'},
      'appointmentDuration': 30,
    },
  },
};

/// The flat settings map, minus the three scheduling keys [installClinicHours]
/// replaces. Kept in step with `world_bootstrap.dart` by hand, which is the
/// cost of that file being another stream's.
const Map<String, String> _baseSettings = {
  'site_name': 'St Aidan’s General',
  'site_logo': '',
  'logo_text_url': '',
  'primary_color': '#0E7C7B',
  'secondary_color': '#F2A65A',
  'theme_preset': 'default',
  'theme_custom_colors': '',
  'theme_font': 'montserrat',
  'triage_scale': 'p1-p5',
  'wait_breach_minutes': '30',
  'show_patient_names': 'true',
  'session_lock_minutes': '5',
  'default_currency_code': 'INR',
  'currency_symbol': '₹',
  'currency_position': 'before',
  'decimal_sep': '.',
  'thousand_sep': ',',
  'cent_precision': '2',
  'zero_format': 'false',
  'date_format': 'DD/MM/YYYY',
  'use_24_hour_clock': 'true',
  'timezone': 'Asia/Kolkata',
  'language': 'en',
  'calendar': 'gregorian',
};

// ── Time ────────────────────────────────────────────────────────────────────
//
// Every timestamp comes off `AppClock`, which the harness freezes. Wall-clock
// time here would be in the *future* relative to a frozen clock, so every
// elapsed figure would render as zero and a screenshot of a busy clinic would
// look like a calm one.

String get _today {
  final now = AppClock.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day).toIso8601String();
}

String _minutesAgo(int minutes) =>
    AppClock.now().toUtc().subtract(Duration(minutes: minutes)).toIso8601String();

String _iso(DateTime value) => value.toUtc().toIso8601String();
