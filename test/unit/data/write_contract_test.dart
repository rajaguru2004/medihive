import 'package:flutter_test/flutter_test.dart';
// The answer tokens a tapped tile carries live beside the model they describe,
// not in the draft — a token and the words on the tile have to travel together
// or a call site can pair the label of one answer with the value of another.
import 'package:medihive/app/data/models/case_session.dart';
import 'package:medihive/app/data/models/drafts/drafts.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — The write contract
///
/// The API runs `whitelist + forbidNonWhitelisted`. A key that is not on the
/// DTO is not ignored: the whole request is a 400, and a 400 on an admission
/// is a patient who does not get admitted while somebody reads a stack trace.
///
/// So every allowed-key list below is **copied from the backend DTO**, with
/// the file path above it so the next person can re-check it against a server
/// that has moved on. This is the point of the whole drafts layer: it turns a
/// field that drifted from a 400 on a ward into a red test on a laptop.
///
/// Each draft is checked twice:
///
///  * **nothing extra** — the body sends no key the DTO would reject. This is
///    the one that catches drift.
///  * **nothing missing** — the body sends exactly what the draft claims to,
///    so a field quietly dropped from a `_shared()` map fails here rather
///    than going unnoticed until a form stops saving one box.
///
/// Where a draft deliberately declines a key the DTO would accept — a
/// `reportedById` the server should be stamping from the bearer token — the
/// expectation says so as `allowed.difference({...})`, which keeps the reason
/// next to the omission.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  /// Asserts a body against its DTO and against its own promise.
  void expectBody(
    Map<String, dynamic> body, {
    required Set<String> allowed,
    required Set<String> expected,
  }) {
    final keys = body.keys.toSet();
    expect(
      keys.difference(allowed),
      isEmpty,
      reason: 'sends a key the DTO does not whitelist — this is a 400',
    );
    expect(keys, expected, reason: 'sends a different set than it claims to');
  }

  // ── Patients ──────────────────────────────────────────────────────────────

  group('PatientDraft', () {
    // hms_v2/src/modules/patients/dto/create-patient.dto.ts
    const create = {
      'firstName',
      'middleName',
      'lastName',
      'dateOfBirth',
      'gender',
      'bloodGroup',
      'phonePrimary',
      'phoneSecondary',
      'email',
      'region',
      'zone',
      'woreda',
      'kebele',
      'houseNumber',
      'addressDescription',
      'emergencyContactName',
      'emergencyContactPhone',
      'emergencyContactRelationship',
      'allergies',
      'chronicConditions',
      'currentMedications',
      'hasInsurance',
      'insuranceProvider',
      'insuranceId',
      'insuranceExpiryDate',
      'photoUrl',
      'maritalStatus',
      'occupation',
      'educationLevel',
      'isVip',
      'notes',
      'externalId',
    };

    // hms_v2/src/modules/patients/dto/update-patient.dto.ts
    // `UpdatePatientDto extends PartialType(CreatePatientDto)` + isActive.
    const update = {...create, 'isActive'};

    final full = PatientDraft(
      firstName: 'Abebe',
      middleName: 'Kebede',
      lastName: 'Assefa',
      dateOfBirth: DateTime(1990, 5, 15),
      gender: 'male',
      bloodGroup: 'A+',
      phonePrimary: '+251911123456',
      phoneSecondary: '+251911654321',
      email: 'patient@example.com',
      region: 'Addis Ababa',
      zone: 'Bole',
      woreda: 'Woreda 03',
      kebele: 'Kebele 10',
      houseNumber: '1024',
      addressDescription: 'Near Bole Medhanialem',
      emergencyContactName: 'Aster Kebede',
      emergencyContactPhone: '+251911987654',
      emergencyContactRelationship: 'Spouse',
      allergies: const ['Penicillin'],
      chronicConditions: const ['Hypertension'],
      currentMedications: const ['Lisinopril 10mg'],
      hasInsurance: true,
      insuranceProvider: 'CBHI',
      insuranceId: 'POL-998877',
      insuranceExpiryDate: DateTime(2026, 12, 31),
      photoUrl: 'https://example.com/photo.jpg',
      maritalStatus: 'married',
      occupation: 'Teacher',
      educationLevel: 'Degree',
      isVip: false,
      notes: 'Requires wheelchair assistance.',
      externalId: 'EXT-12345',
      isActive: true,
    );

    test('create sends the registration DTO and nothing else', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update adds isActive and nothing else', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });

    test('a date of birth goes as a day, not an instant', () {
      // An ISO instant is read in the server's zone: 1990-05-15 in a UTC+
      // zone comes back as the 14th, and an age is then a day out for life.
      expect(full.toCreateJson()['dateOfBirth'], '1990-05-15');
    });

    test('an untouched draft sends nothing at all', () {
      expect(const PatientDraft().toCreateJson(), isEmpty);
      expect(const PatientDraft().toUpdateJson(), isEmpty);
    });

    test('one field set emits only that field', () {
      expect(const PatientDraft(firstName: 'Abebe').toCreateJson(), {
        'firstName': 'Abebe',
      });
    });

    test('blank strings are dropped, not sent as empties', () {
      // A blank on a PATCH would overwrite a stored value with nothing —
      // which is how a patient with a phone number loses it on a round trip.
      final blanked = full.copyWith(notes: '   ', occupation: '');
      final body = blanked.toUpdateJson();
      expect(body.containsKey('notes'), isFalse);
      expect(body.containsKey('occupation'), isFalse);
    });

    test('strings are trimmed', () {
      expect(
        const PatientDraft(firstName: '  Abebe  ').toCreateJson()['firstName'],
        'Abebe',
      );
    });

    test('false is a value, never an absence', () {
      // `hasInsurance: false` is a clinical statement about a patient, and a
      // draft that drops it quotes them the insured price.
      final body = const PatientDraft(hasInsurance: false).toCreateJson();
      expect(body, {'hasInsurance': false});
    });
  });

  // ── Appointments ──────────────────────────────────────────────────────────

  group('AppointmentDraft', () {
    // hms_v2/src/modules/appointments/dto/create-appointment.dto.ts
    const create = {
      'patientId',
      'doctorId',
      'appointmentDate',
      'appointmentTime',
      'durationMinutes',
      'appointmentType',
      'chiefComplaint',
      'notes',
      'departmentId',
    };

    // hms_v2/src/modules/appointments/dto/update-appointment.dto.ts
    const update = {
      'doctorId',
      'appointmentDate',
      'appointmentTime',
      'durationMinutes',
      'appointmentType',
      'chiefComplaint',
      'notes',
      'departmentId',
      'status',
      'cancellationReason',
      'consultationNotes',
      'reminderSent',
    };

    final full = AppointmentDraft(
      patientId: 'pat-1',
      doctorId: 'doc-1',
      appointmentDate: DateTime(2026, 6, 10),
      appointmentTime: '09:30',
      durationMinutes: 30,
      appointmentType: 'follow_up',
      chiefComplaint: 'Routine checkup',
      notes: 'Bring blood work',
      departmentId: 'dept-1',
      status: 'checked_in',
      cancellationReason: 'Patient unwell',
      consultationNotes: 'Seen',
      reminderSent: true,
    );

    test('create sends the booking keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update never sends patientId', () {
      // It is not on `UpdateAppointmentDto`, so an appointment cannot be
      // moved to another patient — and sending it is a 400, not a no-op.
      final body = full.toUpdateJson();
      expectBody(body, allowed: update, expected: update);
      expect(body.containsKey('patientId'), isFalse);
    });
  });

  // ── Consultations ─────────────────────────────────────────────────────────

  group('ConsultationDraft', () {
    // hms_v2/src/modules/consultations/dto/create-consultation.dto.ts
    const create = {
      'patientId',
      'doctorId',
      'appointmentId',
      'visitType',
      'temperature',
      'bloodPressureSystolic',
      'bloodPressureDiastolic',
      'pulseRate',
      'respiratoryRate',
      'weight',
      'height',
      'oxygenSaturation',
      'chiefComplaint',
      'historyOfPresentIllness',
      'physicalExamination',
      'diagnosis',
      'icd10Codes',
      'treatmentPlan',
      'followUpInstructions',
      'followUpDate',
      'referredTo',
      'referralReason',
      'notes',
      'prescriptionItems',
    };

    // hms_v2/src/modules/consultations/dto/update-consultation.dto.ts —
    // a separate class, not a PartialType: it declares no `patientId`,
    // `doctorId`, `appointmentId` or `prescriptionItems`.
    const update = {
      'visitType',
      'temperature',
      'bloodPressureSystolic',
      'bloodPressureDiastolic',
      'pulseRate',
      'respiratoryRate',
      'weight',
      'height',
      'oxygenSaturation',
      'chiefComplaint',
      'historyOfPresentIllness',
      'physicalExamination',
      'diagnosis',
      'icd10Codes',
      'treatmentPlan',
      'followUpInstructions',
      'followUpDate',
      'referredTo',
      'referralReason',
      'notes',
    };

    // hms_v2/src/modules/consultations/dto/create-consultation.dto.ts,
    // `CreatePrescriptionItemDto`.
    const itemKeys = {
      'drugId',
      'drugName',
      'genericName',
      'dosage',
      'frequency',
      'duration',
      'quantity',
      'instructions',
    };

    final full = ConsultationDraft(
      patientId: 'pat-1',
      doctorId: 'doc-1',
      appointmentId: 'apt-1',
      visitType: 'outpatient',
      temperature: 36.8,
      bloodPressureSystolic: 120,
      bloodPressureDiastolic: 80,
      pulseRate: 72,
      respiratoryRate: 16,
      weight: 70.5,
      height: 175,
      oxygenSaturation: 98,
      chiefComplaint: 'Cough',
      historyOfPresentIllness: 'Three days',
      physicalExamination: 'Chest clear',
      diagnosis: 'Acute bronchitis',
      icd10Codes: const ['J20.9'],
      treatmentPlan: 'Rest and fluids',
      followUpInstructions: 'Return if fever persists',
      followUpDate: DateTime(2026, 6, 17),
      referredTo: 'Pulmonologist',
      referralReason: 'Lung function test',
      notes: 'Advised to stop smoking',
      prescriptionItems: const [
        ConsultationPrescriptionItemDraft(
          drugId: 'drug-1',
          drugName: 'Amoxicillin 500mg',
          genericName: 'Amoxicillin',
          dosage: '500mg',
          frequency: 'Three times daily',
          duration: '7 days',
          quantity: 21,
          instructions: 'After meals',
        ),
      ],
    );

    test('create carries the script in the same request', () {
      final body = full.toCreateJson();
      expectBody(body, allowed: create, expected: create);
      final items = body['prescriptionItems'] as List<dynamic>;
      expect((items.single as Map).keys.toSet(), itemKeys);
    });

    test('update drops the four keys its DTO does not declare', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });

    test('an empty prescription list is dropped rather than sent', () {
      // `prescriptionItems: []` passes validation and stores a consultation
      // with no script, which reads as a doctor who prescribed nothing.
      final body = full.copyWith().toCreateJson();
      expect(body.containsKey('prescriptionItems'), isTrue);
      final bare = const ConsultationDraft(
        patientId: 'pat-1',
        prescriptionItems: [],
      ).toCreateJson();
      expect(bare, {'patientId': 'pat-1'});
    });

    test('an unrecorded vital is absent, never zero', () {
      // This backend stores an unobserved numeric vital as 0, and a
      // temperature of 0 renders as hypothermia.
      final body = const ConsultationDraft(pulseRate: 72).toUpdateJson();
      expect(body, {'pulseRate': 72});
    });
  });

  // ── Laboratory ────────────────────────────────────────────────────────────

  group('LabOrderDraft', () {
    // hms_v2/src/modules/laboratory/dto/lab-order.dto.ts, CreateLabOrderDto
    const create = {
      'patientId',
      'consultationId',
      'tests',
      'clinicalIndication',
      'provisionalDiagnosis',
      'priority',
      'notes',
    };

    // hms_v2/src/modules/laboratory/dto/lab-order.dto.ts, UpdateLabOrderDto
    const update = {
      'status',
      'priority',
      'sampleCollectedAt',
      'sampleCollectedById',
      'accessionNumber',
      'notes',
      'rejectionReason',
    };

    // hms_v2/src/modules/laboratory/dto/lab-order.dto.ts, OrderTestItemDto —
    // three keys, and no `testCode` despite the schema comment naming one.
    const itemKeys = {'testId', 'testName', 'urgency'};

    final full = LabOrderDraft(
      patientId: 'pat-1',
      consultationId: 'con-1',
      tests: const [
        LabOrderTestDraft(testId: 'test-1', testName: 'CBC', urgency: 'stat'),
      ],
      clinicalIndication: 'Sepsis query',
      provisionalDiagnosis: 'Pneumonia',
      priority: 'stat',
      notes: 'Call the ward',
      status: 'sample_collected',
      sampleCollectedAt: DateTime.utc(2026, 6, 10, 8, 30),
      sampleCollectedById: 'user-1',
      accessionNumber: 'ACC-1',
      rejectionReason: 'Haemolysed',
    );

    test('create sends the request keys', () {
      final body = full.toCreateJson();
      expectBody(body, allowed: create, expected: create);
      final tests = body['tests'] as List<dynamic>;
      expect((tests.single as Map).keys.toSet(), itemKeys);
    });

    test('update sends the bench keys', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });

    test('a collection time goes as a UTC instant', () {
      // A local ISO string with no offset is read in the server's zone, and a
      // sample taken at 00:30 in Addis lands on the previous day.
      expect(
        full.toUpdateJson()['sampleCollectedAt'],
        '2026-06-10T08:30:00.000Z',
      );
    });

    test('an order with no tests on it never leaves the device', () {
      final bare = const LabOrderDraft(patientId: 'pat-1', tests: [])
          .toCreateJson();
      expect(bare, {'patientId': 'pat-1'});
    });
  });

  group('LabResultDraft', () {
    // hms_v2/src/modules/laboratory/dto/lab-result.dto.ts
    const create = {
      'orderId',
      'testId',
      'resultValue',
      'resultUnit',
      'isAbnormal',
      'isCritical',
      'flag',
      'comment',
    };
    const update = {
      'resultValue',
      'resultUnit',
      'isAbnormal',
      'isCritical',
      'flag',
      'comment',
      'verifiedAt',
      'verifiedById',
    };

    final full = LabResultDraft(
      orderId: 'ord-1',
      testId: 'test-1',
      resultValue: '7.2',
      resultUnit: 'mmol/L',
      isAbnormal: true,
      isCritical: true,
      flag: 'H',
      comment: 'Repeat requested',
      verifiedAt: DateTime.utc(2026, 6, 10, 9),
      verifiedById: 'user-2',
    );

    test('create sends the entry keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update sends the verification keys', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });

    test('a normal result still says so', () {
      // `isCritical: false` is an assertion, not a missing field. Dropping it
      // leaves the previous value standing on a PATCH.
      expect(
        const LabResultDraft(isCritical: false).toUpdateJson(),
        {'isCritical': false},
      );
    });
  });

  group('LabTestDraft', () {
    // hms_v2/src/modules/laboratory/dto/lab-test.dto.ts
    const create = {
      'testName',
      'testCode',
      'testCategory',
      'testType',
      'specimenType',
      'specimenVolume',
      'specimenContainer',
      'resultType',
      'unit',
      'referenceRanges',
      'price',
      'turnaroundTime',
      'department',
      'preparationInstructions',
      'clinicalSignificance',
    };
    const update = {...create, 'isActive'};

    const full = LabTestDraft(
      testName: 'Potassium',
      testCode: 'K',
      testCategory: 'chemistry',
      testType: 'quantitative',
      specimenType: 'blood',
      specimenVolume: '2ml',
      specimenContainer: 'Lithium heparin',
      resultType: 'numeric',
      unit: 'mmol/L',
      referenceRanges: '{"male":{"min":3.5,"max":5.1}}',
      price: 120,
      turnaroundTime: 4,
      department: 'laboratory',
      preparationInstructions: 'None',
      clinicalSignificance: 'Cardiac risk',
      isActive: true,
    );

    test('create sends the catalogue keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update adds isActive', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });

    test('reference ranges go as the string the DTO types them', () {
      // `@IsString()` on a column that holds JSON. Re-encoding a parsed
      // object here would change the shape a site has been storing.
      expect(
        full.toCreateJson()['referenceRanges'],
        '{"male":{"min":3.5,"max":5.1}}',
      );
    });
  });

  // ── Radiology ─────────────────────────────────────────────────────────────

  group('RadiologyExamDraft', () {
    // hms_v2/src/modules/radiology/dto/radiology-exam.dto.ts
    const create = {
      'examName',
      'examCode',
      'examCategory',
      'bodyPart',
      'modality',
      'price',
      'estimatedDuration',
      'preparationInstructions',
      'contrastRequired',
      'description',
    };
    // `UpdateRadiologyExamDto extends PartialType(Create)` + isActive.
    const update = {...create, 'isActive'};

    const full = RadiologyExamDraft(
      examName: 'CT Head',
      examCode: 'CTH',
      examCategory: 'ct',
      bodyPart: 'Head',
      modality: 'CT',
      price: 2400,
      estimatedDuration: 20,
      preparationInstructions: 'Remove metal',
      contrastRequired: true,
      description: 'Non-contrast unless requested',
      isActive: true,
    );

    test('create sends the catalogue keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update adds isActive', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });
  });

  group('RadiologyOrderDraft', () {
    // hms_v2/src/modules/radiology/dto/radiology-order.dto.ts
    const create = {
      'patientId',
      'consultationId',
      'examId',
      'clinicalIndication',
      'provisionalDiagnosis',
      'relevantHistory',
      'urgency',
      'notes',
    };
    // `UpdateRadiologyOrderDto extends PartialType(Create)` plus these.
    const update = {
      ...create,
      'status',
      'scheduledDate',
      'examPerformedAt',
      'performedById',
      'reportCreatedAt',
      'reportedById',
      'reportVerifiedAt',
      'verifiedById',
      'cancellationReason',
    };

    /// The order's own identity, and the four `...ById` stamps the server
    /// takes from the bearer token. A client that sends its own attributes a
    /// study to whoever the form last had selected.
    const declined = {
      'patientId',
      'consultationId',
      'examId',
      'performedById',
      'reportCreatedAt',
      'reportedById',
      'reportVerifiedAt',
      'verifiedById',
    };

    final full = RadiologyOrderDraft(
      patientId: 'pat-1',
      consultationId: 'con-1',
      examId: 'exam-1',
      clinicalIndication: 'Head injury',
      provisionalDiagnosis: 'Query bleed',
      relevantHistory: 'Fall',
      urgency: 'stat',
      notes: 'Porter booked',
      status: 'scheduled',
      scheduledDate: DateTime.utc(2026, 6, 10, 11),
      examPerformedAt: DateTime.utc(2026, 6, 10, 11, 20),
      cancellationReason: 'Patient declined',
    );

    test('create sends the request keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update declines the keys the server should be stamping', () {
      expectBody(
        full.toUpdateJson(),
        allowed: update,
        expected: update.difference(declined),
      );
    });
  });

  group('RadiologyReportDraft', () {
    // hms_v2/src/modules/radiology/dto/radiology-report.dto.ts
    const create = {
      'orderId',
      'technique',
      'findings',
      'impression',
      'recommendations',
      'hasCriticalFindings',
      'criticalFindings',
      'comparedWithPrevious',
      'comparisonNotes',
    };
    // `UpdateRadiologyReportDto extends PartialType(Create)` plus these.
    const update = {
      ...create,
      'criticalNotifiedTo',
      'criticalNotifiedAt',
      'images',
      'dicomStudyUid',
      'templateUsed',
      'reportedById',
      'reportedAt',
      'verifiedById',
      'verifiedAt',
      'status',
      'amendmentReason',
      'amendedAt',
      'amendedById',
    };

    /// The signatures and the study plumbing. A signature a client can choose
    /// is not a signature, and the image list is written by the upload route.
    const declined = {
      'orderId',
      'images',
      'dicomStudyUid',
      'templateUsed',
      'reportedById',
      'reportedAt',
      'verifiedById',
      'verifiedAt',
      'amendedAt',
      'amendedById',
    };

    final full = RadiologyReportDraft(
      orderId: 'ord-1',
      technique: 'Axial 5mm',
      findings: 'No acute intracranial haemorrhage.',
      impression: 'Normal study.',
      recommendations: 'None',
      hasCriticalFindings: true,
      criticalFindings: 'Midline shift',
      comparedWithPrevious: true,
      comparisonNotes: 'Stable since 2025',
      criticalNotifiedTo: 'Dr Smith',
      criticalNotifiedAt: DateTime.utc(2026, 6, 10, 12),
      status: 'final',
      amendmentReason: 'Typo in laterality',
    );

    test('create sends the report body', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update declines the signatures', () {
      expectBody(
        full.toUpdateJson(),
        allowed: update,
        expected: update.difference(declined),
      );
    });

    test('a critical finding carries who was told and when', () {
      // A critical finding with findings text and no notification time is the
      // state a ward escalates from, so the pair is written together.
      final body = full.toUpdateJson();
      expect(body['criticalNotifiedTo'], 'Dr Smith');
      expect(body['criticalNotifiedAt'], '2026-06-10T12:00:00.000Z');
    });
  });

  // ── Pharmacy ──────────────────────────────────────────────────────────────

  group('DrugDraft', () {
    // hms_v2/src/modules/pharmacy/dto/pharmacy-drug.dto.ts
    const create = {
      'drugName',
      'genericName',
      'brandName',
      'drugCode',
      'drugCategory',
      'dosageForm',
      'strength',
      'quantityInStock',
      'unitOfMeasure',
      'reorderLevel',
      'sellingPrice',
      'costPrice',
      'requiresPrescription',
      'storageLocation',
      'description',
    };
    const update = {...create, 'isActive'};

    const full = DrugDraft(
      drugName: 'Amoxicillin',
      genericName: 'Amoxicillin',
      brandName: 'Amoxil',
      drugCode: 'AMX500',
      drugCategory: 'antibiotic',
      dosageForm: 'capsule',
      strength: '500mg',
      quantityInStock: 240,
      unitOfMeasure: 'capsule',
      reorderLevel: 50,
      sellingPrice: 12.5,
      costPrice: 8,
      requiresPrescription: true,
      storageLocation: 'Shelf B3',
      description: 'Broad spectrum',
      isActive: true,
    );

    test('create sends the catalogue keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update adds isActive', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });

    test('zero stock is a fact, not a missing field', () {
      expect(
        const DrugDraft(quantityInStock: 0).toUpdateJson(),
        {'quantityInStock': 0},
      );
    });
  });

  group('PrescriptionDraft', () {
    // hms_v2/src/modules/pharmacy/dto/prescription.dto.ts
    const create = {
      'patientId',
      'doctorId',
      'consultationId',
      'items',
      'notes',
    };
    const update = {'status', 'notes', 'items'};

    // hms_v2/src/modules/pharmacy/dto/prescription.dto.ts,
    // `PrescriptionItemDto` — no `genericName`, unlike the consultation one.
    const itemKeys = {
      'drugId',
      'drugName',
      'dosage',
      'frequency',
      'duration',
      'quantity',
      'instructions',
    };

    const full = PrescriptionDraft(
      patientId: 'pat-1',
      doctorId: 'doc-1',
      consultationId: 'con-1',
      items: [
        PrescriptionItemDraft(
          drugId: 'drug-1',
          drugName: 'Amoxicillin 500mg',
          dosage: '500mg',
          frequency: 'TDS',
          duration: '7 days',
          quantity: 21,
          instructions: 'After meals',
        ),
      ],
      notes: 'Allergy checked',
      status: 'fully_dispensed',
    );

    test('create sends the script', () {
      final body = full.toCreateJson();
      expectBody(body, allowed: create, expected: create);
      final items = body['items'] as List<dynamic>;
      expect((items.single as Map).keys.toSet(), itemKeys);
    });

    test('update sends the dispensing keys', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });
  });

  group('SaleDraft', () {
    // hms_v2/src/modules/pharmacy/dto/pharmacy-sale.dto.ts
    const create = {
      'patientId',
      'prescriptionId',
      'items',
      'paymentMethod',
      'paymentStatus',
    };
    const itemKeys = {
      'drugId',
      'batchId',
      'drugName',
      'quantity',
      'unitPrice',
      'total',
    };

    const full = SaleDraft(
      patientId: 'pat-1',
      prescriptionId: 'presc-1',
      items: [
        SaleItemDraft(
          drugId: 'drug-1',
          batchId: 'batch-1',
          drugName: 'Amoxicillin 500mg',
          quantity: 21,
          unitPrice: 12.5,
          total: 262.5,
        ),
      ],
      paymentMethod: 'cash',
      paymentStatus: 'paid',
    );

    test('create sends the counter keys', () {
      final body = full.toCreateJson();
      expectBody(body, allowed: create, expected: create);
      final items = body['items'] as List<dynamic>;
      expect((items.single as Map).keys.toSet(), itemKeys);
    });

    test('there is no update: the sales route has no PATCH', () {
      // A sale is corrected by a refund. An empty body here is the contract,
      // not an oversight.
      expect(full.toUpdateJson(), isEmpty);
    });
  });

  // ── Billing ───────────────────────────────────────────────────────────────

  group('InvoiceDraft', () {
    // hms_v2/src/modules/billing/dto/invoice.dto.ts, CreateInvoiceDto
    const create = {
      'patientId',
      'consultationId',
      'items',
      'discountAmount',
      'discountPercentage',
      'notes',
      'dueDate',
    };
    // hms_v2/src/modules/billing/dto/invoice.dto.ts, UpdateInvoiceDto
    const update = {
      'status',
      'paymentStatus',
      'notes',
      'cancellationReason',
    };
    // hms_v2/src/modules/billing/dto/invoice.dto.ts, CreateInvoiceItemDto
    const itemKeys = {
      'type',
      'referenceId',
      'description',
      'quantity',
      'unitPrice',
      'discount',
      'tax',
      'total',
    };

    final full = InvoiceDraft(
      patientId: 'pat-1',
      consultationId: 'con-1',
      items: const [
        InvoiceItemDraft(
          type: 'service',
          referenceId: 'svc-1',
          description: 'Consultation',
          quantity: 1,
          unitPrice: 300,
          discount: 0,
          tax: 45,
          total: 345,
        ),
      ],
      discountAmount: 0,
      discountPercentage: 0,
      dueDate: DateTime(2026, 7, 1),
      notes: 'Insurance pending',
      status: 'sent',
      paymentStatus: 'partially_paid',
      cancellationReason: 'Duplicate',
    );

    test('create sends the lines and the terms', () {
      final body = full.toCreateJson();
      expectBody(body, allowed: create, expected: create);
      final items = body['items'] as List<dynamic>;
      expect((items.single as Map).keys.toSet(), itemKeys);
    });

    test('update cannot rewrite a raised invoice lines', () {
      final body = full.toUpdateJson();
      expectBody(body, allowed: update, expected: update);
      expect(body.containsKey('items'), isFalse);
    });

    test('an invoice with no lines on it never leaves the device', () {
      // `items: []` passes the DTO and raises a zero-total invoice, which is
      // worse than a 400 because nobody notices.
      final bare =
          const InvoiceDraft(patientId: 'pat-1', items: []).toCreateJson();
      expect(bare, {'patientId': 'pat-1'});
    });

    test('a due date goes as a calendar day', () {
      expect(full.toCreateJson()['dueDate'], '2026-07-01');
    });
  });

  group('PaymentDraft', () {
    // hms_v2/src/modules/billing/dto/payment.dto.ts
    const create = {
      'invoiceId',
      'patientId',
      'amount',
      'paymentMethod',
      'paymentReference',
      'mobileMoneyProvider',
      'bankName',
      'chequeNumber',
      'notes',
    };

    const full = PaymentDraft(
      invoiceId: 'inv-1',
      patientId: 'pat-1',
      amount: 345,
      paymentMethod: 'mobile_money',
      paymentReference: 'TXN-1',
      mobileMoneyProvider: 'M-Birr',
      bankName: 'CBE',
      chequeNumber: '000123',
      notes: 'Part payment',
    );

    test('create sends the receipt keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('there is no update: a ledger that can be edited is not a ledger', () {
      expect(full.toUpdateJson(), isEmpty);
    });

    test('cardLastFour is not sendable, whatever the column says', () {
      // Stored and returned by the backend, absent from the DTO. A form that
      // collected it would 400 the whole payment.
      expect(full.toCreateJson().containsKey('cardLastFour'), isFalse);
    });
  });

  group('BillingServiceDraft', () {
    // hms_v2/src/modules/billing/dto/service.dto.ts
    const create = {
      'serviceName',
      'serviceCode',
      'serviceCategory',
      'department',
      'unitPrice',
      'isTaxable',
      'taxPercentage',
      'isCoveredByInsurance',
      'insuranceCopayPercentage',
      'description',
    };
    const update = {...create, 'isActive'};

    const full = BillingServiceDraft(
      serviceName: 'Outpatient consultation',
      serviceCode: 'OPD-1',
      serviceCategory: 'consultation',
      department: 'General medicine',
      unitPrice: 300,
      isTaxable: true,
      taxPercentage: 15,
      isCoveredByInsurance: true,
      insuranceCopayPercentage: 20,
      description: 'Standard visit',
      isActive: true,
    );

    test('create sends the catalogue keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update adds isActive', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });

    test('a free service is a real entry, not an empty field', () {
      expect(
        const BillingServiceDraft(unitPrice: 0).toCreateJson(),
        {'unitPrice': 0.0},
      );
    });
  });

  // ── Staff, roles and settings ─────────────────────────────────────────────

  group('UserDraft', () {
    // hms_v2/src/modules/users/dto/user.dto.ts, CreateUserDto
    const create = {
      'email',
      'password',
      'firstName',
      'lastName',
      'phone',
      'organizationId',
      'dateOfBirth',
      'gender',
      'address',
      'employeeId',
      'role',
      'departmentId',
      'specialization',
      'licenseNumber',
      'defaultCalendar',
    };
    // `UpdateUserDto extends PartialType(OmitType(Create, ['password',
    // 'email']))` — every create key but those two.
    const update = {
      'firstName',
      'lastName',
      'phone',
      'organizationId',
      'dateOfBirth',
      'gender',
      'address',
      'employeeId',
      'role',
      'departmentId',
      'specialization',
      'licenseNumber',
      'defaultCalendar',
    };

    final full = UserDraft(
      email: 'alice@hospital.com',
      password: 'Str0ng@Passw0rd',
      firstName: 'Alice',
      lastName: 'Smith',
      phone: '+919876543210',
      organizationId: 'org-demo',
      dateOfBirth: DateTime(1985, 3, 2),
      gender: 'female',
      address: '12 Clinic Road',
      employeeId: 'EMP001',
      role: 'DOCTOR',
      departmentId: 'dept-1',
      specialization: 'Cardiology',
      licenseNumber: 'LIC12345',
      defaultCalendar: 'gregorian',
    );

    test('create sends the account keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update never carries a credential', () {
      // An address change and a credential change are different acts with
      // different audit trails, and the DTO omits both keys.
      final body = full.toUpdateJson();
      expectBody(body, allowed: update, expected: update);
      expect(body.containsKey('password'), isFalse);
      expect(body.containsKey('email'), isFalse);
    });
  });

  group('SettingsUserDraft', () {
    // hms_v2/src/modules/settings/dto/settings.dto.ts, CreateSettingsUserDto
    const create = {
      'organizationId',
      'fullName',
      'email',
      'password',
      'phone',
      'employeeId',
      'role',
      'departmentId',
      'specialization',
      'licenseNumber',
      'isActive',
    };
    // hms_v2/src/modules/settings/dto/settings.dto.ts, UpdateSettingsUserDto
    const update = {
      'fullName',
      'phone',
      'employeeId',
      'role',
      'departmentId',
      'specialization',
      'licenseNumber',
      'isActive',
    };

    const full = SettingsUserDraft(
      organizationId: 'org-demo',
      fullName: 'Dr. Alice Smith',
      email: 'alice.smith@hospital.com',
      password: 'Str0ng@Passw0rd',
      phone: '+919876543210',
      employeeId: 'EMP001',
      role: 'DOCTOR',
      departmentId: 'dept-1',
      specialization: 'Cardiology',
      licenseNumber: 'LIC12345',
      isActive: true,
    );

    test('create sends one fullName, never a split name', () {
      // The two staff routes disagree: `/users` splits the name, this one
      // does not. Sending the other route's keys is a 400.
      final body = full.toCreateJson();
      expectBody(body, allowed: create, expected: create);
      expect(body.containsKey('firstName'), isFalse);
    });

    test('update drops the identity keys', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });
  });

  group('DepartmentDraft', () {
    // hms_v2/src/modules/settings/dto/settings.dto.ts, CreateDepartmentDto
    const create = {
      'organizationId',
      'name',
      'code',
      'description',
      'headId',
      'isActive',
    };
    // hms_v2/src/modules/settings/dto/settings.dto.ts, UpdateDepartmentDto —
    // no organizationId.
    const update = {'name', 'code', 'description', 'headId', 'isActive'};

    const full = DepartmentDraft(
      organizationId: 'org-demo',
      name: 'Cardiology',
      code: 'CARD',
      description: 'Cardiology Department',
      headId: 'user-1',
      isActive: true,
    );

    test('create requires the organisation, update refuses it', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });
  });

  group('MachineDraft', () {
    // hms_v2/src/modules/integrations/dto/machine.dto.ts, CreateMachineDto
    const create = {
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
    // hms_v2/src/modules/integrations/dto/machine.dto.ts, UpdateMachineDto
    const update = {
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

    const full = MachineDraft(
      organizationId: 'org-demo',
      machineName: 'Sysmex XN-1000',
      machineType: 'lab_analyzer',
      manufacturer: 'Sysmex',
      model: 'XN-1000',
      serialNumber: 'SN-12345',
      department: 'laboratory',
      connectionType: 'hl7',
      connectionDetails: {'ipAddress': '192.168.1.100', 'port': 5000},
      testMapping: {'WBC': 'test-1'},
      isActive: true,
      connectionStatus: 'connected',
    );

    test('create sends what the analyser is and how it speaks', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update cannot change the type or the transport', () {
      final body = full.toUpdateJson();
      expectBody(body, allowed: update, expected: update);
      expect(body.containsKey('machineType'), isFalse);
      expect(body.containsKey('connectionType'), isFalse);
    });

    test('an empty connection block is dropped rather than sent as {}', () {
      expect(
        const MachineDraft(machineName: 'Sysmex', connectionDetails: {})
            .toUpdateJson(),
        {'machineName': 'Sysmex'},
      );
    });
  });

  group('RoleDraft and RolePermissionsDraft', () {
    // hms_v2/src/modules/roles/dto/roles.dto.ts, CreateRoleDto
    const create = {'name', 'description', 'organizationId'};
    // hms_v2/src/modules/roles/dto/roles.dto.ts, UpdateRoleDto
    const update = {'name', 'description'};
    // hms_v2/src/modules/roles/dto/roles.dto.ts, AssignPermissionsDto
    const assign = {'permissions'};
    // hms_v2/src/modules/roles/dto/roles.dto.ts, PermissionAssignmentDto
    const grantKeys = {
      'permissionId',
      'canRead',
      'canUpdate',
      'canCreate',
      'canDelete',
    };

    const role = RoleDraft(
      name: 'WARD_NURSE',
      description: 'Ward nursing staff',
      organizationId: 'org-demo',
    );

    test('create may place a role in a site, update may not move it', () {
      expectBody(role.toCreateJson(), allowed: create, expected: create);
      expectBody(role.toUpdateJson(), allowed: update, expected: update);
    });

    test('a permission assignment always spells all four verbs', () {
      // Every one is `@IsBoolean()` and required. A dropped verb fails the
      // whole assignment and leaves the role exactly as it was.
      const draft = RolePermissionsDraft(
        permissions: [
          RolePermissionDraft(permissionId: 'perm-1', canRead: true),
        ],
      );
      final body = draft.toCreateJson();
      expectBody(body, allowed: assign, expected: assign);

      final grants = body['permissions'] as List<dynamic>;
      final grant = grants.single as Map<String, dynamic>;
      expect(grant.keys.toSet(), grantKeys);
      expect(grant['canRead'], isTrue);
      expect(grant['canCreate'], isFalse);
      expect(draft.toUpdateJson(), body);
    });
  });

  group('OrganizationSettingsDraft', () {
    // hms_v2/src/modules/settings/dto/settings.dto.ts, UpdateOrganizationDto
    const organization = {
      'id',
      'name',
      'logoUrl',
      'logoTextUrl',
      'primaryColor',
      'secondaryColor',
      'email',
      'phone',
      'address',
      'city',
      'region',
      'country',
      'isActive',
      'settings',
      'modulesEnabled',
    };

    // hms_v2/src/modules/settings/dto/organization-settings.dto.ts,
    // OrganizationSettingsDto. The flat aliases below it are deprecated and
    // read-only for this app: the backend lifts them into their groups and
    // discards them, so writing them would fight the migration.
    const settings = {'locale', 'appearance', 'clinical', 'scheduling'};
    const locale = {
      'currency',
      'currencySymbol',
      'currencyPosition',
      'decimalSeparator',
      'thousandSeparator',
      'centPrecision',
      'showZeroCents',
      'language',
      'timezone',
      'dateFormat',
      'use24HourClock',
      'calendar',
    };
    const appearance = {'themePreset', 'themeFont', 'customColors'};
    const customColors = {'primary', 'secondary', 'accent'};
    const clinical = {
      'waitBreachMinutes',
      'triageScale',
      'showPatientNames',
      'sessionLockMinutes',
    };
    const scheduling = {'workingHours', 'appointmentDuration'};

    const full = OrganizationSettingsDraft(
      name: 'General Hospital',
      logoUrl: 'https://example.com/logo.png',
      logoTextUrl: 'https://example.com/wordmark.png',
      primaryColor: '#0E7C7B',
      secondaryColor: '#0A5F5E',
      email: 'org@hospital.com',
      phone: '+919876543210',
      address: '123 Health Ave',
      city: 'Health City',
      region: 'Health Region',
      country: 'Ethiopia',
      isActive: true,
      modulesEnabled: {'pharmacy': true, 'laboratory': true},
      currency: 'INR',
      currencySymbol: '₹',
      currencyPosition: 'before',
      decimalSeparator: '.',
      thousandSeparator: ',',
      centPrecision: 2,
      showZeroCents: false,
      language: 'en',
      timezone: 'Asia/Kolkata',
      dateFormat: 'dd/MM/yyyy',
      use24HourClock: true,
      calendar: 'gregorian',
      themePreset: 'default',
      themeFont: 'montserrat',
      customPrimary: '#0E7C7B',
      customSecondary: '#0A5F5E',
      customAccent: '#0070C0',
      waitBreachMinutes: 30,
      triageScale: 'p1-p5',
      showPatientNames: true,
      sessionLockMinutes: 5,
      workingHoursStart: '08:00',
      workingHoursEnd: '17:00',
      appointmentDuration: 30,
    );

    test('the body never carries id, whoever is signed in', () {
      // SUPER_ADMIN-only and ignored otherwise. It once let any holder of
      // SETTINGS_UPDATE rewrite another hospital's configuration by changing
      // one string, and this app has no reason to send it.
      expectBody(
        full.toCreateJson(),
        allowed: organization,
        expected: organization.difference(const {'id'}),
      );
    });

    test('the four groups nest exactly as the DTO declares them', () {
      final body = full.toUpdateJson();
      final group = body['settings'] as Map<String, dynamic>;
      expectBody(group, allowed: settings, expected: settings);

      expectBody(
        group['locale'] as Map<String, dynamic>,
        allowed: locale,
        expected: locale,
      );

      final look = group['appearance'] as Map<String, dynamic>;
      expectBody(look, allowed: appearance, expected: appearance);
      expectBody(
        look['customColors'] as Map<String, dynamic>,
        allowed: customColors,
        expected: customColors,
      );

      expectBody(
        group['clinical'] as Map<String, dynamic>,
        allowed: clinical,
        expected: clinical,
      );

      final when = group['scheduling'] as Map<String, dynamic>;
      expectBody(when, allowed: scheduling, expected: scheduling);
      expect(
        (when['workingHours'] as Map<String, dynamic>).keys.toSet(),
        const {'start', 'end'},
      );
    });

    test('one switch sends one group, and nothing else', () {
      // The backend merges group by group and preserves what it was not
      // sent. A phone saving one switch must not have to send the other
      // fifteen — and an empty group sent as {} would still be merged.
      final body = const OrganizationSettingsDraft(showPatientNames: false)
          .toUpdateJson();
      expect(body.keys.toSet(), const {'settings'});
      expect(body['settings'], {
        'clinical': {'showPatientNames': false},
      });
    });

    test('a zero that means something survives', () {
      // The DTO documents `waitBreachMinutes: 0` as "turn the breach flag
      // off" and `sessionLockMinutes: 0` as "never lock".
      final body = const OrganizationSettingsDraft(
        waitBreachMinutes: 0,
        sessionLockMinutes: 0,
      ).toUpdateJson();
      expect(body['settings'], {
        'clinical': {'waitBreachMinutes': 0, 'sessionLockMinutes': 0},
      });
    });

    test('an untouched draft sends nothing at all', () {
      expect(const OrganizationSettingsDraft().toUpdateJson(), isEmpty);
    });
  });

  // ── Queue, screening and inpatient ────────────────────────────────────────

  group('QueueEntryDraft', () {
    // hms_v2/src/modules/queue/dto/create-queue.dto.ts
    const create = {
      'patientId',
      'serviceArea',
      'serviceType',
      'priority',
      'assignedToId',
      'assignedRoom',
    };
    // hms_v2/src/modules/queue/dto/update-queue.dto.ts
    const update = {
      'status',
      'serviceArea',
      'priority',
      'serviceType',
      'assignedToId',
      'assignedRoom',
      'estimatedWaitMinutes',
      'displayMessage',
    };

    const full = QueueEntryDraft(
      patientId: 'pat-1',
      serviceArea: 'opd',
      serviceType: 'consultation',
      priority: 'p2',
      assignedToId: 'user-1',
      assignedRoom: 'Room 3',
      status: 'called',
      estimatedWaitMinutes: 15,
      displayMessage: 'Please proceed to Room 3',
    );

    test('create sends the ticket keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update never re-points a ticket at another patient', () {
      final body = full.toUpdateJson();
      expectBody(body, allowed: update, expected: update);
      expect(body.containsKey('patientId'), isFalse);
    });

    test('a triage code is a priority the DTO accepts', () {
      // `p1`..`p5` and the word ladder are both valid. Every add-to-queue
      // from the phone was once a 400 because only the words were accepted.
      expect(
        const QueueEntryDraft(priority: 'p1').toCreateJson(),
        {'priority': 'p1'},
      );
    });
  });

  group('ScreeningDraft', () {
    // hms_v2/src/modules/pre-triage/dto/create-pre-triage.dto.ts
    const create = {
      'firstName',
      'lastName',
      'age',
      'gender',
      'phone',
      'chiefComplaint',
      'briefHistory',
      'temperature',
      'bloodPressureSystolic',
      'bloodPressureDiastolic',
      'pulseRate',
      'routedTo',
    };
    // hms_v2/src/modules/pre-triage/dto/update-pre-triage.dto.ts —
    // PartialType(Create) + status + patientId.
    const update = {...create, 'status', 'patientId'};

    const full = ScreeningDraft(
      firstName: 'John',
      lastName: 'Doe',
      age: 35,
      gender: 'male',
      phone: '+251911123456',
      chiefComplaint: 'Fever and cough',
      briefHistory: 'Three days',
      temperature: 38.5,
      bloodPressureSystolic: 120,
      bloodPressureDiastolic: 80,
      pulseRate: 75,
      routedTo: 'adult_triage',
      status: 'routed',
      patientId: 'pat-1',
    );

    test('create sends the screening keys', () {
      expectBody(full.toCreateJson(), allowed: create, expected: create);
    });

    test('update adds the routing outcome', () {
      expectBody(full.toUpdateJson(), allowed: update, expected: update);
    });

    test('a screening with only a complaint on it is still sendable', () {
      // Somebody arriving unable to give a name is exactly the patient this
      // screen exists for; every field on the DTO is optional for that reason.
      expect(
        const ScreeningDraft(chiefComplaint: 'Collapsed').toCreateJson(),
        {'chiefComplaint': 'Collapsed'},
      );
    });
  });

  group('AdmissionDraft and DischargeDraft', () {
    // hms_v2/src/modules/inpatient/dto/admission.dto.ts, CreateAdmissionDto
    const create = {
      'patientId',
      'bedId',
      'admissionType',
      'admissionReason',
      'admittingDoctorId',
      'attendingDoctorId',
    };
    // hms_v2/src/modules/inpatient/dto/admission.dto.ts, UpdateAdmissionDto
    const update = {
      ...create,
      'status',
      'dischargeDate',
      'dischargeReason',
      'dischargeSummary',
      'dischargeDoctorId',
      'followUpDate',
      'followUpNotes',
    };

    const admission = AdmissionDraft(
      patientId: 'pat-1',
      bedId: 'bed-1',
      admissionType: 'emergency',
      admissionReason: 'Chest pain',
      admittingDoctorId: 'doc-1',
      attendingDoctorId: 'doc-2',
      status: 'admitted',
    );

    final discharge = DischargeDraft(
      status: 'discharged',
      dischargeDate: DateTime.utc(2026, 6, 12, 14, 30),
      dischargeReason: 'Recovered',
      dischargeSummary: 'Uneventful stay.',
      dischargeDoctorId: 'doc-2',
      followUpDate: DateTime(2026, 6, 26),
      followUpNotes: 'Clinic in two weeks',
    );

    test('an admission carries no discharge fields', () {
      // The two are different acts by different people at different times. A
      // single draft holding both invites a transfer that also discharges.
      expectBody(
        admission.toUpdateJson(),
        allowed: update,
        expected: {...create, 'status'},
      );
      expectBody(admission.toCreateJson(), allowed: create, expected: create);
    });

    test('a discharge is a PATCH, so both bodies are the same', () {
      const expected = {
        'status',
        'dischargeDate',
        'dischargeReason',
        'dischargeSummary',
        'dischargeDoctorId',
        'followUpDate',
        'followUpNotes',
      };
      expectBody(
        discharge.toUpdateJson(),
        allowed: update,
        expected: expected,
      );
      expect(discharge.toCreateJson(), discharge.toUpdateJson());
    });

    test('a discharge time is an instant and a follow-up is a day', () {
      final body = discharge.toUpdateJson();
      expect(body['dischargeDate'], '2026-06-12T14:30:00.000Z');
      expect(body['followUpDate'], '2026-06-26');
    });
  });

  group('WardDraft and BedDraft', () {
    // hms_v2/src/modules/inpatient/dto/ward.dto.ts
    const wardCreate = {'name', 'code', 'type', 'capacity', 'departmentId'};
    const wardUpdate = {...wardCreate, 'isActive'};
    // hms_v2/src/modules/inpatient/dto/bed.dto.ts
    const bedCreate = {'wardId', 'bedNumber', 'type', 'status'};
    const bedUpdate = {...bedCreate, 'currentPatientId'};

    const ward = WardDraft(
      name: 'Maternity',
      code: 'MAT',
      type: 'maternity',
      capacity: 24,
      departmentId: 'dept-1',
      isActive: true,
    );

    const bed = BedDraft(
      wardId: 'ward-1',
      bedNumber: 'M-04',
      type: 'standard',
      status: 'occupied',
      currentPatientId: 'pat-1',
    );

    test('a ward being stood up may have no beds yet', () {
      expectBody(ward.toCreateJson(), allowed: wardCreate, expected: wardCreate);
      expect(const WardDraft(capacity: 0).toCreateJson(), {'capacity': 0});
    });

    test('update adds isActive', () {
      expectBody(ward.toUpdateJson(), allowed: wardUpdate, expected: wardUpdate);
    });

    test('a bed takes its occupant only on update', () {
      expectBody(bed.toCreateJson(), allowed: bedCreate, expected: bedCreate);
      expectBody(bed.toUpdateJson(), allowed: bedUpdate, expected: bedUpdate);
    });
  });

  // ── The patient portal ────────────────────────────────────────────────────
  //
  // The only two writes in this app that go out without a bearer token. They
  // are still validated by the same `whitelist + forbidNonWhitelisted`, so an
  // extra key here is a patient standing at a desk unable to get into their
  // own record.

  group('PatientClaimDraft', () {
    // hms_v2/src/modules/patient-auth/dto/claim-patient-record.dto.ts
    const create = {'mrn', 'dateOfBirth'};

    final draft = PatientClaimDraft(
      mrn: 'MRN-PORTAL-0001',
      dateOfBirth: DateTime(1990, 5, 17),
    );

    test('sends the two things printed on a card, and nothing else', () {
      expectBody(draft.toCreateJson(), allowed: create, expected: create);
    });

    test('the date of birth is a calendar day, not an instant', () {
      // `@IsDateString()` accepts both, and the difference is a whole day.
      // `isoDay` deliberately does not convert to UTC first: 1990-05-17 in a
      // UTC+ zone becomes the 16th if it does, and the pair then matches
      // nothing — which the server answers with a perfectly valid-looking
      // token that is refused ten minutes later at activation.
      expect(draft.toCreateJson()['dateOfBirth'], '1990-05-17');
    });
  });

  group('PatientActivationDraft', () {
    // hms_v2/src/modules/patient-auth/dto/activate-patient-account.dto.ts
    const create = {'claimToken', 'password', 'email'};

    test('sends the token, the password and the address', () {
      const draft = PatientActivationDraft(
        claimToken: 'a-claim-token-long-enough',
        password: 'Portal@12345',
        email: 'patient@example.com',
      );
      expectBody(draft.toCreateJson(), allowed: create, expected: create);
    });

    test('omits the email rather than sending a blank one', () {
      // `@IsOptional() @IsEmail()` — an empty string is not an email, so
      // sending one is a 400 for the whole request. The record may already
      // carry an address, and the app cannot know: the claim response tells it
      // nothing about the record on purpose.
      const draft = PatientActivationDraft(
        claimToken: 'a-claim-token-long-enough',
        password: 'Portal@12345',
        email: '   ',
      );
      expectBody(
        draft.toCreateJson(),
        allowed: create,
        expected: create.difference({'email'}),
      );
    });
  });

  // ── Case taking ───────────────────────────────────────────────────────────
  //
  // The interview's four writes. Two keys are absent from every one of them and
  // the absences are the contract rather than an oversight: `patientId` arrives
  // from the bearer token, and **`presence` cannot be sent at all**. A client
  // that could post "this is unknown" would be a client that could post "this
  // is a no", and the whole tri-state exists because that is the mistake worth
  // making structurally impossible.

  group('CaseSessionStartDraft', () {
    // hms_v2/src/modules/case-taking/dto/case-taking.dto.ts — StartCaseSessionDto
    const create = {'kind', 'language', 'appointmentId'};

    test('sends the kind and the language', () {
      const draft = CaseSessionStartDraft(language: 'en');
      expectBody(
        draft.toCreateJson(),
        allowed: create,
        // No appointment: an intake taken at a desk belongs to no booking, and
        // `draftBody` drops the null rather than sending one.
        expected: create.difference({'appointmentId'}),
      );
    });

    test('never sends a patient or an organisation', () {
      const draft = CaseSessionStartDraft();
      // Both arrive from the token. Sending either is a 400, which is the
      // server making a tenant-hopping request a syntax error.
      expect(draft.toCreateJson().containsKey('patientId'), isFalse);
      expect(draft.toCreateJson().containsKey('organizationId'), isFalse);
    });
  });

  group('CaseConsentDraft', () {
    // CaseConsentDto
    const create = {'consentVersion', 'accepted'};

    test('sends the wording and the answer', () {
      const draft = CaseConsentDraft(
        consentVersion: '2026.09.1',
        accepted: true,
      );
      expectBody(draft.toCreateJson(), allowed: create, expected: create);
    });

    test('a refusal is sent, not omitted', () {
      // `false` is a value and never an absence — see `draftBody`. A refusal
      // that arrived as a missing key would leave the session open in a state
      // where the next request could still ask a question.
      const draft = CaseConsentDraft(
        consentVersion: '2026.09.1',
        accepted: false,
      );
      expect(draft.toCreateJson()['accepted'], isFalse);
    });
  });

  group('CaseTurnDraft', () {
    // SubmitTurnDto
    const create = {
      'fieldPath',
      'modality',
      'text',
      'value',
      'transcriptConfidence',
      'audioKey',
    };

    test('a spoken answer carries the recogniser\'s own confidence', () {
      final draft = CaseTurnDraft.spoken(
        fieldPath: 'hpi.duration',
        text: 'About three days now',
        confidence: 0.84,
      );
      expectBody(
        draft.toCreateJson(),
        allowed: create,
        expected: {'fieldPath', 'modality', 'text', 'transcriptConfidence'},
      );
      expect(draft.toCreateJson()['modality'], 'voice');
    });

    test('a typed answer is text, and nothing is inferred from it', () {
      final draft = CaseTurnDraft.typed(
        fieldPath: 'chief_complaint.symptom',
        text: 'Chest pain',
      );
      expectBody(
        draft.toCreateJson(),
        allowed: create,
        expected: {'fieldPath', 'modality', 'text'},
      );
      expect(draft.toCreateJson()['modality'], 'text');
    });

    test('a tapped tile is `choice`, never `touch`', () {
      // Two spellings of one concept is one of them eventually being missed;
      // the backend ledger records exactly that drift between its schema and
      // its engine. `ANSWER_MODALITIES` is the single source and `choice` is
      // the word in it.
      final draft = CaseTurnDraft.tapped(
        fieldPath: 'hpi.onset',
        option: const CaseAnswerOption(
          token: 'sudden',
          label: 'Sudden',
          modality: CaseAnswerModality.choice,
        ),
      );
      expect(draft.toCreateJson()['modality'], 'choice');
      expect(draft.toCreateJson()['value'], 'sudden');
    });

    test("\"I don't know\" goes out as not_sure and never as no", () {
      // The single most important assertion in this file. A tapped "I don't
      // know" is a statement about what the patient knows; a "no" is a clinical
      // finding. A chart that says "no known allergies" because nobody asked is
      // wrong in the direction that gets somebody prescribed the drug that
      // kills them.
      final draft = CaseTurnDraft.tapped(
        fieldPath: 'allergies.reported',
        option: CaseAnswerOption.unsure,
      );
      final body = draft.toCreateJson();

      expect(body['value'], 'not_sure');
      expect(body['value'], isNot('no'));
      expect(body['modality'], 'choice');
      // And the state itself is never asserted by the client: `derivePresence`
      // reads the patient's own words and decides, and it is the only thing
      // that does.
      expect(body.containsKey('presence'), isFalse);
    });

    test('a skip carries its meaning in the modality, not in a value', () {
      final draft = CaseTurnDraft.tapped(
        fieldPath: 'family.any_relevant',
        option: CaseAnswerOption.skip,
      );
      final body = draft.toCreateJson();

      expect(body['modality'], 'skip');
      expect(
        body.containsKey('value'),
        isFalse,
        reason: 'a skip that carried a value would be an answer nobody gave',
      );
    });
  });

  group('PatientDocumentUploadDraft', () {
    // hms_v2/src/modules/patient-documents/dto/upload-patient-document.dto.ts
    const create = {'sessionId', 'patientId'};

    test('attaches the document to the interview it was taken during', () {
      const draft = PatientDocumentUploadDraft(sessionId: 'cs-1');
      expectBody(
        draft.toCreateJson(),
        allowed: create,
        // `patientId` is declared by the DTO and deliberately never sent. It
        // exists for a receptionist scanning somebody else's referral letter;
        // a patient's own id is on the bearer token, and the guard prefers the
        // token over the body whatever the body says.
        expected: create.difference({'patientId'}),
      );
    });

    test('a document added from the dashboard names no session', () {
      const draft = PatientDocumentUploadDraft();
      // Dropped rather than sent empty: the server checks the session belongs
      // to this patient and answers a blank one with "That case-taking session
      // could not be found."
      expect(draft.toCreateJson(), isEmpty);
      expect(draft.toFormFields(), isEmpty);
    });

    test('every part of a multipart body goes out as text', () {
      // `forbidNonWhitelisted` applies to a multipart body too, and everything
      // in one arrives as a string no matter what it was on the client. Spelled
      // out here rather than left to `FormData.fromMap` to coerce.
      const draft = PatientDocumentUploadDraft(sessionId: 'cs-1');
      expect(draft.toFormFields(), isA<Map<String, String>>());
      expect(draft.toFormFields(), {'sessionId': 'cs-1'});
    });
  });

  group('CaseFactCorrectionDraft', () {
    // CorrectFactDto
    const update = {'modality', 'text', 'value'};

    test('sends the corrected words and nothing about the fact it replaces',
        () {
      // The fact id is in the path. A correction that also named its target in
      // the body would be a second place for the two to disagree.
      const draft = CaseFactCorrectionDraft(text: 'Four days, not three');
      expectBody(
        draft.toUpdateJson(),
        allowed: update,
        expected: {'text'},
      );
    });
  });
}
