import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — staff, roles and permissions, in fixtures
///
/// Ten people, nine roles and the permission catalogue behind them, all
/// agreeing with the rest of the world: the three doctors the appointment and
/// laboratory pickers already name are the same three rows here, with the same
/// ids, so a flow that walks from a worklist into the directory sees one
/// department rather than two.
///
/// **This install validates like the server does.** Every write is checked
/// against the DTO it is posted to, and an unknown or missing key is answered
/// **400**, because that is what `forbidNonWhitelisted` does on the real
/// backend. That is the whole point of the module: `/api/users` takes
/// `firstName` + `lastName` and `/api/settings/users` takes a single
/// `fullName`, both are live, and sending one route the other's keys is a 400
/// nobody sees until a ward administrator cannot create an account. A fixture
/// that accepted both shapes would let the bug ship.
///
/// The same applies to the **query** on `GET /api/users`: the route binds it to
/// `PaginationDto`, which declares `page`, `limit`, `orderBy` and `orderDir`
/// and nothing else — so `?search=` or `?role=` is a 400 for the whole request
/// rather than a parameter the server ignores.
///
/// **Everything here is mutable, and per install.** A create appends, an edit
/// merges, a delete removes, and assigning permissions replaces the role's
/// whole set the way `assignPermissions` does — so a flow can prove a round
/// trip rather than prove a fixture answered.
///
/// Two shapes are faithful to the live backend rather than to what the routes
/// look like they should do, and both are load-bearing:
///
///   * **`GET /api/roles` carries no permissions and no counts.** The service
///     answers bare `Role` rows, so a card built from the list has nothing to
///     summarise — the editor is where the grants live.
///   * **`GET /api/roles/:id/users` is not mounted.** `RolesController` has a
///     `POST` and a `DELETE` at that path and no `GET`, so it 404s. The role
///     editor asks anyway and falls back to the staff directory; answering it
///     here would test a route that does not exist.
/// ─────────────────────────────────────────────────────────────────────────────

/// Registers every staff, role and permission route the app calls.
void installStaffFixtures(FakeApi api) {
  // Per install, not per library. These are written to.
  final people = _buildPeople();
  final roles = _buildRoles();
  final permissions = _buildPermissions();

  /// Role id → the permission ids it grants. Replaced whole by the PUT, which
  /// is exactly what the server does.
  final grants = _buildGrants(permissions);

  /// Role id → the user ids on the join table. Deliberately separate from each
  /// person's `role` column: the server keeps them in step on a staff write and
  /// lets them diverge on `POST /roles/:id/users`, and the app's member list
  /// has to cope with that.
  final memberships = _buildMemberships(roles, people);

  Map<String, Object?>? personById(String? id) => people.firstWhere(
        (person) => person['id'] == id,
        orElse: () => const <String, Object?>{},
      ).isEmpty
          ? null
          : people.firstWhere((person) => person['id'] == id);

  // ── The permission catalogue ─────────────────────────────────────────────
  //
  // Bare `Permission` rows, which is what `PermissionsService.findAll` answers
  // — **not** the join rows a role carries. So there is no `permissionId` on
  // one of these and `id` is the permission's own id, which is the trap the
  // role editor normalises away.
  api.on('GET', '/api/permissions', (_) => FakeResponse.ok(permissions));

  // ── Roles ────────────────────────────────────────────────────────────────

  api.on('GET', '/api/roles', (_) {
    // No `rolePermissions`, no `_count`: `RolesService.findAll` sends the role
    // rows and nothing else.
    return FakeResponse.ok([
      for (final role in roles)
        {
          'id': role['id'],
          'name': role['name'],
          'description': role['description'],
          'isSystem': role['isSystem'],
          'organizationId': role['organizationId'],
          'createdAt': role['createdAt'],
        },
    ]);
  });

  api.on('GET', '/api/roles/:id', (request) {
    final id = request.pathParams['id'];
    final role = roles.firstWhere(
      (entry) => entry['id'] == id,
      orElse: () => const <String, Object?>{},
    );
    if (role.isEmpty) {
      return FakeResponse.fail(404, 'Role not found', errorCode: 'ROLE_NOT_FOUND');
    }

    // `findByIdWithPermissions` includes the join rows with the permission
    // nested inside each one.
    return FakeResponse.ok({
      ...role,
      'rolePermissions': [
        for (final permissionId in grants[id] ?? const <String>{})
          _joinRow(role, _permissionById(permissions, permissionId)),
      ],
    });
  });

  api.on('PATCH', '/api/roles/:id', (request) {
    final id = request.pathParams['id'];
    final index = roles.indexWhere((entry) => entry['id'] == id);
    if (index == -1) return FakeResponse.fail(404, 'Role not found');

    final refusal = _refuseUnknown(request.jsonBody, _updateRoleKeys);
    if (refusal != null) return refusal;

    if (roles[index]['isSystem'] == true) return _systemProtected();

    final body = Map<String, Object?>.from(request.jsonBody);
    // The backend upper-cases whatever `name` it is sent, which is why two
    // spellings of one role collide with a 409.
    if (body['name'] is String) {
      body['name'] = (body['name']! as String).toUpperCase();
    }
    roles[index] = {...roles[index], ...body};
    return FakeResponse.ok(roles[index]);
  });

  // ── A role's permissions ─────────────────────────────────────────────────

  api.on('PUT', '/api/roles/:id/permissions', (request) {
    final id = request.pathParams['id'];
    final role = roles.firstWhere(
      (entry) => entry['id'] == id,
      orElse: () => const <String, Object?>{},
    );
    if (role.isEmpty) return FakeResponse.fail(404, 'Role not found');
    if (role['isSystem'] == true) return _systemProtected();

    final refusal = _refuseUnknown(
      request.jsonBody,
      const {'permissions'},
      required: const {'permissions'},
    );
    if (refusal != null) return refusal;

    final rows = (request.jsonBody['permissions'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    for (final row in rows) {
      final bad = _refuseUnknown(
        row,
        _assignmentKeys,
        required: _assignmentKeys,
      );
      if (bad != null) return bad;
      if (_permissionById(permissions, '${row['permissionId']}').isEmpty) {
        return FakeResponse.fail(
          404,
          'One or more permissions not found',
          errorCode: 'PERMISSION_NOT_FOUND',
        );
      }
    }

    // **Replaces**, never merges. `assignPermissions` deletes every row for
    // this role inside a transaction and writes the list back, so a partial
    // list silently revokes everything it omits.
    grants[id!] = {for (final row in rows) '${row['permissionId']}'};

    return FakeResponse.ok({'message': 'Permissions assigned successfully'});
  });

  // ── A role's members ─────────────────────────────────────────────────────

  // Not mounted on the server: `RolesController` declares `POST :id/users` and
  // `DELETE :id/users/:userId` and no `GET`, so Nest answers 404. Registered
  // explicitly rather than left unstubbed, because `AppHarness.dispose` fails
  // a flow on an unanswered call and this one is deliberate.
  api.on(
    'GET',
    '/api/roles/:id/users',
    (_) => FakeResponse.fail(404, 'Cannot GET', errorCode: 'NOT_FOUND'),
  );

  api.on('POST', '/api/roles/:id/users', (request) {
    final id = request.pathParams['id']!;
    if (!roles.any((entry) => entry['id'] == id)) {
      return FakeResponse.fail(404, 'Role not found');
    }

    final refusal = _refuseUnknown(
      request.jsonBody,
      const {'userId'},
      required: const {'userId'},
    );
    if (refusal != null) return refusal;

    final userId = '${request.jsonBody['userId']}';
    if (personById(userId) == null) {
      return FakeResponse.fail(404, 'User not found', errorCode: 'USER_NOT_FOUND');
    }

    // The join row only. The person's `role` column is deliberately left
    // alone, because that is what the server does — and it is why the editor's
    // member list keeps an addition locally rather than refetching it.
    memberships.putIfAbsent(id, () => <String>{}).add(userId);
    return FakeResponse.ok({'message': 'User assigned to role successfully'});
  });

  api.on('DELETE', '/api/roles/:id/users/:userId', (request) {
    final id = request.pathParams['id']!;
    final userId = request.pathParams['userId']!;
    if (!roles.any((entry) => entry['id'] == id)) {
      return FakeResponse.fail(404, 'Role not found');
    }
    if (personById(userId) == null) {
      return FakeResponse.fail(404, 'User not found', errorCode: 'USER_NOT_FOUND');
    }
    memberships[id]?.remove(userId);
    return FakeResponse.ok({'message': 'User removed from role successfully'});
  });

  // ── Departments, for the form's picker ───────────────────────────────────

  api.on('GET', '/api/settings/departments', (_) => FakeResponse.ok(_departments));

  // ── The directory: /api/users ────────────────────────────────────────────
  //
  // Registered before `/api/users/staff` on purpose. `FakeApi.on` inserts at
  // the head of the list, so the **last** registration is matched first — and
  // `/api/users/:id` would otherwise swallow `/api/users/staff` and answer it
  // with "user not found".

  api.on('GET', '/api/users/:id', (request) {
    final person = personById(request.pathParams['id']);
    return person == null
        ? FakeResponse.fail(404, 'User not found', errorCode: 'USER_NOT_FOUND')
        : FakeResponse.ok(person);
  });

  api.on('PUT', '/api/users/:id', (request) {
    final id = request.pathParams['id'];
    final index = people.indexWhere((person) => person['id'] == id);
    if (index == -1) {
      return FakeResponse.fail(404, 'User not found', errorCode: 'USER_NOT_FOUND');
    }

    // `UpdateUserDto extends PartialType(OmitType(CreateUserDto, ['password',
    // 'email']))`. Either of those keys here is a 400, and so is `fullName` —
    // the other route's spelling, and the mistake this whole module exists to
    // stop.
    final refusal = _refuseUnknown(request.jsonBody, _updateUserKeys);
    if (refusal != null) return refusal;

    final body = Map<String, Object?>.from(request.jsonBody);
    // The service recomputes `fullName` from the halves rather than storing
    // what it was sent.
    final first = body['firstName'] ?? people[index]['firstName'];
    final last = body['lastName'] ?? people[index]['lastName'];
    body['fullName'] = '${first ?? ''} ${last ?? ''}'.trim();

    people[index] = {...people[index], ...body};
    _syncMembership(memberships, roles, people[index]);
    return FakeResponse.ok(people[index]);
  });

  api.on('DELETE', '/api/users/:id', (request) {
    final id = request.pathParams['id'];
    final index = people.indexWhere((person) => person['id'] == id);
    if (index == -1) {
      return FakeResponse.fail(404, 'User not found', errorCode: 'USER_NOT_FOUND');
    }
    people.removeAt(index);
    for (final holders in memberships.values) {
      holders.remove(id);
    }
    // 204, with no body at all. `ApiEnvelope` reads a 2xx with nothing in it
    // as a success with a null payload, which is what makes a successful
    // delete not throw.
    return const FakeResponse(204, null);
  });

  api.on('POST', '/api/users', (request) {
    final refusal = _refuseUnknown(
      request.jsonBody,
      _createUserKeys,
      required: const {'email', 'password', 'firstName', 'lastName'},
    );
    if (refusal != null) return refusal;

    final password = '${request.jsonBody['password']}';
    if (password.length < 8) {
      return FakeResponse.fail(
        400,
        'password must be longer than or equal to 8 characters',
        errorCode: 'VALIDATION_ERROR',
      );
    }
    if (people.any((person) => person['email'] == request.jsonBody['email'])) {
      return FakeResponse.fail(
        409,
        "Email '${request.jsonBody['email']}' is already registered",
        errorCode: 'USER_EMAIL_TAKEN',
      );
    }

    final body = Map<String, Object?>.from(request.jsonBody)..remove('password');
    final created = <String, Object?>{
      'id': 'u-new-${people.length + 1}',
      'organizationId': 'o-1',
      'isActive': true,
      'lastLoginAt': null,
      'createdAt': _minutesAgo(0),
      ...body,
      'fullName': '${body['firstName'] ?? ''} ${body['lastName'] ?? ''}'.trim(),
    };
    people.insert(0, created);
    _syncMembership(memberships, roles, created);
    return FakeResponse.ok(created);
  });

  api.on('GET', '/api/users', (request) {
    // `PaginationDto` and nothing else. A `search` or a `role` here is a 400
    // for the whole request — the single fact the directory's in-memory
    // narrowing exists to work around.
    final unknown =
        request.query.keys.where((key) => !_paginationKeys.contains(key));
    if (unknown.isNotEmpty) {
      return _propertyRefusal(unknown);
    }

    final page = int.tryParse(request.query['page'] ?? '1') ?? 1;
    final limit = int.tryParse(request.query['limit'] ?? '20') ?? 20;
    final start = (page - 1) * limit;
    final rows = start >= people.length
        ? const <Map<String, Object?>>[]
        : people.skip(start).take(limit).toList();

    return FakeResponse.page(
      rows,
      page: page,
      limit: limit,
      total: people.length,
    );
  });

  // Last, so it wins over `/api/users/:id` above. Gated on `PATIENT_READ` on
  // the server rather than `USER_READ`, which is why the role editor can reach
  // it when neither directory route will answer.
  api.on('GET', '/api/users/staff', (request) {
    final role = request.query['role'];
    final rows = people
        .where((person) => person['isActive'] != false)
        .where((person) => role == null || role.isEmpty || person['role'] == role)
        .toList();
    // A slim projection: `findStaff` selects five columns and orders by name.
    return FakeResponse.ok([
      for (final person in rows..sort(_byName))
        {
          'id': person['id'],
          'fullName': person['fullName'],
          'email': person['email'],
          'role': person['role'],
          'specialization': person['specialization'],
        },
    ]);
  });

  // ── The fallback directory: /api/settings/users ──────────────────────────
  //
  // The route an ADMIN reaches when the roles guard on `GET /api/users`
  // refuses them. Same people, a different write shape, and **no pagination at
  // all** — `findAllUsers` answers a bare array of the whole organisation.

  api.on('GET', '/api/settings/users/:id', (request) {
    final person = personById(request.pathParams['id']);
    return person == null
        ? FakeResponse.fail(404, 'User not found', errorCode: 'USER_NOT_FOUND')
        : FakeResponse.ok(_withDepartment(person));
  });

  api.on('PUT', '/api/settings/users/:id', (request) {
    final id = request.pathParams['id'];
    final index = people.indexWhere((person) => person['id'] == id);
    if (index == -1) {
      return FakeResponse.fail(404, 'User not found', errorCode: 'USER_NOT_FOUND');
    }

    // `UpdateSettingsUserDto`: one `fullName`, never `firstName`/`lastName`,
    // and `isActive` — which the other route's DTO does not have at all.
    final refusal = _refuseUnknown(request.jsonBody, _updateSettingsUserKeys);
    if (refusal != null) return refusal;

    people[index] = {...people[index], ...request.jsonBody};
    _syncMembership(memberships, roles, people[index]);
    return FakeResponse.ok(_withDepartment(people[index]));
  });

  api.on('DELETE', '/api/settings/users/:id', (request) {
    final id = request.pathParams['id'];
    final index = people.indexWhere((person) => person['id'] == id);
    if (index == -1) {
      return FakeResponse.fail(404, 'User not found', errorCode: 'USER_NOT_FOUND');
    }
    people.removeAt(index);
    for (final holders in memberships.values) {
      holders.remove(id);
    }
    // 200 with a body here, unlike the 204 on the other route.
    return FakeResponse.ok({'success': true, 'message': 'User deleted successfully'});
  });

  api.on('POST', '/api/settings/users', (request) {
    final refusal = _refuseUnknown(
      request.jsonBody,
      _createSettingsUserKeys,
      // `role` is `@IsNotEmpty()` on this DTO and optional on the other one.
      required: const {'fullName', 'email', 'role'},
    );
    if (refusal != null) return refusal;

    final password = '${request.jsonBody['password'] ?? ''}';
    if (password.isEmpty) {
      // The service's own refusal. Without a password the row is created and
      // the person can never sign in, and there is no invitation flow.
      return FakeResponse.fail(
        400,
        'Set an initial password for this account. Emailed invitations are '
            'not implemented.',
        errorCode: 'INVITATION_NOT_IMPLEMENTED',
      );
    }
    if (password.length < 8) {
      return FakeResponse.fail(
        400,
        'password must be longer than or equal to 8 characters',
        errorCode: 'VALIDATION_ERROR',
      );
    }
    if (people.any((person) => person['email'] == request.jsonBody['email'])) {
      return FakeResponse.fail(
        409,
        'Email already in use',
        errorCode: 'USER_EMAIL_TAKEN',
      );
    }

    final body = Map<String, Object?>.from(request.jsonBody)..remove('password');
    final created = <String, Object?>{
      'id': 'u-new-${people.length + 1}',
      'organizationId': 'o-1',
      'isActive': true,
      'lastLoginAt': null,
      'createdAt': _minutesAgo(0),
      ...body,
    };
    people.insert(0, created);
    _syncMembership(memberships, roles, created);
    return FakeResponse.ok(_withDepartment(created));
  });

  api.on('GET', '/api/settings/users', (request) {
    final role = request.query['role'];
    final rows = people
        .where((person) => role == null || role.isEmpty || person['role'] == role)
        .map(_withDepartment)
        .toList();
    // A bare array. `findAllUsers` has no pagination at all, so a fixture that
    // paged it here would be testing a shape the server never sends.
    return FakeResponse.ok(rows);
  });
}

// ── DTO vocabularies ────────────────────────────────────────────────────────
//
// Copied from the DTO files, by hand, and checked against a request the way
// `forbidNonWhitelisted` checks it. A key that is not here is a 400 — which is
// the whole reason the two staff routes need two drafts.

/// `PaginationDto`. No `search`, and no `role`.
const Set<String> _paginationKeys = {'page', 'limit', 'orderBy', 'orderDir'};

/// `CreateUserDto` — `hms_v2/src/modules/users/dto/user.dto.ts`.
const Set<String> _createUserKeys = {
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

/// `UpdateUserDto` — the same, minus the two credentials, all optional. No
/// `fullName` and no `isActive`: neither exists on this DTO.
final Set<String> _updateUserKeys =
    _createUserKeys.difference(const {'email', 'password'});

/// `CreateSettingsUserDto` — `hms_v2/src/modules/settings/dto/settings.dto.ts`.
const Set<String> _createSettingsUserKeys = {
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

/// `UpdateSettingsUserDto` — no `organizationId`, no `email`, no `password`.
final Set<String> _updateSettingsUserKeys = _createSettingsUserKeys
    .difference(const {'organizationId', 'email', 'password'});

/// `UpdateRoleDto`.
const Set<String> _updateRoleKeys = {'name', 'description'};

/// `PermissionAssignmentDto`. All five are `@IsBoolean()`/`@IsString()` and
/// **required**, so a row that drops one fails the whole assignment.
const Set<String> _assignmentKeys = {
  'permissionId',
  'canRead',
  'canUpdate',
  'canCreate',
  'canDelete',
};

/// The server's answer to a body that carries a key its DTO does not declare,
/// or drops one it requires.
FakeResponse? _refuseUnknown(
  Map<String, dynamic> body,
  Set<String> allowed, {
  Set<String> required = const {},
}) {
  final unknown = body.keys.where((key) => !allowed.contains(key));
  if (unknown.isNotEmpty) return _propertyRefusal(unknown);

  final missing = required.where(
    (key) => body[key] == null || '${body[key]}'.trim().isEmpty,
  );
  if (missing.isNotEmpty) {
    return FakeResponse.fail(
      400,
      '${missing.join(', ')} should not be empty',
      errorCode: 'VALIDATION_ERROR',
    );
  }
  return null;
}

/// `ValidationPipe`'s own wording for a non-whitelisted property.
FakeResponse _propertyRefusal(Iterable<String> keys) => FakeResponse.fail(
      400,
      keys.map((key) => 'property $key should not exist').join(', '),
      errorCode: 'VALIDATION_ERROR',
    );

FakeResponse _systemProtected() => FakeResponse.fail(
      403,
      'Cannot modify system roles',
      errorCode: 'ROLE_SYSTEM_PROTECTED',
    );

// ── The department ──────────────────────────────────────────────────────────

/// Ten people, so the directory has somebody in every shape it draws.
///
/// `d-1`, `d-2` and `d-3` are the same three clinicians the appointment,
/// consultation and laboratory fixtures already name, with the same ids — a
/// directory that invented its own doctors would put two departments in one
/// world.
///
/// One row is **inactive**, because an account nobody can sign in with looks
/// exactly like one that works until the row says so in a word.
List<Map<String, Object?>> _buildPeople() => [
      _person(
        id: 'u-1',
        first: 'Adaeze',
        last: 'Nwosu',
        email: 'a.nwosu@example.org',
        role: 'SUPER_ADMIN',
        department: 'dept-1',
        employeeId: 'EMP-0001',
        minutesAgo: 60 * 24 * 300,
      ),
      _person(
        id: 'u-2',
        first: 'Martin',
        last: 'Oyelaran',
        email: 'm.oyelaran@example.org',
        role: 'ADMIN',
        department: 'dept-1',
        employeeId: 'EMP-0012',
        minutesAgo: 60 * 24 * 240,
      ),
      _person(
        id: 'd-1',
        first: 'Amara',
        last: 'Okonkwo',
        fullName: 'Dr Amara Okonkwo',
        email: 'a.okonkwo@example.org',
        role: 'DOCTOR',
        department: 'dept-2',
        specialization: 'Emergency medicine',
        licence: 'GMC-7741204',
        employeeId: 'EMP-0031',
        minutesAgo: 60 * 24 * 200,
      ),
      _person(
        id: 'd-2',
        first: 'Priya',
        last: 'Raman',
        fullName: 'Dr Priya Raman',
        email: 'p.raman@example.org',
        role: 'DOCTOR',
        department: 'dept-2',
        specialization: 'Acute medicine',
        licence: 'GMC-8812470',
        employeeId: 'EMP-0032',
        minutesAgo: 60 * 24 * 190,
      ),
      _person(
        id: 'd-3',
        first: 'Samuel',
        last: 'Achterberg',
        fullName: 'Dr Samuel Achterberg',
        email: 's.achterberg@example.org',
        role: 'DOCTOR',
        department: 'dept-3',
        specialization: 'Orthopaedics',
        licence: 'GMC-5540912',
        employeeId: 'EMP-0033',
        minutesAgo: 60 * 24 * 180,
      ),
      // The hospital's own role rather than the built-in one, so the custom
      // role in the editor has somebody in it — a revoke confirmation that can
      // only say "nobody holds this yet" proves nothing about the sentence it
      // exists to get right.
      _person(
        id: 'u-4',
        first: 'Beatrice',
        last: 'Achieng',
        email: 'b.achieng@example.org',
        role: 'WARD_NURSE',
        department: 'dept-4',
        licence: 'NMC-55019',
        employeeId: 'EMP-0044',
        minutesAgo: 60 * 24 * 120,
      ),
      _person(
        id: 'u-6',
        first: 'Grace',
        last: 'Otieno',
        email: 'g.otieno@example.org',
        role: 'NURSE',
        department: 'dept-4',
        licence: 'NMC-61204',
        employeeId: 'EMP-0046',
        minutesAgo: 60 * 24 * 100,
      ),
      _person(
        id: 'u-5',
        first: 'Kofi',
        last: 'Mensah',
        email: 'k.mensah@example.org',
        role: 'RECEPTIONIST',
        department: 'dept-5',
        employeeId: 'EMP-0057',
        minutesAgo: 60 * 24 * 90,
      ),
      _person(
        id: 'u-7',
        first: 'Samuel',
        last: 'Adeyinka',
        email: 's.adeyinka@example.org',
        role: 'LAB_TECHNICIAN',
        department: 'dept-6',
        licence: 'HCPC-BS40219',
        employeeId: 'EMP-0078',
        minutesAgo: 60 * 24 * 60,
      ),
      // The one nobody can sign in with. Its row has to say so in a word.
      _person(
        id: 'u-9',
        first: 'Rosa',
        last: 'Iglesias',
        email: 'r.iglesias@example.org',
        role: 'BILLING_STAFF',
        department: 'dept-7',
        employeeId: 'EMP-0091',
        minutesAgo: 60 * 24 * 30,
        isActive: false,
        neverSignedIn: true,
      ),
    ];

Map<String, Object?> _person({
  required String id,
  required String first,
  required String last,
  required String email,
  required String role,
  required String department,
  required String employeeId,
  required int minutesAgo,
  String? fullName,
  String? specialization,
  String? licence,
  bool isActive = true,
  bool neverSignedIn = false,
}) =>
    {
      'id': id,
      'organizationId': 'o-1',
      'email': email,
      // Both spellings, because `/api/users` stores all three columns: the two
      // halves and the joined name the service recomputes from them.
      'firstName': first,
      'lastName': last,
      'fullName': fullName ?? '$first $last',
      'phone': '+44 7700 9001${id.hashCode.abs() % 90 + 10}',
      'dateOfBirth': null,
      'gender': null,
      'address': null,
      'employeeId': employeeId,
      'role': role,
      'departmentId': department,
      'specialization': specialization,
      'licenseNumber': licence,
      'defaultCalendar': 'gregorian',
      'isActive': isActive,
      // Null rather than a date: an account nobody has ever used must not
      // report the day it was created as a sign-in.
      'lastLoginAt': neverSignedIn ? null : _minutesAgo(minutesAgo ~/ 8),
      'createdAt': _minutesAgo(minutesAgo),
      'updatedAt': _minutesAgo(minutesAgo ~/ 2),
    };

/// The settings route joins the department; the paged route does not.
Map<String, Object?> _withDepartment(Map<String, Object?> person) {
  final id = person['departmentId'];
  final department = _departments.firstWhere(
    (entry) => entry['id'] == id,
    orElse: () => const <String, Object?>{},
  );
  return {
    ...person,
    'department': department.isEmpty
        ? null
        : {'id': department['id'], 'name': department['name']},
  };
}

const List<Map<String, Object?>> _departments = [
  {'id': 'dept-1', 'organizationId': 'o-1', 'name': 'Administration', 'code': 'ADMIN', 'isActive': true},
  {'id': 'dept-2', 'organizationId': 'o-1', 'name': 'Emergency', 'code': 'ED', 'isActive': true},
  {'id': 'dept-3', 'organizationId': 'o-1', 'name': 'Orthopaedics', 'code': 'ORTHO', 'isActive': true},
  {'id': 'dept-4', 'organizationId': 'o-1', 'name': 'Acute Medical', 'code': 'AMU', 'isActive': true},
  {'id': 'dept-5', 'organizationId': 'o-1', 'name': 'Front desk', 'code': 'FD', 'isActive': true},
  {'id': 'dept-6', 'organizationId': 'o-1', 'name': 'Laboratory', 'code': 'LAB', 'isActive': true},
  {'id': 'dept-7', 'organizationId': 'o-1', 'name': 'Finance', 'code': 'FIN', 'isActive': true},
];

// ── Roles ───────────────────────────────────────────────────────────────────

/// Eight built-in roles and one this hospital wrote itself.
///
/// Every role a person in this department holds is here, because a picker that
/// cannot offer somebody's own role is a picker that silently rewrites it: the
/// backend rebuilds the join table from the `role` string on every staff write.
///
/// The custom one is the only one the editor can change: the server answers
/// `ROLE_SYSTEM_PROTECTED` to every edit of the others, so a flow that proves
/// the read-only state needs one of each on screen.
List<Map<String, Object?>> _buildRoles() => [
      _role('role-ward-nurse', 'WARD_NURSE', 'Nights on the acute medical unit',
          isSystem: false),
      _role('role-admin', 'ADMIN', 'Runs the site'),
      _role('role-doctor', 'DOCTOR', 'Sees and treats patients'),
      _role('role-nurse', 'NURSE', 'Works the ward and the queue'),
      _role('role-lab', 'LAB_TECHNICIAN', 'Runs the bench'),
      _role('role-receptionist', 'RECEPTIONIST', 'Front desk and appointments'),
      _role('role-pharmacist', 'PHARMACIST', 'Dispenses and counts stock'),
      _role('role-billing', 'BILLING_STAFF', 'Raises bills and takes money'),
      _role('role-super', 'SUPER_ADMIN', 'Bypasses every guard on the server'),
    ];

Map<String, Object?> _role(
  String id,
  String name,
  String description, {
  bool isSystem = true,
}) =>
    {
      'id': id,
      'name': name,
      'description': description,
      'isSystem': isSystem,
      // A system role belongs to no site, which is why it appears for every
      // one of them.
      'organizationId': isSystem ? null : 'o-1',
      'createdAt': _minutesAgo(60 * 24 * 365),
    };

/// One `RolePermission` join row, shaped as `findByIdWithPermissions` sends it.
///
/// The four flags mirror the permission's own action, because that is how the
/// access map `/auth/me` builds gets its shape — and it is **not** how the
/// guard authorises, which asks only whether the row exists at all.
Map<String, Object?> _joinRow(
  Map<String, Object?> role,
  Map<String, Object?> permission,
) {
  final action = '${permission['action']}';
  return {
    'id': 'rp-${role['id']}-${permission['id']}',
    'roleId': role['id'],
    'permissionId': permission['id'],
    'role': role['name'],
    'canCreate': action == 'create',
    'canRead': action == 'read',
    'canUpdate': action == 'update',
    'canDelete': action == 'delete',
    'permission': permission,
  };
}

Map<String, Object?> _permissionById(
  List<Map<String, Object?>> permissions,
  String id,
) =>
    permissions.firstWhere(
      (entry) => entry['id'] == id,
      orElse: () => const <String, Object?>{},
    );

/// What each role starts with, as permission ids.
///
/// `WARD_NURSE` is the interesting one: it reads patients and works the queue,
/// the ward and pre-triage — so taking `patients:read` away from it in the
/// editor is a change with consequences a confirmation can name.
Map<String, Set<String>> _buildGrants(List<Map<String, Object?>> permissions) {
  Set<String> pick(List<String> codes) => {
        for (final permission in permissions)
          if (codes.contains(permission['code'])) '${permission['id']}',
      };

  return {
    'role-ward-nurse': pick(const [
      'patients:read',
      'queue:read',
      'queue:create',
      'queue:update',
      'inpatient:read',
      'inpatient:create',
      'inpatient:update',
      'pre-triage:read',
      'pre-triage:create',
      'dashboard:read',
    ]),
    'role-admin': pick(const [
      'users:create',
      'users:read',
      'users:update',
      'users:delete',
      'roles:read',
      'patients:read',
      'settings:read',
      'settings:update',
      'dashboard:read',
    ]),
    'role-doctor': pick(const [
      'patients:read',
      'patients:create',
      'patients:update',
      'consultations:read',
      'consultations:create',
      'consultations:update',
      'laboratory:read',
      'laboratory:create',
      'dashboard:read',
    ]),
    'role-nurse': pick(const [
      'patients:read',
      'queue:read',
      'queue:create',
      'queue:update',
      'inpatient:read',
      'dashboard:read',
    ]),
    'role-lab': pick(const [
      'laboratory:read',
      'laboratory:create',
      'laboratory:update',
      'patients:read',
      'dashboard:read',
    ]),
    'role-receptionist': pick(const [
      'patients:read',
      'patients:create',
      'appointments:read',
      'appointments:create',
      'appointments:update',
      'queue:read',
      'queue:create',
      'dashboard:read',
    ]),
  };
}

/// The join table, seeded from each person's `role` column.
///
/// Which is exactly how the server seeds it — `create` and `update` both look
/// the role up by name and rewrite the rows — and exactly why the two can
/// afterwards diverge.
Map<String, Set<String>> _buildMemberships(
  List<Map<String, Object?>> roles,
  List<Map<String, Object?>> people,
) {
  final out = <String, Set<String>>{for (final role in roles) '${role['id']}': {}};
  for (final person in people) {
    final role = roles.firstWhere(
      (entry) => entry['name'] == person['role'],
      orElse: () => const <String, Object?>{},
    );
    if (role.isEmpty) continue;
    out['${role['id']}']!.add('${person['id']}');
  }
  return out;
}

/// Keeps the join table in step with a person's `role` column after a write,
/// the way `UserService.update` does: every row for that user is deleted and
/// one is written for the named role.
void _syncMembership(
  Map<String, Set<String>> memberships,
  List<Map<String, Object?>> roles,
  Map<String, Object?> person,
) {
  final id = '${person['id']}';
  final role = roles.firstWhere(
    (entry) => entry['name'] == person['role'],
    orElse: () => const <String, Object?>{},
  );
  for (final holders in memberships.values) {
    holders.remove(id);
  }
  if (role.isEmpty) return;
  memberships.putIfAbsent('${role['id']}', () => <String>{}).add(id);
}

// ── Permissions ─────────────────────────────────────────────────────────────

/// The catalogue, as the seed writes it: `category` is the resource and `code`
/// is `<resource>:<action>`.
///
/// Three shapes on purpose:
///
///   * most modules carry all four verbs;
///   * `dashboard` and `audit` carry **only** read, so the editor has to leave
///     three switches off the card rather than draw controls that cannot do
///     anything;
///   * `permissions` carries an `assign` action that is not one of the four,
///     so the editor has to draw it as its own row rather than drop it — and a
///     dropped row is a revoked permission on the next save.
List<Map<String, Object?>> _buildPermissions() => [
      ..._crud('patients', 'PATIENT'),
      ..._crud('appointments', 'APPOINTMENT'),
      ..._crud('consultations', 'CONSULTATION'),
      ..._crud('pre-triage', 'PRE_TRIAGE'),
      ..._crud('queue', 'QUEUE'),
      ..._crud('inpatient', 'INPATIENT'),
      ..._crud('laboratory', 'LABORATORY'),
      ..._crud('billing', 'BILLING'),
      ..._crud('users', 'USER'),
      ..._crud('roles', 'ROLE'),
      _permission('permissions', 'PERMISSION', 'read'),
      _permission('permissions', 'PERMISSION', 'assign'),
      _permission('settings', 'SETTINGS', 'read'),
      _permission('settings', 'SETTINGS', 'update'),
      _permission('dashboard', 'DASHBOARD', 'read'),
      _permission('audit', 'AUDIT', 'read'),
    ];

List<Map<String, Object?>> _crud(String category, String prefix) => [
      for (final action in const ['create', 'read', 'update', 'delete'])
        _permission(category, prefix, action),
    ];

Map<String, Object?> _permission(
  String category,
  String prefix,
  String action,
) =>
    {
      // The permission's **own** id, under `id`, with no `permissionId` beside
      // it — which is the shape `GET /api/permissions` answers and the one a
      // role editor has to normalise before it can post an assignment.
      'id': 'perm-$category-$action',
      'name': '${prefix}_${action.toUpperCase()}',
      'code': '$category:$action',
      'category': category,
      'resource': category,
      'action': action,
      'description': '${action[0].toUpperCase()}${action.substring(1)} '
          '$category records',
      'isDeleted': false,
    };

// ── Builders ────────────────────────────────────────────────────────────────

int _byName(Map<String, Object?> a, Map<String, Object?> b) =>
    '${a['fullName']}'.compareTo('${b['fullName']}');

// Every timestamp comes off `AppClock`, which the harness freezes. Wall-clock
// time here would be silently wrong: "signed in 40 days ago" computed against
// `DateTime.now()` is in the future relative to a clock frozen in 2026, and a
// record screen would report a sign-in that has not happened.
String _minutesAgo(int minutes) => AppClock.now()
    .toUtc()
    .subtract(Duration(minutes: minutes))
    .toIso8601String();
