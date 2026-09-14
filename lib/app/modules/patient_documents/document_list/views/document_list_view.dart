import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/patient_text.dart';
import '../../../../core/keys/app_keys.dart';
import '../../../../data/models/patient_document.dart';
import '../../../../data/services/settings_service.dart';
import '../../../../theme/theme.dart';
import '../controllers/document_list_controller.dart';

/// The prescriptions, reports and letters a patient has handed over.
///
/// The register is the patient one rather than the ward one: nothing is set
/// below 17, every target is well past the 48 the staff screens hold to, and
/// the three ways to add a document are three full rows rather than a `+` in a
/// corner. Somebody sitting in a waiting room holding a paper prescription is
/// not browsing — they are looking for the thing they were told to do.
///
/// **Adding is three separate rows, not one button and a sheet.** The wording
/// differs between them in the way that matters when the device says no: a
/// patient who declines the camera is told they can attach a photo they
/// already have, and the row that does that is already on screen.
class DocumentListView extends GetView<DocumentListController> {
  const DocumentListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the top, before anything can decide not to. A `GetView` whose
    // build never touches `controller` never constructs it, so a `lazyPut`
    // controller's `onReady` — which is where this screen's fetch lives —
    // simply never runs.
    final c = controller;

    return Scaffold(
      key: PatientDocumentsKeys.screen,
      appBar: DetailHeader(title: PatientText.documentsTitle),
      body: BentoScreen(
        bottomClearance: false,
        onRefresh: c.reload,
        slivers: [
          BentoSection(
            top: BentoSpace.page,
            child: _AddADocument(controller: c),
          ),
          BentoSection(bottom: 0, child: _Sending(controller: c)),
          BentoSection(child: _Documents(controller: c)),
        ],
      ),
    );
  }
}

/// The three ways in.
class _AddADocument extends StatelessWidget {
  const _AddADocument({required this.controller});

  final DocumentListController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BentoCard(
      key: PatientDocumentsKeys.add,
      hero: true,
      padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BentoSpace.listPad,
              6,
              BentoSpace.listPad,
              10,
            ),
            child: Text(
              PatientText.addADocument,
              style: isDark
                  ? AppTextStyles.darkTitle3()
                  : AppTextStyles.lightTitle3(),
            ),
          ),
          _AddRow(
            rowKey: PatientDocumentsKeys.addCamera,
            icon: Icons.photo_camera_outlined,
            label: PatientText.takeAPhoto,
            origin: DocumentOrigin.camera,
            controller: controller,
          ),
          const Hairline(indent: BentoSpace.listPad),
          _AddRow(
            rowKey: PatientDocumentsKeys.addGallery,
            icon: Icons.photo_library_outlined,
            label: PatientText.chooseAPhoto,
            origin: DocumentOrigin.gallery,
            controller: controller,
          ),
          const Hairline(indent: BentoSpace.listPad),
          _AddRow(
            rowKey: PatientDocumentsKeys.addPdf,
            icon: Icons.picture_as_pdf_outlined,
            label: PatientText.chooseAPdf,
            origin: DocumentOrigin.file,
            controller: controller,
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.origin,
    required this.controller,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final DocumentOrigin origin;
  final DocumentListController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => BentoRow(
        key: rowKey,
        icon: icon,
        title: label,
        titleMaxLines: 2,
        // Absent rather than disabled would be wrong here: a send in flight is
        // a state that ends by itself in a second or two, and a row that
        // vanished and came back would move the two under it. The tap is
        // dropped instead, which is what `onTap: null` does.
        onTap: controller.isUploading.value
            ? null
            : () => controller.add(origin),
      ),
    );
  }
}

/// What is happening to the file right now.
///
/// A figure and a bar, never a bare spinner. A spinner with no number on it
/// reads as a hung screen and the second tap sends the photograph twice —
/// which the server reports honestly as a duplicate, and which is still a
/// thing not to cause.
class _Sending extends StatelessWidget {
  const _Sending({required this.controller});

  final DocumentListController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final error = controller.uploadError.value;
      if (error != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: BentoSpace.section),
          child: NoticeBanner(
            key: PatientDocumentsKeys.uploadError,
            icon: Icons.info_outline_rounded,
            tint: AppColors.warning,
            message: error,
          ),
        );
      }

      if (!controller.isUploading.value) return const SizedBox.shrink();

      final fraction = controller.uploadProgress.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: BentoSpace.section),
        child: BentoCard(
          key: PatientDocumentsKeys.uploadProgress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PatientText.sendingPercent((fraction * 100).round()),
                // Tabular, because this is a figure that ticks. A proportional
                // `9` narrower than a `0` makes the line shuffle sideways at
                // every frame, which reads as the screen having changed more
                // than it has.
                style: numeralStyle(
                  context,
                  size: 17,
                  weight: FontWeight.w600,
                  color: secondaryLabelColor(context),
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              UsedBar(fraction: fraction, color: brandFillColor(context)),
            ],
          ),
        ),
      );
    });
  }
}

/// What they have already handed over.
class _Documents extends StatelessWidget {
  const _Documents({required this.controller});

  final DocumentListController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.hasLoadError) {
        return ErrorRetryBanner(
          key: PatientDocumentsKeys.error,
          margin: EdgeInsets.zero,
          message: controller.rxLoadError.value ?? '',
          onRetry: controller.reload,
        );
      }

      if (controller.rxFirstLoad.value && controller.isLoading) {
        return const BentoCard(child: BentoSkeleton(rows: 2));
      }

      final rows = controller.documents;
      if (rows.isEmpty) {
        return BentoCard(
          child: EmptyState(
            key: PatientDocumentsKeys.empty,
            compact: true,
            icon: Icons.description_outlined,
            title: PatientText.noDocumentsYet,
            message: PatientText.noDocumentsYetBody,
          ),
        );
      }

      return BentoCard(
        key: PatientDocumentsKeys.list,
        padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Hairline(indent: BentoSpace.listPad),
              _DocumentRow(
                document: rows[i],
                onTap: () => controller.open(rows[i]),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document, required this.onTap});

  final PatientDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final when = document.uploadedAt == null
        ? ''
        : SettingsService.to.date(document.uploadedAt);

    return BentoRow(
      key: PatientDocumentsKeys.document(document.id),
      icon: _iconFor(document),
      title: document.kind.label,
      // The server's own sentence, under the row. It is the whole status: "We
      // found some information in this document", "You have already uploaded
      // this document", "We couldn't read this document clearly". Two lines,
      // because it is a sentence and a sentence cut in half is a status
      // nobody can act on.
      subtitle: [if (when.isNotEmpty) when, document.message].join(' · '),
      subtitleMaxLines: 2,
      titleMaxLines: 2,
      onTap: onTap,
      trailing: _Mark(document: document),
    );
  }

  static IconData _iconFor(PatientDocument document) => switch (document.kind) {
        DocumentKind.prescription => Icons.medication_outlined,
        DocumentKind.laboratoryReport => Icons.science_outlined,
        DocumentKind.imagingReport => Icons.monitor_heart_outlined,
        DocumentKind.dischargeSummary => Icons.local_hospital_outlined,
        DocumentKind.referralLetter => Icons.mail_outline_rounded,
        DocumentKind.consultationNote => Icons.notes_rounded,
        DocumentKind.other || DocumentKind.unknown => Icons.description_outlined,
      };
}

/// Where this document has got to, as a glyph and a word.
///
/// Never a colour on its own — `.agents/RULES.md` §0 — and never red: a
/// document that could not be read is not a deteriorating patient, and a red
/// mark here would cost the ward board's own red its meaning.
class _Mark extends StatelessWidget {
  const _Mark({required this.document});

  final PatientDocument document;

  @override
  Widget build(BuildContext context) {
    final (icon, label, tint) = switch (document.status) {
      _ when document.isDuplicate => (
          Icons.content_copy_outlined,
          'Same again',
          null,
        ),
      DocumentStatus.verified => (
          Icons.check_circle_outline_rounded,
          'Confirmed',
          AppColors.success,
        ),
      DocumentStatus.needsReview || DocumentStatus.extracted => (
          Icons.fact_check_outlined,
          'Please check',
          AppColors.warning,
        ),
      DocumentStatus.failed || DocumentStatus.rejectedQuality => (
          Icons.image_not_supported_outlined,
          'Not read',
          AppColors.warning,
        ),
      DocumentStatus.uploaded || DocumentStatus.processing => (
          Icons.hourglass_empty_rounded,
          'Reading',
          null,
        ),
    };

    final ink =
        tint == null ? tertiaryLabelColor(context) : semanticInk(context, tint);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: ink),
        const SizedBox(width: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (Theme.of(context).brightness == Brightness.dark
                  ? AppTextStyles.darkFootnote(weight: FontWeight.w600)
                  : AppTextStyles.lightFootnote(weight: FontWeight.w600))
              .copyWith(color: ink),
        ),
      ],
    );
  }
}
