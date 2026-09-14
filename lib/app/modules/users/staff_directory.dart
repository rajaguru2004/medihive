import 'package:get/get.dart';

import '../../core/app_log.dart';
import '../../data/models/drafts/admin_drafts.dart';
import '../../data/models/staff_user.dart';
import '../../data/network/endpoints.dart';
import '../../data/repositories/crud_repository.dart';
import '../../data/services/data_bus.dart';
import '../../data/utils/api_envelope.dart';

/// Which of the two staff routes this account is actually allowed to use.
///
/// Both are live and both are the same table. They are not the same API:
/// `/api/users` splits the name into `firstName`/`lastName` and `/api/settings
/// /users` takes a single `fullName`, so the *write* shape follows from which
/// one answered the *read*.
enum StaffSource {
  /// `/api/users` — `UserController`. `GET` carries `@Roles(SUPER_ADMIN,
  /// ADMIN)` on top of `USER_READ`, which is the reason for the fallback.
  users,

  /// `/api/settings/users` — `SettingsController`. Gated on `SETTINGS_READ`,
  /// which several administrator shapes hold when the roles guard above
  /// refuses them.
  settingsUsers,
}

/// The staff directory, over whichever of the two routes this account can read.
///
/// A `CrudRepository` rather than a controller concern, because the choice of
/// route has to survive a screen: the directory discovers it, and the form
/// pushed on top of the directory has to write in the dialect the directory
/// found. Putting the memory here keeps the decision in one file instead of
/// threading a flag through three sets of route arguments — and a deep link
/// straight to the form still gets an answer rather than a null.
class StaffDirectory extends CrudRepository<StaffUser> {
  const StaffDirectory()
      : super(Endpoints.users, StaffUser.fromJson, entityName);

  /// What this resource is called on the `DataBus`.
  static const String entityName = 'users';

  /// Everything `PaginationDto` declares, and nothing else.
  ///
  /// `GET /api/users` binds its whole query to `PaginationDto`, which has
  /// `page`, `limit`, `orderBy` and `orderDir` and no `search` or `role` — and
  /// the global `ValidationPipe` runs `forbidNonWhitelisted`, so either of
  /// those is a 400 for the entire request rather than a parameter the server
  /// ignores. Narrowing happens in the controller, over rows already in hand.
  static const Set<String> pagedParams = {
    'page',
    'limit',
    'orderBy',
    'orderDir',
  };

  static StaffSource _source = StaffSource.users;

  /// Which route answered last. Read by the form to choose a draft.
  static StaffSource get source => _source;

  /// True when the settings route is the one in use — the single fact that
  /// decides `SettingsUserDraft` over `UserDraft`.
  static bool get usesSettingsRoute => _source == StaffSource.settingsUsers;

  /// Forgets the probe, so the next load asks the preferred route again.
  ///
  /// Called when the directory reloads from cold. Two clinicians hand a ward
  /// tablet over between shifts, and the second one's grants are not the
  /// first one's — a remembered fallback would quietly keep the new
  /// administrator on the narrower route.
  static void forget() => _source = StaffSource.users;

  Crud get _routes =>
      usesSettingsRoute ? Endpoints.settingsUsers : Endpoints.users;

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// One page of the directory, from whichever route will answer.
  ///
  /// The preferred route first, then the fallback, and the answer is
  /// remembered: an administrator refused `GET /api/users` by the controller's
  /// roles guard is not refused `GET /api/settings/users`, and the two carry
  /// the same people. Both refusing is the no-access state, and the
  /// `ApiForbiddenException` is rethrown so `PagedListController` shows the
  /// locked panel rather than a retry.
  @override
  Future<PagedResult<StaffUser>> list([
    PagedQuery query = const PagedQuery(),
  ]) async {
    if (usesSettingsRoute) return _listSettings(query);
    try {
      return await _listUsers(query);
    } on ApiForbiddenException catch (e) {
      _source = StaffSource.settingsUsers;
      AppLog.info(
        'StaffDirectory',
        '/api/users refused (${e.errorCode}); falling back to settings',
      );
      return _listSettings(query);
    }
  }

  Future<PagedResult<StaffUser>> _listUsers(PagedQuery query) async {
    final response = await client.get(
      Endpoints.users.list,
      queryParameters: {
        for (final entry in query.toQueryParameters().entries)
          if (pagedParams.contains(entry.key)) entry.key: entry.value,
      },
    );
    final envelope = ApiEnvelope.of(response).orThrow();
    return PagedResult<StaffUser>(
      items: envelope.listOf(StaffUser.fromJson),
      pagination: envelope.pagination ?? Pagination.none,
    );
  }

  /// The settings route answers a **bare array** of the whole organisation —
  /// `findAllUsers` has no pagination at all — so this is one complete page
  /// and there is never a second one to ask for.
  Future<PagedResult<StaffUser>> _listSettings(PagedQuery query) async {
    final role = query.params['role'];
    final response = await client.get(
      Endpoints.settingsUsers.list,
      queryParameters: {
        if (role != null && '$role'.isNotEmpty) 'role': role,
      },
    );
    final envelope = ApiEnvelope.of(response).orThrow();
    return PagedResult<StaffUser>(
      items: envelope.listOf(StaffUser.fromJson),
      pagination: Pagination.none,
    );
  }

  @override
  Future<StaffUser> read(String id) async {
    final response = await client.get(_routes.byId(id));
    return StaffUser.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// Active staff, for the pickers that assign work and for the role editor's
  /// member list. `GET /api/users/staff` is gated on `PATIENT_READ` rather
  /// than `USER_READ`, so it answers for accounts neither directory route
  /// will.
  Future<List<StaffUser>> staff({String? role}) async {
    final response = await client.get(
      Endpoints.staff,
      queryParameters: {if (role != null && role.isNotEmpty) 'role': role},
    );
    return ApiEnvelope.of(response).orThrow().listOf(StaffUser.fromJson);
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Creates an account in the dialect the answering route speaks.
  ///
  /// **The two routes take different bodies for the same row.** `/api/users`
  /// wants `firstName` + `lastName` and treats `role` as optional;
  /// `/api/settings/users` wants a single `fullName` and declares `role`
  /// `@IsNotEmpty()`. Sending either route the other's keys is a 400 —
  /// `forbidNonWhitelisted` rejects the unknown key and `@IsNotEmpty` rejects
  /// the missing one — so the draft is chosen here, from the fact the read
  /// established, and never guessed at the call site.
  Future<StaffUser> createAccount(StaffFormValues values) {
    final body = usesSettingsRoute
        ? SettingsUserDraft(
            fullName: values.fullName,
            email: values.email,
            password: values.password,
            phone: values.phone,
            employeeId: values.employeeId,
            role: values.role,
            departmentId: values.departmentId,
            specialization: values.specialization,
            licenseNumber: values.licenseNumber,
          ).toCreateJson()
        : UserDraft(
            email: values.email,
            password: values.password,
            firstName: values.firstName,
            lastName: values.lastName,
            phone: values.phone,
            employeeId: values.employeeId,
            role: values.role,
            departmentId: values.departmentId,
            specialization: values.specialization,
            licenseNumber: values.licenseNumber,
          ).toCreateJson();

    return _write(_routes.create, body, verb: HttpVerb.post);
  }

  /// Saves an edit. Both routes are **PUT**, and both omit `email` and
  /// `password` from their update DTO: changing an address and changing a
  /// credential are different acts with different audit trails, and sending
  /// either key here is a 400.
  Future<StaffUser> updateAccount(String id, StaffFormValues values) {
    final body = usesSettingsRoute
        ? SettingsUserDraft(
            fullName: values.fullName,
            phone: values.phone,
            employeeId: values.employeeId,
            role: values.role,
            departmentId: values.departmentId,
            specialization: values.specialization,
            licenseNumber: values.licenseNumber,
            isActive: values.isActive,
          ).toUpdateJson()
        : UserDraft(
            firstName: values.firstName,
            lastName: values.lastName,
            phone: values.phone,
            employeeId: values.employeeId,
            role: values.role,
            departmentId: values.departmentId,
            specialization: values.specialization,
            licenseNumber: values.licenseNumber,
          ).toUpdateJson();

    return _write(_routes.update(id), body, verb: HttpVerb.put);
  }

  /// Switches an account on or off.
  ///
  /// Only the settings route can do this: `UpdateUserDto` is
  /// `PartialType(OmitType(CreateUserDto, …))` and `CreateUserDto` has no
  /// `isActive` at all, so the same key that works here is a 400 on
  /// `/api/users`. [canSetActive] is what a screen asks before offering the
  /// control.
  static bool get canSetActive => usesSettingsRoute;

  Future<StaffUser> setActive(String id, {required bool isActive}) => _write(
        Endpoints.settingsUsers.update(id),
        SettingsUserDraft(isActive: isActive).toUpdateJson(),
        verb: HttpVerb.put,
      );

  /// Removes an account. A soft delete on both routes, and `/api/users`
  /// answers **204 with no body** — which `ApiEnvelope` reads as a success
  /// with a null payload rather than as a failure.
  @override
  Future<void> delete(String id) async {
    final response = await client.delete(_routes.delete(id));
    ApiEnvelope.of(response).orThrow();
    _announce();
  }

  Future<StaffUser> _write(
    String path,
    Map<String, dynamic> body, {
    required HttpVerb verb,
  }) async {
    final response = switch (verb) {
      HttpVerb.post => await client.post(path, data: body),
      _ => await client.put(path, data: body),
    };
    final saved = StaffUser.fromJson(ApiEnvelope.of(response).orThrow().object);
    _announce();
    return saved;
  }

  /// Every write says so, because this module's own screens are the ones most
  /// likely to be looking at the row that changed — the directory behind a
  /// form, the record behind a role editor.
  ///
  /// Spelled out here rather than inherited: the base class announces from its
  /// own `create`/`update`/`delete`, and none of those is the method this
  /// resource writes through.
  void _announce() {
    if (Get.isRegistered<DataBus>()) DataBus.to.changedRecord(entityName);
  }
}

/// What a staff form collected, before it is shaped for whichever route
/// answered.
///
/// A plain bag rather than a draft: there are two drafts for this one form and
/// the form must not have to know which. [StaffDirectory.createAccount] picks.
class StaffFormValues {
  const StaffFormValues({
    this.email,
    this.password,
    this.firstName,
    this.lastName,
    this.fullName,
    this.phone,
    this.employeeId,
    this.role,
    this.departmentId,
    this.specialization,
    this.licenseNumber,
    this.isActive,
  });

  final String? email;
  final String? password;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? phone;
  final String? employeeId;
  final String? role;
  final String? departmentId;
  final String? specialization;
  final String? licenseNumber;
  final bool? isActive;
}
