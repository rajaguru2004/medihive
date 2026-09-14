import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/admin_drafts.dart';
import '../../../data/models/role.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/network/dio_client.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/access_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/formatters.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../users/staff_directory.dart';
import '../../users/user_routes.dart';

/// Which half of the editor is showing.
enum RoleEditorTab {
  /// The permission grid.
  access,

  /// The people who hold this role.
  members,
}

extension RoleEditorTabLabel on RoleEditorTab {
  String get label => switch (this) {
        RoleEditorTab.access => 'What it can do',
        RoleEditorTab.members => 'Who holds it',
      };
}

/// One role: what it is called, what it allows, and who holds it.
///
/// **The four switches per module are four permission rows, not four flags on
/// one.** `PermissionsGuard` authorises by *name* — it asks whether
/// `PATIENT_DELETE` appears in the row set at all — and the four booleans only
/// feed the access map `/auth/me` sends the app. So a row written with
/// `canDelete: false` still grants `PATIENT_DELETE` on the server, and the only
/// way to take a verb away is to **leave its row out of the assignment
/// entirely**. That is what [granted] holds: the permission ids that survive,
/// one per verb the role keeps.
class RoleEditorController extends GetxController with LoadStateMixin {
  static RoleEditorController get to => Get.find<RoleEditorController>();

  static const StaffDirectory _directory = StaffDirectory();

  /// The four verbs a module card draws, in the order a reader scans them.
  static const List<AccessVerb> verbs = [
    AccessVerb.read,
    AccessVerb.create,
    AccessVerb.update,
    AccessVerb.delete,
  ];

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  final role = Role.empty.obs;
  final tab = RoleEditorTab.access.obs;

  /// Every permission the server ships, as the catalogue answers them.
  final catalogue = <PermissionGrant>[].obs;

  /// The permission ids this role will hold when saved.
  final granted = <String>{}.obs;

  /// The ids it holds right now, for telling an addition from a removal.
  final _original = <String>{};

  /// The people who hold it.
  final members = <StaffUser>[].obs;

  /// True when the member list was derived from the staff directory rather
  /// than from the role itself. See [_loadMembers].
  final membersAreDerived = false.obs;

  final missing = false.obs;
  final isWorking = false.obs;
  final actionError = RxnString();

  late final String id;

  DioClient get _client => Get.find<DioClient>();

  bool get canUpdate => AccessService.to.can(Modules.roles, AccessVerb.update);

  /// The server refuses every edit to a system role with
  /// `ROLE_SYSTEM_PROTECTED`, so the fields are read-only rather than allowed
  /// to fail on save. Membership is *not* protected — `assignUserToRole` has
  /// no such check — so the second tab stays live.
  bool get isProtected => role.value.isSystem;

  bool get canEditPermissions => canUpdate && !isProtected;
  bool get canEditMembers => canUpdate;

  /// Modules in the order a reader thinks about them: the clinical ones first,
  /// then the back office, then the administrative ones.
  List<String> get modules {
    final byModule = <String>{for (final row in catalogue) row.module}.toList();
    byModule.sort((a, b) {
      final left = Modules.all.indexOf(a);
      final right = Modules.all.indexOf(b);
      // A module the access map does not know about still belongs on screen —
      // it sorts after the ones that do rather than vanishing.
      if (left == -1 && right == -1) return a.compareTo(b);
      if (left == -1) return 1;
      if (right == -1) return -1;
      return left.compareTo(right);
    });
    return byModule;
  }

  /// The catalogue rows for one module.
  List<PermissionGrant> rowsFor(String module) =>
      catalogue.where((row) => row.module == module).toList();

  /// The row that carries one verb of one module, or null where the catalogue
  /// has none — there is no `DASHBOARD_DELETE`, and a switch for it would be a
  /// control that cannot do anything.
  PermissionGrant? rowFor(String module, AccessVerb verb) =>
      rowsFor(module).firstWhereOrNull((row) => _actionOf(row) == verb.name);

  /// Rows in a module that are not one of the four verbs — `PERMISSION_ASSIGN`
  /// is the one the seed ships. Drawn as their own switch rather than dropped,
  /// because dropping one would revoke it on the next save.
  List<PermissionGrant> extrasFor(String module) => rowsFor(module)
      .where((row) => !verbs.any((verb) => verb.name == _actionOf(row)))
      .toList();

  bool isOn(PermissionGrant? row) =>
      row != null && granted.contains(row.permissionId);

  /// What this module allows, as a word — for the card's own summary.
  String summaryFor(String module) {
    final on = [
      for (final verb in verbs)
        if (isOn(rowFor(module, verb))) verb.name,
    ];
    if (on.isEmpty) return 'Nothing';
    if (on.length == verbs.length) return 'Everything';
    return on.map(Formatters.label).join(', ');
  }

  /// A role has to be called something.
  ///
  /// Checked here rather than left to the server, which would answer a blank
  /// name by silently keeping the old one — `draftBody` drops an empty string,
  /// so the PATCH would carry no `name` at all and the save would look like it
  /// worked.
  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Give the role a name' : null;

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final args = argument is Map ? argument : const {};

    final passed = args['role'] ?? argument;
    if (passed is Role) _fill(passed);

    final fromArgs = StaffRoutes.idFrom(argument);
    id = fromArgs.isNotEmpty ? fromArgs : role.value.id;
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void _fill(Role value) {
    role.value = value;
    nameController.text = value.displayName;
    descriptionController.text = value.description ?? '';
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          missing.value = false;
          try {
            final response = await _client.get(Endpoints.roles.byId(id));
            _fill(
              Role.fromJson(ApiEnvelope.of(response).orThrow().object),
            );
          } on ApiNotFoundException {
            if (role.value.isEmpty) {
              missing.value = true;
              return;
            }
          }

          await _loadCatalogue();
          _seedGrants();
          await _loadMembers();
        },
        fallback: "Couldn't load that role.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  Future<void> _loadCatalogue() async {
    final response = await _client.get(Endpoints.permissions);
    catalogue.assignAll(
      ApiEnvelope.of(response)
          .orThrow()
          .objects
          .map(_catalogueRow)
          .where((row) => row.permissionId.isNotEmpty),
    );
  }

  /// One catalogue row, normalised.
  ///
  /// `GET /api/permissions` answers bare `Permission` rows, not the join rows
  /// `PermissionGrant` was written for — so `permissionId` is absent and `id`
  /// **is** the permission's id. Copying it across here is what stops the save
  /// posting a list of empty `permissionId`s, which the server answers with
  /// "one or more permissions not found" and no clue which.
  static PermissionGrant _catalogueRow(Map<String, dynamic> json) {
    final parsed = PermissionGrant.fromJson(json);
    return PermissionGrant(
      id: parsed.id,
      permissionId:
          parsed.permissionId.isEmpty ? parsed.id : parsed.permissionId,
      name: parsed.name,
      code: parsed.code,
      category: parsed.category,
      description: parsed.description,
    );
  }

  void _seedGrants() {
    final held = <String>{
      for (final grant in role.value.permissions)
        if (grant.permissionId.isNotEmpty) grant.permissionId,
    };
    _original
      ..clear()
      ..addAll(held);
    granted
      ..clear()
      ..addAll(held);
  }

  /// The people holding this role.
  ///
  /// `GET /api/roles/:id/users` **is not mounted** — `RolesController` has a
  /// `POST` and a `DELETE` at that path and no `GET`, so the request 404s. It
  /// is still asked for first: it is the route this belongs on, and the day it
  /// lands this screen is already correct.
  ///
  /// The fallback is the staff directory filtered by the role's own name,
  /// which reads the legacy `role` **column** rather than the `UserRole` join
  /// table. The two agree for anybody created or edited through a staff form —
  /// both of those rewrite the join rows from the column — and diverge for
  /// anybody added through the button below, which writes the join row and
  /// leaves the column alone. So an addition made here is kept locally rather
  /// than refetched.
  Future<void> _loadMembers() async {
    try {
      final response = await _client.get(Endpoints.roleUsers(id));
      members.assignAll(
        ApiEnvelope.of(response).orThrow().listOf(_memberRow),
      );
      membersAreDerived.value = false;
      return;
    } on ApiNotFoundException {
      AppLog.info(
        'RoleEditorController',
        'no GET on role users; deriving from the staff directory',
      );
    } on ApiForbiddenException catch (e) {
      AppLog.info('RoleEditorController', 'role users refused: ${e.message}');
      return;
    }

    try {
      members.assignAll(await _directory.staff(role: role.value.name));
      membersAreDerived.value = true;
    } on ApiForbiddenException catch (e) {
      AppLog.info('RoleEditorController', 'staff refused: ${e.message}');
    }
  }

  /// A member row, from either shape.
  ///
  /// The role route's own projection nests the person under `user`; the staff
  /// route answers the person directly.
  static StaffUser _memberRow(Map<String, dynamic> json) =>
      json['user'] is Map ? StaffUser.of(json['user']) : StaffUser.fromJson(json);

  // ── The grid ──────────────────────────────────────────────────────────────

  void toggle(PermissionGrant row, {required bool on}) {
    if (!canEditPermissions) return;
    if (on) {
      granted.add(row.permissionId);
    } else {
      granted.remove(row.permissionId);
    }
  }

  /// The modules that lose something, named the way a person would say them.
  ///
  /// Drives the confirmation. A revoke is the change worth stopping on: adding
  /// a permission gives somebody a screen they did not have, and removing one
  /// takes away a screen they are using.
  List<String> get losses {
    final removed = _original.difference(granted);
    if (removed.isEmpty) return const [];

    final byModule = <String>{};
    for (final permissionId in removed) {
      final row = catalogue.firstWhereOrNull(
        (entry) => entry.permissionId == permissionId,
      );
      if (row == null) continue;
      final action = _actionOf(row);
      byModule.add('${Formatters.label(row.module)} — ${_verbWord(action)}');
    }
    return byModule.toList()..sort();
  }

  /// The sentence a confirmation shows, or null when nothing is being taken
  /// away.
  String? get revokeWarning {
    final lost = losses;
    if (lost.isEmpty) return null;

    final holders = members.length;
    final who = switch (holders) {
      0 => 'Nobody holds this role yet, so nothing changes today',
      1 => 'One person holds this role',
      _ => '$holders people hold this role',
    };

    return '$who. Saving takes away:\n\n• ${lost.join('\n• ')}\n\n'
        'Next time they open one of those, the screen is empty and there is '
        'nothing on it to say why.';
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<String?> save() => _run(() async {
        // The name and the description first, because a permission set saved
        // against a role whose rename failed is a role nobody can find.
        // Back into the stored spelling before it is compared or sent. The
        // field shows `Ward Nurse` because that is what a person reads; the
        // column holds `WARD_NURSE`, and the server only upper-cases what it
        // is sent — so posting the readable form back would rename the role to
        // `WARD NURSE` on every save, and the second save would 409 against
        // the first.
        final name = storedName(nameController.text);
        final description = descriptionController.text.trim();
        final renamed =
            name != role.value.name || description != (role.value.description ?? '');

        if (renamed) {
          final response = await _client.patch(
            Endpoints.roles.update(id),
            data: RoleDraft(
              name: name,
              description: description,
            ).toUpdateJson(),
          );
          ApiEnvelope.of(response).orThrow();
        }

        // One PUT, and it **replaces** the whole set: `assignPermissions`
        // deletes every row for this role and writes the list back. A partial
        // list silently revokes everything it omits, which is how a ward loses
        // its patient list halfway through a shift — so the body is built from
        // every switch that is on, not from the ones that changed.
        final response = await _client.put(
          Endpoints.assignPermission(id),
          data: RolePermissionsDraft(
            permissions: [
              for (final permissionId in granted)
                _assignmentFor(permissionId),
            ],
          ).toUpdateJson(),
        );
        ApiEnvelope.of(response).orThrow();

        await load(silent: true);
        showBentoToast('${role.value.displayName} saved.');
      }, fallback: "Couldn't save that role.");

  /// One row of the assignment.
  ///
  /// The verb flags mirror the permission's own action, so the access map
  /// `/auth/me` builds agrees with the name the guard checks. A row for an
  /// action outside the four — `PERMISSION_ASSIGN` — carries four falses: the
  /// guard grants it by name regardless, and inventing a flag for it would put
  /// a capability in the access map that nothing on the server honours.
  RolePermissionDraft _assignmentFor(String permissionId) {
    final row = catalogue.firstWhereOrNull(
      (entry) => entry.permissionId == permissionId,
    );
    final action = row == null ? '' : _actionOf(row);
    return RolePermissionDraft(
      permissionId: permissionId,
      canRead: action == AccessVerb.read.name,
      canCreate: action == AccessVerb.create.name,
      canUpdate: action == AccessVerb.update.name,
      canDelete: action == AccessVerb.delete.name,
    );
  }

  // ── Members ───────────────────────────────────────────────────────────────

  /// Staff who do not already hold this role, for the add picker.
  Future<List<StaffUser>> addableStaff() async {
    final held = members.map((person) => person.id).toSet();
    final everybody = await _directory.staff();
    return everybody.where((person) => !held.contains(person.id)).toList();
  }

  Future<String?> addMember(StaffUser person) => _run(() async {
        final response = await _client.post(
          Endpoints.roleUsers(id),
          data: {'userId': person.id},
        );
        // A 403 arrives as an ordinary response on this client. Without this
        // the row appears, the toast says it worked, and the server never
        // heard of it.
        ApiEnvelope.of(response).orThrow();
        if (!members.any((member) => member.id == person.id)) {
          members.add(person);
        }
        showBentoToast('${person.displayName} now holds '
            '${role.value.displayName}.');
      }, fallback: "Couldn't add them to this role.");

  Future<String?> removeMember(StaffUser person) => _run(() async {
        final response = await _client.delete(Endpoints.roleUser(id, person.id));
        ApiEnvelope.of(response).orThrow();
        members.removeWhere((member) => member.id == person.id);
        showBentoToast('${person.displayName} no longer holds '
            '${role.value.displayName}.');
      }, fallback: "Couldn't take this role away from them.");

  void showTab(RoleEditorTab next) => tab.value = next;

  // ── Plumbing ──────────────────────────────────────────────────────────────

  /// The stored spelling of a role name: upper-cased, with the spaces a reader
  /// types turned back into the underscores the column holds.
  static String storedName(String typed) =>
      typed.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');

  /// `create`, `read`, `update`, `delete`, `assign` — from the console's code
  /// where there is one, and from the name's own suffix otherwise.
  static String _actionOf(PermissionGrant row) {
    final code = row.code ?? '';
    if (code.contains(':')) return code.split(':').last.toLowerCase();
    final cut = row.name.lastIndexOf('_');
    return cut == -1 ? row.name.toLowerCase() : row.name.substring(cut + 1).toLowerCase();
  }

  /// The verb as somebody would say it about a screen.
  static String _verbWord(String action) => switch (action) {
        'read' => 'seeing it at all',
        'create' => 'adding anything',
        'update' => 'changing anything',
        'delete' => 'removing anything',
        _ => Formatters.label(action).toLowerCase(),
      };

  Future<String?> _run(
    Future<void> Function() body, {
    required String fallback,
  }) async {
    if (isWorking.value) return null;
    isWorking.value = true;
    actionError.value = null;
    try {
      await body();
      return null;
    } on ApiForbiddenException catch (e) {
      // The one a system role produces: `ROLE_SYSTEM_PROTECTED`. The screen
      // should have made this unreachable; showing the server's words is what
      // covers the case where it did not.
      actionError.value = e.message;
      return e.message;
    } catch (e, stack) {
      AppLog.error('RoleEditorController', fallback, e, stack);
      actionError.value = parseErrorMessage(e, fallback);
      return actionError.value;
    } finally {
      isWorking.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}
