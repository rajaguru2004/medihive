import 'package:get/get.dart' hide Response;

import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/role.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/network/dio_client.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../users/staff_directory.dart';
import '../../users/user_routes.dart';

/// One staff account, and everything that can be done to it.
class UserDetailController extends GetxController with LoadStateMixin {
  static UserDetailController get to => Get.find<UserDetailController>();

  static const StaffDirectory _directory = StaffDirectory();

  final user = StaffUser.empty.obs;

  /// The role catalogue, so a membership can be named and a new one offered.
  final roles = <Role>[].obs;

  /// The roles this account holds.
  ///
  /// **Derived, and deliberately local.** The truth is the `UserRole` join
  /// table and no route exposes it: `GET /api/users/:id` and
  /// `GET /api/settings/users/:id` both answer the row, whose only role signal
  /// is the legacy `role` column. The backend keeps that column and the join
  /// table in step on create and update — both delete every `userRole` row and
  /// rebuild it from the string — but `POST /roles/:id/users` adds a join row
  /// and leaves the column alone. So an assignment made here would vanish on
  /// the next refetch if this list were rebuilt from the server each time.
  final memberships = <Role>[].obs;

  /// True when the account is gone — a stale deep link, or somebody removed it
  /// under this screen. Distinct from an error: there is nothing to retry.
  final missing = false.obs;

  /// Guards the action bar while a write is in flight, so a double tap does
  /// not assign a role twice or fire two deletes.
  final isWorking = false.obs;

  /// Why the last write was refused, in the server's own words.
  ///
  /// Shown inline rather than as a toast: a refusal belongs beside the control
  /// that was refused, and a toast disappears in three seconds and takes the
  /// reason with it.
  final actionError = RxnString();

  late final String id;

  DioClient get _client => Get.find<DioClient>();

  bool get canUpdate => AccessService.to.can(Modules.users, AccessVerb.update);
  bool get canDelete => AccessService.to.can(Modules.users, AccessVerb.delete);

  /// Changing who holds a role is a roles write, not a users write —
  /// `POST /roles/:id/users` is gated on `ROLE_UPDATE`.
  bool get canAssignRoles =>
      AccessService.to.can(Modules.roles, AccessVerb.update);

  /// Whether this account can be switched on and off at all.
  ///
  /// Only through `/api/settings/users`. `UpdateUserDto` is
  /// `PartialType(OmitType(CreateUserDto, …))` and `CreateUserDto` has no
  /// `isActive`, so the same key that works on one route is a 400 on the
  /// other. The control is absent rather than disabled when the directory
  /// answered through the paged route.
  bool get canSetActive => canUpdate && StaffDirectory.canSetActive;

  /// Roles the account does not already hold, for the assign picker.
  List<Role> get assignableRoles {
    final held = memberships.map((role) => role.id).toSet();
    return roles.where((role) => !held.contains(role.id)).toList();
  }

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final args = argument is Map ? argument : const {};

    final passed = args['user'];
    if (passed is StaffUser) user.value = passed;

    id = StaffRoutes.idFrom(argument).isNotEmpty
        ? StaffRoutes.idFrom(argument)
        : user.value.id;
  }

  @override
  void onReady() {
    super.onReady();
    load();

    if (Get.isRegistered<DataBus>()) {
      // How this screen hears that the form saved something. Never by reaching
      // into that controller, and never by awaiting `Get.toNamed` — which
      // completes when the pushed route is *popped* and hangs anything that
      // then wants to pop it.
      ever<int>(DataBus.to.tick(StaffDirectory.entityName), (_) {
        if (isWorking.value || isLoading) return;
        load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          missing.value = false;
          try {
            user.value = await _directory.read(id);
          } on ApiNotFoundException {
            if (user.value.isEmpty) {
              missing.value = true;
              return;
            }
            // A row the list handed over is still worth showing: the record
            // route can refuse an id the list route answered for.
          }
          await _loadRoles();
        },
        fallback: "Couldn't load that account.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  Future<void> _loadRoles() async {
    try {
      final response = await _client.get(Endpoints.roles.list);
      final catalogue =
          ApiEnvelope.of(response).orThrow().listOf(Role.fromJson);
      roles.assignAll(catalogue);

      // Seeded once, from the column, and then left to the writes below. See
      // the note on [memberships].
      if (memberships.isEmpty) {
        final held = (user.value.role ?? '').trim().toUpperCase();
        memberships.assignAll(
          catalogue.where((role) => role.name.toUpperCase() == held),
        );
      }
    } on ApiForbiddenException catch (e) {
      // Not a banner. The record still reads; the role section simply is not
      // offered.
      AppLog.info('UserDetailController', 'roles refused: ${e.message}');
    }
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Gives this person a role. `POST /roles/:id/users` answers `{message}`
  /// rather than a record, so nothing is parsed out of it.
  Future<String?> assignRole(Role role) => _run(() async {
        final response = await _client.post(
          Endpoints.roleUsers(role.id),
          data: {'userId': id},
        );
        // A 403 arrives as an ordinary response on this client, so the
        // envelope has to be asked. Without this the switch flips, the toast
        // says it worked, and the server never heard of it.
        ApiEnvelope.of(response).orThrow();
        if (!memberships.any((held) => held.id == role.id)) {
          memberships.add(role);
        }
        showBentoToast('${user.value.displayName} now holds ${role.displayName}.');
      }, fallback: "Couldn't give them that role.");

  /// Takes a role away. The person keeps their account and loses whatever that
  /// role allowed.
  Future<String?> removeRole(Role role) => _run(() async {
        final response = await _client.delete(Endpoints.roleUser(role.id, id));
        ApiEnvelope.of(response).orThrow();
        memberships.removeWhere((held) => held.id == role.id);
        showBentoToast('${role.displayName} taken away.');
      }, fallback: "Couldn't take that role away.");

  Future<String?> setActive({required bool isActive}) => _run(() async {
        user.value = await _directory.setActive(id, isActive: isActive);
        showBentoToast(
          isActive
              ? '${user.value.displayName} can sign in again.'
              : '${user.value.displayName} can no longer sign in.',
        );
      }, fallback: "Couldn't change that account.");

  /// Removes the account. A soft delete on the server — the audit trail stays.
  Future<String?> deleteAccount() => _run(() async {
        final name = user.value.displayName;
        await _directory.delete(id);
        Get.back<void>();
        showBentoToast('$name can no longer sign in.');
      }, fallback: "Couldn't remove that account.");

  /// Runs a write, guarding the action bar and returning the server's own
  /// words on refusal.
  ///
  /// The message is returned rather than shown, because a refusal belongs
  /// beside the control that was refused: a toast disappears in three seconds
  /// and takes the reason with it.
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
      actionError.value = e.message;
      return e.message;
    } catch (e, stack) {
      AppLog.error('UserDetailController', fallback, e, stack);
      actionError.value = parseErrorMessage(e, fallback);
      return actionError.value;
    } finally {
      isWorking.value = false;
    }
  }
}
