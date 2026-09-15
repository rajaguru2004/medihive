import 'package:flutter/material.dart';

import '../core/i18n/patient_text.dart';
import 'app_bento.dart';
import 'app_colors.dart';
import 'app_surfaces.dart';
import 'app_text_styles.dart';
import 'app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the conversation layer of the kit
///
/// Every other surface in this app is read by somebody who works here.
/// This one is read by a patient: sitting in a waiting room, frightened or
/// bored or in pain, on a device they have never held before, answering
/// questions about their own body before anybody has seen them.
///
/// **It is the same visual world at a different density.** Not a second design
/// system — a screen that looked like a different app would read as a third
/// party asking for medical details, which is exactly the thing a patient
/// should be suspicious of. The tokens are the same tokens. What changes:
///
///  * **One question at a time**, and it is the largest thing on screen.
///  * **Type steps up.** The live question is `title2`; a past one is
///    `headline`; an answer is `body`. Nothing a patient reads is below 17.
///  * **Targets step up.** A choice is 64 high and the microphone is 88, well
///    past the 48 the staff screens hold to. A first-time anxious patient is
///    not a nurse who has used the app four hundred times this month.
///  * **Nothing here is coloured to mean good or bad.** See
///    [UnknownAnswerRow] and [ConfidenceMark] — a "Yes" is not good news and a
///    "No" is not bad news, and which is which changes with every question.
///
/// Dark is not a preference on this surface either. A waiting room at eleven
/// at night is dim and the person holding the tablet has been there two hours.
///
/// ## Where red is
///
/// Exactly one component uses `AppColors.acuityCritical`: [RedFlagNotice].
/// `.agents/RULES.md` §0 says red means one thing, and a red flag *is* that
/// thing — a patient who should not be sitting in the waiting room. Every
/// other state on this surface, including the app admitting it cannot hear,
/// is carried by a word, a glyph and a neutral tint.
/// ─────────────────────────────────────────────────────────────────────────────

// ── The patient register ────────────────────────────────────────────────────
//
// Stated once, here, so twelve components cannot each decide for themselves
// how big a question is.

/// The question being asked right now.
TextStyle _liveQuestionStyle(BuildContext context) =>
    (Theme.of(context).brightness == Brightness.dark
            ? AppTextStyles.darkTitle2()
            : AppTextStyles.lightTitle2())
        .copyWith(height: 1.3);

/// A question already answered, further up the transcript. A step down, not
/// two: it is still a sentence somebody may want to re-read before they
/// correct their answer.
TextStyle _pastQuestionStyle(BuildContext context) =>
    (Theme.of(context).brightness == Brightness.dark
            ? AppTextStyles.darkHeadline()
            : AppTextStyles.lightHeadline())
        .copyWith(height: 1.35);

/// What the patient said, or chose.
TextStyle _answerStyle(BuildContext context) =>
    (Theme.of(context).brightness == Brightness.dark
            ? AppTextStyles.darkBody()
            : AppTextStyles.lightBody())
        .copyWith(height: 1.35);

/// The quieter line under a question: why it is being asked, or what counts as
/// an answer.
TextStyle _detailStyle(BuildContext context) =>
    (Theme.of(context).brightness == Brightness.dark
            ? AppTextStyles.darkCallout()
            : AppTextStyles.lightCallout())
        .copyWith(height: 1.4);

/// The word on a choice. Body size, semibold — a choice a patient taps is not
/// a caption.
TextStyle _choiceStyle(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppTextStyles.darkHeadline()
        : AppTextStyles.lightHeadline();

/// The quieter half of a two-line choice.
///
/// **The same size as the line above it**, stepped down by weight and by a
/// label token rather than by size. That is not symmetry for its own sake: the
/// case this exists for is the language picker, where the top line is a native
/// name in a script the reader may not know and the second line is the only
/// thing left for them to go on. Shrinking the fallback to a caption would make
/// the least legible thing on the row the one somebody is reading it for — and
/// the patient register this file sets out puts a floor of 17 under anything a
/// patient reads anyway.
TextStyle _choiceDetailStyle(BuildContext context) =>
    (Theme.of(context).brightness == Brightness.dark
            ? AppTextStyles.darkBody()
            : AppTextStyles.lightBody())
        .copyWith(color: secondaryLabelColor(context));

/// A choice, and the microphone.
///
/// Both deliberately well past [AppTheme.minTapTarget]. 48 is the floor for a
/// nurse who has used this app four hundred times this month and knows where
/// everything is; this surface is held by somebody who has never seen it, may
/// be frightened, and may be doing it one-handed.
const double _choiceHeight = AppTheme.minTapTarget + 16;
const double _micDiameter = AppTheme.minTapTarget + 40;

/// How much of the available width a bubble may take.
///
/// A bubble that runs edge to edge is a paragraph, and a paragraph does not
/// read as somebody speaking. The gap on the other side is what makes the
/// alternation between two speakers legible without either one being labelled.
const double _bubbleWidth = 0.88;

// ── What an answer is ───────────────────────────────────────────────────────

/// The four things a patient can say to a yes/no question.
///
/// **Four, not two.** This is the enum [UnknownAnswerRow] exists to make
/// visible, and the reason it is an enum rather than a `bool?` is that three
/// of these are facts and the fourth is the absence of one:
///
///  * [yes] — the patient reports it.
///  * [no] — the patient denies it. A *positive* finding, not a blank: "denies
///    chest pain" is something a clinician writes down and acts on.
///  * [unknown] — the patient does not know. Not the same as [no], and the
///    difference is the whole point. "Has anyone in your family had a heart
///    attack?" answered *no* by somebody adopted is a family history this app
///    invented.
///  * [skipped] — nobody answered. They moved past it, or would rather not
///    say. Not a finding at all, and the one of the four that must never be
///    filed as one.
enum PatientAnswer {
  yes,
  no,
  unknown,
  skipped;

  /// Reads a stored answer back, unknown-safe.
  ///
  /// The safety property, and it is the same shape as `BedState.resolve`
  /// refusing to read an unrecognised bed as vacant: **a token this build has
  /// never seen resolves to [unknown], never to [yes] or [no].** Something was
  /// recorded that this app cannot read; turning that into a denial writes a
  /// clinical finding nobody stated, and a note reading "denies chest pain"
  /// that the patient never said is worse than no note at all.
  ///
  /// Nothing at all — null, empty, whitespace — is [skipped], because nothing
  /// recorded means nothing was answered.
  static PatientAnswer resolve(String? raw) {
    final token = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[’']"), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (token.isEmpty) return skipped;

    return switch (token) {
      'yes' || 'y' || 'true' || '1' || 'present' || 'positive' => yes,
      'no' || 'n' || 'false' || '0' || 'absent' || 'negative' || 'denies' => no,
      'unknown' ||
      'unsure' ||
      'not sure' ||
      'dont know' ||
      'do not know' ||
      'dk' =>
        unknown,
      'skip' || 'skipped' || 'declined' || 'refused' || 'not asked' => skipped,
      _ => unknown,
    };
  }

  /// What the backend stores. Matched by [resolve], so the pair round-trips.
  String get storageValue => name;

  /// Three of the four are something to write on the case. A [skipped]
  /// question is a gap, and a gap filed as a finding is the failure this whole
  /// enum exists to prevent.
  bool get isRecorded => this != PatientAnswer.skipped;

  /// Only [yes] and [no] settle the question that was asked. A screen counting
  /// "how much of this is done" counts these; a screen listing "what a
  /// clinician still needs to ask" lists the other two.
  bool get isDefinite => this == PatientAnswer.yes || this == PatientAnswer.no;

  /// The word on the button.
  String get label => switch (this) {
        PatientAnswer.yes => PatientText.yes,
        PatientAnswer.no => PatientText.no,
        PatientAnswer.unknown => PatientText.iDontKnow,
        PatientAnswer.skipped => PatientText.skip,
      };

  /// The word in the transcript above, where the row of buttons is no longer
  /// on screen to give it context. "Skip" is an instruction; "Skipped" is what
  /// happened.
  String get transcriptLabel => switch (this) {
        PatientAnswer.yes => PatientText.yes,
        PatientAnswer.no => PatientText.no,
        PatientAnswer.unknown => PatientText.notSure,
        PatientAnswer.skipped => PatientText.skipped,
      };

  /// The mark beside the word.
  ///
  /// Not decoration: it is the second channel, so the four stay four for a
  /// reader who is colour-blind, reading a screenshot, or looking at the
  /// screen from an angle across a waiting room.
  IconData get icon => switch (this) {
        PatientAnswer.yes => Icons.check_rounded,
        PatientAnswer.no => Icons.close_rounded,
        PatientAnswer.unknown => Icons.help_outline_rounded,
        PatientAnswer.skipped => Icons.skip_next_rounded,
      };
}

/// How sure the app is that it heard what the patient said.
///
/// **Deliberately outside the acuity ramp.** This describes the app's hearing,
/// not the patient's condition, and `.agents/RULES.md` §0 is explicit that a
/// category routed through the clinical ramp is painted with a meaning it does
/// not have. A transcript the app is unsure of is not a deteriorating patient,
/// so there is no red here and never will be.
enum AnswerConfidence {
  /// Heard, and worth showing back without a caveat.
  clear,

  /// Heard, but the patient should read it before it is filed.
  unsure,

  /// Not heard well enough to show as an answer at all.
  unheard;

  /// Resolves a transcriber's 0…1 score.
  ///
  /// **An absent score is [unsure], never [clear].** A transcript this app
  /// cannot vouch for, marked "Clear", asks the patient to confirm something
  /// on the app's authority rather than on their own memory of what they just
  /// said — which is precisely the wrong way round.
  static AnswerConfidence fromScore(double? score) {
    if (score == null || score.isNaN) return unsure;
    if (score < 0.5) return unheard;
    if (score < 0.8) return unsure;
    return clear;
  }

  String get label => switch (this) {
        AnswerConfidence.clear => PatientText.heardClearly,
        AnswerConfidence.unsure => PatientText.pleaseCheckThis,
        AnswerConfidence.unheard => PatientText.didNotCatchThat,
      };

  IconData get icon => switch (this) {
        AnswerConfidence.clear => Icons.check_rounded,
        AnswerConfidence.unsure => Icons.hearing_rounded,
        AnswerConfidence.unheard => Icons.hearing_disabled_rounded,
      };
}

/// How an answer got onto the case.
///
/// A clinician reading this back later needs to know whether "no chest pain"
/// is what the patient said, what they tapped, or what the register already
/// held. Those are three different strengths of evidence and only the first
/// two happened today.
enum AnswerSource {
  spoken,
  typed,
  chosen,

  /// Carried over from the patient's existing record rather than asked again.
  record;

  String get label => switch (this) {
        AnswerSource.spoken => PatientText.spoken,
        AnswerSource.typed => PatientText.typed,
        AnswerSource.chosen => PatientText.chosen,
        AnswerSource.record => PatientText.fromYourRecord,
      };

  IconData get icon => switch (this) {
        AnswerSource.spoken => Icons.graphic_eq_rounded,
        AnswerSource.typed => Icons.keyboard_rounded,
        AnswerSource.chosen => Icons.check_circle_outline_rounded,
        AnswerSource.record => Icons.description_outlined,
      };
}

// ── The transcript ──────────────────────────────────────────────────────────

/// Who is talking.
enum ConversationSpeaker { assistant, patient }

/// One utterance, placed: aligned to its speaker's side, held to a bubble's
/// width, with room under it for the marks that qualify it.
///
/// The transcript is a column of these. Nothing about a turn animates on
/// arrival — `DESIGN.md` §7 has the reasoning, and it is stronger here than on
/// a ward board: a patient re-reading the question they are halfway through
/// answering should not have the page move under them.
class ConversationTurn extends StatelessWidget {
  const ConversationTurn({
    super.key,
    required this.speaker,
    this.footnote,
    required this.child,
  });

  final ConversationSpeaker speaker;

  /// The chips under the bubble — a [SourceChip], a [ConfidenceMark], a way to
  /// change the answer. Aligned to the same side as the bubble.
  final Widget? footnote;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isPatient = speaker == ConversationSpeaker.patient;
    final side =
        isPatient ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpace.header),
      child: LayoutBuilder(
        // Measured against what is actually available rather than against the
        // window: these sit inside a page-padded section, and a fraction of
        // the screen width overflows it by the padding every time.
        builder: (context, constraints) => Column(
          crossAxisAlignment: side,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: constraints.maxWidth * _bubbleWidth),
              child: child,
            ),
            if (footnote != null) ...[
              const SizedBox(height: 7),
              footnote!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A question, asked.
///
/// [live] is the question on the table right now: it steps up to `title2` and
/// announces itself to a screen reader, because a patient using VoiceOver has
/// no other way to know the conversation moved on.
class AssistantBubble extends StatelessWidget {
  const AssistantBubble({
    super.key,
    required this.text,
    this.detail,
    this.live = false,
  });

  final String text;

  /// Why this is being asked, or what counts as an answer. One short line —
  /// anything longer is a second question wearing a hat.
  final String? detail;

  final bool live;

  @override
  Widget build(BuildContext context) {
    return ConversationTurn(
      speaker: ConversationSpeaker.assistant,
      child: Semantics(
        liveRegion: live,
        child: DecoratedBox(
          // The kit's own card material, with one corner pulled in toward the
          // speaker. `copyWith` rather than a hand-rolled decoration so the
          // glass, the hairline and the shadow stay defined in one place and a
          // bubble is a card that happens to point somewhere.
          decoration: bentoCardDecoration(context).copyWith(
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(BentoRadius.card),
              topEnd: Radius.circular(BentoRadius.card),
              bottomEnd: Radius.circular(BentoRadius.card),
              bottomStart: Radius.circular(BentoRadius.small),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BentoSpace.cardPad,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  // No `maxLines`. A question cut off in the middle is a
                  // question answered from a guess at its second half.
                  style: live
                      ? _liveQuestionStyle(context)
                      : _pastQuestionStyle(context),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 8),
                  Text(detail!, style: _detailStyle(context)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the patient said back.
///
/// Tinted with the brand rather than with anything semantic. The bubble's job
/// is to say *who spoke*, and an answer coloured by its content would be this
/// surface judging a reply it is not qualified to judge.
class PatientBubble extends StatelessWidget {
  const PatientBubble({
    super.key,
    required this.text,
    this.source,
    this.confidence,
    this.onChange,
  });

  final String text;
  final AnswerSource? source;
  final AnswerConfidence? confidence;

  /// Changing an answer already given. Present on every answer that matters:
  /// a patient who realises at question nine that they misheard question three
  /// and cannot go back will abandon the form, and an abandoned form is worse
  /// than a wrong one because nobody knows it is wrong.
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final marks = <Widget>[
      if (source != null) SourceChip(source: source!),
      if (confidence != null) ConfidenceMark(confidence: confidence!),
      if (onChange != null)
        TextButton(
          onPressed: onChange,
          child: Text(PatientText.change),
        ),
    ];

    return ConversationTurn(
      speaker: ConversationSpeaker.patient,
      footnote: marks.isEmpty
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: marks,
            ),
      child: DecoratedBox(
        decoration: bentoCardDecoration(
          context,
          fill: brandTonalColor(context),
        ).copyWith(
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(BentoRadius.card),
            topEnd: Radius.circular(BentoRadius.card),
            bottomStart: Radius.circular(BentoRadius.card),
            bottomEnd: Radius.circular(BentoRadius.small),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BentoSpace.cardPad,
            vertical: 14,
          ),
          child: Text(text, style: _answerStyle(context)),
        ),
      ),
    );
  }
}

// ── Answering ───────────────────────────────────────────────────────────────

/// The choices for one question, as a grid of equal tiles.
///
/// Equal is the design. A row where one option is a button and the others are
/// a link underneath is a row that has already decided what the patient ought
/// to say — see [UnknownAnswerRow], which is the case where that matters
/// clinically.
///
/// Laid out as rows of [columns] rather than as a `Wrap`, so tiles in one row
/// share a height when one of their labels runs to two lines. The
/// `IntrinsicHeight` is not incidental: `.agents/RULES.md` §2.5 records that
/// `CrossAxisAlignment.stretch` on a `Row` inside a sliver is laid out at
/// infinite height and asserts.
class AnswerChoiceRow<T> extends StatelessWidget {
  const AnswerChoiceRow({
    super.key,
    required this.choices,
    required this.labelOf,
    required this.onSelected,
    this.selected,
    this.detailOf,
    this.iconOf,
    this.keyOf,
    this.columns = 2,
  }) : assert(columns >= 1, 'A choice grid needs at least one column.');

  final List<T> choices;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  /// Null until the patient has answered. Not a default: a pre-selected answer
  /// on a clinical question is an answer the app supplied.
  final T? selected;

  /// A second line under [labelOf], for a choice whose own name is not enough
  /// on its own.
  ///
  /// Null on every clinical question, and that is the rule rather than a
  /// coincidence: "Yes — you are reporting this symptom" is the screen
  /// explaining an answer to the person giving it, which is one step from
  /// leading them. What it is for is a choice whose label is in a *script*
  /// rather than in a language — a language picker, where the row says தமிழ்
  /// and the line under it says Tamil.
  final String? Function(T)? detailOf;

  final IconData? Function(T)? iconOf;
  final Key? Function(T)? keyOf;
  final int columns;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var start = 0; start < choices.length; start += columns) {
      final slice = choices.sublist(
        start,
        (start + columns).clamp(0, choices.length),
      );

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(
                  child: i < slice.length
                      ? _ChoiceTile(
                          key: keyOf?.call(slice[i]),
                          label: labelOf(slice[i]),
                          detail: detailOf?.call(slice[i]),
                          icon: iconOf?.call(slice[i]),
                          selected: slice[i] == selected,
                          onTap: () => onSelected(slice[i]),
                        )
                      // Holds the column open so a last row of one is the same
                      // width as the rows above it rather than stretching to
                      // twice the size and reading as the recommended answer.
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          rows[i],
        ],
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
    this.icon,
  });

  final String label;

  /// The quieter second line. See `AnswerChoiceRow.detailOf`.
  final String? detail;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final brand = brandInkColor(context);
    final mark = selected ? brand : tertiaryLabelColor(context);

    // One node: the `InkWell`'s button, the label inside it, and the selected
    // state, merged so a screen reader says "Yes, selected, button" instead of
    // announcing an unnamed button and then a stray word.
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: AnimatedContainer(
          duration: motionDuration(context, const Duration(milliseconds: 160)),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: _choiceHeight),
          decoration: BoxDecoration(
            color: selected ? brandTonalColor(context) : wellColor(context),
            borderRadius: BorderRadius.circular(BentoRadius.control),
            // Tint, border weight *and* the check below. A selected state
            // carried by colour alone is one that eight percent of men, every
            // screenshot and every glance from an angle all miss.
            border: Border.all(
              color: selected ? brand : hairlineColor(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(BentoRadius.control),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 22, color: mark),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: _choiceStyle(context),
                          ),
                          // Never ellipsised and never capped at a line. A
                          // language's own name is not site data that can run
                          // long; it is the one string on the row somebody may
                          // be matching by shape, and `தமிழ…` is not a
                          // language anybody recognises.
                          if (detail != null && detail!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              detail!,
                              textAlign: TextAlign.center,
                              style: _choiceDetailStyle(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_rounded, size: 20, color: brand),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UnknownAnswerRow extends StatelessWidget {
  const UnknownAnswerRow({
    super.key,
    required this.selected,
    required this.onAnswered,
    this.keyOf,
  });

  /// Null until answered. There is no default: a pre-selected "No" is a denial
  /// nobody made.
  final PatientAnswer? selected;

  final ValueChanged<PatientAnswer> onAnswered;
  final Key? Function(PatientAnswer)? keyOf;

  @override
  Widget build(BuildContext context) => AnswerChoiceRow<PatientAnswer>(
        choices: PatientAnswer.values,
        labelOf: (answer) => answer.label,
        iconOf: (answer) => answer.icon,
        keyOf: keyOf,
        selected: selected,
        onSelected: onAnswered,
      );
}

// ── Speaking ────────────────────────────────────────────────────────────────

/// What the microphone is doing.
enum MicState {
  /// Waiting to be pressed.
  idle,

  /// Recording.
  listening,

  /// Recording finished; the words are being worked out.
  working,
}

/// The control a patient speaks into. 88 across, which is deliberate.
///
/// **It does not turn red while it records.** Every other app on the device
/// does, and on this one red means a deteriorating patient and nothing else
/// (`.agents/RULES.md` §0). A recording indicator borrowing it would put a red
/// dot on the screen of every patient who chose to talk instead of type, and
/// after a week of that nobody on the ward reads red as urgent any more. The
/// live state is carried by the halo, the glyph and the word underneath.
class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.state,
    required this.onPressed,
  });

  final MicState state;

  /// Null disables the control — while a recording is being transcribed, for
  /// instance. A tap that does nothing is worse than a control that is plainly
  /// not accepting one.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fill = brandFillColor(context);
    final onFill = onBrandFillColor(context);
    final working = state == MicState.working;

    final label = switch (state) {
      MicState.idle => PatientText.speakYourAnswer,
      MicState.listening => PatientText.tapWhenFinished,
      MicState.working => PatientText.writingThatDown,
    };

    // Merged rather than labelled: the `InkWell` already announces a button and
    // the word underneath is already the label, so an outer `Semantics` with a
    // label of its own reads the whole thing out twice.
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: motionDuration(context),
            curve: Curves.easeOutCubic,
            width: _micDiameter,
            height: _micDiameter,
            decoration: BoxDecoration(
              color: working ? wellColor(context) : fill,
              shape: BoxShape.circle,
              // A halo, not a blur: a spread shadow with no blur radius is one
              // extra draw, where a `BackdropFilter` is a read-back of
              // everything under it on every frame. There are none of those in
              // this app and this is not going to be the first.
              boxShadow: state == MicState.listening
                  ? [
                      BoxShadow(
                        color: fill.withValues(alpha: 0.26),
                        spreadRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: working
                    // A spinner is the one animation in this file that would
                    // run forever, and under Reduce Motion it would keep
                    // scheduling frames after the setting asked it not to —
                    // which is what hangs a harness waiting for the tree to go
                    // quiet. Off, the state is still carried: a still glyph
                    // here and the word underneath.
                    ? Center(
                        child: MediaQuery.disableAnimationsOf(context)
                            ? Icon(
                                Icons.more_horiz_rounded,
                                size: 30,
                                color: brandInkColor(context),
                              )
                            : SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: brandInkColor(context),
                                ),
                              ),
                      )
                    : Icon(
                        state == MicState.listening
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        size: 36,
                        color: onFill,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: _detailStyle(context),
          ),
        ],
      ),
    );
  }
}

/// Bars that move with the patient's voice.
///
/// **It is driven by [level] and nothing else.** There is no repeating
/// animation here, for two reasons that both matter:
///
///  * A meter that animates on its own is a meter that lies. Somebody speaking
///    quietly into a microphone the app cannot hear would watch it dance and
///    conclude they had been heard; they find out otherwise at the transcript,
///    having said the whole thing once already.
///  * An animation that repeats forever ignores Reduce Motion, which the e2e
///    harness turns on, and hangs the suite with no message. `DESIGN.md` §7 is
///    explicit; a `TweenAnimationBuilder` on a value that changes is the
///    honest shape anyway.
class ListeningIndicator extends StatelessWidget {
  const ListeningIndicator({
    super.key,
    required this.level,
    this.bars = 5,
  }) : assert(bars >= 3, 'A meter reads as a meter from three bars up.');

  /// 0…1, from `SpeechAudio.levelOfPcm16`.
  final double level;

  final int bars;

  static const double _height = 36;
  static const double _floor = 6;

  @override
  Widget build(BuildContext context) {
    final tint = brandInkColor(context);
    final centre = (bars - 1) / 2;
    final loudness = level.clamp(0.0, 1.0);

    return SizedBox(
      height: _height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            TweenAnimationBuilder<double>(
              // Short: the meter is following a voice, and a long ease turns
              // speech into a slow swell that no longer matches the speaking.
              duration: motionDuration(context, const Duration(milliseconds: 110)),
              curve: Curves.easeOut,
              tween: Tween<double>(
                end: _floor +
                    (_height - _floor) *
                        loudness *
                        // The ends move less than the middle, which is what
                        // makes a row of bars read as one meter rather than as
                        // five separate ones.
                        (1 - (i - centre).abs() / centre * 0.55),
              ),
              builder: (context, height, _) => Container(
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(BentoRadius.rule),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the app thinks it heard, shown back before it is filed.
///
/// The confirmation step is not politeness. A transcriber that mishears
/// "no allergies" as "no, allergies" has written the opposite of what was
/// said, and the only person in the building who can catch that is the one who
/// just spoke. So the words go on screen at reading size, with the app's own
/// confidence beside them, and nothing is recorded until the patient says it
/// is right.
class TranscriptDraft extends StatelessWidget {
  const TranscriptDraft({
    super.key,
    required this.text,
    required this.onAccept,
    required this.onRetry,
    this.confidence = AnswerConfidence.unsure,
    this.onType,
  });

  final String text;
  final VoidCallback onAccept;
  final VoidCallback onRetry;
  final AnswerConfidence confidence;

  /// The way out for somebody the microphone is never going to hear — a quiet
  /// voice, a strong accent, a noisy waiting room. Offered here rather than
  /// after the third failed attempt.
  final VoidCallback? onType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Both sides flexible, neither pinned. A `Spacer` between two
              // inflexible children lays each of them out unbounded, so the
              // row overflows as soon as one of these strings grows — which
              // it does at the largest system text size, and again the day
              // `PatientText` starts answering in a language whose word for
              // "check this" is longer than ours.
              Flexible(
                child: Text(
                  PatientText.youSaid.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.overline(
                    isDark ? Brightness.dark : Brightness.light,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(child: ConfidenceMark(confidence: confidence)),
            ],
          ),
          const SizedBox(height: 10),
          // Never truncated. Half a sentence a patient is being asked to
          // confirm is half a sentence they will confirm without reading.
          Text(text, style: _answerStyle(context)),
          const SizedBox(height: BentoSpace.action),
          PrimaryBar(label: PatientText.thatIsRight, onPressed: onAccept),
          const SizedBox(height: 8),
          SecondaryBar(label: PatientText.sayItAgain, onPressed: onRetry),
          if (onType != null) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: onType,
                child: Text(PatientText.typeItInstead),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Marks ───────────────────────────────────────────────────────────────────

/// How sure the app is that it heard right, as a word and a glyph.
///
/// Never a colour on its own, and never red — see [AnswerConfidence].
class ConfidenceMark extends StatelessWidget {
  const ConfidenceMark({super.key, required this.confidence});

  final AnswerConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Amber where the app is admitting something, neutral where it is not.
    // `warning` is semantic feedback about the app, which is what this is; the
    // acuity ramp describes patients and this does not.
    final ink = confidence == AnswerConfidence.clear
        ? tertiaryLabelColor(context)
        : semanticInk(context, AppColors.warning);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(confidence.icon, size: 14, color: ink),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            confidence.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // The weight is asked of the factory rather than applied with a
            // `copyWith`, which moves the weight and not the face's `wght`
            // axis; the colour is a `copyWith`, which is only a colour.
            style: (isDark
                    ? AppTextStyles.darkFootnote(weight: FontWeight.w600)
                    : AppTextStyles.lightFootnote(weight: FontWeight.w600))
                .copyWith(color: ink),
          ),
        ),
      ],
    );
  }
}

/// Where an answer came from: spoken, typed, chosen, or already on file.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source});

  final AnswerSource source;

  @override
  Widget build(BuildContext context) {
    final ink = tertiaryLabelColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: wellColor(context),
        borderRadius: BorderRadius.circular(BentoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 13, color: ink),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              source.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).brightness == Brightness.dark
                  ? AppTextStyles.darkFootnote()
                  : AppTextStyles.lightFootnote(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress ────────────────────────────────────────────────────────────────

/// How far through the questions, in words and as a rule.
///
/// Not `RatioBar`, which measures a quantity — beds used out of beds held. A
/// rail measures a *position in a sequence*, and the number of questions left
/// is the thing a patient most wants to know and the thing a bar alone cannot
/// tell them. So the words are not a caption on the bar; they are the
/// component, and the rule underneath is the glance version.
class ProgressRail extends StatelessWidget {
  const ProgressRail({super.key, required this.step, required this.total});

  /// One-based. Clamped, because an off-by-one that renders "Question 12 of
  /// 11" is a patient who believes the form is broken.
  final int step;

  final int total;

  static const double _thickness = 6;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    final at = step.clamp(1, total);
    final fraction = at / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          PatientText.questionProgress(at, total),
          // Tabular, because this is a figure that ticks. A proportional `9`
          // narrower than a `0` makes the whole line shuffle sideways at every
          // question, which reads as the screen having changed more than it
          // has.
          style: numeralStyle(
            context,
            size: 15,
            weight: FontWeight.w600,
            color: secondaryLabelColor(context),
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _thickness,
          child: TweenAnimationBuilder<double>(
            duration: motionDuration(context, const Duration(milliseconds: 260)),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(end: fraction),
            builder: (context, value, _) => Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: wellColor(context),
                    borderRadius: BorderRadius.circular(BentoRadius.rule),
                  ),
                ),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: brandFillColor(context),
                      borderRadius: BorderRadius.circular(BentoRadius.rule),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Safety ──────────────────────────────────────────────────────────────────

/// The one red thing on this surface: stop answering questions and find
/// somebody.
///
/// **It never says what might be wrong.** The only free text it can render is
/// [reported] — the patient's own words, quoted back — and the three lines
/// around it are fixed copy in `PatientText`, none of which names a condition.
/// That is a structural guarantee rather than a rule somebody has to remember,
/// and it is structural because the failure has two shapes and both are bad:
/// a screen that guesses "this may be a heart attack" has made a diagnosis
/// nobody qualified made, and a screen that guesses wrong teaches the next
/// patient that the red notice means nothing.
///
/// The red is `AppColors.acuityCritical`, which `.agents/RULES.md` §0 reserves
/// for a deteriorating patient. This is that: somebody in a waiting room who
/// should not be in a waiting room. It is the only place on this surface that
/// earns it.
///
/// The action stays **teal**, because teal is the brand and never an acuity —
/// the card says how serious this is and the button says what to do about it,
/// and those are two different jobs for two different colours.
class RedFlagNotice extends StatelessWidget {
  const RedFlagNotice({
    super.key,
    required this.reported,
    this.onTellSomeone,
  });

  /// What the patient said, in their words. Quoted, not summarised: a
  /// paraphrase is the app editing a clinical statement.
  final String reported;

  /// Null where there is nothing for the app to do about it — a kiosk with
  /// nobody to alert still has to show the notice.
  final VoidCallback? onTellSomeone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = semanticInk(context, AppColors.acuityCritical);

    return BentoCard(
      // A tinted card, the way `NoticeBanner` is tinted: this has to read as a
      // different kind of object before it is read as a sentence.
      fill: Color.alphaBlend(
        AppColors.acuityCritical.withValues(alpha: isDark ? 0.18 : 0.14),
        surfaceColor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                // The kit's own icon-box size, as `BentoRow` draws one. This
                // is a mark, not a control: nothing about it is tappable and
                // sizing it like a target would say otherwise.
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  // A fill, not a word, so the raw ramp colour is right here —
                  // `DESIGN.md` §2.5: fills are seen, words are read.
                  color: AppColors.acuityCritical,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  PatientText.tellANurseNow,
                  style: (isDark
                          ? AppTextStyles.darkTitle3()
                          : AppTextStyles.lightTitle3())
                      .copyWith(color: ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(PatientText.doNotWaitForTheRest, style: _answerStyle(context)),
          // Only when there is something to quote.
          //
          // The quote is the patient's own words, and on a resumed session
          // there may be none — the flag is raised from facts already on the
          // record while `_lastPatientWords()` has nothing to return. Drawn
          // unconditionally that rendered an empty white box labelled "YOU
          // SAID" on the one screen in the app that must not look broken. A
          // patient being told to find a nurse now reads that box for what
          // they are supposed to have said, and finding it blank invites them
          // to distrust the rest of the panel.
          //
          // The notice above it stands on its own: it names no condition and
          // needs no quote to say what to do.
          if (reported.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            InsetSurface(
              radius: BentoRadius.control,
              padding: const EdgeInsets.all(BentoSpace.listPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    PatientText.youSaid.toUpperCase(),
                    style: AppTextStyles.overline(
                      isDark ? Brightness.dark : Brightness.light,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // No `maxLines`, against the usual rule for site-supplied
                  // text. `CLAUDE.md` is explicit that a clinical figure is
                  // never ellipsised, and the same holds harder for the
                  // sentence that triggered the one red notice in the app:
                  // "chest pain spreading to my…" is worse than useless to the
                  // person being shown this screen.
                  Text(reported, style: _answerStyle(context)),
                ],
              ),
            ),
          ],
          if (onTellSomeone != null) ...[
            const SizedBox(height: BentoSpace.action),
            PrimaryBar(
              label: PatientText.tellANurse,
              onPressed: onTellSomeone,
            ),
          ],
        ],
      ),
    );
  }
}
