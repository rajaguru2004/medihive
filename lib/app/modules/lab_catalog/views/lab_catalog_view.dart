import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/laboratory_keys.dart';
import '../../../data/models/lab_test.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../laboratory/laboratory_routes.dart';
import '../controllers/lab_catalog_controller.dart';

/// The laboratory catalogue: everything this site can be asked to run.
class LabCatalogView extends GetView<LabCatalogController> {
  const LabCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`, or the lazyPut controller is never built
    // and the catalogue never loads.
    final catalogue = controller;

    return Obx(() {
      final rows = catalogue.visible;

      return SimpleCrudScaffold(
        screenKey: LaboratoryKeys.catalogScreen,
        title: 'Test catalogue',
        subtitle: 'What can be ordered, and what it costs',
        phase: catalogue.phase.value,
        itemCount: rows.length,
        searchKey: LaboratoryKeys.catalogSearch,
        searchHint: 'Test, code or specimen',
        onSearch: catalogue.search,
        onFilter: catalogue.categories.isEmpty
            ? null
            : () => _openCategoryFilter(catalogue),
        filterCount: catalogue.filterCount,
        filterKey: LaboratoryKeys.catalogFilter,
        onRefresh: () => catalogue.reload(silent: true),
        error: catalogue.errorMessage.value,
        onRetry: catalogue.reload,
        // Absent, not disabled, for an account that may not add one.
        addLabel: catalogue.canCreate ? 'Add a test' : null,
        addKey: LaboratoryKeys.catalogAdd,
        onAdd: catalogue.canCreate
            ? () => Get.toNamed<void>(LabRoutes.testEdit)
            : null,
        empty: _empty(catalogue),
        itemBuilder: (context, index) => _row(context, catalogue, rows[index]),
      );
    });
  }

  Future<void> _openCategoryFilter(LabCatalogController catalogue) {
    return Get.bottomSheet<void>(
      FilterSheet(
        groups: [
          FilterGroup(
            field: LabCatalogController.categoryField,
            label: 'Category',
            options: catalogue.categories,
            labelOf: Formatters.label,
          ),
        ],
        selected: {
          for (final entry in catalogue.filters.entries)
            entry.key: [...entry.value],
        },
        optionKey: (field, value) => LaboratoryKeys.catalogCategory(value),
        onApply: (next) {
          Get.back<void>();
          catalogue.applyFilters(next);
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _empty(LabCatalogController catalogue) {
    if (catalogue.isFiltered) {
      return EmptyState(
        key: LaboratoryKeys.catalogEmpty,
        icon: Icons.filter_list_off_rounded,
        title: 'Nothing matches',
        message: 'No test in the catalogue matches what you asked for.',
        actionLabel: 'Clear filters',
        onAction: catalogue.clearFilters,
      );
    }
    return EmptyState(
      key: LaboratoryKeys.catalogEmpty,
      icon: Icons.menu_book_outlined,
      title: 'The catalogue is empty',
      message: 'Nothing has been set up to order yet.',
      actionLabel: catalogue.canCreate ? 'Add a test' : null,
      onAction: catalogue.canCreate
          ? () => Get.toNamed<void>(LabRoutes.testEdit)
          : null,
    );
  }

  Widget _row(
    BuildContext context,
    LabCatalogController catalogue,
    LabTest test,
  ) {
    final facts = <String>[
      test.displayCode,
      if ((test.specimenType ?? '').isNotEmpty)
        Formatters.label(test.specimenType),
      if (test.turnaroundTime != null) '${test.turnaroundTime}h',
    ];

    return LookupRow(
      key: LaboratoryKeys.catalogRow(test.id),
      title: test.testName,
      subtitle: facts.join(' · '),
      value: catalogue.priceOf(test),
      enabled: test.isActive,
      onTap: catalogue.canUpdate
          ? () => Get.toNamed<void>(
                LabRoutes.testEdit,
                arguments: {'test': test},
              )
          : null,
      onLongPress: catalogue.canUpdate || catalogue.canDelete
          ? () => _openRowActions(context, catalogue, test)
          : null,
    );
  }

  Future<void> _openRowActions(
    BuildContext context,
    LabCatalogController catalogue,
    LabTest test,
  ) {
    return Get.bottomSheet<void>(
      RowActionsSheet(
        title: test.testName,
        subtitle: test.displayCode,
        actions: [
          if (catalogue.canUpdate)
            RowAction(
              label: 'Edit',
              icon: Icons.edit_outlined,
              onSelected: () {
                Get.back<void>();
                Get.toNamed<void>(
                  LabRoutes.testEdit,
                  arguments: {'test': test},
                );
              },
            ),
          if (catalogue.canDelete)
            RowAction(
              label: 'Remove from the catalogue',
              icon: Icons.delete_outline_rounded,
              destructive: true,
              onSelected: () async {
                Get.back<void>();
                final confirmed = await ConfirmDialog.show(
                  context,
                  title: 'Remove ${test.testName}?',
                  message: 'It stops being orderable. Orders that already name '
                      'it keep it, so nothing already requested is lost.',
                  confirmLabel: 'Remove',
                  destructive: true,
                );
                if (confirmed) await catalogue.remove(test);
              },
            ),
        ],
      ),
      isScrollControlled: true,
    );
  }
}
