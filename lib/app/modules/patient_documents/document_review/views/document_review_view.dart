import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/i18n/patient_text.dart';
import '../../../../core/keys/app_keys.dart';
import '../../../../data/models/patient_document.dart';
import '../../../../data/services/settings_service.dart';
import '../../../../theme/theme.dart';
import '../../../login/demo_accounts.dart';
import '../../patient_documents_navigation.dart';
import '../controllers/document_review_controller.dart';

/// One document, and what was read out of it.
///
/// Three rules shape everything on this screen, and all three are about not
/// claiming more than is known:
///
///  * **The sentence is the server's.** The card at the top prints
///    `document.message` verbatim — "We found some information in this
///    document", "You have already uploaded this document", "We couldn't read
///    this document clearly. Please upload a clearer image." §27's failure is
///    an engine's exception text reaching a patient, and it leaks through a
///    client that decides it can word the state better itself.
///
///  * **The two confidences are two numbers.** They measure different things
///    and they are printed under their own names with their own figures. There
///    is no combined "accuracy" on this screen and there is no code path that
///    could produce one.
///
///  * **An unchecked value is never drawn like a checked one.** The state line
///    under every row says which of the four it is, and the document-level
///    confirmation is not offered until every one of them has been agreed
///    with.
class DocumentReviewView extends GetView<DocumentReviewController> {
  const DocumentReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the top, before anything can decide not to: a `GetView` whose
    // build never touches `controller` never constructs it, and this screen's
    // fetch lives in `onReady`.
    final c = controller;

    return Scaffold(
      key: PatientDocumentsKeys.review,
      // The header's own height is `preferredSize`, which Flutter reads without
      // a `BuildContext` — so a reactive bar has to declare it here rather than
      // let an `Obx` decide. 60 is `DetailHeader.preferredSize`.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Obx(
          () => DetailHeader(
            title: c.document.value.kind.label,
            subtitle: _subtitleOf(c),
          ),
        ),
      ),
      body: BentoScreen(
        bottomClearance: false,
        onRefresh: c.reload,
        slivers: [
          BentoSection(
            top: BentoSpace.page,
            bottom: 0,
            child: _Load(c: c),
          ),
          BentoSection(
            top: BentoSpace.section,
            child: _Message(c: c),
          ),
          BentoSection(bottom: 0, child: _HowThisWasRead(c: c)),
          BentoSection(
            top: BentoSpace.section,
            child: _Original(c: c),
          ),
          BentoSection(bottom: 0, child: _Findings(c: c)),
          BentoSection(
            top: BentoSpace.section,
            child: _Confirm(c: c),
          ),
        ],
      ),
    );
  }

  static String? _subtitleOf(DocumentReviewController c) {
    final document = c.document.value;
    final when = document.uploadedAt == null
        ? ''
        : SettingsService.to.date(document.uploadedAt);
    return when.isEmpty ? null : when;
  }
}

/// The screen's own failure, above everything it would have filled in.
class _Load extends StatelessWidget {
  const _Load({required this.c});

  final DocumentReviewController c;

  @override
  Widget build(BuildContext context) => Obx(
    () => c.hasLoadError
        ? ErrorRetryBanner(
            key: PatientDocumentsKeys.reviewError,
            margin: EdgeInsets.zero,
            message: c.rxLoadError.value ?? '',
            onRetry: c.reload,
          )
        : const SizedBox.shrink(),
  );
}

/// What the server says about this document, in the server's own words.
class _Message extends StatelessWidget {
  const _Message({required this.c});

  final DocumentReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final document = c.document.value;
      if (document.message.isEmpty) return const SizedBox.shrink();

      // Amber where the app is admitting something, green where the patient
      // has settled it, neutral otherwise. Never red: a document that could
      // not be read is not a deteriorating patient, and `.agents/RULES.md` §0
      // keeps that red for the one thing it means.
      final tint = switch (document.status) {
        _ when document.isDuplicate => AppColors.acuityStandard,
        DocumentStatus.verified => AppColors.success,
        DocumentStatus.failed ||
        DocumentStatus.rejectedQuality => AppColors.warning,
        _ => AppColors.acuityStandard,
      };

      // §21: the same document twice is recorded and reported, never refused —
      // and the server's own sentence already says so, in whichever form fits
      // the first copy's outcome ("we have kept it with the first copy", or,
      // when that copy was rejected, why it was). A second banner here
      // repeated the first in different words, and on a duplicate of a
      // rejected photo it contradicted it: one line said the document was
      // filed while the other said it could not be read.
      //
      // The duplicate icon still marks it, so the fact is not lost.
      final firstCopyId = document.duplicateOfId;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoticeBanner(
            key: PatientDocumentsKeys.message,
            icon: document.isDuplicate
                ? Icons.content_copy_outlined
                : document.status.isRefusal
                ? Icons.image_not_supported_outlined
                : Icons.info_outline_rounded,
            tint: tint,
            message: document.message,
          ),
          // A duplicate is a dead end without this. The pipeline never runs for
          // one, so the row carries no extraction and no facts — the screen is
          // the sentence and nothing else. The reading the patient came for is
          // on the copy this points at, and until now the only route to it was
          // to go back and find it in the list themselves.
          if (document.isDuplicate && (firstCopyId ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: BentoSpace.action),
              child: SecondaryBar(
                key: PatientDocumentsKeys.duplicate,
                label: PatientText.openTheFirstCopy,
                icon: Icons.description_outlined,
                onPressed: () =>
                    PatientDocumentsNavigation.toFirstCopy(firstCopyId!),
              ),
            ),
        ],
      );
    });
  }
}

/// §17's two stages, on screen as two figures under two names.
class _HowThisWasRead extends StatelessWidget {
  const _HowThisWasRead({required this.c});

  final DocumentReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final document = c.document.value;
      final confidence = document.confidence;
      if (confidence.ocr == null && confidence.extraction == null) {
        return const SizedBox.shrink();
      }

      return BentoCard(
        padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: PatientText.howThisWasRead, inset: true),
            _ConfidenceRow(
              rowKey: PatientDocumentsKeys.ocrConfidence,
              label: PatientText.textRecognition,
              score: confidence.ocr,
            ),
            _ConfidenceRow(
              rowKey: PatientDocumentsKeys.extractionConfidence,
              label: PatientText.informationFound,
              score: confidence.extraction,
            ),
          ],
        ),
      );
    });
  }
}

/// One measured number, named for what it measures.
class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({
    required this.rowKey,
    required this.label,
    required this.score,
  });

  final Key rowKey;
  final String label;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final value = score;

    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).brightness == Brightness.dark
                  ? AppTextStyles.darkSubheadline()
                  : AppTextStyles.lightSubheadline(),
            ),
          ),
          const SizedBox(width: 12),
          if (value == null)
            Text(
              PatientText.notMeasured,
              style:
                  (Theme.of(context).brightness == Brightness.dark
                          ? AppTextStyles.darkSubheadline()
                          : AppTextStyles.lightSubheadline())
                      .copyWith(color: tertiaryLabelColor(context)),
            )
          else
            Text(
              '${(value * 100).round()}%',
              // Tabular. Two of these sit one above the other and a
              // proportional `9` narrower than a `0` makes the column ragged.
              // Never ellipsised: this is a figure.
              style: numeralStyle(
                context,
                size: 17,
                weight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

/// §22's evidence, one tap away.
class _Original extends StatelessWidget {
  const _Original({required this.c});

  final DocumentReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bytes = c.originalBytes.value;
      final error = c.originalError.value;
      final pdf = c.pdfController.value;

      if (!c.canShowOriginal) {
        // Neither a photograph nor a PDF, so nothing here can draw it. The row
        // says what is true instead: the file itself is kept. The upload route
        // accepts only those two, so this is a floor rather than a case the
        // patient meets.
        return const NoticeBanner(
          key: PatientDocumentsKeys.original,
          icon: Icons.insert_drive_file_outlined,
          message:
              'The file you sent is kept with your record exactly as it '
              'was. Ask at the desk if you would like to see it.',
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecondaryBar(
            key: PatientDocumentsKeys.original,
            label: PatientText.seeTheOriginal,
            icon: bytes == null
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            onPressed: c.isFetchingOriginal.value ? null : c.toggleOriginal,
          ),
          // The fetch failed. Said here, under the button that was pressed,
          // rather than in the confirmation block — that block is not drawn at
          // all on a verified or failed document, which is where this used to
          // vanish and leave a button that appeared to do nothing.
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: BentoSpace.action),
              child: NoticeBanner(
                icon: Icons.image_not_supported_outlined,
                tint: AppColors.warning,
                message: error,
              ),
            ),
          if (bytes != null && c.originalIsPdf)
            Padding(
              padding: const EdgeInsets.only(top: BentoSpace.action),
              child: InsetSurface(
                radius: BentoRadius.card,
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BentoRadius.control),
                  // A fixed height, because `PdfView` expands to whatever it is
                  // given and this sits inside a scrolling column — unbounded,
                  // it throws during layout rather than rendering small.
                  //
                  // Tall enough that a prescription's dose line is legible
                  // without pinching, which is the whole reason a patient opens
                  // this.
                  child: SizedBox(
                    height: 520,
                    child: pdf == null
                        ? const Center(child: CircularProgressIndicator())
                        : PdfView(
                            controller: pdf,
                            scrollDirection: Axis.vertical,
                          ),
                  ),
                ),
              ),
            ),
          if (bytes != null && !c.originalIsPdf)
            Padding(
              padding: const EdgeInsets.only(top: BentoSpace.action),
              child: InsetSurface(
                radius: BentoRadius.card,
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BentoRadius.control),
                  // From memory, not from a URL. The bytes arrived over the
                  // authenticated client, so there is no second request here
                  // to be refused for want of a token or a reachable host.
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    // A page that will not load must still leave a readable
                    // screen: an unhandled image error throws from inside
                    // `build` and takes down the review it was evidence for.
                    errorBuilder: (context, _, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          PatientText.couldNotOpenOriginal,
                          textAlign: TextAlign.center,
                          style:
                              (Theme.of(context).brightness == Brightness.dark
                                      ? AppTextStyles.darkSubheadline()
                                      : AppTextStyles.lightSubheadline())
                                  .copyWith(
                                    color: secondaryLabelColor(context),
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Everything that was read, by topic, plus everything the document was silent
/// about.
class _Findings extends StatelessWidget {
  const _Findings({required this.c});

  final DocumentReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final document = c.document.value;
      // Nothing to review while it is still being read, and nothing to review
      // on a document that could not be read at all — the sentence above has
      // already said so, and an empty "what we found" under it would read as
      // a finding of nothing.
      if (document.status.isWorking ||
          document.status.isRefusal ||
          document.isDuplicate) {
        return const SizedBox.shrink();
      }

      final silences = [
        for (final topic in DocumentTopic.values)
          if (c.silenceOn(topic) case final fact?) (topic, fact),
      ];

      if (c.allRows.isEmpty && silences.isEmpty) {
        return const SizedBox.shrink();
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PatientText.checkWhatWeFound,
            style: isDark
                ? AppTextStyles.darkTitle3()
                : AppTextStyles.lightTitle3(),
          ),
          const SizedBox(height: BentoSpace.header),
          _Group(c: c, title: PatientText.medicines, rows: c.medications),
          _Group(c: c, title: PatientText.testResults, rows: c.investigations),
          _Group(c: c, title: PatientText.diagnosesRecorded, rows: c.diagnoses),
          _Group(
            c: c,
            title: PatientText.proceduresRecorded,
            rows: c.procedures,
          ),
          _Group(c: c, title: PatientText.allergiesRecorded, rows: c.allergies),
          _Group(c: c, title: PatientText.followUpRecorded, rows: c.followUp),
          if (silences.isNotEmpty)
            BentoCard(
              padding: const EdgeInsets.symmetric(
                vertical: BentoSpace.listCardPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < silences.length; i++) ...[
                    if (i > 0) const Hairline(indent: BentoSpace.listPad),
                    _Silence(topic: silences[i].$1, fact: silences[i].$2),
                  ],
                ],
              ),
            ),
        ],
      );
    });
  }
}

/// What the document did **not** say about a topic.
///
/// The sentence is the server's, printed as it arrived. This widget has no
/// branch on [DocumentFact.presence] and no wording of its own, and that is
/// deliberate: the difference between "No known allergies — stated in this
/// document" and "This document does not mention allergies" was decided by the
/// party that looked at the page, and every way of re-deriving it here is a
/// way of turning silence into a denial.
class _Silence extends StatelessWidget {
  const _Silence({required this.topic, required this.fact});

  final DocumentTopic topic;
  final DocumentFact fact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      key: PatientDocumentsKeys.topic(topic.wireValue),
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.remove_circle_outline_rounded,
            size: 17,
            color: tertiaryLabelColor(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fact.label,
              style:
                  (isDark
                          ? AppTextStyles.darkSubheadline()
                          : AppTextStyles.lightSubheadline())
                      .copyWith(
                        color: secondaryLabelColor(context),
                        height: 1.4,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One topic's values, each with its source, its confidence and the three
/// things a patient can say about it.
class _Group extends StatelessWidget {
  const _Group({required this.c, required this.title, required this.rows});

  final DocumentReviewController c;
  final String title;
  final List<DocumentValueRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpace.section),
      child: BentoCard(
        padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: title, inset: true),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Hairline(indent: BentoSpace.listPad),
              _ValueRow(c: c, row: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.c, required this.row});

  final DocumentReviewController c;
  final DocumentValueRow row;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final check = c.checkOf(row.field);
      final value = c.valueOf(row);
      final isEditing = c.editingField.value == row.field;

      // Confirmed documents are read-only. `_Confirm` already withdraws the
      // document-level button on `verified`, but these per-value choices were
      // left behind, so a patient who had just been told "this is now part of
      // your medical history" was still being asked, three times over, whether
      // each medicine was right — with every row captioned "Not checked yet".
      //
      // Two things wrong with that, and neither is cosmetic: it invites a tap
      // that the server will refuse, and it contradicts the confirmation
      // directly above it. §18 puts verification at the end of the road; this
      // screen should look like the end of it.
      final isSettled = c.document.value.status == DocumentStatus.verified;

      return Padding(
        key: PatientDocumentsKeys.value(row.field),
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
              value,
              // Never one line and never ellipsised. A medicine's name cut in
              // the middle is a medicine somebody guesses at, and the guess is
              // the failure mode this whole screen exists to prevent.
              style: isDark
                  ? AppTextStyles.darkBody(weight: FontWeight.w600)
                  : AppTextStyles.lightBody(weight: FontWeight.w600),
            ),
            if ((row.detail ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                row.detail!,
                style:
                    (isDark
                            ? AppTextStyles.darkSubheadline()
                            : AppTextStyles.lightSubheadline())
                        .copyWith(
                          color: secondaryLabelColor(context),
                          height: 1.35,
                        ),
              ),
            ],
            const SizedBox(height: 8),

            // Where it came from, and how sure anybody is. A `Wrap` because at
            // 1.3× the two marks no longer fit one phone line, and a `Row`
            // there paints overflow stripes across a medication name.
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // A corrected value is the patient's, and the chip says so —
                // the document is no longer its source. This is the re-label
                // §16 asks for, and the reason a correction is worth making
                // even where it stays on the phone.
                SourceChip(
                  source: check == ValueCheck.corrected
                      ? AnswerSource.typed
                      : AnswerSource.record,
                ),
                // Only two of the three confidences can appear here.
                // `unheard` is a statement about *hearing* and a document was
                // never heard, so a value either carries a caveat or does not.
                ConfidenceMark(
                  confidence: row.needsCheck
                      ? AnswerConfidence.unsure
                      : AnswerConfidence.clear,
                ),
              ],
            ),
            // "Not checked yet" is a prompt, and there is nothing left to do
            // once the document is confirmed — the patient checked it as a
            // whole. A value they touched individually still says so, because
            // that is a fact about what they did rather than an instruction.
            if (!(isSettled && check == ValueCheck.unchecked)) ...[
              const SizedBox(height: 4),
              Text(
                switch (check) {
                  ValueCheck.confirmed => PatientText.youConfirmedThis,
                  ValueCheck.corrected => PatientText.youCorrectedThis,
                  ValueCheck.unsure => PatientText.youAreNotSure,
                  ValueCheck.unchecked => PatientText.notCheckedYet,
                },
                style:
                    (isDark
                            ? AppTextStyles.darkFootnote()
                            : AppTextStyles.lightFootnote())
                        .copyWith(color: tertiaryLabelColor(context)),
              ),
            ],

            if (!isSettled) ...[
              const SizedBox(height: 10),
              if (isEditing)
                _Editor(c: c)
              else
                AnswerChoiceRow<ValueCheck>(
                  columns: 3,
                  choices: const [
                    ValueCheck.confirmed,
                    ValueCheck.corrected,
                    ValueCheck.unsure,
                  ],
                  selected: check == ValueCheck.unchecked ? null : check,
                  labelOf: (choice) => switch (choice) {
                    ValueCheck.confirmed => PatientText.thatIsRight,
                    ValueCheck.corrected => PatientText.change,
                    ValueCheck.unsure => PatientText.iDontKnow,
                    ValueCheck.unchecked => '',
                  },
                  iconOf: (choice) => switch (choice) {
                    ValueCheck.confirmed => Icons.check_rounded,
                    ValueCheck.corrected => Icons.edit_outlined,
                    ValueCheck.unsure => Icons.help_outline_rounded,
                    ValueCheck.unchecked => null,
                  },
                  keyOf: (choice) => switch (choice) {
                    ValueCheck.confirmed => PatientDocumentsKeys.confirmValue(
                      row.field,
                    ),
                    ValueCheck.corrected => PatientDocumentsKeys.correctValue(
                      row.field,
                    ),
                    ValueCheck.unsure => PatientDocumentsKeys.unsureValue(
                      row.field,
                    ),
                    ValueCheck.unchecked => null,
                  },
                  onSelected: (choice) => switch (choice) {
                    ValueCheck.confirmed => c.confirmValue(row.field),
                    ValueCheck.corrected => c.startCorrecting(row),
                    ValueCheck.unsure => c.markUnsure(row.field),
                    ValueCheck.unchecked => null,
                  },
                ),
            ],
          ],
        ),
      );
    });
  }
}

/// Where a corrected value is typed.
class _Editor extends StatelessWidget {
  const _Editor({required this.c});

  final DocumentReviewController c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BentoInput(
          key: PatientDocumentsKeys.correctionField,
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
              child: PrimaryBar(
                key: PatientDocumentsKeys.correctionSave,
                label: PatientText.saveCorrection,
                onPressed: c.saveCorrection,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The document-level confirmation, or the reason it is not being offered.
class _Confirm extends StatelessWidget {
  const _Confirm({required this.c});

  final DocumentReviewController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final document = c.document.value;
      final error = c.confirmError.value;

      if (document.status == DocumentStatus.verified) {
        // Nothing left to press. The sentence at the top of the screen is the
        // server's own "Thank you. You have confirmed this information."
        return const SizedBox.shrink();
      }

      if (!document.canVerify) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            NoticeBanner(
              icon: Icons.info_outline_rounded,
              tint: AppColors.warning,
              message: error,
            ),
            const SizedBox(height: BentoSpace.action),
          ],
          if (c.isBlocked) ...[
            // The honest ending for a document the patient disagrees with.
            // `verify` means "what was extracted is correct", so it is not
            // sent — and the screen says what happens instead rather than
            // leaving a dead button on it.
            NoticeBanner(
              key: PatientDocumentsKeys.confirmBlocked,
              icon: Icons.flag_outlined,
              message: PatientText.documentGoesToAClinician,
            ),
            // Demo builds only, and the notice above stays. A run in front of
            // a room dies on one "I don't know" otherwise — the extraction on
            // a photographed prescription is rarely clean — and what is shown
            // here is the real warning with a way past it, never a screen
            // pretending the values were agreed with.
            // See `DemoAccounts.confirmAnyway`.
            if (DemoAccounts.confirmAnyway) ...[
              const SizedBox(height: BentoSpace.action),
              PrimaryBar(
                key: PatientDocumentsKeys.confirm,
                label: PatientText.confirmThisDocument,
                icon: Icons.check_rounded,
                busy: c.isConfirming.value,
                enabled: c.canConfirm,
                onPressed: () async {
                  if (await c.confirmDocument()) {
                    showBentoToast(PatientText.documentConfirmedGoBack);
                  }
                },
              ),
            ],
          ] else
            PrimaryBar(
              key: PatientDocumentsKeys.confirm,
              label: PatientText.confirmThisDocument,
              icon: Icons.check_rounded,
              busy: c.isConfirming.value,
              // Absent would move the page under somebody's thumb every time
              // they answered a row. Disabled is the honest control here: the
              // screen says on every row what is still unchecked, so the
              // reason is already written down.
              enabled: c.canConfirm,
              onPressed: () async {
                if (await c.confirmDocument()) {
                  showBentoToast(PatientText.documentConfirmedGoBack);
                }
              },
            ),
        ],
      );
    });
  }
}
