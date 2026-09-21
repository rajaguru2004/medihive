import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/i18n/patient_text.dart';
import '../../../core/keys/app_keys.dart';
import '../../../data/models/case_review.dart';
import '../../../data/models/case_session.dart';
import '../../../data/services/settings_service.dart';
import '../../../theme/theme.dart';
import '../../patient_portal/patient_portal_navigation.dart';
import '../controllers/case_review_controller.dart';

/// "Here is what we understood about you."
///
/// The last screen before a case leaves the phone, and the screen this whole
/// feature is judged on. Four things it does and one it refuses to:
///
///  * **Every line says which of the six states it is in.** A value, a denial,
///    an "I don't know", a "not applicable", a refusal and a question nobody
///    asked are six different clinical facts and they are printed as six. The
///    row that lets a patient settle one is `UnknownAnswerRow` — four equal
///    tiles, because a "no" laid out as a button beside an "I don't know" laid
///    out as a link is a screen that has already decided what they ought to
///    say.
///
///  * **What is missing is printed (§36).** An omitted line reads as nothing
///    to report, and "nothing to report" about an allergy history nobody took
///    is the sentence this entire feature exists to avoid.
///
///  * **A contradiction shows both sides and changes neither (§20, §33).**
///    There is deliberately no control in that card. The app cannot resolve a
///    disagreement between a document and a record, and a button implying it
///    could would be the app making a clinical decision.
///
///  * **Nothing here is presented as a diagnosis (§43).** The disclaimer is on
///    screen above the case rather than in a footnote, and there is no field
///    anywhere in the review document that could hold one.
///
/// What it refuses: to draw an unconfirmed value like a confirmed one. The
/// wording under each line follows the server's `verification` and nothing
/// else — a tap on this device selects a tile, and selecting a tile is not the
/// record agreeing with you.
class CaseReviewView extends GetView<CaseReviewController> {
  const CaseReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the top: a `GetView` whose build never touches `controller`
    // never constructs it, and this screen's fetch lives in `onReady`.
    final c = controller;

    return Scaffold(
      key: CaseReviewKeys.screen,
      appBar: DetailHeader(title: PatientText.reviewTitle),
      body: BentoScreen(
        bottomClearance: false,
        onRefresh: c.reload,
        slivers: [
          BentoSection(top: BentoSpace.page, bottom: 0, child: _Load(c: c)),
          BentoSection(top: BentoSpace.section, child: _Header(c: c)),
          BentoSection(bottom: 0, child: _Safety(c: c)),
          BentoSection(top: BentoSpace.section, child: _Contradictions(c: c)),
          BentoSection(bottom: 0, child: _Sections(c: c)),
          BentoSection(top: BentoSpace.section, child: _Missing(c: c)),
          BentoSection(child: _Submit(c: c)),
        ],
      ),
    );
  }
}

class _Load extends StatelessWidget {
  const _Load({required this.c});

  final CaseReviewController c;

  @override
  Widget build(BuildContext context) => Obx(
        () => c.hasLoadError
            ? ErrorRetryBanner(
                key: CaseReviewKeys.error,
                margin: EdgeInsets.zero,
                message: c.rxLoadError.value ?? '',
                onRetry: c.reload,
              )
            : const SizedBox.shrink(),
      );
}

/// What this screen is, what it is not, and how far through the questions they
/// got.
class _Header extends StatelessWidget {
  const _Header({required this.c});

  final CaseReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final review = c.review.value;
      final receipt = c.receipt;

      final expected = review.sections
          .fold<int>(0, (sum, section) => sum + section.items.length);
      final addressed = expected -
          review.sections.fold<int>(
            0,
            (sum, section) =>
                sum + section.items.where((item) => item.outstanding).length,
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The case has gone. Said first, because it changes what every
          // control below it means.
          if (c.isSubmitted) ...[
            BentoCard(
              key: CaseReviewKeys.submitted,
              hero: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 22,
                        color: semanticInk(context, AppColors.success),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          PatientText.caseSent,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: isDark
                              ? AppTextStyles.darkTitle3()
                              : AppTextStyles.lightTitle3(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    PatientText.caseSentBody,
                    style: (isDark
                            ? AppTextStyles.darkBody()
                            : AppTextStyles.lightBody())
                        .copyWith(
                      color: secondaryLabelColor(context),
                      height: 1.45,
                    ),
                  ),
                  if (receipt?.submittedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${SettingsService.to.date(receipt!.submittedAt)} · '
                      '${SettingsService.to.time(receipt.submittedAt)}',
                      style: (isDark
                              ? AppTextStyles.darkFootnote()
                              : AppTextStyles.lightFootnote())
                          .copyWith(color: tertiaryLabelColor(context)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: BentoSpace.action),
            NoticeBanner(
              key: CaseReviewKeys.locked,
              icon: Icons.lock_outline_rounded,
              message: PatientText.alreadySent,
            ),
            const SizedBox(height: BentoSpace.section),
          ],

          Text(
            PatientText.reviewIntro,
            key: CaseReviewKeys.intro,
            style: (isDark
                    ? AppTextStyles.darkBody()
                    : AppTextStyles.lightBody())
                .copyWith(height: 1.45),
          ),
          const SizedBox(height: BentoSpace.action),

          // §43, above the case rather than under it. A patient who believes
          // the app has told them what is wrong may not go in at all.
          NoticeBanner(
            key: CaseReviewKeys.disclaimer,
            icon: Icons.info_outline_rounded,
            message: PatientText.notADiagnosis,
          ),

          if (expected > 0) ...[
            const SizedBox(height: BentoSpace.section),
            Column(
              key: CaseReviewKeys.progress,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PatientText.answeredProgress(addressed, expected),
                  // Tabular: two figures that tick as the patient answers, and
                  // a proportional `9` makes the line shuffle sideways.
                  style: numeralStyle(
                    context,
                    size: 15,
                    weight: FontWeight.w600,
                    color: secondaryLabelColor(context),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                UsedBar(
                  fraction: addressed / expected,
                  color: brandFillColor(context),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

/// The one red thing on this surface, and only when a rule fired.
///
/// The server's own patient view: a routing sentence and nothing else. The rule
/// set's titles name syndromes, and a syndrome on a patient's screen is a
/// diagnosis nobody qualified made.
class _Safety extends StatelessWidget {
  const _Safety({required this.c});

  final CaseReviewController c;

  @override
  Widget build(BuildContext context) => Obx(() {
        final safety = c.review.value.safety;
        if (!safety.hasFired) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: BentoSpace.section),
          child: RedFlagNotice(
            key: CaseReviewKeys.safety,
            reported: safety.patientMessage!,
            // Null: this screen has nobody to alert. The notice still shows,
            // which is the whole contract of the component.
            onTellSomeone: null,
          ),
        );
      });
}

/// §20 and §33: both values, and no way to resolve them from here.
class _Contradictions extends StatelessWidget {
  const _Contradictions({required this.c});

  final CaseReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = c.contradictions;
      if (rows.isEmpty) return const SizedBox.shrink();

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PatientText.pleaseCheckThese,
            style: isDark
                ? AppTextStyles.darkTitle3()
                : AppTextStyles.lightTitle3(),
          ),
          const SizedBox(height: 6),
          Text(
            PatientText.contradictionIntro,
            style: (isDark
                    ? AppTextStyles.darkSubheadline()
                    : AppTextStyles.lightSubheadline())
                .copyWith(color: secondaryLabelColor(context), height: 1.4),
          ),
          const SizedBox(height: BentoSpace.header),
          BentoCard(
            key: CaseReviewKeys.contradictions,
            padding: const EdgeInsets.symmetric(
              vertical: BentoSpace.listCardPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  _Contradiction(row: rows[i]),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _Contradiction extends StatelessWidget {
  const _Contradiction({required this.row});

  final ReviewContradiction row;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final held = row.finding.recordValues.join(', ');

    return Padding(
      key: CaseReviewKeys.contradiction(row.id),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(BentoSpace.listPad, 0,
                BentoSpace.listPad, 4),
            child: Text(
              row.documentKind.label,
              style: (isDark
                      ? AppTextStyles.darkFootnote(weight: FontWeight.w600)
                      : AppTextStyles.lightFootnote(weight: FontWeight.w600))
                  .copyWith(color: tertiaryLabelColor(context)),
            ),
          ),
          // Both sides, stacked so neither is squeezed into half a phone — a
          // medicine name cut in the middle is the failure this card exists to
          // prevent. And no control: the app cannot decide which is right, and
          // a button implying it could would be it making a clinical decision.
          FactRow(
            label: PatientText.inYourDocument,
            value: row.finding.documentValue,
            stacked: true,
          ),
          FactRow(
            label: row.finding.recordHadEntries
                ? PatientText.inYourRecord
                : PatientText.notInYourRecordYet,
            value: held.isEmpty ? '—' : held,
            stacked: true,
          ),
        ],
      ),
    );
  }
}

/// The case itself, section by section.
class _Sections extends StatelessWidget {
  const _Sections({required this.c});

  final CaseReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final review = c.review.value;

      if (review.sections.isEmpty) {
        if (c.isLoading) return const BentoCard(child: BentoSkeleton(rows: 4));
        if (c.hasLoadError) return const SizedBox.shrink();
        return const BentoCard(
          child: EmptyState(
            compact: true,
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Nothing to read back yet',
            message: 'Once you have answered some questions, what we '
                'understood will be here for you to check.',
          ),
        );
      }

      final error = c.actionError.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            NoticeBanner(
              icon: Icons.info_outline_rounded,
              tint: AppColors.warning,
              message: error,
            ),
            const SizedBox(height: BentoSpace.section),
          ],
          for (final section in review.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: BentoSpace.section),
              child: BentoCard(
                key: CaseReviewKeys.section(section.section),
                padding: const EdgeInsets.symmetric(
                  vertical: BentoSpace.listCardPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: section.title, inset: true),
                    for (var i = 0; i < section.items.length; i++) ...[
                      if (i > 0) const Hairline(indent: BentoSpace.listPad),
                      _Item(c: c, item: section.items[i]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.c, required this.item});

  final CaseReviewController c;
  final CaseReviewItem item;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final isEditing = c.editingField.value == item.fieldPath;
      final wasChecked = c.isChecked(item.fieldPath);

      return Padding(
        key: CaseReviewKeys.item(item.fieldPath),
        padding: const EdgeInsets.fromLTRB(
          BentoSpace.listPad,
          10,
          BentoSpace.listPad,
          14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.label,
              style: (isDark
                      ? AppTextStyles.darkSubheadline()
                      : AppTextStyles.lightSubheadline())
                  .copyWith(color: secondaryLabelColor(context)),
            ),
            const SizedBox(height: 3),
            // `display` is always safe to print: the value when there is one,
            // and the presence's own wording otherwise. Never one line and
            // never ellipsised — a duration cut to `16…` could be 16 days or
            // 160.
            Text(
              // The net under the net. `display` is contractually never empty
              // — the renderer prints the presence's own wording where there
              // is no value — and `presenceText` is sent separately so that a
              // client cannot draw a blank line where "Patient unsure"
              // belongs. If the contract ever slips, this is what the patient
              // sees instead of nothing.
              item.display.isEmpty ? item.presenceText : item.display,
              style: isDark
                  ? AppTextStyles.darkBody(weight: FontWeight.w600)
                  : AppTextStyles.lightBody(weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SourceChip(source: _sourceOf(item.source)),
                if (item.confidence != null)
                  ConfidenceMark(
                    confidence: AnswerConfidence.fromScore(item.confidence),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Follows the **server**, never the tap. A line the record has not
            // confirmed says so, even on a screen where the patient has just
            // pressed "That's right" — because until the write lands, it has
            // not.
            Text(
              item.verification.isConfirmed
                  ? PatientText.youConfirmedThis
                  : PatientText.notCheckedYet,
              style: (isDark
                      ? AppTextStyles.darkFootnote()
                      : AppTextStyles.lightFootnote())
                  .copyWith(color: tertiaryLabelColor(context)),
            ),

            if (c.canEdit) ...[
              const SizedBox(height: 10),
              if (isEditing)
                _Editor(c: c)
              else if (item.isRecorded)
                AnswerChoiceRow<_ItemAction>(
                  columns: 3,
                  choices: _ItemAction.values,
                  selected: wasChecked ? _ItemAction.confirm : null,
                  labelOf: (action) => switch (action) {
                    _ItemAction.confirm => PatientText.thatIsRight,
                    _ItemAction.change => PatientText.change,
                    _ItemAction.unsure => PatientText.iDontKnow,
                  },
                  iconOf: (action) => switch (action) {
                    _ItemAction.confirm => Icons.check_rounded,
                    _ItemAction.change => Icons.edit_outlined,
                    _ItemAction.unsure => Icons.help_outline_rounded,
                  },
                  keyOf: (action) => switch (action) {
                    _ItemAction.confirm =>
                      CaseReviewKeys.confirmItem(item.fieldPath),
                    _ItemAction.change =>
                      CaseReviewKeys.correctItem(item.fieldPath),
                    _ItemAction.unsure =>
                      CaseReviewKeys.unsureItem(item.fieldPath),
                  },
                  onSelected: (action) => switch (action) {
                    _ItemAction.confirm => c.confirmItem(item),
                    _ItemAction.change => c.startCorrecting(item),
                    _ItemAction.unsure => c.markUnsure(item),
                  },
                )
              else
                // Four equal tiles for a question that has no value on it. Four
                // different clinical facts, and never two and two: a "no"
                // drawn as a button beside an "I don't know" drawn as a link is
                // a screen that has decided what the patient ought to say.
                UnknownAnswerRow(
                  selected: _answerOf(item.presence),
                  keyOf: (answer) => switch (answer) {
                    PatientAnswer.unknown =>
                      CaseReviewKeys.unsureItem(item.fieldPath),
                    PatientAnswer.yes =>
                      CaseReviewKeys.confirmItem(item.fieldPath),
                    PatientAnswer.no =>
                      CaseReviewKeys.correctItem(item.fieldPath),
                    PatientAnswer.skipped => null,
                  },
                  onAnswered: (answer) => c.answer(item, answer),
                ),
            ],
          ],
        ),
      );
    });
  }

  /// The four tiles, from the six presences.
  ///
  /// `recorded` and `notApplicable` are deliberately null: neither is one of
  /// the four things this row can say, and pre-selecting the nearest tile would
  /// be the app putting an answer in somebody's mouth. `notAssessed` is null
  /// too, and that is the whole point of the row.
  static PatientAnswer? _answerOf(FactPresence presence) => switch (presence) {
        FactPresence.none => PatientAnswer.no,
        FactPresence.unknown => PatientAnswer.unknown,
        FactPresence.declined => PatientAnswer.skipped,
        FactPresence.recorded ||
        FactPresence.notApplicable ||
        FactPresence.notAssessed =>
          null,
      };

  /// The engine's seven sources, through the kit's four.
  ///
  /// `SourceChip` carries a document glyph for [AnswerSource.record], which is
  /// what a document and an existing record have in common from the patient's
  /// side: neither is something they said just now. A **correction** reads as
  /// typed, which is what it is, and that re-label is the visible consequence
  /// of changing a line.
  static AnswerSource _sourceOf(CaseFactSource source) => switch (source) {
        CaseFactSource.patientVoice => AnswerSource.spoken,
        CaseFactSource.patientText => AnswerSource.typed,
        CaseFactSource.patientCorrection => AnswerSource.typed,
        CaseFactSource.patientChoice => AnswerSource.chosen,
        CaseFactSource.uploadedDocument ||
        CaseFactSource.existingRecord ||
        CaseFactSource.clinicianConfirmed =>
          AnswerSource.record,
      };
}

/// The three things a patient can say about a line that has a value on it.
enum _ItemAction { confirm, change, unsure }

class _Editor extends StatelessWidget {
  const _Editor({required this.c});

  final CaseReviewController c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BentoInput(
          key: CaseReviewKeys.correctionField,
          controller: c.correctionText,
          label: PatientText.whatShouldItSay,
          hint: PatientText.typeHere,
        ),
        const SizedBox(height: BentoSpace.action),
        Row(
          children: [
            Expanded(
              child: SecondaryBar(
                label: PatientText.skip,
                onPressed: c.cancelCorrecting,
              ),
            ),
            const SizedBox(width: BentoSpace.action),
            Expanded(
              child: Obx(
                () => PrimaryBar(
                  key: CaseReviewKeys.correctionSave,
                  label: PatientText.saveCorrection,
                  busy: c.isSaving.value,
                  onPressed: c.saveCorrection,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// §36, printed rather than omitted.
class _Missing extends StatelessWidget {
  const _Missing({required this.c});

  final CaseReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final outstanding = c.review.value.outstandingItems;
      if (outstanding.isEmpty) return const SizedBox.shrink();

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return BentoCard(
        key: CaseReviewKeys.missing,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              PatientText.stillToAsk,
              style: isDark
                  ? AppTextStyles.darkTitle3()
                  : AppTextStyles.lightTitle3(),
            ),
            const SizedBox(height: 6),
            Text(
              PatientText.stillToAskBody,
              style: (isDark
                      ? AppTextStyles.darkSubheadline()
                      : AppTextStyles.lightSubheadline())
                  .copyWith(color: secondaryLabelColor(context), height: 1.4),
            ),
            const SizedBox(height: BentoSpace.action),
            for (final item in outstanding)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.radio_button_unchecked_rounded,
                      size: 15,
                      color: tertiaryLabelColor(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        style: isDark
                            ? AppTextStyles.darkSubheadline()
                            : AppTextStyles.lightSubheadline(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Sending it.
class _Submit extends StatelessWidget {
  const _Submit({required this.c});

  final CaseReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!c.canEdit) return const SizedBox.shrink();

      final error = c.actionError.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            NoticeBanner(
              key: CaseReviewKeys.submitError,
              icon: Icons.info_outline_rounded,
              tint: AppColors.warning,
              message: error,
            ),
            const SizedBox(height: BentoSpace.action),
          ],
          PrimaryBar(
            key: CaseReviewKeys.submit,
            label: PatientText.sendToTheHospital,
            icon: Icons.send_rounded,
            busy: c.isSubmitting.value,
            onPressed: () async {
              if (!await c.submit()) return;
              showBentoToast(PatientText.caseSent);
              if (!context.mounted) return;
              await _offerBooking(context, c);
            },
          ),
        ],
      );
    });
  }
}

/// Offers a booking, with the complaint the interview just recorded.
///
/// Asked **after** the case has gone and never before it: the two are separate
/// things a patient may want, and a dialog in front of the send button would
/// make the one they came to do conditional on an answer about the other.
/// Declining is a plain "not now" with no consequence — the answers are
/// already with the hospital, and a clinic that reads them will book whatever
/// it thinks is needed.
///
/// What crosses over is the complaint and nothing else. The day, the time and
/// the clinician are chosen on the booking screen by the patient, because the
/// interview never asked them and a screen that filled them in would be
/// guessing at the one part of a booking a patient has an opinion about.
Future<void> _offerBooking(
  BuildContext context,
  CaseReviewController c,
) async {
  final complaint = c.review.value.complaintSummary;

  final wantsBooking = await ConfirmDialog.show(
    context,
    title: PatientText.bookAfterCaseTitle,
    message: complaint.isEmpty
        ? PatientText.bookAfterCaseBodyNoComplaint
        : PatientText.bookAfterCaseBody(complaint),
    confirmLabel: PatientText.bookAfterCaseYes,
    cancelLabel: PatientText.bookAfterCaseNo,
    confirmKey: CaseReviewKeys.bookConfirm,
    cancelKey: CaseReviewKeys.bookDecline,
  );

  if (!wantsBooking) return;
  PatientPortalNavigation.toBooking(reason: complaint);
}
