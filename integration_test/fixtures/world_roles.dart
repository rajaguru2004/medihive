/// The roles the backend seeds, and exactly what each one is granted.
///
/// The permission lists below are copied from the server's seed. The access
/// map every fixture serves is **derived** from them ([accessModules]), so a
/// change to a grant changes the map with it. Two hand-maintained sources
/// would eventually disagree — a fixture granting a nurse `INPATIENT_CREATE`
/// alongside an access map that hides the ward from her — and a harness
/// disagreeing with itself looks exactly like the app disagreeing with the
/// server.
library;

/// One seeded account, with the grants the server gives its role.
enum WorldRole {
  /// Bypasses every guard on the server, so it holds the whole catalogue.
  superAdmin(
    id: 'u-1',
    displayName: 'Adaeze Nwosu',
    email: 'a.nwosu@example.org',
    roleName: 'SUPER_ADMIN',
    department: 'Administration',
    employeeId: 'EMP-0001',
  ),

  admin(
    id: 'u-2',
    displayName: 'Martin Oyelaran',
    email: 'm.oyelaran@example.org',
    roleName: 'ADMIN',
    department: 'Administration',
    employeeId: 'EMP-0012',
  ),

  /// The clinician the rest of the world is built around: every appointment
  /// and consultation fixture names her as the doctor, so signing in as this
  /// role shows a clinic that is actually hers.
  doctor(
    id: 'd-1',
    displayName: 'Dr Amara Okonkwo',
    email: 'a.okonkwo@example.org',
    roleName: 'DOCTOR',
    department: 'Emergency',
    specialization: 'Emergency medicine',
    licenseNumber: 'GMC-7741204',
    employeeId: 'EMP-0031',
  ),

  nurse(
    id: 'u-4',
    displayName: 'Beatrice Achieng',
    email: 'b.achieng@example.org',
    roleName: 'NURSE',
    department: 'Acute Medical',
    licenseNumber: 'NMC-55019',
    employeeId: 'EMP-0044',
  ),

  receptionist(
    id: 'u-5',
    displayName: 'Kofi Mensah',
    email: 'k.mensah@example.org',
    roleName: 'RECEPTIONIST',
    department: 'Front desk',
    employeeId: 'EMP-0057',
  ),

  pharmacist(
    id: 'u-6',
    displayName: 'Nadia Haddad',
    email: 'n.haddad@example.org',
    roleName: 'PHARMACIST',
    department: 'Pharmacy',
    licenseNumber: 'GPhC-2088431',
    employeeId: 'EMP-0063',
  ),

  labTechnician(
    id: 'u-7',
    displayName: 'Samuel Adeyinka',
    email: 's.adeyinka@example.org',
    roleName: 'LAB_TECHNICIAN',
    department: 'Laboratory',
    employeeId: 'EMP-0078',
  ),

  radiologist(
    id: 'u-8',
    displayName: 'Dr Wei Zhang',
    email: 'w.zhang@example.org',
    roleName: 'RADIOLOGIST',
    department: 'Radiology',
    specialization: 'Diagnostic radiology',
    licenseNumber: 'GMC-6620118',
    employeeId: 'EMP-0084',
  ),

  billingStaff(
    id: 'u-9',
    displayName: 'Rosa Iglesias',
    email: 'r.iglesias@example.org',
    roleName: 'BILLING_STAFF',
    department: 'Finance',
    employeeId: 'EMP-0091',
  ),

  /// The one account in this list who does not work here.
  ///
  /// Ifeoma Balogun is already `p-1` in the world — she is on the clinic
  /// board, she has appointments, she was recently discharged — and this is
  /// her signing in to read her own record. Deliberately the same person
  /// rather than a tenth invented one: the whole point of the portal is that a
  /// patient and a clinician are looking at the same record from two sides,
  /// and a fixture with a portal patient nobody in the department has ever
  /// seen cannot show that.
  ///
  /// No department and no employee id, because she has neither. The live API
  /// sends null for all three and the shell has to survive it.
  patient(
    id: 'u-10',
    displayName: 'Ifeoma Balogun',
    email: 'i.balogun@example.org',
    roleName: 'PATIENT',
    department: '',
  );

  const WorldRole({
    required this.id,
    required this.displayName,
    required this.email,
    required this.roleName,
    required this.department,
    this.specialization = '',
    this.licenseNumber = '',
    this.employeeId = '',
  });

  final String id;

  /// The person, not the role. `/auth/me` sends it as `fullName`.
  final String displayName;

  final String email;

  /// The server's own role name — `DOCTOR`, `LAB_TECHNICIAN`. Upper-case and
  /// underscored, because that is what the seed writes and what the token's
  /// `roles` claim carries; `SUPER_ADMIN` is the one the access map reads.
  final String roleName;

  final String department;
  final String specialization;
  final String licenseNumber;
  final String employeeId;

  /// The hospital every fixture in this world belongs to.
  static const String organizationId = 'o-1';

  /// A plausible department id, so `/auth/me` can send `departmentId`,
  /// `department` and `departmentName` the way the route does.
  String get departmentId => 'dept-${index + 1}';

  String get phone => '+44 7700 9001${(index + 10).toString().padLeft(2, '0')}';

  /// What the seed grants this role, as `<MODULE>_<VERB>` codes.
  ///
  /// Copied from the backend seed. Nothing derives these — they *are* the
  /// source, and everything else in this file is derived from them.
  List<String> get permissions => switch (this) {
        WorldRole.superAdmin => _everything(),
        WorldRole.admin => [
            ..._all('USER'),
            'ROLE_READ',
            'PATIENT_READ',
            'APPOINTMENT_READ',
            'AUDIT_READ',
            'DASHBOARD_READ',
            ..._only('SETTINGS', const ['READ', 'UPDATE']),
          ],
        WorldRole.doctor => [
            ..._all('PATIENT'),
            ..._all('APPOINTMENT'),
            ..._all('CONSULTATION'),
            ..._all('INPATIENT'),
            ..._all('LABORATORY'),
            ..._all('RADIOLOGY'),
            ..._all('PHARMACY'),
            ..._all('PRE_TRIAGE'),
            ..._all('QUEUE'),
            // Read-only on both, and the seed says why: the intake is the
            // patient's own account of why they came and the documents are
            // what they brought. A clinician records their own findings in a
            // consultation, so there is nothing here for them to edit — and
            // an intake a clinician can rewrite stops being evidence of what
            // the patient said.
            //
            // These two were missing from this table while the seed granted
            // them, which is drift in the direction that hides a feature: the
            // hub's Intake tab rendered the refusal screen for the one role
            // it was written for.
            'CASE_TAKING_READ',
            'PATIENT_DOCUMENT_READ',
            'DASHBOARD_READ',
          ],
        WorldRole.nurse => [
            'PATIENT_READ',
            'APPOINTMENT_READ',
            'CONSULTATION_READ',
            ..._only('INPATIENT', _cru),
            ..._only('PRE_TRIAGE', _cru),
            ..._only('QUEUE', _cru),
            // Same pair as the doctor, and for the same reason. The seed
            // grants a nurse both reads.
            'CASE_TAKING_READ',
            'PATIENT_DOCUMENT_READ',
            'DASHBOARD_READ',
          ],
        WorldRole.receptionist => [
            ..._only('PATIENT', _cru),
            ..._all('APPOINTMENT'),
            ..._all('QUEUE'),
            'BILLING_READ',
            'DASHBOARD_READ',
          ],
        WorldRole.pharmacist => [
            ..._all('PHARMACY'),
            'PATIENT_READ',
            'DASHBOARD_READ',
          ],
        WorldRole.labTechnician => [
            ..._all('LABORATORY'),
            'PATIENT_READ',
            'DASHBOARD_READ',
          ],
        WorldRole.radiologist => [
            ..._all('RADIOLOGY'),
            'PATIENT_READ',
            'DASHBOARD_READ',
          ],
        WorldRole.billingStaff => [
            ..._all('BILLING'),
            'PATIENT_READ',
            'DASHBOARD_READ',
          ],
        // Create and update on both of the portal's own modules — filling in
        // an intake and correcting it before the consultation is the patient
        // doing their own work — but no DELETE, and **no `PATIENT_READ`**.
        // That last omission is the one the landing decision turns on: every
        // staff role above holds it, because a clinician who cannot look a
        // patient up cannot do their job, and an account that can file its own
        // history and cannot read anybody else's record is the person rather
        // than the hospital. See `PatientShell.isPortalAccount`.
        WorldRole.patient => [
            'APPOINTMENT_CREATE',
            'APPOINTMENT_READ',
            ..._only('CASE_TAKING', _cru),
            ..._only('PATIENT_DOCUMENT', _cru),
            'DASHBOARD_READ',
          ],
      };

  /// The `access.modules` block of `GET /api/auth/me`, derived from
  /// [permissions].
  ///
  /// All four flags on every module this role touches, granted or not: that is
  /// what the server sends, and a map carrying only the granted keys would
  /// parse to the same thing while hiding whether the server was explicit.
  Map<String, Map<String, bool>> get accessModules {
    final modules = <String, Map<String, bool>>{};
    for (final code in permissions) {
      final cut = code.lastIndexOf('_');
      if (cut <= 0) continue;
      final module = _modulesByPrefix[code.substring(0, cut)];
      final field = _accessFields[code.substring(cut + 1)];
      if (module == null || field == null) continue;
      modules.putIfAbsent(module, _closed)[field] = true;
    }
    return modules;
  }

  /// The whole `access` block, as `/auth/me` and `/auth/me/access` send it.
  Map<String, Object?> get accessBlock => {'modules': accessModules};
}

/// The verbs a permission code can end in, in the order the seed lists them.
const List<String> _crud = ['CREATE', 'READ', 'UPDATE', 'DELETE'];

/// Read and change, but never remove — the shape several clinical roles hold.
const List<String> _cru = ['CREATE', 'READ', 'UPDATE'];

List<String> _all(String prefix) =>
    [for (final verb in _crud) '${prefix}_$verb'];

List<String> _only(String prefix, List<String> verbs) =>
    [for (final verb in verbs) '${prefix}_$verb'];

/// Every row in the catalogue. What a super admin effectively holds, expanded
/// rather than flagged, because that is what the server's map answers with.
List<String> _everything() => [
      for (final prefix in _modulesByPrefix.keys)
        for (final verb in _crud) '${prefix}_$verb',
    ];

Map<String, bool> _closed() => {
      'canCreate': false,
      'canRead': false,
      'canUpdate': false,
      'canDelete': false,
    };

/// `PATIENT_READ` → `patients`: the server's own `category` grouping.
///
/// Spelled as the server spells it, **including the hyphen in `pre-triage`** —
/// the one key that does not follow the pattern, and the one a typo hides in.
///
/// Deliberately not `AccessMap.fromPermissions`, which does the same job in
/// `lib/`. A fixture derived from the parser it feeds proves only that the
/// parser agrees with itself; the divergence worth catching is between the app
/// and the server, and that needs two independent tables.
const Map<String, String> _modulesByPrefix = {
  'PATIENT': 'patients',
  'APPOINTMENT': 'appointments',
  'CONSULTATION': 'consultations',
  'PRE_TRIAGE': 'pre-triage',
  'QUEUE': 'queue',
  'INPATIENT': 'inpatient',
  'LABORATORY': 'laboratory',
  'RADIOLOGY': 'radiology',
  'PHARMACY': 'pharmacy',
  'BILLING': 'billing',
  'INTEGRATION': 'integrations',
  'USER': 'users',
  'ROLE': 'roles',
  'PERMISSION': 'permissions',
  'SETTINGS': 'settings',
  'DASHBOARD': 'dashboard',
  'AUDIT': 'audit',
  // The portal's own two. `resource` on the server's permission rows is what
  // `/auth/me` keys its module map by, and these are the strings it sends —
  // checked against the live API, which answers a patient's map with
  // `case-taking` and `patient-documents` beside the seventeen staff ones.
  'CASE_TAKING': 'case-taking',
  'PATIENT_DOCUMENT': 'patient-documents',
};

const Map<String, String> _accessFields = {
  'CREATE': 'canCreate',
  'READ': 'canRead',
  'UPDATE': 'canUpdate',
  'DELETE': 'canDelete',
};
