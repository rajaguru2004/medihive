import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/case_intake_keys.dart';
import 'package:medihive/app/core/keys/patient_hub_keys.dart';

import '../support/pump.dart';
import 'robot.dart';

/// A clinician reading an intake a patient sent in.
///
/// The counterpart to `CaseReviewRobot`, which drives the same document from
/// the patient's side. The assertions here are about the difference between
/// the two: what a doctor is shown that a patient is not, and what neither of
/// them is allowed to do to it.
final class CaseIntakeRobot extends Robot {
  CaseIntakeRobot(super.harness);

  @override
  String? get route => null;

  @override
  Key get anchor => CaseIntakeKeys.screen;

  /// Opens one intake from the row on the patient's chart.
  Future<void> openFromChart(String submissionId) async {
    await tester.scrollToKey(PatientHubKeys.row('intake', submissionId));
    await tester.tapKey(PatientHubKeys.row('intake', submissionId));
    await tester.pumpUntilFound(find.byKey(CaseIntakeKeys.screen));
    await settle();
  }

  Future<void> assertOnIntake() async {
    await tester.pumpUntilFound(find.byKey(CaseIntakeKeys.screen));
    expect(Get.currentRoute, startsWith('/intakes/'));
  }

  /// The sentence that changes how everything under it is read.
  ///
  /// Keyed rather than matched on words, and asserted in its own step because
  /// it is the one line whose absence would leave a clinician reading a
  /// patient's own account as though somebody had checked it.
  Future<void> seeItIsUnverified() async {
    await tester.scrollToKey(CaseIntakeKeys.unverifiedNotice);
    expect(find.byKey(CaseIntakeKeys.unverifiedNotice), findsOneWidget);
  }

  /// A safety rule, by its own title.
  ///
  /// The assertion this screen exists for: the patient's view of the same case
  /// answers with a count and no titles, because a rule set's titles name
  /// syndromes. The clinician is the qualified reader.
  /// [saying] and [advising] are the rule's `clinicianSummary` and
  /// `recommendedAction` — the two sentences that decide what happens next.
  /// Asserted **inside this flag's own card**, because the whole defect this
  /// pins was that they parsed to null and rendered as nothing: a check for
  /// the title alone passed the entire time they were absent.
  Future<void> seeRedFlag(
    String id, {
    required String titled,
    String? saying,
    String? advising,
  }) async {
    final card = CaseIntakeKeys.redFlag(id);
    await tester.scrollToKey(card);
    expect(find.byKey(card), findsOneWidget);

    for (final sentence in [titled, ?saying, ?advising]) {
      expect(
        find.descendant(of: find.byKey(card), matching: find.textContaining(sentence)),
        findsOneWidget,
        reason: 'the flag\'s card must carry "$sentence"',
      );
    }
  }

  /// The patient's own wording for a rule is **not** on the clinician's
  /// screen. Both strings are on the wire; printing the reassurance written
  /// for the patient in place of the clinical summary is reading the wrong
  /// sentence.
  void seeNoPatientWording(String patientMessage) {
    expect(
      find.textContaining(patientMessage),
      findsNothing,
      reason: 'the clinician screen printed the patient-facing wording',
    );
  }

  /// One line of the case, with what the patient actually said about it.
  ///
  /// [saying] is checked inside the line's own widget rather than anywhere on
  /// screen: "None reported" appears against several questions, and a loose
  /// finder would pass on somebody else's answer.
  Future<void> seeItem(String fieldPath, {required String saying}) async {
    final key = CaseIntakeKeys.item(fieldPath);
    await tester.scrollToKey(key);
    expect(
      find.descendant(of: find.byKey(key), matching: find.textContaining(saying)),
      findsOneWidget,
      reason: '$fieldPath should read "$saying"',
    );
  }

  /// §36 on the clinician's screen: the questions nobody reached, printed.
  Future<void> seeNotAsked({required String naming}) async {
    await tester.scrollToKey(CaseIntakeKeys.missing);
    expect(
      find.descendant(
        of: find.byKey(CaseIntakeKeys.missing),
        matching: find.textContaining(naming),
      ),
      findsOneWidget,
      reason: 'an unanswered question must be printed, not omitted — an '
          'omitted line reads as nothing to report',
    );
  }

  /// "There is nothing here a clinician could change."
  ///
  /// The screen's whole read-only claim in one step. A doctor holds
  /// `case-taking: read` and nothing else, so a control that wrote would be a
  /// 403 — and, worse, would imply an intake is something a clinician may
  /// rewrite.
  Future<void> seeNothingIsEditable() async {
    for (final field in find.byType(TextField).evaluate()) {
      final widget = field.widget as TextField;
      expect(
        widget.enabled,
        isFalse,
        reason: 'an intake offered an editable field',
      );
    }
    expect(
      find.widgetWithText(ElevatedButton, 'Save'),
      findsNothing,
      reason: 'an intake offered a save control',
    );
  }

  Future<void> seeIntakeNotFound() async {
    await tester.pumpUntilFound(find.byKey(CaseIntakeKeys.error));
  }
}
