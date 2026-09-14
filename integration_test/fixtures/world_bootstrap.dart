part of 'world.dart';

/// Who is signed in, and what site this is — the half of the world that
/// changes with the role.
///
/// A `part` of `world.dart` rather than a second library, so the two halves
/// still share one set of builders and one frozen clock: the department there
/// and the identity here have to be the same world, or a screenshot shows a
/// consultant looking at somebody else's ward.
///
/// Everything here answers in the shapes the live API was verified to send.
/// The shapes it *used* to send are still tolerated by the app — `/auth/me` as
/// a bare user, `/api/settings` as an array of `{settingKey, settingValue}`
/// documents — and that is exactly why a fixture must not use them: nothing
/// fails, and the harness quietly stops exercising the contract.
abstract final class _Bootstrap {
  static void install(FakeApi api, WorldRole role) {
    _auth(api, role);
    _settings(api);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static void _auth(FakeApi api, WorldRole role) {
    // `{accessToken, refreshToken, expiresIn, tokenType}` and **no user**. The
    // app names the person it just signed in from the token's own claims and
    // then replaces them from `/auth/me`; a fixture that sends a user here
    // skips both paths, which is how a login screen that cannot read a token
    // still passes its flow.
    api.json('POST', '/api/auth/login', {
      'accessToken': fakeJwtFor(role),
      'refreshToken': World.refreshToken,
      'expiresIn': fakeJwtExpiresIn(),
      'tokenType': 'Bearer',
    });

    // The user, their access map and their organisation in one round trip.
    // `AccessService.load` is the app's only caller and it fans all three out.
    api.json('GET', '/api/auth/me', {
      'user': _user(role),
      'access': role.accessBlock,
      'organization': _organization,
    });

    // The map alone — what `AccessService` falls back to when `/auth/me` is
    // 500ing. Registered even though the route above answers, because a flow
    // that breaks `/auth/me` on purpose needs somewhere for the fallback to
    // land.
    api.json('GET', '/api/auth/me/access', role.accessBlock);

    // 204 and no body, and it *requires* the refresh token in the body. The
    // 400 is not pedantry: `AuthService.revokeToken` returns early when it has
    // no refresh token to send, so a fixture that accepted an empty body would
    // let a regression that stops persisting the refresh token pass as a
    // successful sign-out.
    api.on('POST', '/api/auth/logout', (request) {
      final refresh = switch (request.body) {
        final Map<dynamic, dynamic> body => '${body['refreshToken'] ?? ''}',
        _ => '',
      };
      return refresh.isEmpty
          ? FakeResponse.fail(400, 'refreshToken is required')
          : const FakeResponse(204, null);
    });
  }

  /// The `user` block of `GET /auth/me`.
  static Map<String, Object?> _user(WorldRole role) => {
        'id': role.id,
        'email': role.email,
        'fullName': role.displayName,
        'name': role.displayName,
        'firstName': _firstName(role.displayName),
        'lastName': _lastName(role.displayName),
        'phone': role.phone,
        // The role's *name*, not a populated document. `AuthUser` reads either;
        // this route sends the scalar.
        'role': role.roleName,
        'roles': [role.roleName],
        'permissions': role.permissions,
        'departmentId': role.departmentId,
        'department': {'id': role.departmentId, 'name': role.department},
        // Sent alongside the object, and read in preference to it. A reader
        // that took the map and stringified it printed `{id: …, name: …}` into
        // the shell's header once; both keys here keep that path honest.
        'departmentName': role.department,
        'specialization': role.specialization,
        'licenseNumber': role.licenseNumber,
        'employeeId': role.employeeId,
        'avatar': '',
        'lastLoginAt': World._minutesAgo(6),
      };

  /// The signed-in user as a previous session would have cached them.
  ///
  /// Shaped like `AuthUser.toJson`, because that is what wrote the real one:
  /// seeding the `/auth/me` shape instead would restore a session through a
  /// code path no cold start ever takes.
  static Map<String, Object?> cachedUser(WorldRole role) => {
        'id': role.id,
        'name': role.displayName,
        'email': role.email,
        'roleName': role.roleName,
        'role': role.roleName,
        'roles': [role.roleName],
        'avatar': '',
        'department': role.department,
        'organizationId': WorldRole.organizationId,
        'permissions': role.permissions,
      };

  /// The access map as a previous session would have cached it.
  ///
  /// `isSuperAdmin` is false even for the super admin, deliberately: the server
  /// **expands** that role into every module rather than flagging it, so a map
  /// restored from storage carries seventeen full entries and no flag. Seeding
  /// the flag instead would let a bug in the expansion pass unnoticed.
  static Map<String, Object?> cachedAccess(WorldRole role) => {
        'modules': role.accessModules,
        'isSuperAdmin': false,
      };

  // ── Settings ──────────────────────────────────────────────────────────────

  static void _settings(FakeApi api) {
    // A **flat snake_case map of strings**, which is what this route answers
    // with. It used to be an array of `{settingKey, settingValue}` documents
    // and `SiteSettings.fromResult` still reads those, so the old fixture
    // passed while testing a shape the server no longer sends — and it sent
    // `30` and `true` as an int and a bool, so the string coercion every real
    // setting goes through was never exercised.
    api.json('GET', '/api/settings', _flatSettings);

    // The same site in the other shape, for the dashboard's own read.
    api.json('GET', '/api/settings/organization', _organization);
  }

  /// Every key the live route returns, all of them strings.
  ///
  /// Each one agrees with [_organization] below. They must: both land on the
  /// same `SiteSettings` through different parsers, the splash screen loads
  /// them in parallel, and a disagreement on any of the three theming keys
  /// rebuilds the theme a second time — which is a visible flash and reads as
  /// a bug.
  static const Map<String, String> _flatSettings = {
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
    // Moment tokens, not ICU. `Formatters.icuPattern` translates them, and a
    // fixture written in ICU would skip the translation the server's own
    // spelling needs.
    'date_format': 'DD/MM/YYYY',
    'use_24_hour_clock': 'true',
    'timezone': 'Asia/Kolkata',
    'language': 'en',
    'calendar': 'gregorian',
    'working_hours_start': '08:00',
    'working_hours_end': '17:00',
    'appointment_duration': '30',
  };

  /// The organisation as `/auth/me` and `/settings/organization` send it:
  /// branding at the top, then settings grouped into four.
  ///
  /// No `customColors` under `appearance`, on purpose — `SiteSettings` joins
  /// that trio into the same comma-separated string the flat route sends, and
  /// the flat route sends an empty one. A colour here and not there would
  /// change the theme signature between the two loads.
  static const Map<String, Object?> _organization = {
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
      'appearance': {
        'themePreset': 'default',
        'themeFont': 'montserrat',
      },
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
    // Every module on. The shell hides one a site has switched **explicitly
    // off**, and this site has switched nothing off — so what a role can see
    // is decided by the access map alone, which is the thing a role flow is
    // about. A flow testing a disabled module overrides `/auth/me`.
    'modulesEnabled': {
      'patients': true,
      'appointments': true,
      'consultations': true,
      'pre-triage': true,
      'queue': true,
      'inpatient': true,
      'laboratory': true,
      'radiology': true,
      'pharmacy': true,
      'billing': true,
      'integrations': true,
      'users': true,
      'roles': true,
      'permissions': true,
      'settings': true,
      'dashboard': true,
      'audit': true,
    },
  };

  // ── Names ─────────────────────────────────────────────────────────────────
  //
  // The server stores `firstName` and `lastName` separately and composes
  // `fullName` from them; the fixtures hold the composed name, so these split
  // it back. The honorific comes off first — "Dr" is not a first name, and a
  // greeting that reads "Good afternoon, Dr" is the reason this is not a plain
  // `split(' ').first`.

  static String _firstName(String fullName) {
    final parts = _nameParts(fullName);
    return parts.isEmpty ? '' : parts.first;
  }

  static String _lastName(String fullName) {
    final parts = _nameParts(fullName);
    return parts.length < 2 ? '' : parts.last;
  }

  static List<String> _nameParts(String fullName) => fullName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty && !_honorifics.contains(part))
      .toList();

  static const Set<String> _honorifics = {'Dr', 'Dr.', 'Prof', 'Prof.'};
}
