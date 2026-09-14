import 'dart:async';

import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/models/department.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/repositories/crud_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// The department repository, shared by the list and the form.
///
/// `Endpoints.departments` is one of the three collections this API updates
/// with **PUT** rather than PATCH; `CrudRepository` reads that off the route
/// rather than assuming, which is what keeps an edit here from 404ing on a
/// path that exists.
class DepartmentRepository extends CrudRepository<Department> {
  const DepartmentRepository()
      : super(Endpoints.departments, Department.fromJson, departmentsEntity);

  /// What a department is called on the [DataBus].
  static const String departmentsEntity = 'departments';
}

/// The units this hospital is divided into.
///
/// A lookup list rather than a module with a detail screen: there is nothing to
/// say about Cardiology that does not fit on its row, so `SimpleCrudScaffold`
/// is the shape — rows, a search, and one primary action.
///
/// Not a `PagedListController`. `GET /settings/departments` has no pagination
/// DTO at all — it answers a bare array however it is asked — so a paged
/// controller would send `page` and `limit` to a route that declares neither,
/// and `forbidNonWhitelisted` makes each of those a 400 for the whole request.
class SettingsDepartmentsController extends GetxController with LoadStateMixin {
  static SettingsDepartmentsController get to =>
      Get.find<SettingsDepartmentsController>();

  static const DepartmentRepository repository = DepartmentRepository();

  final departments = <Department>[].obs;
  final query = ''.obs;

  /// Adding, editing and deleting a department are all `SETTINGS_UPDATE` on
  /// the server — there is no separate create or delete permission on this
  /// controller. Asked here the way the server will answer it, so a button is
  /// not hidden from somebody the server would have let through.
  bool get canWrite => AccessService.to.can(Modules.settings, AccessVerb.update);

  bool get canRead => AccessService.to.canRead(Modules.settings);

  /// Filtered in memory, because the route has no `search` parameter to send it
  /// to. A hospital has tens of departments, not thousands.
  List<Department> get rows {
    final needle = query.value.trim().toLowerCase();
    if (needle.isEmpty) return departments;
    return departments
        .where(
          (d) =>
              d.name.toLowerCase().contains(needle) ||
              (d.code ?? '').toLowerCase().contains(needle) ||
              (d.description ?? '').toLowerCase().contains(needle) ||
              (d.headName ?? '').toLowerCase().contains(needle),
        )
        .toList();
  }

  /// Which of the five states the list is in.
  ListPhase get phase {
    if (hasNoAccess) return ListPhase.forbidden;
    if (rxFirstLoad.value && isLoading) return ListPhase.firstLoad;
    if (hasLoadError) return ListPhase.error;
    return ListPhase.ready;
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(load());

    if (Get.isRegistered<DataBus>()) {
      // The form announces its writes through `CrudRepository`, so the list
      // refreshes itself rather than being poked by the screen that changed
      // something.
      ever<int>(
        DataBus.to.tick(DepartmentRepository.departmentsEntity),
        (_) {
          if (!isLoading) unawaited(load(silent: true));
        },
      );
    }
  }

  Future<void> load({bool silent = false}) async {
    if (!canRead) {
      rxNoAccess.value = true;
      rxFirstLoad.value = false;
      return;
    }
    await runGuarded(
      () async {
        final result = await repository.list();
        departments.assignAll(result.items);
      },
      fallback: "Couldn't load this hospital's departments.",
      silent: silent,
    );
  }

  Future<void> reload() => load(silent: true);

  void search(String value) => query.value = value;

  /// What the row says under the name.
  String? subtitleOf(Department department) {
    final parts = <String>[
      if ((department.code ?? '').trim().isNotEmpty) department.code!,
      if ((department.headName ?? '').trim().isNotEmpty)
        'Headed by ${department.headName}',
      if (department.staffCount != null) _staff(department.staffCount!),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _staff(int count) => switch (count) {
        0 => 'Nobody assigned',
        1 => '1 person',
        _ => '$count people',
      };
}
