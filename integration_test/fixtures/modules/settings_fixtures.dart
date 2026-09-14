import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';
import '../world_roles.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the site's own configuration, in fixtures
///
/// One hospital, configured the way the seeded demo is: India-first money, a
/// 24-hour clock, four departments with real people heading them.
///
/// **`PUT /settings/organization` merges here for real.** That is the whole
/// point of this file. The route takes a *partial* patch and deep-merges it
/// leaf by leaf — see `mergeOrganizationSettings` in
/// `hms_v2/src/modules/settings/organization-settings.ts` — and every settings
/// screen in the app depends on that: the Appearance screen sends two keys, the
/// Locale screen sends fourteen, and neither may stamp the other's. A fixture
/// that answered a fixed record would let a screen posting its whole form pass
/// while quietly overwriting the working hours a receptionist set an hour
/// earlier on the web.
///
/// **`PUT /settings/modules` replaces rather than merges**, exactly as the
/// handler does (`JSON.stringify(dto.modulesEnabled)`), so a screen that sends
/// only the switches it shows is caught deleting the keys it does not.
///
/// The record is mutable and rebuilt per install, so one flow's save is not
/// visible to the next flow in the same file.
/// ─────────────────────────────────────────────────────────────────────────────

/// Registers every settings route the app calls. Called from `World.install`.
void installSettingsFixtures(FakeApi api) {
  // Per install, not per library: these are written to.
  final organization = _buildOrganization();
  final departments = _buildDepartments();

  // ── The organisation ─────────────────────────────────────────────────────

  api.on('GET', '/api/settings/organization', (_) {
    return FakeResponse.ok(_clone(organization));
  });

  api.on('PUT', '/api/settings/organization', (request) {
    final patch = request.body is Map
        ? (request.body! as Map).cast<String, Object?>()
        : <String, Object?>{};

    // `updateOrganization` destructures `{id, settings, modulesEnabled,
    // ...updateData}`: the branding keys are assigned, `settings` is merged and
    // `modulesEnabled` is replaced. `id` never lands — it is SUPER_ADMIN-only
    // and ignored for everyone else.
    for (final entry in patch.entries) {
      if (entry.key == 'id' ||
          entry.key == 'settings' ||
          entry.key == 'modulesEnabled') {
        continue;
      }
      organization[entry.key] = entry.value;
    }

    if (patch['settings'] is Map) {
      organization['settings'] = _mergeSettings(
        (organization['settings']! as Map).cast<String, Object?>(),
        (patch['settings']! as Map).cast<String, Object?>(),
      );
    }

    if (patch['modulesEnabled'] is Map) {
      organization['modulesEnabled'] =
          (patch['modulesEnabled']! as Map).cast<String, Object?>();
    }

    return FakeResponse.ok(_clone(organization));
  });

  // ── The modules ──────────────────────────────────────────────────────────

  api.on('PUT', '/api/settings/modules', (request) {
    final body = request.body is Map
        ? (request.body! as Map).cast<String, Object?>()
        : <String, Object?>{};

    // `UpdateModulesDto` requires both. The 400 is not pedantry: the DTO is
    // `@IsString() @IsNotEmpty()` on `organizationId`, so a screen that forgot
    // to load the organisation would otherwise pass its flow and 400 on a ward.
    final orgId = '${body['organizationId'] ?? ''}';
    if (orgId.isEmpty) {
      return FakeResponse.fail(
        400,
        'organizationId should not be empty',
        errorCode: 'VALIDATION_ERROR',
      );
    }
    if (body['modulesEnabled'] is! Map) {
      return FakeResponse.fail(
        400,
        'modulesEnabled must be an object',
        errorCode: 'VALIDATION_ERROR',
      );
    }

    // Replaced whole, the way the handler does it. Nothing merges.
    organization['modulesEnabled'] =
        (body['modulesEnabled']! as Map).cast<String, Object?>();

    return FakeResponse.ok(_clone(organization));
  });

  // ── The flat map ─────────────────────────────────────────────────────────
  //
  // Derived from the record above rather than typed beside it, so a saved
  // setting is visible to anything that reloads. Two hand-written copies would
  // eventually disagree, and a disagreement on any of the three theming keys
  // rebuilds the theme a second time — which is a visible flash and reads as a
  // bug.

  api.on('GET', '/api/settings', (_) {
    return FakeResponse.ok(_flatSettingsOf(organization));
  });

  // ── The marks ────────────────────────────────────────────────────────────

  api.on('POST', '/api/settings/organization/logo', (request) {
    final filename = request.formFiles['file'] ?? '';
    if (filename.isEmpty) {
      // What the route's `FileInterceptor('file')` produces for a part sent
      // under any other name: a 200-shaped request with no file in it.
      return FakeResponse.fail(
        400,
        'No file uploaded',
        errorCode: 'VALIDATION_ERROR',
      );
    }
    final kind = request.formFields['type'] == 'logoText' ? 'wordmark' : 'logo';
    return FakeResponse.ok({'url': '/uploads/org/$kind-$filename'});
  });

  // ── Departments ──────────────────────────────────────────────────────────
  //
  // A **bare array**, with no `meta`: `GET /settings/departments` has no
  // pagination DTO at all and answers one however it is asked. A fixture that
  // paged it here would be testing a shape the server never sends.

  api.on('GET', '/api/settings/departments', (_) {
    return FakeResponse.ok([for (final row in departments) _clone(row)]);
  });

  api.on('GET', '/api/settings/departments/:id', (request) {
    final id = request.pathParams['id'];
    final row = departments.where((d) => d['id'] == id).toList();
    return row.isEmpty
        ? FakeResponse.fail(404, 'Department not found', errorCode: 'NOT_FOUND')
        : FakeResponse.ok(_clone(row.first));
  });

  api.on('POST', '/api/settings/departments', (request) {
    final body = request.body is Map
        ? (request.body! as Map).cast<String, Object?>()
        : <String, Object?>{};

    // `organizationId` is required on create and absent from update. Held to
    // here, because the asymmetry is exactly the kind of thing a draft gets
    // wrong once and nobody notices until a 400 on a ward.
    if ('${body['organizationId'] ?? ''}'.isEmpty) {
      return FakeResponse.fail(
        400,
        'organizationId should not be empty',
        errorCode: 'VALIDATION_ERROR',
      );
    }

    final created = <String, Object?>{
      'id': 'dept-${departments.length + 1}',
      'organizationId': body['organizationId'],
      'name': body['name'] ?? '',
      'code': body['code'],
      'description': body['description'],
      'headId': body['headId'],
      'headName': _staffName('${body['headId'] ?? ''}'),
      'isActive': body['isActive'] ?? true,
      'userCount': 0,
      'createdAt': _now,
    };
    departments.add(created);
    return FakeResponse.ok(_clone(created));
  });

  api.on('PUT', '/api/settings/departments/:id', (request) {
    final id = request.pathParams['id'];
    final index = departments.indexWhere((d) => d['id'] == id);
    if (index == -1) {
      return FakeResponse.fail(
        404,
        'Department not found',
        errorCode: 'NOT_FOUND',
      );
    }

    final body = request.body is Map
        ? (request.body! as Map).cast<String, Object?>()
        : <String, Object?>{};

    // `UpdateDepartmentDto` does not declare `organizationId`, and
    // `forbidNonWhitelisted` is on globally.
    if (body.containsKey('organizationId')) {
      return FakeResponse.fail(
        400,
        'property organizationId should not exist',
        errorCode: 'VALIDATION_ERROR',
      );
    }

    final row = departments[index];
    for (final entry in body.entries) {
      row[entry.key] = entry.value;
    }
    row['headName'] = _staffName('${row['headId'] ?? ''}');
    return FakeResponse.ok(_clone(row));
  });

  api.on('DELETE', '/api/settings/departments/:id', (request) {
    final id = request.pathParams['id'];
    final index = departments.indexWhere((d) => d['id'] == id);
    if (index == -1) {
      return FakeResponse.fail(
        404,
        'Department not found',
        errorCode: 'NOT_FOUND',
      );
    }
    // The server unassigns every user first and then soft-deletes the row.
    // Nobody's account goes with it, which is what the confirm on the form
    // promises — so the fixture drops the row and leaves the staff list alone.
    departments.removeAt(index);
    return const FakeResponse(204, null);
  });
}

// ── The record ──────────────────────────────────────────────────────────────

/// The site, in the shape `/settings/organization` answers with.
///
/// The values agree with the world's own bootstrap on every key the flat
/// settings map carries — both land on the same `SiteSettings` through
/// different parsers, and a disagreement on `theme_preset`,
/// `theme_custom_colors` or `theme_font` would rebuild the theme on the second
/// load. The contact block is new here rather than different: the flat map has
/// no slug, no address and no phone, so nothing can disagree about them.
Map<String, Object?> _buildOrganization() => {
      'id': WorldRole.organizationId,
      'name': 'St Aidan’s General',
      'slug': 'st-aidans-general',
      'logoUrl': '',
      'logoTextUrl': '',
      'primaryColor': '#0E7C7B',
      'secondaryColor': '#F2A65A',
      'email': 'contact@st-aidans.example.org',
      'phone': '+44 1632 960111',
      'address': '14 Wellsbourne Road',
      'city': 'Harrowfield',
      'region': 'West Midlands',
      'country': 'United Kingdom',
      'isActive': true,
      'settings': <String, Object?>{
        'locale': <String, Object?>{
          'currency': 'INR',
          'currencySymbol': '₹',
          'currencyPosition': 'before',
          'decimalSeparator': '.',
          'thousandSeparator': ',',
          'centPrecision': 2,
          'showZeroCents': false,
          // Moment tokens, not ICU — the spelling the console writes and the
          // one `Formatters.icuPattern` exists to translate. A fixture written
          // in ICU would skip the translation the server's own spelling needs.
          'dateFormat': 'DD/MM/YYYY',
          'use24HourClock': true,
          'timezone': 'Asia/Kolkata',
          'language': 'en',
          'calendar': 'gregorian',
        },
        'appearance': <String, Object?>{
          'themePreset': 'default',
          'themeFont': 'montserrat',
          // No `customColors`: the flat route sends an empty
          // `theme_custom_colors`, and a colour here and not there would change
          // the theme signature between the two loads.
        },
        'clinical': <String, Object?>{
          'triageScale': 'p1-p5',
          'waitBreachMinutes': 30,
          'showPatientNames': true,
          'sessionLockMinutes': 5,
        },
        'scheduling': <String, Object?>{
          'workingHours': <String, Object?>{'start': '08:00', 'end': '17:00'},
          'appointmentDuration': 30,
        },
      },
      // Every module on. The shell hides one a site has switched **explicitly
      // off**, and this site has switched nothing off — so a flow about the
      // modules screen turns something off itself and can assert the map that
      // came back.
      'modulesEnabled': <String, Object?>{
        'pharmacy': true,
        'laboratory': true,
        'radiology': true,
        'inpatient': true,
        'inventory': true,
        'accounting': true,
      },
    };

/// Four units, with the heads the staff fixtures already name.
///
/// `userCount` and `headName` are the shape `GET /settings/departments` sends —
/// it builds its own row rather than handing back Prisma's, so there is no
/// `_count` block here and a model that only read one of the two spellings
/// would show every department as uncounted.
List<Map<String, Object?>> _buildDepartments() => [
      {
        'id': 'dept-1',
        'organizationId': WorldRole.organizationId,
        'name': 'Emergency',
        'code': 'ED',
        'description': 'Resuscitation, majors and the triage desk.',
        'headId': 'd-1',
        'headName': 'Dr Amara Okonkwo',
        'isActive': true,
        'userCount': 9,
        'createdAt': _now,
      },
      {
        'id': 'dept-2',
        'organizationId': WorldRole.organizationId,
        'name': 'Acute Medical',
        'code': 'AMU',
        'description': 'The medical take and the short-stay ward.',
        'headId': 'd-2',
        'headName': 'Dr Priya Raman',
        'isActive': true,
        'userCount': 14,
        'createdAt': _now,
      },
      {
        'id': 'dept-3',
        'organizationId': WorldRole.organizationId,
        'name': 'Laboratory',
        'code': 'LAB',
        'description': 'Haematology, chemistry and microbiology.',
        'headId': null,
        'headName': null,
        'isActive': true,
        'userCount': 6,
        'createdAt': _now,
      },
      {
        // Retired rather than removed, so the list has a dimmed row and the
        // "Off" pill on it is exercised by a screenshot.
        'id': 'dept-4',
        'organizationId': WorldRole.organizationId,
        'name': 'Records',
        'code': 'REC',
        'description': 'Medical records and coding.',
        'headId': null,
        'headName': null,
        'isActive': false,
        'userCount': 0,
        'createdAt': _now,
      },
    ];

/// The three clinicians `World._doctors` serves on `/api/users/staff`.
///
/// Named here so a department that is given a head comes back with the head's
/// name on it, the way the live route resolves it — a form that saved a
/// `headId` and got a row with no `headName` would show "Headed by" nothing on
/// the row it just wrote.
const Map<String, String> _staff = {
  'd-1': 'Dr Amara Okonkwo',
  'd-2': 'Dr Priya Raman',
  'd-3': 'Dr Samuel Achterberg',
};

String? _staffName(String id) => id.isEmpty ? null : _staff[id];

// ── The merge ───────────────────────────────────────────────────────────────

const List<String> _groups = ['locale', 'appearance', 'clinical', 'scheduling'];

/// The four groups merged leaf by leaf, with the two nested objects one level
/// deeper — `mergeOrganizationSettings`, in Dart.
///
/// A group the patch does not mention is kept whole. That is what makes a
/// partial save safe, and it is the single behaviour a flow has to be able to
/// prove: send a date format, and the wait-breach threshold three groups away
/// is still there afterwards.
Map<String, Object?> _mergeSettings(
  Map<String, Object?> stored,
  Map<String, Object?> patch,
) {
  final merged = <String, Object?>{..._clone(stored)};

  // Unknown top-level keys ride along. Some other deployment may be storing
  // something here that this version has never heard of, and deleting it
  // because we do not recognise it is data loss nobody notices for a month.
  for (final entry in patch.entries) {
    if (_groups.contains(entry.key)) continue;
    merged[entry.key] = entry.value;
  }

  for (final group in _groups) {
    final current = merged[group] is Map
        ? (merged[group]! as Map).cast<String, Object?>()
        : <String, Object?>{};
    final next = patch[group] is Map
        ? (patch[group]! as Map).cast<String, Object?>()
        : <String, Object?>{};

    if (next.isEmpty) {
      merged[group] = current;
      continue;
    }

    final combined = <String, Object?>{...current};
    for (final entry in next.entries) {
      if (entry.key == 'workingHours' || entry.key == 'customColors') {
        if (entry.value == null) {
          combined[entry.key] = null;
          continue;
        }
        final base = combined[entry.key] is Map
            ? (combined[entry.key]! as Map).cast<String, Object?>()
            : <String, Object?>{};
        combined[entry.key] = <String, Object?>{
          ...base,
          ...(entry.value! as Map).cast<String, Object?>(),
        };
        continue;
      }
      combined[entry.key] = entry.value;
    }
    merged[group] = combined;
  }

  return merged;
}

/// The resolved settings as the flat `{key: value}` map `GET /api/settings`
/// serves — `toSiteSettingsMap`, in Dart.
///
/// **All strings.** The route answers strings and nothing else, which is what
/// puts `SiteSettings`' coercion on the path: a fixture sending `30` and `true`
/// as an int and a bool tests a shape the server does not send.
Map<String, String> _flatSettingsOf(Map<String, Object?> organization) {
  final settings = (organization['settings']! as Map).cast<String, Object?>();
  final locale = (settings['locale']! as Map).cast<String, Object?>();
  final appearance =
      (settings['appearance']! as Map).cast<String, Object?>();
  final clinical = (settings['clinical']! as Map).cast<String, Object?>();
  final scheduling = (settings['scheduling']! as Map).cast<String, Object?>();
  final hours = (scheduling['workingHours']! as Map).cast<String, Object?>();

  final custom = appearance['customColors'] is Map
      ? (appearance['customColors']! as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final customColors = [
    '${custom['primary'] ?? ''}',
    '${custom['secondary'] ?? ''}',
    '${custom['accent'] ?? ''}',
  ].where((value) => value.isNotEmpty).join(',');

  return {
    'site_name': '${organization['name'] ?? ''}',
    'site_logo': '${organization['logoUrl'] ?? ''}',
    'logo_text_url': '${organization['logoTextUrl'] ?? ''}',
    'primary_color': '${organization['primaryColor'] ?? ''}',
    'secondary_color': '${organization['secondaryColor'] ?? ''}',
    'theme_preset': '${appearance['themePreset']}',
    'theme_custom_colors': customColors,
    'theme_font': '${appearance['themeFont']}',
    'triage_scale': '${clinical['triageScale']}',
    'wait_breach_minutes': '${clinical['waitBreachMinutes']}',
    'show_patient_names': '${clinical['showPatientNames']}',
    'session_lock_minutes': '${clinical['sessionLockMinutes']}',
    'default_currency_code': '${locale['currency']}',
    'currency_symbol': '${locale['currencySymbol']}',
    'currency_position': '${locale['currencyPosition']}',
    'decimal_sep': '${locale['decimalSeparator']}',
    'thousand_sep': '${locale['thousandSeparator']}',
    'cent_precision': '${locale['centPrecision']}',
    'zero_format': '${locale['showZeroCents']}',
    'date_format': '${locale['dateFormat']}',
    'use_24_hour_clock': '${locale['use24HourClock']}',
    'timezone': '${locale['timezone']}',
    'language': '${locale['language']}',
    'calendar': '${locale['calendar']}',
    'working_hours_start': '${hours['start']}',
    'working_hours_end': '${hours['end']}',
    'appointment_duration': '${scheduling['appointmentDuration']}',
  };
}

/// A deep copy, so a handler hands out a snapshot rather than the live record.
///
/// Without it a flow asserting on a response it captured earlier would watch
/// that response change under it the next time anything saved.
Map<String, Object?> _clone(Map<String, Object?> value) => {
      for (final entry in value.entries)
        entry.key: entry.value is Map
            ? _clone((entry.value! as Map).cast<String, Object?>())
            : entry.value,
    };

/// Every timestamp comes off `AppClock`, which the harness freezes. Wall-clock
/// time here would be silently wrong in a screenshot taken next week.
String get _now => AppClock.now().toUtc().toIso8601String();
