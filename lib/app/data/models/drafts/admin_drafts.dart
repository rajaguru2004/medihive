
import 'draft_json.dart';

/// A staff account on `/api/users`.
///
/// DTO: `hms_v2/src/modules/users/dto/user.dto.ts`. `UpdateUserDto extends
/// PartialType(OmitType(CreateUserDto, ['password', 'email']))`, so a PATCH
/// accepts every create key **except** those two — an address change and a
/// credential change are different acts with different audit trails.
///
/// Not the same shape as [SettingsUserDraft]: this route splits the name into
/// `firstName`/`lastName`, the settings route takes a single `fullName`. Both
/// exist, both are live, and sending one route the other route's keys is a 400.
class UserDraft {
  const UserDraft({
    this.email,
    this.password,
    this.firstName,
    this.lastName,
    this.phone,
    this.organizationId,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.employeeId,
    this.role,
    this.departmentId,
    this.specialization,
    this.licenseNumber,
    this.defaultCalendar,
  });

  /// Create only.
  final String? email;

  /// Create only. At least 8 characters; the DTO rejects shorter.
  final String? password;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? organizationId;

  /// Typed `@IsString()` rather than `@IsDateString()` on this DTO, so a plain
  /// `yyyy-MM-dd` is what it wants.
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;
  final String? employeeId;

  /// The legacy single-role column. Display only — authorisation is decided by
  /// the permission set, never by this string.
  final String? role;
  final String? departmentId;
  final String? specialization;
  final String? licenseNumber;

  /// `ethiopian` or `gregorian`.
  final String? defaultCalendar;

  UserDraft copyWith({
    String? email,
    String? password,
    String? firstName,
    String? lastName,
    String? phone,
    String? organizationId,
    DateTime? dateOfBirth,
    String? gender,
    String? address,
    String? employeeId,
    String? role,
    String? departmentId,
    String? specialization,
    String? licenseNumber,
    String? defaultCalendar,
  }) =>
      UserDraft(
        email: email ?? this.email,
        password: password ?? this.password,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        organizationId: organizationId ?? this.organizationId,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        address: address ?? this.address,
        employeeId: employeeId ?? this.employeeId,
        role: role ?? this.role,
        departmentId: departmentId ?? this.departmentId,
        specialization: specialization ?? this.specialization,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        defaultCalendar: defaultCalendar ?? this.defaultCalendar,
      );

  Map<String, dynamic> _shared() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'organizationId': organizationId,
        'dateOfBirth': isoDay(dateOfBirth),
        'gender': gender,
        'address': address,
        'employeeId': employeeId,
        'role': role,
        'departmentId': departmentId,
        'specialization': specialization,
        'licenseNumber': licenseNumber,
        'defaultCalendar': defaultCalendar,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'email': email,
        'password': password,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody(_shared());
}

/// A staff account on `/api/settings/users` — the console's route.
///
/// DTO: `CreateSettingsUserDto` / `UpdateSettingsUserDto` in
/// `hms_v2/src/modules/settings/dto/settings.dto.ts`.
///
/// `password` is typed optional and is required in practice: the route used to
/// create accounts with no password at all, which could then never sign in and
/// had no invitation flow to accept. Optional in the type only so the error can
/// name the problem.
///
/// `organizationId` and `email` are create-only.
class SettingsUserDraft {
  const SettingsUserDraft({
    this.organizationId,
    this.fullName,
    this.email,
    this.password,
    this.phone,
    this.employeeId,
    this.role,
    this.departmentId,
    this.specialization,
    this.licenseNumber,
    this.isActive,
  });

  /// Create only.
  final String? organizationId;

  /// One field, not two. This route does not take `firstName`/`lastName`.
  final String? fullName;

  /// Create only.
  final String? email;

  /// Create only.
  final String? password;
  final String? phone;
  final String? employeeId;
  final String? role;
  final String? departmentId;
  final String? specialization;
  final String? licenseNumber;
  final bool? isActive;

  SettingsUserDraft copyWith({
    String? organizationId,
    String? fullName,
    String? email,
    String? password,
    String? phone,
    String? employeeId,
    String? role,
    String? departmentId,
    String? specialization,
    String? licenseNumber,
    bool? isActive,
  }) =>
      SettingsUserDraft(
        organizationId: organizationId ?? this.organizationId,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        password: password ?? this.password,
        phone: phone ?? this.phone,
        employeeId: employeeId ?? this.employeeId,
        role: role ?? this.role,
        departmentId: departmentId ?? this.departmentId,
        specialization: specialization ?? this.specialization,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> _shared() => {
        'fullName': fullName,
        'phone': phone,
        'employeeId': employeeId,
        'role': role,
        'departmentId': departmentId,
        'specialization': specialization,
        'licenseNumber': licenseNumber,
        'isActive': isActive,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'organizationId': organizationId,
        'email': email,
        'password': password,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody(_shared());
}

/// A department being created or edited.
///
/// DTO: `CreateDepartmentDto` / `UpdateDepartmentDto` in
/// `hms_v2/src/modules/settings/dto/settings.dto.ts`.
///
/// `organizationId` is **required** on create and **absent** from update.
/// Asymmetric, and followed rather than smoothed over: sending it on a PUT is a
/// 400, and omitting it on a POST is a 400 the other way.
class DepartmentDraft {
  const DepartmentDraft({
    this.organizationId,
    this.name,
    this.code,
    this.description,
    this.headId,
    this.isActive,
  });

  /// Create only.
  final String? organizationId;
  final String? name;
  final String? code;
  final String? description;
  final String? headId;
  final bool? isActive;

  DepartmentDraft copyWith({
    String? organizationId,
    String? name,
    String? code,
    String? description,
    String? headId,
    bool? isActive,
  }) =>
      DepartmentDraft(
        organizationId: organizationId ?? this.organizationId,
        name: name ?? this.name,
        code: code ?? this.code,
        description: description ?? this.description,
        headId: headId ?? this.headId,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> _shared() => {
        'name': name,
        'code': code,
        'description': description,
        'headId': headId,
        'isActive': isActive,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'organizationId': organizationId,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody(_shared());
}

/// An instrument being wired in or reconfigured.
///
/// DTO: `hms_v2/src/modules/integrations/dto/machine.dto.ts`
/// (`CreateMachineDto` / `UpdateMachineDto`), which is what
/// `/api/integrations/machines` accepts.
///
/// `/api/settings/integrations` has a **second, different** DTO for the same
/// table — `CreateSettingsIntegrationDto` spells the model column
/// `machineModel` and flattens the connection into `ipAddress`, `port`,
/// `apiEndpoint` and `apiKey`. This draft targets the integrations route and
/// its nested `connectionDetails`; a settings-route form needs its own.
///
/// `machineType`, `connectionType` and `organizationId` are create-only: what
/// an analyser *is* and how it speaks are not edits, they are a new
/// integration.
class MachineDraft {
  const MachineDraft({
    this.organizationId,
    this.machineName,
    this.machineType,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.department,
    this.connectionType,
    this.connectionDetails,
    this.testMapping,
    this.isActive,
    this.connectionStatus,
  });

  /// Create only.
  final String? organizationId;
  final String? machineName;

  /// Create only. `lab_analyzer`, `radiology_equipment`, `vital_signs_monitor`
  /// — a Prisma enum, so anything else is a 400.
  final String? machineType;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final String? department;

  /// Create only. `hl7`, `astm`, `rest_api`, `file_upload`, `serial`.
  final String? connectionType;

  /// Host, port, protocol version. Free-form on the backend, so it stays a map
  /// rather than a class that would 400 the first time somebody adds a key.
  final Map<String, dynamic>? connectionDetails;

  /// The analyser's own test codes mapped onto this site's `LabTest` ids.
  final Map<String, dynamic>? testMapping;

  /// Update only.
  final bool? isActive;

  /// Update only. `connected`, `disconnected`, `error`.
  final String? connectionStatus;

  MachineDraft copyWith({
    String? organizationId,
    String? machineName,
    String? machineType,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? department,
    String? connectionType,
    Map<String, dynamic>? connectionDetails,
    Map<String, dynamic>? testMapping,
    bool? isActive,
    String? connectionStatus,
  }) =>
      MachineDraft(
        organizationId: organizationId ?? this.organizationId,
        machineName: machineName ?? this.machineName,
        machineType: machineType ?? this.machineType,
        manufacturer: manufacturer ?? this.manufacturer,
        model: model ?? this.model,
        serialNumber: serialNumber ?? this.serialNumber,
        department: department ?? this.department,
        connectionType: connectionType ?? this.connectionType,
        connectionDetails: connectionDetails ?? this.connectionDetails,
        testMapping: testMapping ?? this.testMapping,
        isActive: isActive ?? this.isActive,
        connectionStatus: connectionStatus ?? this.connectionStatus,
      );

  Map<String, dynamic> _shared() => {
        'machineName': machineName,
        'manufacturer': manufacturer,
        'model': model,
        'serialNumber': serialNumber,
        'department': department,
        'connectionDetails': connectionDetails,
        'testMapping': testMapping,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'organizationId': organizationId,
        'machineType': machineType,
        'connectionType': connectionType,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'isActive': isActive,
        'connectionStatus': connectionStatus,
      });
}

/// A role being created or renamed.
///
/// DTO: `CreateRoleDto` / `UpdateRoleDto` in
/// `hms_v2/src/modules/roles/dto/roles.dto.ts`.
///
/// `organizationId` is create-only — a role cannot be moved between sites. The
/// backend upper-cases whatever `name` it is sent, so `Ward Nurse` and `WARD
/// NURSE` collide; a role editor should say so before the 409 does.
class RoleDraft {
  const RoleDraft({
    this.name,
    this.description,
    this.organizationId,
  });

  final String? name;
  final String? description;

  /// Create only. Null makes a role every site shares.
  final String? organizationId;

  RoleDraft copyWith({
    String? name,
    String? description,
    String? organizationId,
  }) =>
      RoleDraft(
        name: name ?? this.name,
        description: description ?? this.description,
        organizationId: organizationId ?? this.organizationId,
      );

  Map<String, dynamic> toCreateJson() => draftBody({
        'name': name,
        'description': description,
        'organizationId': organizationId,
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        'name': name,
        'description': description,
      });
}

/// One permission as a role is about to hold it.
///
/// DTO: `PermissionAssignmentDto` in
/// `hms_v2/src/modules/roles/dto/roles.dto.ts`. All four verbs are
/// `@IsBoolean()` and **required**, so [toJson] emits every one of them — an
/// unset verb becomes `false` rather than a dropped key, because a dropped key
/// fails the whole assignment and leaves the role as it was.
class RolePermissionDraft {
  const RolePermissionDraft({
    this.permissionId,
    this.canRead,
    this.canUpdate,
    this.canCreate,
    this.canDelete,
  });

  final String? permissionId;
  final bool? canRead;
  final bool? canUpdate;
  final bool? canCreate;
  final bool? canDelete;

  RolePermissionDraft copyWith({
    String? permissionId,
    bool? canRead,
    bool? canUpdate,
    bool? canCreate,
    bool? canDelete,
  }) =>
      RolePermissionDraft(
        permissionId: permissionId ?? this.permissionId,
        canRead: canRead ?? this.canRead,
        canUpdate: canUpdate ?? this.canUpdate,
        canCreate: canCreate ?? this.canCreate,
        canDelete: canDelete ?? this.canDelete,
      );

  Map<String, dynamic> toJson() => draftBody({
        'permissionId': permissionId,
        // Never dropped: the DTO requires all four, and a grant that omits
        // one is a grant the server refuses whole.
        'canRead': canRead ?? false,
        'canUpdate': canUpdate ?? false,
        'canCreate': canCreate ?? false,
        'canDelete': canDelete ?? false,
      });
}

/// A role's whole permission set, replaced in one call.
///
/// DTO: `AssignPermissionsDto` in `hms_v2/src/modules/roles/dto/roles.dto.ts`.
/// One key, `permissions`.
///
/// `PUT /roles/:id/permissions` is the only write, so [toCreateJson] and
/// [toUpdateJson] are the same body. The call **replaces** the set rather than
/// merging into it: a partial list silently revokes everything it omits, which
/// is how a ward loses its patient list halfway through a shift.
class RolePermissionsDraft {
  const RolePermissionsDraft({
    this.permissions,
  });

  final List<RolePermissionDraft>? permissions;

  RolePermissionsDraft copyWith({
    List<RolePermissionDraft>? permissions,
  }) =>
      RolePermissionsDraft(
        permissions: permissions ?? this.permissions,
      );

  Map<String, dynamic> _body() => {
        'permissions': permissions?.map((grant) => grant.toJson()).toList(),
      };

  /// Identical to [toUpdateJson]: assigning permissions is always a PUT.
  Map<String, dynamic> toCreateJson() => draftBody(_body());

  Map<String, dynamic> toUpdateJson() => draftBody(_body());
}

/// The site's own configuration.
///
/// DTO: `UpdateOrganizationDto` in
/// `hms_v2/src/modules/settings/dto/settings.dto.ts`, whose `settings` field is
/// the validated `OrganizationSettingsDto` in
/// `hms_v2/src/modules/settings/dto/organization-settings.dto.ts`.
///
/// `PUT /settings/organization` is the only write, so [toCreateJson] and
/// [toUpdateJson] are the same body.
///
/// The leaves are held flat here and nested on the way out, because a form
/// edits one switch at a time and the backend merges group by group: a group
/// that is not sent is preserved, never overwritten. That is also why an empty
/// group is dropped rather than sent as `{}`.
///
/// `UpdateOrganizationDto` also accepts `id`, documented as SUPER_ADMIN-only
/// and ignored for everyone else. Deliberately absent: it once let any holder
/// of `SETTINGS_UPDATE` rewrite another hospital's configuration by changing
/// one string, and this app has no reason to send it.
///
/// The DTO still accepts a set of deprecated flat aliases — `currency`,
/// `defaultTimezone`, `workingHours` at the settings root. Read as a fallback
/// by `Organization`, never written: the backend lifts them into their groups
/// and discards them, so writing them would fight the migration.
class OrganizationSettingsDraft {
  const OrganizationSettingsDraft({
    this.name,
    this.logoUrl,
    this.logoTextUrl,
    this.primaryColor,
    this.secondaryColor,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.region,
    this.country,
    this.isActive,
    this.modulesEnabled,
    this.currency,
    this.currencySymbol,
    this.currencyPosition,
    this.decimalSeparator,
    this.thousandSeparator,
    this.centPrecision,
    this.showZeroCents,
    this.language,
    this.timezone,
    this.dateFormat,
    this.use24HourClock,
    this.calendar,
    this.themePreset,
    this.themeFont,
    this.customPrimary,
    this.customSecondary,
    this.customAccent,
    this.waitBreachMinutes,
    this.triageScale,
    this.showPatientNames,
    this.sessionLockMinutes,
    this.workingHoursStart,
    this.workingHoursEnd,
    this.appointmentDuration,
  });

  final String? name;
  final String? logoUrl;
  final String? logoTextUrl;

  /// A hex colour. The nested `settings.appearance.customColors` group
  /// validates its three against `#rgb`/`#rrggbb`; these two top-level ones are
  /// plain strings on the DTO.
  final String? primaryColor;
  final String? secondaryColor;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? region;
  final String? country;
  final bool? isActive;

  /// Which modules this site licenses.
  final Map<String, bool>? modulesEnabled;

  /// A 3-letter ISO code; the DTO rejects any other length.
  final String? currency;
  final String? currencySymbol;

  /// `before` or `after`.
  final String? currencyPosition;
  final String? decimalSeparator;
  final String? thousandSeparator;
  final int? centPrecision;
  final bool? showZeroCents;
  final String? language;
  final String? timezone;
  final String? dateFormat;
  final bool? use24HourClock;
  final String? calendar;
  final String? themePreset;
  final String? themeFont;
  final String? customPrimary;
  final String? customSecondary;
  final String? customAccent;

  /// Zero is a value, and the DTO documents it: it turns the breach flag off
  /// for sites that escalate out of band.
  final int? waitBreachMinutes;
  final String? triageScale;
  final bool? showPatientNames;

  /// Zero never locks the device.
  final int? sessionLockMinutes;

  /// `08:00`. The DTO matches a 24-hour clock and rejects anything else.
  final String? workingHoursStart;
  final String? workingHoursEnd;
  final int? appointmentDuration;

  OrganizationSettingsDraft copyWith({
    String? name,
    String? logoUrl,
    String? logoTextUrl,
    String? primaryColor,
    String? secondaryColor,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? region,
    String? country,
    bool? isActive,
    Map<String, bool>? modulesEnabled,
    String? currency,
    String? currencySymbol,
    String? currencyPosition,
    String? decimalSeparator,
    String? thousandSeparator,
    int? centPrecision,
    bool? showZeroCents,
    String? language,
    String? timezone,
    String? dateFormat,
    bool? use24HourClock,
    String? calendar,
    String? themePreset,
    String? themeFont,
    String? customPrimary,
    String? customSecondary,
    String? customAccent,
    int? waitBreachMinutes,
    String? triageScale,
    bool? showPatientNames,
    int? sessionLockMinutes,
    String? workingHoursStart,
    String? workingHoursEnd,
    int? appointmentDuration,
  }) =>
      OrganizationSettingsDraft(
        name: name ?? this.name,
        logoUrl: logoUrl ?? this.logoUrl,
        logoTextUrl: logoTextUrl ?? this.logoTextUrl,
        primaryColor: primaryColor ?? this.primaryColor,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        city: city ?? this.city,
        region: region ?? this.region,
        country: country ?? this.country,
        isActive: isActive ?? this.isActive,
        modulesEnabled: modulesEnabled ?? this.modulesEnabled,
        currency: currency ?? this.currency,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        currencyPosition: currencyPosition ?? this.currencyPosition,
        decimalSeparator: decimalSeparator ?? this.decimalSeparator,
        thousandSeparator: thousandSeparator ?? this.thousandSeparator,
        centPrecision: centPrecision ?? this.centPrecision,
        showZeroCents: showZeroCents ?? this.showZeroCents,
        language: language ?? this.language,
        timezone: timezone ?? this.timezone,
        dateFormat: dateFormat ?? this.dateFormat,
        use24HourClock: use24HourClock ?? this.use24HourClock,
        calendar: calendar ?? this.calendar,
        themePreset: themePreset ?? this.themePreset,
        themeFont: themeFont ?? this.themeFont,
        customPrimary: customPrimary ?? this.customPrimary,
        customSecondary: customSecondary ?? this.customSecondary,
        customAccent: customAccent ?? this.customAccent,
        waitBreachMinutes: waitBreachMinutes ?? this.waitBreachMinutes,
        triageScale: triageScale ?? this.triageScale,
        showPatientNames: showPatientNames ?? this.showPatientNames,
        sessionLockMinutes: sessionLockMinutes ?? this.sessionLockMinutes,
        workingHoursStart: workingHoursStart ?? this.workingHoursStart,
        workingHoursEnd: workingHoursEnd ?? this.workingHoursEnd,
        appointmentDuration: appointmentDuration ?? this.appointmentDuration,
      );

  /// The four groups, each dropped whole when the form touched none of it —
  /// a group sent as `{}` would still be merged, and the merge is what keeps
  /// the fifteen settings a phone did not send.
  Map<String, dynamic> _settings() => {
        'locale': {
          'currency': currency,
          'currencySymbol': currencySymbol,
          'currencyPosition': currencyPosition,
          'decimalSeparator': decimalSeparator,
          'thousandSeparator': thousandSeparator,
          'centPrecision': centPrecision,
          'showZeroCents': showZeroCents,
          'language': language,
          'timezone': timezone,
          'dateFormat': dateFormat,
          'use24HourClock': use24HourClock,
          'calendar': calendar,
        },
        'appearance': {
          'themePreset': themePreset,
          'themeFont': themeFont,
          'customColors': {
            'primary': customPrimary,
            'secondary': customSecondary,
            'accent': customAccent,
          },
        },
        'clinical': {
          'waitBreachMinutes': waitBreachMinutes,
          'triageScale': triageScale,
          'showPatientNames': showPatientNames,
          'sessionLockMinutes': sessionLockMinutes,
        },
        'scheduling': {
          'workingHours': {
            'start': workingHoursStart,
            'end': workingHoursEnd,
          },
          'appointmentDuration': appointmentDuration,
        },
      };

  Map<String, dynamic> _body() => {
        'name': name,
        'logoUrl': logoUrl,
        'logoTextUrl': logoTextUrl,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'region': region,
        'country': country,
        'isActive': isActive,
        'modulesEnabled': modulesEnabled,
        'settings': _settings(),
      };

  /// Identical to [toUpdateJson]: the organisation route is a PUT.
  Map<String, dynamic> toCreateJson() => draftBody(_body());

  Map<String, dynamic> toUpdateJson() => draftBody(_body());
}
