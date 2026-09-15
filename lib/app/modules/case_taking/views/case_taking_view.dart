import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/i18n/patient_text.dart';
import '../../../core/keys/app_keys.dart';
import '../../../data/models/case_session.dart';
import '../../../theme/theme.dart';
import '../controllers/case_taking_controller.dart';
import '../interview_turn.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — one question at a time
///
/// The screen is four bands, and the order is the argument:
///
/// ```
/// ┌─ where we are ────────────  ProgressRail, from the server's own count
/// ├─ if something needs seeing   RedFlagNotice — pinned, never scrolled away
/// ├─ what has been said ───────  the conversation, scrolling
/// ├─ the question ─────────────  pinned above its answers, at title2
/// └─ the three ways to answer    tap · type · speak
/// ```
///
/// **The question is pinned rather than being the last row of the list.** A
/// question that scrolls off while somebody is reaching for the keyboard is a
/// question answered from a memory of its second half, and §43's first
/// principle is one question at a time. So the conversation gives way and the
/// question stays.
///
/// **The red-flag notice is pinned too**, above everything but the rail. A
/// notice that says "do not wait" and can be scrolled out of sight is a notice
/// that will be, and it is the one thing on this surface allowed to be red.
///
/// Every answer control is on screen at once, none of them behind a menu. §10
/// is explicit that voice, text and touch are all available; the way to break
/// that is to make two of them a second choice, and a mode switch makes two of
/// them a second choice.
/// ─────────────────────────────────────────────────────────────────────────────
class CaseTakingView extends GetView<CaseTakingController> {
  const CaseTakingView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read once here, so a `GetView` whose build never touched `controller`
    // cannot leave a `lazyPut` controller unbuilt — the trap that hung the
    // splash screen.
    final c = controller;

    return Scaffold(
      key: CaseTakingKeys.screen,
      appBar: DetailHeader(title: PatientText.interviewTitle),
      body: BentoGround(
        child: SafeArea(
          child: MaxWidthBody(
            maxWidth: 560,
            // Budgeted from the space this column actually has, not from the
            // screen: the app bar and both safe areas have already been taken
            // out by the time the constraints reach here, and a percentage of
            // the full screen height overflows by exactly that much. It did —
            // by 65 points, on the one screen that has all three pinned bands
            // up at once, which is the red-flag one.
            child: LayoutBuilder(
              builder: (context, box) {
                final available = box.maxHeight;
                return Obx(() {
                  // The caps have to add up, and how they add up depends on
                  // what is actually on screen — see `livePanelHeightFraction`,
                  // where the three cases and the cost of each are written down.
                  final panelCap = c.livePanelHeightFraction;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Rail(c),
                      // Two capped bands and one that takes the slack. Both
                      // caps hold their own scroll, so the content inside gives
                      // way rather than the column overflowing — and together
                      // they leave the rail room to grow at the largest text
                      // size.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: available * c.noticesHeightFraction,
                        ),
                        child: _Notices(c),
                      ),
                      // The live panel is measured first, at whatever height it
                      // needs up to its cap, and the transcript takes what is
                      // left. That order is the whole point: the question being
                      // asked now outranks the history of the ones already
                      // answered. `Flexible` rather than `Expanded` so an empty
                      // transcript yields its space instead of holding it open.
                      Flexible(child: _Conversation(c)),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: available * panelCap,
                        ),
                        child: _LivePanel(c),
                      ),
                    ],
                  );
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Where we are ────────────────────────────────────────────────────────────

class _Rail extends StatelessWidget {
  const _Rail(this.c);

  final CaseTakingController c;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      BentoSpace.page,
      BentoSpace.page,
      BentoSpace.page,
      0,
    ),
    child: Obx(() {
      final progress = c.rxProgress.value;
      // The server's figures, whole. There is no arithmetic here on the
      // number of bubbles on screen: the phone does not know which
      // questions apply to this patient, so a local count would promise a
      // finish line that moves.
      return ProgressRail(
        key: CaseTakingKeys.progress,
        step: progress.step,
        total: progress.expected,
      );
    }),
  );
}

// ── What needs saying before anything else ──────────────────────────────────

class _Notices extends StatelessWidget {
  const _Notices(this.c);

  final CaseTakingController c;

  @override
  Widget build(BuildContext context) => Obx(() {
    final raised = c.rxRedFlagRaised.value;
    final quote = c.rxRedFlagQuote.value ?? '';
    final stale = c.rxFromSnapshot.value;
    final error = c.rxLoadError.value;

    if (!raised && !stale && error == null) return const SizedBox.shrink();

    // Scrollable inside its cap. The red-flag notice quotes the patient's
    // own words and never ellipsises them — "chest pain spreading to my…"
    // is worse than useless on the one screen that matters — so a long
    // sentence has to be able to scroll rather than push the question off
    // the bottom of the page.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        BentoSpace.section,
        BentoSpace.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (raised) ...[
            // The only free text this can render is the patient's own
            // words. Everything else on it is fixed copy in `PatientText`,
            // none of which names a condition — so there is no path by
            // which this screen tells somebody they are having a heart
            // attack, and none by which it tells them they are not.
            //
            // The server's own `patientMessage` is deliberately not drawn
            // here. It says the same thing the fixed copy says, and
            // rendering server free text on this surface would reopen the
            // hole the component closes.
            KeyedSubtree(
              key: CaseTakingKeys.redFlag,
              child: RedFlagNotice(reported: quote),
            ),
            const SizedBox(height: BentoSpace.action),
          ],
          if (stale) ...[
            NoticeBanner(
              message: PatientText.showingWhereYouLeftOff,
              icon: Icons.cloud_off_rounded,
              tint: AppColors.warning,
            ),
            const SizedBox(height: BentoSpace.action),
          ],
          if (error != null)
            ErrorRetryBanner(
              key: CaseTakingKeys.error,
              message: error,
              title: PatientText.couldNotStart,
              onRetry: c.reload,
              margin: EdgeInsets.zero,
            ),
        ],
      ),
    );
  });
}

// ── What has been said ──────────────────────────────────────────────────────

class _Conversation extends StatelessWidget {
  const _Conversation(this.c);

  final CaseTakingController c;

  @override
  Widget build(BuildContext context) => Obx(() {
    final turns = c.rxTurns.toList();

    if (turns.isEmpty && c.rxFirstLoad.value) {
      return const Padding(
        padding: EdgeInsets.all(BentoSpace.page),
        child: BentoSkeleton(rows: 2),
      );
    }

    // Nothing said yet, so take no room. A `ListView` is greedy — it fills
    // whatever height it is handed, including when it has no children — and on
    // the first question that turned the top half of the screen into a blank
    // field while the question and its answers were squeezed into a scroll
    // below it.
    if (turns.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      key: CaseTakingKeys.transcript,
      // Newest at the bottom, and on screen without anybody scrolling.
      //
      // A `ListView` is lazy: it builds what it has room to show and nothing
      // else. Anchored at the top, that is the *oldest* turns — so after six
      // questions the patient's latest answer was neither visible nor in the
      // tree, and what they saw above the question was how the conversation
      // started. `reverse` anchors the list at the end instead, which is both
      // the right reading order for a conversation and the only one where the
      // answer just given is the one on screen.
      //
      // The index is flipped to match: under `reverse`, item 0 sits at the
      // bottom, so it has to be the last turn.
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        BentoSpace.section,
        BentoSpace.page,
        BentoSpace.action,
      ),
      itemCount: turns.length,
      itemBuilder: (context, index) => _Turn(turns[turns.length - 1 - index]),
    );
  });
}

class _Turn extends StatelessWidget {
  const _Turn(this.turn);

  final InterviewTurn turn;

  @override
  Widget build(BuildContext context) {
    if (turn.speaker == ConversationSpeaker.assistant) {
      return AssistantBubble(text: turn.text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        PatientBubble(
          text: turn.text,
          source: turn.source,
          confidence: turn.confidence,
        ),
        if (turn.stillReading) const _StillReading(),
      ],
    );
  }
}

/// "Still reading that", under the answer it belongs to.
///
/// **Not a spinner, and not in the way.** Reading a long answer properly costs
/// the model eight to twenty seconds on this hardware, and the next question is
/// already on screen above the keyboard — so what this owes the patient is the
/// fact that their answer arrived, not a wheel to watch. A
/// `CircularProgressIndicator` here would also schedule frames forever and
/// ignore Reduce Motion, which is the exact shape that hangs the e2e harness.
///
/// Amber rather than red: this is the app admitting something about itself, and
/// red on this surface belongs to a patient who should not be in a waiting
/// room.
class _StillReading extends StatelessWidget {
  const _StillReading();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = semanticInk(context, AppColors.warning);

    return Padding(
      key: CaseTakingKeys.stillReading,
      padding: const EdgeInsets.only(top: 6, right: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded, size: 14, color: ink),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              PatientText.stillReadingThat,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (isDark
                          ? AppTextStyles.darkFootnote(weight: FontWeight.w600)
                          : AppTextStyles.lightFootnote(
                              weight: FontWeight.w600,
                            ))
                      .copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ── The question, and the three ways to answer it ───────────────────────────

class _LivePanel extends StatelessWidget {
  const _LivePanel(this.c);

  final CaseTakingController c;

  @override
  Widget build(BuildContext context) {
    // Its own scroll, inside the cap its parent gave it. A 0–10 severity
    // question is thirteen tiles plus a keyboard and a microphone, and at the
    // largest system text size that is taller than a phone — so the panel
    // gives way rather than pushing the question off the top.
    //
    // Anchored to the top, deliberately. `reverse: true` pins the *bottom* of
    // the content, which does precisely what the paragraph above says it must
    // not: the moment the panel is taller than its cap, the question scrolls
    // out of sight and the patient is answering a question they cannot read.
    // A contact sheet caught it showing the answer tiles sliced through the
    // middle of their own glyphs with no question above them. If something has
    // to fall off the bottom, let it be the microphone — every question is
    // answerable by touch.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        0,
        BentoSpace.page,
        BentoSpace.page,
      ),
      child: Obx(() {
        final question = c.rxQuestion.value;
        final finished = c.rxStatus.value.isFinished;
        final settling =
            c.rxStatus.value == CaseInterviewStatus.awaitingExtraction;
        final sending = c.rxSending.value;
        final turnError = c.rxTurnError.value;

        if (finished) return _Finished(c);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (question != null)
              KeyedSubtree(
                key: CaseTakingKeys.question,
                // `live` steps the question up to title2 and announces it to
                // a screen reader — a patient using VoiceOver has no other
                // way to know the conversation moved on.
                child: AssistantBubble(text: question.prompt, live: true),
              )
            else if (settling)
              NoticeBanner(
                message: PatientText.almostThere,
                icon: Icons.edit_note_rounded,
              )
            else if (sending)
              // The gap between one question and the next, said out loud.
              //
              // `_submit` moves the question into the conversation and clears
              // `rxQuestion` *before* the round trip, which is right — the
              // answer belongs under the question it answered. What that leaves
              // is a panel with nothing on it, and the design justified that on
              // the round trip being milliseconds. It is milliseconds only when
              // the hospital answers: on a dropped connection it is the thirty
              // second connect timeout, and for all of it the screen was a
              // question bubble with a blank half-page under it and no word of
              // explanation. This is that word. Not a spinner — see
              // `_StillReading` for why nothing on this surface may schedule
              // frames forever.
              NoticeBanner(
                key: CaseTakingKeys.sending,
                message: PatientText.sendingYourAnswer,
                icon: Icons.schedule_send_rounded,
              ),
            if (turnError != null) ...[
              const SizedBox(height: BentoSpace.action),
              ErrorRetryBanner(
                key: CaseTakingKeys.answerError,
                message: turnError,
                title: PatientText.couldNotSendAnswer,
                onRetry: c.retryAnswer,
                margin: EdgeInsets.zero,
              ),
            ],
            // Gated on the question and on nothing else. **Not on
            // `rxLoading`.** It was, and that is the one state this screen is
            // forbidden to be in: a patient whose connection dropped gets the
            // question back off the phone's own snapshot, presses "Try again",
            // and the retry turns `rxLoading` true for as long as the request
            // takes — up to the thirty second connect timeout on a network
            // that is not there. For all of it the tiles, the keyboard and the
            // microphone were gone, the error banner had been cleared by the
            // retry that hid them, and what was left was a question with
            // nothing to answer it with and nothing saying why.
            //
            // A question already on screen does not become unanswerable
            // because a refresh is in flight. The only in-flight state that may
            // touch these controls is `sending`, which is one answer's round
            // trip and is passed down to disable the send button rather than to
            // remove anything.
            if (question != null) ...[
              const SizedBox(height: BentoSpace.section),
              _Answers(c, question: question, sending: sending),
            ],
          ],
        );
      }),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished(this.c);

  final CaseTakingController c;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BentoCard(
      key: CaseTakingKeys.finished,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            PatientText.thatIsEverything,
            style: isDark
                ? AppTextStyles.darkTitle3()
                : AppTextStyles.lightTitle3(),
          ),
          const SizedBox(height: 10),
          Text(
            PatientText.aDoctorWillRead,
            style:
                (isDark ? AppTextStyles.darkBody() : AppTextStyles.lightBody())
                    .copyWith(
                      color: secondaryLabelColor(context),
                      height: 1.45,
                    ),
          ),
          const SizedBox(height: BentoSpace.section),
          // The read-back and the submission are the next phase's screen; the
          // route it will own is where this button goes when it exists. Until
          // then this is honest about what has happened — the answers are on
          // the server and nothing is lost by leaving.
          PrimaryBar(
            key: CaseTakingKeys.finishedDone,
            label: PatientText.done,
            onPressed: c.leave,
          ),
        ],
      ),
    );
  }
}

/// Tap, type, speak — all three, always.
class _Answers extends StatelessWidget {
  const _Answers(this.c, {required this.question, required this.sending});

  final CaseTakingController c;
  final CaseQuestion question;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: CaseTakingKeys.answers,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TouchAnswers(c, question: question),
        const SizedBox(height: BentoSpace.section),
        _TypedAnswer(c, sending: sending),
        const SizedBox(height: BentoSpace.section),
        _Voice(c),
      ],
    );
  }
}

/// The tiles.
///
/// A yes/no question gets `UnknownAnswerRow` — four equal tiles for four
/// different clinical facts, and the one component in the kit whose whole
/// purpose is that "I don't know" is not a smaller version of "No". Everything
/// else gets its own options followed by the same two reserved answers, so
/// there is a way past every question without typing a word.
class _TouchAnswers extends StatelessWidget {
  const _TouchAnswers(this.c, {required this.question});

  final CaseTakingController c;
  final CaseQuestion question;

  @override
  Widget build(BuildContext context) {
    if (question.isYesNo) {
      return UnknownAnswerRow(
        // Null, always. A pre-selected answer on a question nobody has answered
        // is a denial the patient did not make.
        selected: null,
        // Keyed by the **token each tile sends**, not by the enum's own name,
        // so the two row shapes below and above key identically: "I don't
        // know" is `case_answer_not_sure` whichever control drew it, and the
        // way past a question is `case_answer_skip` on both. A key that
        // described the widget rather than the wire would let the two drift and
        // leave a test asserting on the one the patient is not using.
        keyOf: _keyForAnswer,
        onAnswered: c.answerYesNo,
      );
    }

    return AnswerChoiceRow<CaseAnswerOption>(
      choices: question.touchOptions,
      columns: question.touchColumns,
      labelOf: (option) => option.label,
      keyOf: (option) => option.modality == CaseAnswerModality.skip
          ? CaseTakingKeys.skip
          : CaseTakingKeys.answer(option.token),
      onSelected: c.answerByTouch,
    );
  }

  static Key _keyForAnswer(PatientAnswer answer) => switch (answer) {
    PatientAnswer.yes => CaseTakingKeys.answer(CaseChoiceTokens.yes),
    PatientAnswer.no => CaseTakingKeys.answer(CaseChoiceTokens.no),
    PatientAnswer.unknown => CaseTakingKeys.answer(CaseChoiceTokens.unsure),
    PatientAnswer.skipped => CaseTakingKeys.skip,
  };
}

class _TypedAnswer extends StatelessWidget {
  const _TypedAnswer(this.c, {required this.sending});

  final CaseTakingController c;
  final bool sending;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      BentoInput(
        label: PatientText.typeYourAnswer,
        placeholder: PatientText.typeHere,
        fieldKey: CaseTakingKeys.typed,
        controller: c.typed,
        focusNode: c.typedFocus,
        enabled: !sending,
        // Several sentences is a normal answer to "what is bothering you",
        // and a single-line field silently scrolls the first half of it out
        // of sight while somebody is deciding whether they said it right.
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => c.answerByTyping(),
      ),
      const SizedBox(height: BentoSpace.action),
      PrimaryBar(
        key: CaseTakingKeys.send,
        label: sending ? PatientText.sending : PatientText.sendAnswer,
        icon: Icons.arrow_forward_rounded,
        onPressed: sending ? null : c.answerByTyping,
      ),
    ],
  );
}

class _Voice extends StatelessWidget {
  const _Voice(this.c);

  final CaseTakingController c;

  @override
  Widget build(BuildContext context) => Obx(() {
    final available = c.rxVoiceAvailable.value;
    final notice = c.rxVoiceNotice.value;
    final needsSettings = c.rxVoiceNeedsSettings.value;
    final draft = c.rxDraft.value;
    final mic = c.rxMic.value;
    final level = c.rxLevel.value;

    // Gone, with a sentence in its place. Not a disabled microphone: a
    // control that is plainly not accepting a tap is better than one that
    // takes it and does nothing, and the sentence is the part that tells
    // somebody they can still finish.
    if (!available) {
      return Column(
        key: CaseTakingKeys.voiceUnavailable,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          NoticeBanner(
            message: notice ?? PatientText.voiceUnavailable,
            icon: Icons.mic_off_rounded,
            tint: AppColors.warning,
          ),
          if (needsSettings) ...[
            const SizedBox(height: BentoSpace.action),
            SecondaryBar(
              label: PatientText.openSettings,
              onPressed: c.openVoiceSettings,
            ),
          ],
        ],
      );
    }

    if (draft != null) {
      return KeyedSubtree(
        key: CaseTakingKeys.draft,
        child: TranscriptDraft(
          text: draft.text,
          confidence: AnswerConfidence.fromScore(draft.confidence),
          onAccept: c.acceptDraft,
          onRetry: c.recordAgain,
          onType: c.typeInstead,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mic == MicState.listening) ...[
          KeyedSubtree(
            key: CaseTakingKeys.listening,
            child: ListeningIndicator(level: level),
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        MicButton(
          key: CaseTakingKeys.mic,
          state: mic,
          onPressed: mic == MicState.working ? null : c.toggleMicrophone,
        ),
      ],
    );
  });
}
