import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/case_intake_keys.dart';
import '../../../data/models/case_review.dart';
import '../../../data/services/settings_service.dart';
import '../../../theme/theme.dart';
import '../controllers/case_intake_controller.dart';

/// The intake, read by the clinician it was written for.
///
/// This is the staff register, not the patient one: the density of a ward
/// screen, `StatusPill`s on the rules that fired, and the engine's own wording
/// throughout. The patient's view of this same document
/// (`CaseReviewView`) is the opposite on every count, and the two are
/// different screens rather than one screen with a flag because they disagree
/// about what may be shown at all.
///
/// Three things it is careful about:
///
///  * **Every line says which of the six states it is in.** A denial, an "I
///    don't know", a refusal and a question nobody asked are four different
///    clinical facts. The server sends `presenceText` for each; this screen
///    prints it rather than deciding for itself, and never renders a value
///    where there is none.
///
///  * **What is missing is printed (§36).** An omitted line reads as nothing
///    to report, and "nothing to report" about an allergy history nobody took
///    is what this whole feature exists to avoid.
///
///  * **Nothing here is editable.** No correction control, no status ladder,
///    no "confirm". A clinician records their own findings in a consultation;
///    an intake a clinician can rewrite stops being evidence of what the
///    patient said.
class CaseIntakeView extends GetView<CaseIntakeController> {
  const CaseIntakeView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the top: a `GetView` whose build never touches `controller`
    // never constructs it, and this screen's fetch lives in `onReady`.
    final c = controller;

    return Scaffold(
      key: CaseIntakeKeys.screen,
      appBar: DetailHeader(
        title: 'Patient intake',
        action: Obx(
          () => c.intake.value.text.isEmpty
              ? const SizedBox.shrink()
              : CircleIconButton(
                  key: CaseIntakeKeys.copyTranscript,
                  icon: Icons.copy_all_outlined,
                  tooltip: 'Copy the whole intake',
                  onTap: c.copyTranscript,
                ),
        ),
      ),
      body: BentoScreen(
        bottomClearance: false,
        onRefresh: c.reload,
        slivers: [
          BentoSection(top: BentoSpace.page, bottom: 0, child: _Load(c: c)),
          BentoSection(top: BentoSpace.section, child: _Header(c: c)),
          BentoSection(bottom: 0, child: _RedFlags(c: c)),
          BentoSection(top: BentoSpace.section, child: _Sections(c: c)),
          BentoSection(top: BentoSpace.section, child: _Missing(c: c)),
          BentoSection(top: BentoSpace.section, child: _Transcript(c: c)),
        ],
      ),
    );
  }
}

class _Load extends StatelessWidget {
  const _Load({required this.c});

  final CaseIntakeController c;

  @override
  Widget build(BuildContext context) => Obx(
        () => c.hasNoAccess
            ? const EmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Not yours to read',
                message: 'This account cannot read patient intakes.',
              )
            : c.hasLoadError
                ? ErrorRetryBanner(
                    key: CaseIntakeKeys.error,
                    margin: EdgeInsets.zero,
                    message: c.rxLoadError.value ?? '',
                    onRetry: c.reload,
                  )
                : const SizedBox.shrink(),
      );
}

/// Who wrote it, when, and how much of it there is.
class _Header extends StatelessWidget {
  const _Header({required this.c});

  final CaseIntakeController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading && c.rxFirstLoad.value) {
        return const BentoCard(child: BentoSkeleton(rows: 3));
      }

      final intake = c.intake.value;
      if (intake.isEmpty) return const SizedBox.shrink();

      final summary = intake.summary;
      final patient = summary.patient;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BentoCard(
            key: CaseIntakeKeys.header,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FactRow(
                  label: 'Patient',
                  value: patient.displayName.isEmpty
                      ? '—'
                      : '${patient.displayName} · MRN ${patient.mrn}',
                ),
                FactRow(
                  label: 'Sent',
                  value: summary.submittedAt == null
                      ? '—'
                      : '${SettingsService.to.date(summary.submittedAt)} · '
                          '${SettingsService.to.time(summary.submittedAt)}',
                ),
                FactRow(
                  label: 'Answered',
                  value: '${summary.percentComplete}% of the questions asked',
                ),
                // Both languages, because one cannot say what happened. A
                // Tamil answer rendered in English is a fact worth knowing
                // before the consultation, not during it.
                if (summary.wasInterpreted)
                  FactRow(
                    label: 'Language',
                    value: 'Answered in ${summary.inputLanguageName}, '
                        'written in ${summary.outputLanguageName}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: BentoSpace.action),
          // "We could not read this", said out loud. Without it the screen
          // below is a header and nothing else, which reads as *this patient
          // submitted an empty intake* — a clinical statement about them,
          // made by a parser. Amber, because it is a gap in what the
          // clinician is being shown rather than decoration.
          if (intake.isUnreadable) ...[
            const NoticeBanner(
              key: CaseIntakeKeys.unreadableNotice,
              message: 'This intake was sent, but this version of the app '
                  'could not read what is in it. Nothing here means the '
                  'patient answered nothing — ask the desk to open it on the '
                  'console.',
              icon: Icons.report_gmailerrorred_outlined,
              tint: AppColors.warning,
            ),
            const SizedBox(height: BentoSpace.action),
          ],
          // The line that changes how everything under it is read, so it is
          // above everything under it. Neutral rather than amber: this is a
          // property of the document, not a warning about this patient.
          const NoticeBanner(
            key: CaseIntakeKeys.unverifiedNotice,
            message: 'Written by the patient in their own words, before they '
                'were seen. Nothing here has been verified by a clinician.',
            icon: Icons.record_voice_over_outlined,
          ),
        ],
      );
    });
  }
}

/// The safety rules that fired.
///
/// The part of this document the patient's own view of it does not show, and
/// the reason the two are separate screens. §43 keeps a rule set's titles off
/// a patient's screen because they name syndromes and a syndrome on a
/// patient's screen is a diagnosis nobody qualified made. The clinician is the
/// qualified reader — withholding which rules fired from the person deciding
/// what to do about them would be the inverse mistake.
class _RedFlags extends StatelessWidget {
  const _RedFlags({required this.c});

  final CaseIntakeController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final safety = c.intake.value.safety;
      if (safety.isEmpty) return const SizedBox.shrink();

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return BentoCard(
        key: CaseIntakeKeys.redFlags,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              safety.triggered.length == 1
                  ? 'One safety rule fired'
                  : '${safety.triggered.length} safety rules fired',
              style: isDark
                  ? AppTextStyles.darkTitle3()
                  : AppTextStyles.lightTitle3(),
            ),
            const SizedBox(height: 4),
            Text(
              'Rule set ${safety.rulesetVersion}. These are the rules that ran '
              'on this case, not a diagnosis.',
              style: (isDark
                      ? AppTextStyles.darkFootnote()
                      : AppTextStyles.lightFootnote())
                  .copyWith(color: secondaryLabelColor(context)),
            ),
            const SizedBox(height: BentoSpace.action),
            for (final flag in safety.triggered) ...[
              InsetSurface(
                key: CaseIntakeKeys.redFlag(flag.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            flag.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: isDark
                                ? AppTextStyles.darkHeadline()
                                : AppTextStyles.lightHeadline(),
                          ),
                        ),
                        const SizedBox(width: BentoSpace.action),
                        // Colour **and** word, never colour alone: the pill
                        // carries its own label.
                        StatusPill(status: flag.severity, compact: true),
                      ],
                    ),
                    if ((flag.rationale ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        flag.rationale!,
                        style: (isDark
                                ? AppTextStyles.darkSubheadline()
                                : AppTextStyles.lightSubheadline())
                            .copyWith(
                          color: secondaryLabelColor(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if ((flag.action ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        flag.action!,
                        style: isDark
                            ? AppTextStyles.darkSubheadline()
                            : AppTextStyles.lightSubheadline(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: BentoSpace.header),
            ],
          ],
        ),
      );
    });
  }
}

/// The case itself, section by section.
class _Sections extends StatelessWidget {
  const _Sections({required this.c});

  final CaseIntakeController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sections = c.intake.value.sections;
      if (sections.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections) ...[
            SectionHeader(title: section.title),
            const SizedBox(height: BentoSpace.header),
            BentoCard(
              key: CaseIntakeKeys.section(section.section),
              padding: const EdgeInsets.symmetric(
                vertical: BentoSpace.listCardPad,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < section.items.length; i++) ...[
                    if (i > 0) const Hairline(indent: BentoSpace.listPad),
                    _Item(item: section.items[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: BentoSpace.section),
          ],
        ],
      );
    });
  }
}

/// One line of the case.
///
/// The value when there is one, and the presence's own wording when there is
/// not — `display` already carries that rule and `presenceText` states it
/// again, so a blank can never stand in for "Patient unsure". Never
/// ellipsised down to something ambiguous: a clinical figure cut short is a
/// different figure.
class _Item extends StatelessWidget {
  const _Item({required this.item});

  final CaseReviewItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recorded = item.isRecorded;

    return Padding(
      key: CaseIntakeKeys.item(item.fieldPath),
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: (isDark
                    ? AppTextStyles.darkFootnote()
                    : AppTextStyles.lightFootnote())
                .copyWith(color: secondaryLabelColor(context)),
          ),
          const SizedBox(height: 2),
          Text(
            item.display,
            style: isDark
                ? AppTextStyles.darkBody()
                : AppTextStyles.lightBody(),
          ),
          // The state, spelled out — but only when `display` has not already
          // said it. The renderer puts the presence's own wording in `display`
          // for a line with no value, so printing `presenceText` underneath it
          // renders "None reported" twice in one row. It differs only when a
          // field overrides the wording ("No known allergies" against the
          // canonical "None reported"), and *that* pair is worth both lines.
          if (!recorded &&
              item.presenceText.isNotEmpty &&
              item.presenceText != item.display) ...[
            const SizedBox(height: 4),
            Text(
              item.presenceText,
              style: (isDark
                      ? AppTextStyles.darkCaption1()
                      : AppTextStyles.lightCaption1())
                  .copyWith(color: tertiaryLabelColor(context)),
            ),
          ],
        ],
      ),
    );
  }
}

/// §36: every applicable question nobody answered, printed rather than
/// omitted — because an omitted line reads as nothing to report.
class _Missing extends StatelessWidget {
  const _Missing({required this.c});

  final CaseIntakeController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final intake = c.intake.value;
      final outstanding = intake.outstandingItems;

      // The questions' own wording where the sections parsed, and their field
      // keys where they did not. `missingInformation` is a **separately
      // defaulted** field on the stored document — a case this build cannot
      // fully read answers with an empty `sections` and an intact list of what
      // was never asked, and a card built only from `outstandingItems` would
      // drop the lot. §36's whole claim is that an unanswered question is
      // printed rather than omitted, and `hpi.radiation` on screen is worse
      // reading than "Does the pain go anywhere else?" and far better than
      // silence.
      final labels = outstanding.isNotEmpty
          ? [for (final item in outstanding) item.label]
          : intake.missingInformation;
      if (labels.isEmpty) return const SizedBox.shrink();

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return BentoCard(
        key: CaseIntakeKeys.missing,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Not asked',
              style: isDark
                  ? AppTextStyles.darkTitle3()
                  : AppTextStyles.lightTitle3(),
            ),
            const SizedBox(height: 4),
            Text(
              'The interview did not reach these. Silence here is not a '
              'negative finding.',
              style: (isDark
                      ? AppTextStyles.darkSubheadline()
                      : AppTextStyles.lightSubheadline())
                  .copyWith(color: secondaryLabelColor(context), height: 1.4),
            ),
            const SizedBox(height: BentoSpace.action),
            for (final label in labels)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '· $label',
                  style: isDark
                      ? AppTextStyles.darkBody()
                      : AppTextStyles.lightBody(),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// The whole case as text — what gets read on a ward round, and what the copy
/// button puts on the clipboard.
class _Transcript extends StatelessWidget {
  const _Transcript({required this.c});

  final CaseIntakeController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final text = c.intake.value.text.trim();
      if (text.isEmpty) return const SizedBox.shrink();

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return BentoCard(
        key: CaseIntakeKeys.transcript,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'As written',
              style: isDark
                  ? AppTextStyles.darkTitle3()
                  : AppTextStyles.lightTitle3(),
            ),
            const SizedBox(height: BentoSpace.header),
            // The server's own rendering, printed as it arrived. Rebuilding it
            // from the sections above would be a second renderer quietly
            // disagreeing with the one that wrote the record.
            SelectableText(
              text,
              style: (isDark
                      ? AppTextStyles.darkSubheadline()
                      : AppTextStyles.lightSubheadline())
                  .copyWith(height: 1.5),
            ),
          ],
        ),
      );
    });
  }
}
