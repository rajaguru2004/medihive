import '../fakes/fake_api.dart';

/// A coherent department, in fixtures.
///
/// One world rather than a stub per test. The numbers agree with each other —
/// the dashboard's bed counts match the wards, the queue's length matches the
/// dashboard's waiting figure — so a screenshot is a picture of a department
/// that could exist, and a flow that walks from one screen to another sees the
/// same patients on both.
///
/// A flow that needs one endpoint different **overrides that one endpoint**
/// (`api.json(...)`) rather than writing a second world: later registrations
/// win.
abstract final class World {
  /// Registers every route the app calls.
  static void install(FakeApi api) {
    _auth(api);
    _settings(api);
    _dashboard(api);
    _queue(api);
    _appointments(api);
    _inpatient(api);
    _preTriage(api);
    _consultations(api);
    _lookups(api);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static const signedInUser = {
    'id': 'u-1',
    'name': 'Dr Amara Okonkwo',
    'email': 'a.okonkwo@example.org',
    'roleName': 'Consultant',
    'role': 'r-1',
    'department': 'Emergency',
    'permissions': <String>[],
  };

  static void _auth(FakeApi api) {
    api.json('POST', '/api/auth/login', {
      'accessToken': 'fake-token',
      'refreshToken': 'fake-refresh',
      'user': signedInUser,
    });
    api.json('POST', '/api/auth/logout', null);
    api.json('GET', '/api/auth/me', signedInUser);
    api.json('GET', '/api/auth/me/access', signedInUser);
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  static void _settings(FakeApi api) {
    api.json('GET', '/api/settings', [
      {'settingKey': 'site_name', 'settingValue': 'St Aidan’s General'},
      {'settingKey': 'theme_preset', 'settingValue': 'default'},
      {'settingKey': 'theme_font', 'settingValue': 'montserrat'},
      {'settingKey': 'wait_breach_minutes', 'settingValue': 30},
      {'settingKey': 'show_patient_names', 'settingValue': true},
      {'settingKey': 'triage_scale', 'settingValue': 'p1-p5'},
      {'settingKey': 'currency_symbol', 'settingValue': '₹'},
      {'settingKey': 'date_format', 'settingValue': 'DD/MM/YYYY'},
    ]);
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  static void _dashboard(FakeApi api) {
    api.json('GET', '/api/dashboard', {
      'stats': {
        'totalPatients': 1284,
        'todayAppointments': 18,
        'pendingLabOrders': 7,
        'pendingPrescriptions': 4,
        'todayRevenue': 184500,
        // Agrees with the ward fixtures below: 26 of 40 beds.
        'occupiedBeds': 26,
        'availableBeds': 11,
        'queueWaiting': 6,
        // One critical patient, so the attention card is in the screenshots.
        'criticalAlerts': 1,
      },
      'appointmentStatuses': {
        'completed': 7,
        'confirmed': 5,
        'scheduled': 4,
        'cancelled': 2,
      },
      'queueByService': [
        {'name': 'Emergency', 'count': 4},
        {'name': 'OPD', 'count': 6},
        {'name': 'Radiology', 'count': 2},
        {'name': 'Laboratory', 'count': 3},
      ],
      'recentPatients': [
        _patientRow('p-1', 'MRN-10421', 'Ifeoma', 'Balogun', 'Female', '1991-04-12'),
        _patientRow('p-2', 'MRN-10422', 'Tom', 'Whitfield', 'Male', '1958-11-02'),
        _patientRow('p-3', 'MRN-10423', 'Sana', 'Qureshi', 'Female', '2019-07-30'),
        _patientRow('p-4', 'MRN-10424', 'Grace', 'Mwangi', 'Female', '1976-01-19'),
        _patientRow('p-5', 'MRN-10425', 'Henrik', 'Nilsen', 'Male', '2002-09-08'),
        _patientRow('p-6', 'MRN-10426', 'Yusuf', 'Adeyemi', 'Male', '1984-03-25'),
      ],
      'upcomingAppointments': [
        {
          'id': 'a-1',
          'appointmentDate': _today,
          'appointmentTime': '14:30',
          'status': 'confirmed',
          'patient': {
            'id': 'p-1',
            'mrn': 'MRN-10421',
            'firstName': 'Ifeoma',
            'lastName': 'Balogun',
          },
        },
        {
          'id': 'a-2',
          'appointmentDate': _today,
          'appointmentTime': '15:00',
          'status': 'scheduled',
          'patient': {
            'id': 'p-2',
            'mrn': 'MRN-10422',
            'firstName': 'Tom',
            'lastName': 'Whitfield',
          },
        },
        {
          'id': 'a-3',
          'appointmentDate': _today,
          'appointmentTime': '15:45',
          'status': 'scheduled',
          'patient': {
            'id': 'p-4',
            'mrn': 'MRN-10424',
            'firstName': 'Grace',
            'lastName': 'Mwangi',
          },
        },
      ],
    });

    // The dashboard also asks for the organisation. Same route family, and
    // the app tolerates either shape.
    api.json('GET', '/api/organization', {
      'name': 'St Aidan’s General',
      'logoUrl': '',
    });
  }

  // ── Queue ─────────────────────────────────────────────────────────────────

  static void _queue(FakeApi api) {
    api.on('GET', '/api/queue', (request) {
      final statuses = (request.query['status'] ?? '').split(',');
      final live = statuses.contains('waiting');
      return FakeResponse.page(live ? _liveQueue : _queueHistory);
    });
    api.on('PATCH', '/api/queue/:id', (_) => FakeResponse.ok(null));
    api.on('POST', '/api/queue', (_) => FakeResponse.ok(null));
    api.on('DELETE', '/api/queue/:id', (_) => FakeResponse.ok(null));
  }

  /// Deliberately mixed acuity and mixed wait, so the board's sort and its
  /// breach flag are both visible in one screenshot.
  static final _liveQueue = [
    _queueRow('q-1', 1, 'P1', 'waiting', 'Emergency', 42, 'p-2', 'MRN-10422', 'Tom', 'Whitfield', 'Male'),
    _queueRow('q-2', 2, 'P3', 'waiting', 'Emergency', 18, 'p-6', 'MRN-10426', 'Yusuf', 'Adeyemi', 'Male'),
    _queueRow('q-3', 3, 'P4', 'waiting', 'OPD', 35, 'p-1', 'MRN-10421', 'Ifeoma', 'Balogun', 'Female'),
    _queueRow('q-4', 4, 'P5', 'waiting', 'OPD', 8, 'p-5', 'MRN-10425', 'Henrik', 'Nilsen', 'Male'),
    _queueRow('q-5', 5, 'P2', 'called', 'Emergency', 12, 'p-3', 'MRN-10423', 'Sana', 'Qureshi', 'Female'),
    _queueRow('q-6', 6, 'P4', 'in_service', 'Radiology', 24, 'p-4', 'MRN-10424', 'Grace', 'Mwangi', 'Female'),
  ];

  static final _queueHistory = [
    _queueRow('q-7', 7, 'P4', 'completed', 'OPD', 31, 'p-1', 'MRN-10421', 'Ifeoma', 'Balogun', 'Female'),
    _queueRow('q-8', 8, 'P5', 'no_show', 'OPD', 46, 'p-5', 'MRN-10425', 'Henrik', 'Nilsen', 'Male'),
  ];

  // ── Appointments ──────────────────────────────────────────────────────────

  static void _appointments(FakeApi api) {
    api.page('GET', '/api/appointments', _appointmentRows);
    api.on('PATCH', '/api/appointments/:id', (_) => FakeResponse.ok(null));
  }

  static final _appointmentRows = [
    _appointmentRow('a-1', '09:15', 'completed', 'p-1', 'MRN-10421', 'Ifeoma', 'Balogun', 'Routine review'),
    _appointmentRow('a-2', '10:00', 'completed', 'p-6', 'MRN-10426', 'Yusuf', 'Adeyemi', 'Post-op check'),
    _appointmentRow('a-3', '11:30', 'checked_in', 'p-4', 'MRN-10424', 'Grace', 'Mwangi', 'Persistent cough'),
    _appointmentRow('a-4', '14:30', 'confirmed', 'p-2', 'MRN-10422', 'Tom', 'Whitfield', 'Chest pain follow-up'),
    _appointmentRow('a-5', '15:00', 'scheduled', 'p-3', 'MRN-10423', 'Sana', 'Qureshi', 'Six-year check'),
    _appointmentRow('a-6', '15:45', 'cancelled', 'p-5', 'MRN-10425', 'Henrik', 'Nilsen', 'Knee assessment'),
  ];

  // ── Inpatient ─────────────────────────────────────────────────────────────

  static void _inpatient(FakeApi api) {
    api.json('GET', '/api/inpatient/stats', {
      'totalBeds': 40,
      'occupiedBeds': 26,
      'availableBeds': 11,
      'todayAdmissions': 3,
      'todayDischarges': 2,
      'occupancyRate': 0.65,
    });
    api.json('GET', '/api/inpatient/wards', _wards);
    api.page('GET', '/api/inpatient/admissions', _admissions);
    api.on('GET', '/api/inpatient/beds', (request) {
      final wardId = request.query['wardId'] ?? 'w-1';
      return FakeResponse.page(
        _beds.where((b) => b['wardId'] == wardId).toList(),
      );
    });
    api.on('PATCH', '/api/inpatient/beds/:id', (_) => FakeResponse.ok(null));
    api.on('PATCH', '/api/inpatient/wards/:id', (_) => FakeResponse.ok(null));
    api.on('POST', '/api/inpatient/wards', (_) => FakeResponse.ok(null));
    api.on('POST', '/api/inpatient/beds', (_) => FakeResponse.ok(null));
    api.on('POST', '/api/inpatient/admissions', (_) => FakeResponse.ok(null));
    api.on(
      'PATCH',
      '/api/inpatient/admissions/:id',
      (_) => FakeResponse.ok(null),
    );
  }

  static final _wards = [
    {
      'id': 'w-1',
      'organizationId': 'o-1',
      'name': 'Acute Medical',
      'code': 'AMU',
      'type': 'general',
      'capacity': 18,
      'isActive': true,
      'occupiedBeds': 14,
      'availableBeds': 3,
      'occupancyRate': 0.78,
      'beds': <Object?>[],
    },
    {
      'id': 'w-2',
      'organizationId': 'o-1',
      'name': 'Intensive Care',
      'code': 'ICU',
      'type': 'icu',
      'capacity': 8,
      'isActive': true,
      // Full, so the red capacity treatment appears in the screenshots.
      'occupiedBeds': 8,
      'availableBeds': 0,
      'occupancyRate': 1.0,
      'beds': <Object?>[],
    },
    {
      'id': 'w-3',
      'organizationId': 'o-1',
      'name': 'Maternity',
      'code': 'MAT',
      'type': 'maternity',
      'capacity': 14,
      'isActive': true,
      'occupiedBeds': 4,
      'availableBeds': 8,
      'occupancyRate': 0.29,
      'beds': <Object?>[],
    },
  ];

  /// One bay of Acute Medical, with all four bed states present so the map
  /// and its legend are both meaningful.
  static final _beds = [
    _bed('b-1', 'w-1', '01', 'occupied'),
    _bed('b-2', 'w-1', '02', 'occupied'),
    _bed('b-3', 'w-1', '03', 'available'),
    _bed('b-4', 'w-1', '04', 'occupied'),
    _bed('b-5', 'w-1', '05', 'reserved'),
    _bed('b-6', 'w-1', '06', 'available'),
    _bed('b-7', 'w-1', '07', 'maintenance'),
    _bed('b-8', 'w-1', '08', 'occupied'),
    _bed('b-9', 'w-1', '09', 'occupied'),
    _bed('b-10', 'w-1', '10', 'available'),
    _bed('b-11', 'w-1', '11', 'occupied'),
    _bed('b-12', 'w-1', '12', 'occupied'),
  ];

  static final _admissions = [
    _admission('adm-1', 'b-1', '01', 'active', -9, 'p-2', 'MRN-10422', 'Tom', 'Whitfield', 'Male', 'Chest pain, rule out ACS'),
    _admission('adm-2', 'b-2', '02', 'active', -3, 'p-4', 'MRN-10424', 'Grace', 'Mwangi', 'Female', 'Community-acquired pneumonia'),
    _admission('adm-3', 'b-4', '04', 'active', -1, 'p-6', 'MRN-10426', 'Yusuf', 'Adeyemi', 'Male', 'Post-operative observation'),
    _admission('adm-4', 'b-8', '08', 'active', 0, 'p-1', 'MRN-10421', 'Ifeoma', 'Balogun', 'Female', 'Dehydration, IV fluids'),
    _admission('adm-5', 'b-3', '03', 'discharged', -14, 'p-5', 'MRN-10425', 'Henrik', 'Nilsen', 'Male', 'Elective knee repair'),
  ];

  // ── Pre-triage ────────────────────────────────────────────────────────────

  static void _preTriage(FakeApi api) {
    api.page('GET', '/api/pre-triage', _screenings);
    api.on('GET', '/api/pre-triage/:id', (request) {
      final id = request.pathParams['id'];
      return FakeResponse.ok(
        _screenings.firstWhere(
          (s) => s['id'] == id,
          orElse: () => _screenings.first,
        ),
      );
    });
    api.on('POST', '/api/pre-triage', (_) => FakeResponse.ok(null));
    api.on('PATCH', '/api/pre-triage/:id', (_) => FakeResponse.ok(null));
    api.on('DELETE', '/api/pre-triage/:id', (_) => FakeResponse.ok(null));
    api.on(
      'POST',
      '/api/pre-triage/:id/convert',
      (_) => FakeResponse.ok(null),
    );
  }

  /// One screening with a genuinely alarming set of observations, so the
  /// out-of-range treatment is in the contact sheet.
  static final _screenings = [
    {
      'id': 's-1',
      'screeningNumber': 'SCR-2041',
      'firstName': 'Tom',
      'lastName': 'Whitfield',
      'age': 67,
      'gender': 'Male',
      'phone': '+44 7700 900142',
      'chiefComplaint': 'Central chest pain radiating to the left arm, '
          'onset 40 minutes ago',
      'briefHistory': 'Hypertensive, on ramipril. Ex-smoker. No prior cardiac '
          'events.',
      'temperature': 37.1,
      'pulseRate': 128,
      'bloodPressureSystolic': 168,
      'bloodPressureDiastolic': 96,
      'routedTo': 'Emergency',
      'status': 'screening',
      'screenedAt': _minutesAgo(40),
    },
    {
      'id': 's-2',
      'screeningNumber': 'SCR-2042',
      'firstName': 'Sana',
      'lastName': 'Qureshi',
      'age': 6,
      'gender': 'Female',
      'chiefComplaint': 'Fever and sore throat for two days',
      'temperature': 38.4,
      'pulseRate': 104,
      'bloodPressureSystolic': 98,
      'bloodPressureDiastolic': 62,
      'status': 'screening',
      'screenedAt': _minutesAgo(18),
    },
    {
      'id': 's-3',
      'screeningNumber': 'SCR-2043',
      'firstName': 'Henrik',
      'lastName': 'Nilsen',
      'age': 23,
      'gender': 'Male',
      'chiefComplaint': 'Twisted right ankle playing football',
      'temperature': 36.6,
      'pulseRate': 72,
      'bloodPressureSystolic': 118,
      'bloodPressureDiastolic': 74,
      'routedTo': 'Radiology',
      'status': 'routed',
      'screenedAt': _minutesAgo(95),
    },
    {
      'id': 's-4',
      'screeningNumber': 'SCR-2044',
      'firstName': 'Grace',
      'lastName': 'Mwangi',
      'age': 49,
      'gender': 'Female',
      'chiefComplaint': 'Persistent cough, three weeks',
      'temperature': 37.4,
      'pulseRate': 88,
      'bloodPressureSystolic': 126,
      'bloodPressureDiastolic': 80,
      'status': 'registered_as_patient',
      'patient': {'mrn': 'MRN-10424'},
      'screenedAt': _minutesAgo(260),
    },
  ];

  // ── Consultations ─────────────────────────────────────────────────────────

  static void _consultations(FakeApi api) {
    api.page('GET', '/api/consultations', _consultationRows);
    api.on('DELETE', '/api/consultations/:id', (_) => FakeResponse.ok(null));
  }

  static final _consultationRows = [
    _consultation('c-1', 'outpatient', 'p-1', 'MRN-10421', 'Ifeoma', 'Balogun', 'Female',
        'Viral upper respiratory infection', 'Rest, fluids, paracetamol as needed.'),
    _consultation('c-2', 'emergency', 'p-2', 'MRN-10422', 'Tom', 'Whitfield', 'Male',
        'Unstable angina', 'Admitted to AMU. Aspirin loaded, troponin sent.'),
    _consultation('c-3', 'followup', 'p-6', 'MRN-10426', 'Yusuf', 'Adeyemi', 'Male',
        'Healing well post-appendicectomy', 'Wound check in one week.'),
  ];

  // ── Lookups ───────────────────────────────────────────────────────────────

  static void _lookups(FakeApi api) {
    api.page('GET', '/api/patients', _patients);
    api.json('GET', '/api/users', _doctors);
    api.page('GET', '/api/queue/waiting', _liveQueue);
  }

  static final _patients = [
    _patientRow('p-1', 'MRN-10421', 'Ifeoma', 'Balogun', 'Female', '1991-04-12'),
    _patientRow('p-2', 'MRN-10422', 'Tom', 'Whitfield', 'Male', '1958-11-02'),
    _patientRow('p-3', 'MRN-10423', 'Sana', 'Qureshi', 'Female', '2019-07-30'),
    _patientRow('p-4', 'MRN-10424', 'Grace', 'Mwangi', 'Female', '1976-01-19'),
    _patientRow('p-5', 'MRN-10425', 'Henrik', 'Nilsen', 'Male', '2002-09-08'),
    _patientRow('p-6', 'MRN-10426', 'Yusuf', 'Adeyemi', 'Male', '1984-03-25'),
  ];

  static const _doctors = [
    {
      'id': 'd-1',
      'fullName': 'Dr Amara Okonkwo',
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

  // ── Builders ──────────────────────────────────────────────────────────────

  static String get _today => _dayOffset(0);

  static String _dayOffset(int days) {
    final now = DateTime.now().toUtc().add(Duration(days: days));
    return DateTime.utc(now.year, now.month, now.day).toIso8601String();
  }

  static String _minutesAgo(int minutes) => DateTime.now()
      .toUtc()
      .subtract(Duration(minutes: minutes))
      .toIso8601String();

  static Map<String, Object?> _patientRow(
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
        'createdAt': _minutesAgo(60),
      };

  static Map<String, Object?> _queueRow(
    String id,
    int number,
    String priority,
    String status,
    String area,
    int waitedMinutes,
    String patientId,
    String mrn,
    String first,
    String last,
    String gender,
  ) =>
      {
        'id': id,
        'organizationId': 'o-1',
        'patientId': patientId,
        'serviceArea': area,
        'serviceType': null,
        'queueNumber': '$number',
        'priority': priority,
        'assignedRoom': null,
        'status': status,
        'joinedQueueAt': _minutesAgo(waitedMinutes),
        'waitTime': waitedMinutes,
        'patient': {
          'id': patientId,
          'mrn': mrn,
          'firstName': first,
          'lastName': last,
          'gender': gender,
        },
      };

  static Map<String, Object?> _appointmentRow(
    String id,
    String time,
    String status,
    String patientId,
    String mrn,
    String first,
    String last,
    String complaint,
  ) =>
      {
        'id': id,
        'organizationId': 'o-1',
        'patientId': patientId,
        'doctorId': 'd-1',
        'appointmentDate': _today,
        'appointmentTime': time,
        'durationMinutes': 15,
        'appointmentType': 'follow_up',
        'status': status,
        'chiefComplaint': complaint,
        'notes': '',
        'reminderSent': false,
        'patient': {
          'id': patientId,
          'mrn': mrn,
          'firstName': first,
          'lastName': last,
        },
        'doctor': {
          'id': 'd-1',
          'fullName': 'Dr Amara Okonkwo',
          'specialization': 'Emergency medicine',
        },
      };

  static Map<String, Object?> _bed(
    String id,
    String wardId,
    String number,
    String status,
  ) =>
      {
        'id': id,
        'organizationId': 'o-1',
        'wardId': wardId,
        'bedNumber': number,
        'type': 'standard',
        'status': status,
        'ward': {'id': wardId, 'name': 'Acute Medical', 'code': 'AMU'},
      };

  static Map<String, Object?> _admission(
    String id,
    String bedId,
    String bedNumber,
    String status,
    int dayOffset,
    String patientId,
    String mrn,
    String first,
    String last,
    String gender,
    String reason,
  ) =>
      {
        'id': id,
        'organizationId': 'o-1',
        'patientId': patientId,
        'bedId': bedId,
        'admissionDate': _dayOffset(dayOffset),
        'admissionType': 'routine',
        'admissionReason': reason,
        'status': status,
        'dischargeDate': status == 'discharged' ? _dayOffset(-1) : null,
        'patient': {
          'id': patientId,
          'mrn': mrn,
          'firstName': first,
          'lastName': last,
          'gender': gender,
        },
        'bed': {
          'id': bedId,
          'organizationId': 'o-1',
          'wardId': 'w-1',
          'bedNumber': bedNumber,
          'type': 'standard',
          'status': 'occupied',
          'ward': {'id': 'w-1', 'name': 'Acute Medical', 'code': 'AMU'},
        },
      };

  static Map<String, Object?> _consultation(
    String id,
    String visitType,
    String patientId,
    String mrn,
    String first,
    String last,
    String gender,
    String diagnosis,
    String plan,
  ) =>
      {
        'id': id,
        'organizationId': 'o-1',
        'patientId': patientId,
        'doctorId': 'd-1',
        'visitDate': _dayOffset(0),
        'visitType': visitType,
        'temperature': 37.2,
        'bloodPressureSystolic': 124,
        'bloodPressureDiastolic': 78,
        'pulseRate': 76,
        'respiratoryRate': 16,
        'oxygenSaturation': 98,
        'weight': 72.5,
        'chiefComplaint': 'See history',
        'diagnosis': diagnosis,
        'treatmentPlan': plan,
        'createdAt': _dayOffset(0),
        'updatedAt': _dayOffset(0),
        'isDeleted': false,
        'patient': {
          'id': patientId,
          'mrn': mrn,
          'firstName': first,
          'lastName': last,
          'gender': gender,
          'dateOfBirth': '1980-01-01T00:00:00.000Z',
        },
        'doctor': {
          'id': 'd-1',
          'fullName': 'Dr Amara Okonkwo',
          'specialization': 'Emergency medicine',
        },
      };
}
