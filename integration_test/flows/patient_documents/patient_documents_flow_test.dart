import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/data/services/file_source.dart';
import 'package:medihive/app/data/services/image_source.dart';
import 'package:medihive/app/theme/theme.dart';

import '../../fakes/fake_api.dart';
import '../../fakes/fake_image_http.dart';
import '../../fixtures/modules/patient_documents_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/patient_documents_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerPatientDocumentsFlows();
}

/// P8 — a patient photographs the papers they brought with them, and then
/// checks what was read out of them.
///
/// The happy path is one test here and the other seven are the ways this screen
/// can be quietly wrong. Each of those has a spec section behind it and a
/// real-world consequence, and the assertions are named after the consequence:
/// a fabricated denial is the one that gets somebody prescribed the drug that
/// kills them, a leaked engine message is the one that tells somebody in a
/// corridor that a Python service is down, and a duplicate silently swallowed
/// is the one that leaves a patient pressing a button that appears to do
/// nothing.
void registerPatientDocumentsFlows() {
  group('patient documents', () {
    /// Boots the portal with two documents already held and a picker that
    /// answers.
    ///
    /// The pickers are registered **before** the screen opens, so the
    /// repository's own `register()` — which installs the real `image_picker`
    /// and `file_picker` implementations — finds them already there and leaves
    /// them alone. That is the same `isRegistered` guard radiology and the
    /// profile screen have always relied on, pointed at a test rather than at
    /// a build with no plugin in it.
    Future<PatientDocumentsRobot> openPortal(
      WidgetTester tester, {
      FileSource files = const StubPdfFileSource(),
      void Function(FakeApi api)? extra,
    }) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
        overrides: (api) {
          installPatientDocumentsFixtures(api, withDocuments: true);
          extra?.call(api);
        },
      );

      Get.put<ImageSource>(const StubImageSource(), permanent: true);
      Get.put<FileSource>(files, permanent: true);
      addTearDown(() {
        Get.delete<ImageSource>(force: true);
        Get.delete<FileSource>(force: true);
      });

      return PatientDocumentsRobot(harness);
    }

    testWidgets('what was read is shown as read, and never as decided',
        (tester) async {
      final documents = await openPortal(tester);

      await documents.openFromDashboard();
      await documents.assertOnList();
      await documents.seeDocument(kReadableDocumentId);
      await documents.openDocument(kReadableDocumentId);
      await documents.assertOnReview();

      // §2. The server's own sentence, and it says the opposite of "filed":
      // please check this before it is added to your medical history.
      await documents.seeMessage(containing: 'before it is added');

      // §17. Two measurements of two different things, each under its own
      // name, and no third number pretending to be both.
      await documents.seeBothConfidences();
      documents.seeNoBlendedConfidence();

      // A clearly printed medicine, and one the model itself flagged as
      // ambiguous. The second carries the mark; the first does not.
      await documents.seeValue('medications.0', reading: kGroundedMedication);
      await documents.seeValueIsClear('medications.0');
      await documents.seeValue('medications.1', reading: kUncertainMedication);
      await documents.seeValueNeedsCheck('medications.1');

      // Nothing is confirmed, and nothing looks it.
      await documents.seeValueState('medications.0', 'Not checked yet');
      await documents.seeConfirmOfferedButNotReady();

      // And nothing has been confirmed on the server either. `verify` is the
      // only way out of needs_review and the patient has not said so.
      documents.api.requireNoCall(
        'POST',
        '/api/patient-documents/:documentId/verify',
      );
    });

    testWidgets(
        'a low-confidence medicine can be corrected, and that re-labels it',
        (tester) async {
      final documents = await openPortal(tester);

      await documents.openFromDashboard();
      await documents.openDocument(kReadableDocumentId);
      await documents.assertOnReview();

      // Before: the document is the authority for this line.
      await documents.seeValueNeedsCheck('medications.1');
      await documents.seeValueSource('medications.1', AnswerSource.record);

      await documents.correctValue('medications.1', kCorrectedMedication);

      // After: the patient is. The value on screen is theirs and the chip says
      // where it came from — which is the whole point of making a correction
      // that the API has nowhere to file yet.
      await documents.seeValue('medications.1', reading: kCorrectedMedication);
      await documents.seeValueSource('medications.1', AnswerSource.typed);
      await documents.seeValueState('medications.1', 'You corrected this');

      // And the document is no longer confirmable as read, because it was not
      // read correctly. Said in words rather than left as a dead button.
      await documents.seeConfirmWithheld();
      documents.api.requireNoCall(
        'POST',
        '/api/patient-documents/:documentId/verify',
      );
    });

    testWidgets('a document that does not mention allergies never says none',
        (tester) async {
      final documents = await openPortal(tester);

      await documents.openFromDashboard();
      await documents.openDocument(kReadableDocumentId);
      await documents.assertOnReview();

      // §19, and the single most dangerous mistake available on this screen.
      // The prescription has no allergy section; the line says exactly that,
      // in the server's own words, because the server is the party that looked
      // at the page.
      await documents.seeSilenceOn(
        'allergies',
        saying: 'does not mention allergies',
      );
      documents.seeNoFabricatedDenial();
    });

    testWidgets('an unreadable photograph gets a sentence, not a stack trace',
        (tester) async {
      final documents = await openPortal(tester);

      await documents.openFromDashboard();
      await documents.openDocument(kUnreadableDocumentId);
      await documents.assertOnReview();

      // §27's worked example, shown verbatim: what happened, and what to do
      // about it.
      await documents.seeMessage(containing: "couldn't read this document");
      await documents.seeMessage(containing: 'clearer image');
      documents.seeNoTechnicalDetail();

      // Nothing to confirm on a document nothing was read out of.
      documents.api.requireNoCall(
        'POST',
        '/api/patient-documents/:documentId/verify',
      );
    });

    testWidgets('confirming every value is what lets the document be confirmed',
        (tester) async {
      final documents = await openPortal(tester);

      await documents.openFromDashboard();
      await documents.openDocument(kReadableDocumentId);
      await documents.assertOnReview();

      for (final field in const [
        'medications.0',
        'medications.1',
        'diagnosesRecorded.0',
        'followUp.0',
      ]) {
        await documents.confirmValue(field);
      }

      await documents.seeConfirmReady();
      await documents.confirmDocument();

      // The one write this screen makes, and the only transition out of
      // needs_review anywhere in the system.
      documents.api.requireCall(
        'POST',
        '/api/patient-documents/:documentId/verify',
      );
      documents.seeToast(containing: 'confirmed');
      await documents.letToastsExpire();
    });

    testWidgets('the same document sent twice is reported as the same document',
        (tester) async {
      final documents = await openPortal(tester);

      await documents.openFromDashboard();

      // The first photograph. `StubImageSource` answers with the same bytes
      // under the same name every time, which is exactly the case §21 is
      // about: an upload that looked like it stalled, and a second tap.
      await documents.addFromCamera();
      await documents.assertOnReview();
      await documents.backToList();

      await documents.addFromCamera();
      await documents.assertOnReview();

      // Told, not refused, and not silently swallowed either. A patient who
      // pressed the button twice needs to know which of those happened.
      await documents.seeReportedAsDuplicate();
      documents.seeNoTechnicalDetail();
    });

    testWidgets('the original the reading came from is one tap away',
        (tester) async {
      // `Image.network` goes out through `HttpClient` rather than through Dio,
      // so the fake API never sees it. Without this the widget opens a real
      // socket to a host that does not exist, which on a device is a slow
      // failure and on CI is a hang.
      final previous = HttpOverrides.current;
      HttpOverrides.global = FakeImageHttpOverrides();
      addTearDown(() => HttpOverrides.global = previous);

      final documents = await openPortal(tester);

      await documents.openFromDashboard();
      await documents.openDocument(kReadableDocumentId);
      await documents.assertOnReview();

      await documents.openOriginal();

      // §22: the evidence is reachable, and the link is fetched at the moment
      // it is wanted rather than held — it expires in five minutes.
      documents.api.requireCall(
        'GET',
        '/api/patient-documents/:documentId/original',
      );
    });

    testWidgets('backing out of the picker is not a failure', (tester) async {
      final documents = await openPortal(
        tester,
        files: const CancelledFileSource(),
      );

      await documents.openFromDashboard();
      await documents.addPdf();

      // Null and only null means "they looked at the picker and changed their
      // mind". Nothing was sent and nothing is said, which is the difference
      // between this and a refused permission — that one throws, and carries
      // the sentence to show.
      documents.seeNoUploadRefusal();
      documents.api.requireNoCall('POST', '/api/patient-documents');
      documents.seeNoToast();
    });

    testWidgets('a document still being read says so, and then stops saying it',
        (tester) async {
      final documents = await openPortal(
        tester,
        extra: installProcessingDocumentFixture,
      );

      await documents.openFromDashboard();
      await documents.openDocument(kReadableDocumentId);

      // §28. The first read answers `processing`; the screen polls, and the
      // second answer is the finished document. Nothing on the waiting screen
      // is a spinner that ignores Reduce Motion.
      await documents.seeMessage(containing: 'reading your document');
      await documents.waitUntilFinishedReading();
      await documents.seeValue('medications.0', reading: kGroundedMedication);
    });
  });
}
