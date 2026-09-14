import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/modules/case_review/case_review_routes.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// "Here is what we understood about you", and sending it.
///
/// Most of what is worth asserting on this screen is a *shape* rather than a
/// string: that six presences are still six, that a contradiction shows both
/// sides and offers no way to resolve them, that a question nobody asked is
/// printed rather than omitted. Each of those has a method here, named after
/// the property rather than after the widget that happens to carry it.
final class CaseReviewRobot extends Robot {
  CaseReviewRobot(super.harness);

  @override
  String? get route => CaseReviewRoutes.review;

  @override
  Key get anchor => CaseReviewKeys.screen;

  // ── Getting there ─────────────────────────────────────────────────────────

  /// From the patient's own dashboard, which is where §39 puts the way in.
  Future<void> openFromDashboard() async {
    await tester.scrollToKey(CaseReviewKeys.openFromDashboard);
    await tester.tapKey(CaseReviewKeys.openFromDashboard);
    await tester.pumpUntilFound(find.byKey(CaseReviewKeys.screen));
    await settle();
  }

  /// The dashboard card that says what has happened to their answers. §39.
  Future<void> seeCaseOnDashboard({required String saying}) async {
    await tester.scrollToKey(CaseReviewKeys.dashboardCard);
    expect(
      find.descendant(
        of: find.byKey(CaseReviewKeys.dashboardCard),
        matching: find.textContaining(saying),
      ),
      findsWidgets,
      reason: 'expected the dashboard to say "$saying" about this case',
    );
  }

  void seeNoCaseOnDashboard() =>
      expect(find.byKey(CaseReviewKeys.dashboardCard), findsNothing);

  // ── What the screen promises before anything else ─────────────────────────

  /// §43: the disclaimer is on screen, above the case, not in a footnote.
  Future<void> seeItIsNotADiagnosis() async {
    await tester.scrollToKey(CaseReviewKeys.disclaimer);
    expect(
      find.descendant(
        of: find.byKey(CaseReviewKeys.disclaimer),
        matching: find.textContaining('not a diagnosis'),
      ),
      findsOneWidget,
    );
  }

  /// And nothing anywhere on it reads as one.
  void seeNoDiagnosisLanguage() {
    for (final phrase in const [
      'You have',
      'diagnosed',
      'Diagnosis:',
      'likely',
      'probably',
      'suggests',
      'consistent with',
    ]) {
      expect(
        find.textContaining(phrase, skipOffstage: false),
        findsNothing,
        reason: 'the review screen said "$phrase", which reads as the app '
            'deciding something about this patient',
      );
    }
  }

  // ── One line of the case ──────────────────────────────────────────────────

  Future<void> seeItem(String fieldPath, {required String saying}) async {
    await tester.scrollToKey(CaseReviewKeys.item(fieldPath));
    expect(
      find.descendant(
        of: find.byKey(CaseReviewKeys.item(fieldPath)),
        matching: find.textContaining(saying),
      ),
      findsWidgets,
      reason: 'expected $fieldPath to read "$saying"',
    );
  }

  /// "This line is attributed to X" — and after a correction, that it moved.
  Future<void> seeItemSource(String fieldPath, AnswerSource expected) async {
    await tester.scrollToKey(CaseReviewKeys.item(fieldPath));
    final chip = find.descendant(
      of: find.byKey(CaseReviewKeys.item(fieldPath)),
      matching: find.byType(SourceChip),
    );
    expect(chip, findsOneWidget);
    expect(tester.widget<SourceChip>(chip).source, expected);
  }

  /// **The four-states assertion.**
  ///
  /// A line with no value on it gets the four-tile row, and the tile that is
  /// selected is the one matching what the patient actually said. A "no" and an
  /// "I don't know" are two different clinical facts and this is where the app
  /// proves it still knows that.
  Future<void> seeFourWaysToAnswer(
    String fieldPath, {
    PatientAnswer? selected,
  }) async {
    await tester.scrollToKey(CaseReviewKeys.item(fieldPath));
    final row = find.descendant(
      of: find.byKey(CaseReviewKeys.item(fieldPath)),
      matching: find.byType(UnknownAnswerRow),
    );
    expect(
      row,
      findsOneWidget,
      reason: '$fieldPath has no value on it, so it should offer all four '
          'answers rather than a yes and a no',
    );
    expect(
      tester.widget<UnknownAnswerRow>(row).selected,
      selected,
      reason: '$fieldPath should be showing ${selected ?? 'nothing'} as the '
          'answer already given',
    );
  }

  Future<void> confirmItem(String fieldPath) async {
    await tester.tapKey(CaseReviewKeys.confirmItem(fieldPath));
    await settle();
  }

  Future<void> markItemUnsure(String fieldPath) async {
    await tester.tapKey(CaseReviewKeys.unsureItem(fieldPath));
    await settle();
  }

  Future<void> correctItem(String fieldPath, String text) async {
    await tester.tapKey(CaseReviewKeys.correctItem(fieldPath));
    await tester.pumpUntilFound(find.byKey(CaseReviewKeys.correctionField));
    await tester.enterTextByKey(CaseReviewKeys.correctionField, text);
    await tester.tapKeyWithoutKeyboard(CaseReviewKeys.correctionSave);
    await settle();
  }

  // ── What is missing, and what disagrees ───────────────────────────────────

  /// §36: the questions nobody asked are printed, not omitted.
  Future<void> seeStillToAsk({required String naming}) async {
    await tester.scrollToKey(CaseReviewKeys.missing);
    expect(
      find.descendant(
        of: find.byKey(CaseReviewKeys.missing),
        matching: find.textContaining(naming),
      ),
      findsOneWidget,
      reason: 'expected the unanswered question "$naming" to be listed',
    );
  }

  /// §20 and §33: both sides on screen, and nothing offering to pick one.
  Future<void> seeContradiction({
    required String documentValue,
    required String recordValue,
  }) async {
    await tester.scrollToKey(CaseReviewKeys.contradictions);
    final card = find.byKey(CaseReviewKeys.contradictions);
    expect(card, findsOneWidget);

    for (final value in [documentValue, recordValue]) {
      expect(
        find.descendant(of: card, matching: find.textContaining(value)),
        findsWidgets,
        reason: 'a contradiction must show "$value" — both sides, or it is '
            'not a contradiction, it is a correction',
      );
    }

    // And no control. The app cannot decide which is right, and a button
    // implying it could would be the app making a clinical decision.
    expect(
      find.descendant(of: card, matching: find.byType(PrimaryBar)),
      findsNothing,
      reason: 'the contradiction card offered a way to resolve itself',
    );
    expect(
      find.descendant(of: card, matching: find.byType(UnknownAnswerRow)),
      findsNothing,
      reason: 'the contradiction card offered a way to resolve itself',
    );
  }

  void seeNoContradictions() =>
      expect(find.byKey(CaseReviewKeys.contradictions), findsNothing);

  // ── Sending it ────────────────────────────────────────────────────────────

  Future<void> submit() async {
    await tester.tapKey(CaseReviewKeys.submit);
    await settle();
  }

  Future<void> seeSent() async {
    await tester.pumpUntilFound(find.byKey(CaseReviewKeys.submitted));
    expect(find.byKey(CaseReviewKeys.submitted), findsOneWidget);
  }

  /// A sent case cannot be changed here, and the screen stops offering to.
  Future<void> seeLockedAfterSending() async {
    await tester.scrollToKey(CaseReviewKeys.locked);
    expect(find.byKey(CaseReviewKeys.locked), findsOneWidget);
    expect(
      find.byKey(CaseReviewKeys.submit),
      findsNothing,
      reason: 'a sent case still offered a Send button, which is a 409 with a '
          'sentence on it',
    );
    expect(
      find.byType(UnknownAnswerRow),
      findsNothing,
      reason: 'a sent case still offered to change an answer',
    );
  }
}
