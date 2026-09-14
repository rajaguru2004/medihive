import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/models/role.dart';
import '../../../data/network/dio_client.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/access_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/load_state.dart';

/// The roles list.
///
/// Roles first, permissions second. A permission matrix is the wrong first
/// screen: it asks somebody to reason about forty switches before they have
/// decided which job they are describing. A list of roles, each saying in
/// plain words what it can do, is the same information in the order people
/// actually think in.
class RolesController extends GetxController with LoadStateMixin {
  static RolesController get to => Get.find<RolesController>();

  final _roles = <Role>[].obs;

  List<Role> get roles => _roles;

  /// System roles cannot be edited — the server refuses with
  /// `ROLE_SYSTEM_PROTECTED` — so they are shown, marked, and not offered an
  /// editor. Listing them matters anyway: somebody comparing a custom role to
  /// NURSE needs to see what NURSE has.
  List<Role> get systemRoles => _roles.where((r) => r.isSystem).toList();
  List<Role> get customRoles => _roles.where((r) => !r.isSystem).toList();

  bool get canCreate => AccessService.to.can(Modules.roles, AccessVerb.create);
  bool get canEdit => AccessService.to.can(Modules.roles, AccessVerb.update);

  DioClient get _client => Get.find<DioClient>();

  @override
  void onReady() {
    super.onReady();
    reload();
  }

  /// Not named `refresh()`: `GetxController.refresh()` exists and returns
  /// void, so an `onRefresh:` wired to it would never be awaited.
  Future<void> reload() => runGuarded(
        () async {
          final response = await _client.get(Endpoints.roles.list);
          final envelope = ApiEnvelope.of(response).orThrow();
          _roles.assignAll(envelope.listOf(Role.fromJson));
        },
        fallback: 'The roles could not be loaded.',
      );
}
