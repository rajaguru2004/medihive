import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/patient_text.dart';
import '../../../../core/keys/app_keys.dart';
import '../../../../data/models/patient_document.dart';
import '../../../../data/services/settings_service.dart';
import '../../../../data/utils/formatters.dart';
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
///
/// **What they have added is filed by date, newest first.** The reasoning is
/// on [_Documents]; the short version is that the pile in their hand has
/// dates on it and the list should be readable against that pile.
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

/// What they have already handed over, filed by date.
///
/// ── Why this is grouped rather than one flat list
///
/// The question a patient arrives with is "have you got the March report?",
/// never "which of these did I upload third". A list ordered by upload time
/// answers only the second, and it answers it in an order with no relation to
/// the bundle of paper in their hand: a discharge letter from January
/// photographed this morning sorts above a report from last week.
///
/// So the heading is the date the **document** carries, and the day it
/// arrived is the fallback — marked as the fallback, on the heading and again
/// on the row. Those are two different facts and neither stands in for the
/// other silently. Filing a January letter under "Today" because that is when
/// it was photographed would be this screen inventing a clinical date, which
/// is the one thing this whole module is built not to do.
class _Documents extends StatelessWidget {
  const _Documents({required this.controller});

  final DocumentListController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // An error *instead of* the list only when there is no list.
      //
      // The refresh that runs when a patient comes back from a document is
      // silent and can fail — a clinic's wifi drops for a second — and the
      // documents it failed to re-read are still on screen and still true.
      // Replacing them with a retry banner throws away what they came back
      // to, to report a failure about something they did not ask for. With
      // rows present the banner goes *above* them instead, further down.
      if (controller.hasLoadError && controller.documents.isEmpty) {
        return ErrorRetryBanner(
          key: PatientDocumentsKeys.error,
          margin: EdgeInsets.zero,
          message: controller.rxLoadError.value ?? '',
          onRetry: controller.reload,
        );
      }

      // Nothing to show *and* something in flight — not "the first load".
      //
      // Those come apart the moment anything reloads: a controller that is
      // rebuilt, a pull to refresh, or a return from a document all put a
      // populated list into a loading state, and keying the skeleton off
      // `rxFirstLoad` replaced rows the patient was reading with grey bars.
      // Tied to emptiness instead, the skeleton appears exactly when there is
      // genuinely nothing else to draw.
      if (controller.isLoading && controller.documents.isEmpty) {
        return const BentoCard(child: BentoSkeleton(rows: 2));
      }

      if (controller.documents.isEmpty) {
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

      // Read explicitly, and not only through `groups`.
      //
      // `groups` does reach `filter.value` — inside `_matchesFilter`, which
      // `documents.where(...).toList()` forces — and GetX tracks reads for
      // the whole execution of this callback, nested calls included. So the
      // subscription exists today. It exists *by way of* a lazy iterable
      // being forced over a non-empty list, which is a thread thin enough
      // that the next person to touch either end breaks the filter and finds
      // out from a patient. One line here makes it a fact of this widget.
      final _ = controller.filter.value;
      final groups = controller.groups;

      return Column(
        key: PatientDocumentsKeys.list,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A refresh that failed while rows were on screen. Above them, not
          // instead of them — see the note on the early return above.
          if (controller.hasLoadError) ...[
            ErrorRetryBanner(
              key: PatientDocumentsKeys.error,
              margin: EdgeInsets.zero,
              message: controller.rxLoadError.value ?? '',
              onRetry: controller.reload,
            ),
            const SizedBox(height: BentoSpace.header),
          ],
          _ToCheck(controller: controller),
          _Filters(controller: controller),
          if (groups.isEmpty)
            BentoCard(
              child: EmptyState(
                key: PatientDocumentsKeys.emptyFilter,
                compact: true,
                icon: Icons.filter_alt_off_outlined,
                title: PatientText.noDocumentsYet,
                message: PatientText.documentsNoneInFilter,
              ),
            )
          else
            for (var g = 0; g < groups.length; g++) ...[
              if (g > 0) const SizedBox(height: BentoSpace.section),
              _DayHeading(group: groups[g]),
              const SizedBox(height: BentoSpace.header),
              _DayCard(group: groups[g], controller: controller),
            ],
        ],
      );
    });
  }
}

/// The one line that says there is something to do.
///
/// Above the filters rather than inside them: a patient who has a document
/// waiting should not have to discover a chip to find that out. Amber, never
/// red — §0.1, a document that needs checking is not a deteriorating patient.
class _ToCheck extends StatelessWidget {
  const _ToCheck({required this.controller});

  final DocumentListController controller;

  @override
  Widget build(BuildContext context) {
    final waiting = controller.needsCheckCount;
    if (waiting == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpace.header),
      child: NoticeBanner(
        key: PatientDocumentsKeys.toCheck,
        icon: Icons.fact_check_outlined,
        tint: AppColors.warning,
        message: PatientText.documentsNeedChecking(waiting),
      ),
    );
  }
}

/// All / To check / Confirmed, each carrying its count.
///
/// Hidden below two documents: a filter over a single row is furniture.
class _Filters extends StatelessWidget {
  const _Filters({required this.controller});

  final DocumentListController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.documents.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpace.header),
      child: FilterChips<DocumentFilter>(
        options: DocumentFilter.values,
        selected: controller.filter.value,
        onSelected: (value) => controller.filter.value = value,
        countOf: controller.countFor,
        keyOf: (value) => PatientDocumentsKeys.filter(value.name),
        labelOf: (value) => switch (value) {
          DocumentFilter.all => PatientText.documentsFilterAll,
          DocumentFilter.needsCheck => PatientText.documentsFilterNeedsCheck,
          DocumentFilter.confirmed => PatientText.documentsFilterConfirmed,
        },
      ),
    );
  }
}

/// `Today`, `Yesterday`, or `12 Mar 2026`.
///
/// When the group's date came from the upload rather than off the paper, the
/// heading says so — once, on the right, quietly. A group whose documents all
/// carry their own date says nothing, because that is the expected case and a
/// label on it would be noise on every row of a full screen.
class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.group});

  final DocumentDateGroup group;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final undated = group.isUndated;

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: BentoSpace.page),
      child: Row(
        children: [
          Expanded(
            child: Text(
              undated ? PatientText.documentsUndatedHeading : _label(),
              key: undated
                  ? PatientDocumentsKeys.dayUndated
                  : PatientDocumentsKeys.day(group.day),
              style: isDark
                  ? AppTextStyles.darkTitle3()
                  : AppTextStyles.lightTitle3(),
            ),
          ),
          if (!group.fromPaper && !undated)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                PatientText.documentsDateAdded,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (isDark
                        ? AppTextStyles.darkFootnote()
                        : AppTextStyles.lightFootnote())
                    .copyWith(color: tertiaryLabelColor(context)),
              ),
            ),
        ],
      ),
    );
  }

  /// Relative for the two days a patient thinks of by name, absolute after
  /// that. `Formatters.relativeDay` is not used: it says "6 days ago", which
  /// is a duration, and a heading over a medical document wants the date.
  String _label() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final days = midnight.difference(group.day).inDays;

    return switch (days) {
      0 => PatientText.documentsToday,
      1 => PatientText.documentsYesterday,
      _ => Formatters.dateMedium(group.day),
    };
  }
}

/// One day's documents, ruled like every other list card in the app.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.group, required this.controller});

  final DocumentDateGroup group;
  final DocumentListController controller;

  @override
  Widget build(BuildContext context) {
    final rows = group.documents;

    return BentoCard(
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
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document, required this.onTap});

  final PatientDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `filedAt` rather than `when`: `when` is a pattern keyword, and a record
    // destructure cannot bind it.
    final (filedAt, fromPaper) = DocumentListController.filedUnder(document);

    // Which date this is, in words. The heading has already grouped by it;
    // the row repeats it because somebody scrolling past a heading still has
    // to be able to tell a report dated in March from one we only know the
    // arrival of.
    final dated = filedAt == null
        ? ''
        : fromPaper
            ? PatientText.documentDated(Formatters.dateMedium(filedAt))
            : PatientText.documentAdded(SettingsService.to.date(filedAt));

    return BentoRow(
      key: PatientDocumentsKeys.document(document.id),
      icon: _iconFor(document),
      title: document.kind.label,
      // The server's own sentence, under the row. It is the whole status: "We
      // found some information in this document", "You have already uploaded
      // this document", "We couldn't read this document clearly". Two lines,
      // because it is a sentence and a sentence cut in half is a status
      // nobody can act on.
      subtitle: [if (dated.isNotEmpty) dated, document.message].join(' · '),
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
