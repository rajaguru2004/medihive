import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/radiology_keys.dart';
import '../../../data/models/radiology_exam.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../radiology/radiology_routes.dart';
import '../controllers/radiology_catalog_controller.dart';

/// The imaging catalogue: what this department can be asked for.
class RadiologyCatalogView extends GetView<RadiologyCatalogController> {
  const RadiologyCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.displayed;
      final money = SettingsService.to.settings.money;

      return SimpleCrudScaffold(
        title: 'Exam catalogue',
        subtitle: 'What imaging can be ordered here',
        screenKey: RadiologyKeys.catalog,
        phase: controller.phase.value,
        itemCount: rows.length,
        onRefresh: () => controller.reload(silent: true),
        onSearch: controller.search,
        searchHint: 'Exam, code, modality or body part',
        searchKey: RadiologyKeys.catalogSearch,
        error: controller.errorMessage.value,
        onRetry: controller.reload,
        // Absent, not disabled, when this account may not add one.
        addLabel: controller.canAdd ? 'Add an exam' : null,
        addKey: RadiologyKeys.catalogAdd,
        onAdd: controller.canAdd
            ? () => Get.toNamed<void>(RadiologyRoutes.examForm)
            : null,
        empty: EmptyState(
          key: RadiologyKeys.catalogEmpty,
          icon: controller.isFiltered
              ? Icons.filter_alt_off_outlined
              : Icons.list_alt_outlined,
          title: controller.isFiltered
              ? 'Nothing matches that'
              : 'The catalogue is empty',
          message: controller.isFiltered
              ? null
              : 'Add the exams this department offers so they can be ordered.',
          actionLabel: controller.isFiltered
              ? null
              : (controller.canAdd ? 'Add an exam' : null),
          onAction: controller.isFiltered || !controller.canAdd
              ? null
              : () => Get.toNamed<void>(RadiologyRoutes.examForm),
        ),
        itemBuilder: (context, i) => LookupRow(
          key: RadiologyKeys.exam(rows[i].id),
          title: rows[i].displayName,
          subtitle: _subtitleOf(rows[i]),
          value: rows[i].priceLabel(money),
          enabled: rows[i].isActive,
          onTap: controller.canEdit
              ? () => Get.toNamed<void>(
                    RadiologyRoutes.examForm,
                    arguments: {'examId': rows[i].id},
                  )
              : null,
        ),
      );
    });
  }
}

/// Everything about the exam that decides whether it is the right one, in the
/// order somebody checks it: what machine, what part, how long, and whether
/// the patient needs preparing.
String _subtitleOf(RadiologyExam exam) => [
      if ((exam.examCode ?? '').trim().isNotEmpty) exam.examCode!,
      if ((exam.examCategory ?? '').trim().isNotEmpty)
        Formatters.label(exam.examCategory),
      if ((exam.modality ?? '').trim().isNotEmpty) exam.modality!,
      if (exam.estimatedDuration != null) '${exam.estimatedDuration} min',
      if (exam.contrastRequired) 'Contrast',
    ].join(' · ');
