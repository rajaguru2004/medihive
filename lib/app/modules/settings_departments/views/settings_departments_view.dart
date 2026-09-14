import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/settings_departments_keys.dart';
import '../../../data/models/department.dart';
import '../../../theme/theme.dart';
import '../../settings/settings_routes.dart';
import '../controllers/settings_departments_controller.dart';

/// The units this hospital is divided into.
///
/// A lookup list: rows, a search, and one primary action. There is nothing to
/// say about Cardiology that does not fit on its row, so there is no detail
/// screen — a tap opens the editor.
class SettingsDepartmentsView extends GetView<SettingsDepartmentsController> {
  const SettingsDepartmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of the build, or the `lazyPut` never happens and
    // `onReady` never fetches.
    final units = controller;

    return Obx(() {
      final rows = units.rows;
      final searching = units.query.value.trim().isNotEmpty;

      return SimpleCrudScaffold(
        screenKey: SettingsDepartmentsKeys.screen,
        title: 'Departments',
        subtitle: 'Units, their codes and who heads them',
        itemCount: rows.length,
        phase: units.phase,
        error: units.rxLoadError.value,
        onRetry: units.load,
        onRefresh: units.reload,
        onSearch: units.search,
        searchKey: SettingsDepartmentsKeys.search,
        searchHint: 'Name, code or head',
        empty: EmptyState(
          key: SettingsDepartmentsKeys.empty,
          icon: Icons.account_tree_outlined,
          title: searching
              ? 'Nothing matches that'
              : 'No departments yet',
          message: searching
              ? 'Try a shorter search.'
              : 'A department is a unit staff belong to — Cardiology, '
                  'Records, the Laboratory. Wards and rotas group by them.',
          actionLabel: units.canWrite && !searching ? 'Add a department' : null,
          onAction: units.canWrite && !searching ? () => _open(null) : null,
          actionKey: SettingsDepartmentsKeys.add,
        ),
        // Absent, not disabled, for an account that may not add one.
        addLabel: units.canWrite ? 'Add a department' : null,
        onAdd: units.canWrite ? () => _open(null) : null,
        addKey: SettingsDepartmentsKeys.add,
        itemBuilder: (context, index) {
          final department = rows[index];
          return LookupRow(
            key: SettingsDepartmentsKeys.department(department.id),
            title: department.name,
            subtitle: units.subtitleOf(department),
            enabled: department.isActive,
            onTap: units.canWrite ? () => _open(department) : null,
          );
        },
      );
    });
  }

  /// Null adds a new one; a department edits that one.
  void _open(Department? department) => Get.toNamed<void>(
        SettingsRoutes.departmentForm,
        arguments: department == null ? null : {'department': department},
      );
}
