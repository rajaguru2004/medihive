import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/theme/theme.dart';

import '../../fixtures/modules/case_review_fixtures.dart';
import '../../fixtures/modules/case_taking_fixtures.dart';
import '../../fixtures/modules/patient_documents_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/case_review_robot.dart';
import '../../robots/patient_portal_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerCaseReviewFlows();
}

/// P9 — the patient reads back what the hospital understood, changes what is
/// wrong, and sends it.
///
/// The properties under test are the ones a screen loses quietly. Six presences
/// staying six is the first: an "I don't know" that renders like a "no" is a
/// chart entry nobody made, and the difference is invisible in a screenshot. A
/// contradiction shown with one value is not a contradiction, it is a
/// correction the app made on somebody's behalf. And a question nobody asked,
/// omitted, reads as nothing to report.
void registerCaseReviewFlows() {
  group('case review', () {
    /// Boots the portal with an interview that has run out of questions.
    ///
    /// Order matters in the overrides. `installCaseTakingFixtures` is what
    /// makes `sessions/current` answer with a session — the app has no other
    /// way to find an open interview — and the review fixtures go **after** it
    /// so that this flow's own correction handlers win: both register
    /// `POST /turns` and `PATCH /facts/:factId`, because on the server a
    /// correction is one write whichever door it arrives through.
    Future<(CaseReviewRobot, PatientPortalRobot)> openPortal(
      WidgetTester tester, {
      bool withDocuments = false,
    }) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) {
          installCaseTakingFixtures(
            api,
            from: kCaseScript.length,
            resumed: true,
          );
          installPatientDocumentsFixtures(api, withDocuments: withDocuments);
          installCaseReviewFixtures(api);
        },
      );
      return (CaseReviewRobot(harness), PatientPortalRobot(harness));
    }

    testWidgets('the dashboard offers the case back, and the case is not a '
        'diagnosis', (tester) async {
      final (review, portal) = await openPortal(tester);

      await portal.assertOnPortal();
      // §39, first half: an interview that has not been sent is on the
      // dashboard, because `sessions/current` can see it.
      await review.seeCaseOnDashboard(saying: 'not sent yet');
      await review.openFromDashboard();

      // §43. On screen, above the case, and not in a footnote — a patient who
      // believes the app has told them what is wrong may not go in at all.
      await review.seeItIsNotADiagnosis();
      review.seeNoDiagnosisLanguage();

      await review.seeItem(kComplaintField, saying: kComplaintValue);
    });

    testWidgets('the four states of an answer stay four states on screen',
        (tester) async {
      final (review, _) = await openPortal(tester);
      await review.openFromDashboard();

      // A denial is a finding and says so. Silence is not a denial and says
      // that instead. "I don't know" is neither. Three different sentences for
      // three different clinical facts, and the fourth — a refusal — has its
      // own too.
      await review.seeItem(kDeniedField, saying: 'None reported');
      await review.seeItem(kUnsureField, saying: 'Patient unsure');
      await review.seeItem(kUnansweredField, saying: 'Not assessed');

      // And each of them is still answerable, with all four tiles offered and
      // the one they already chose showing as chosen.
      await review.seeFourWaysToAnswer(kDeniedField,
          selected: PatientAnswer.no);
      await review.seeFourWaysToAnswer(kUnsureField,
          selected: PatientAnswer.unknown);
      // Nothing selected. A pre-selected answer on a question nobody has asked
      // is an answer the app supplied.
      await review.seeFourWaysToAnswer(kUnansweredField, selected: null);

      // §36: printed, not omitted, and with the question's own wording rather
      // than its field key.
      await review.seeStillToAsk(naming: kUnansweredLabel);
    });

    testWidgets('an uncertain answer never becomes a denial', (tester) async {
      final (review, _) = await openPortal(tester);
      await review.openFromDashboard();

      // The patient changes their mind about a question they had denied.
      await review.markItemUnsure(kDeniedField);

      // It comes back as uncertainty, not as a blank and not as the "no" it
      // was. The token that travelled was `not_sure` — a thing the patient
      // pressed — and the server derived the state from it.
      await review.seeItem(kDeniedField, saying: 'Patient unsure');
      await review.seeFourWaysToAnswer(kDeniedField,
          selected: PatientAnswer.unknown);
    });

    testWidgets('a correction re-labels the line it changed', (tester) async {
      final (review, _) = await openPortal(tester);
      await review.openFromDashboard();

      // Before: heard, and attributed to the hearing.
      await review.seeItem(kDurationField, saying: kDurationBefore);
      await review.seeItemSource(kDurationField, AnswerSource.spoken);

      await review.correctItem(kDurationField, kDurationAfter);

      // After: the patient's words, attributed to the patient. The old reading
      // is not overwritten on the server — `recordFact` retires it and keeps
      // it — which is the part a clinician needs.
      await review.seeItem(kDurationField, saying: kDurationAfter);
      await review.seeItemSource(kDurationField, AnswerSource.typed);
    });

    testWidgets('a contradiction shows both values and resolves neither',
        (tester) async {
      final (review, _) = await openPortal(tester, withDocuments: true);
      await review.openFromDashboard();

      // §20 and §33. The prescription names a medicine the record does not
      // hold; both sides are on screen and the card offers nothing that would
      // pick one.
      await review.seeContradiction(
        documentValue: 'Metformin 500 mg',
        recordValue: 'Amlodipine 5mg',
      );
    });

    testWidgets('a patient with no documents sees no contradictions',
        (tester) async {
      // The other side of the same decision. Without this, a card that rendered
      // unconditionally would pass the test above.
      final (review, _) = await openPortal(tester);
      await review.openFromDashboard();
      review.seeNoContradictions();
    });

    testWidgets('sending it once locks the screen and tells the dashboard',
        (tester) async {
      final (review, portal) = await openPortal(tester);
      await review.openFromDashboard();

      await review.submit();
      await review.seeSent();
      review.seeToast(containing: 'sent');
      await review.letToastsExpire();

      // Every write on this screen is a 409 now, so the screen stops offering
      // them rather than offering them to be refused.
      await review.seeLockedAfterSending();

      final submission = review.api.requireCall(
        'POST',
        '/api/case-taking/sessions/:sessionId/submit',
      );
      expect(
        submission.jsonBody.containsKey('patientId'),
        isFalse,
        reason: 'the patient arrives from the bearer token; sending one is a '
            '400 that takes the whole submission with it',
      );

      // §39, second half — and the half `sessions/current` cannot answer,
      // because a submitted case is no longer an open one.
      await review.back();
      await portal.assertOnPortal();
      await review.seeCaseOnDashboard(saying: 'have been sent');
    });
  });
}
