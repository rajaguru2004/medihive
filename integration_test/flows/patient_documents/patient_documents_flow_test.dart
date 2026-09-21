import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/data/repositories/patient_documents_repository.dart';
import 'package:medihive/app/data/services/image_source.dart';
import 'package:medihive/app/data/services/patient_document_file_source.dart';
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

/// P8 — a patient hands over the papers they brought with them, and then checks
/// what was read out of them.
///
/// ## Why nothing here taps "Take a photo"
///
/// The device tier runs on an emulator, which has no lens. Tapping the camera
/// opens a capture surface nothing can service, so the test either hangs
/// waiting for frames or "passes" because a stub swallowed the tap — and a test
/// that passes for that reason is worse than no test at all. The camera stays
/// in the UI, because a patient holding a prescription needs it and §4 lists it
/// first; what the automated tier drives is the photo library and the file
/// picker, which reach exactly the same code from [DocumentOrigin.gallery]
/// onwards. The camera *branch* — that it asks for the camera, that a
/// backed-out picker is not a failure, that a refusal is a sentence — is
/// covered in `test/unit/modules/document_list_controller_test.dart`, where it
/// costs nothing and needs no hardware.
///
/// The happy path is one test here and the rest are the ways this screen can be
/// quietly wrong. Each has a spec section behind it and a real consequence, and
/// the assertions are named after the consequence: a fabricated denial is the
/// one that gets somebody prescribed the drug that kills them, a leaked engine
/// message is the one that tells somebody in a corridor that a Python service
/// is down, and a duplicate silently swallowed leaves a patient pressing a
/// button that appears to do nothing.
void registerPatientDocumentsFlows() {
  group('patient documents', () {
    /// Boots the portal with two documents already held and pickers that
    /// answer with the backend's own fixture documents.
    ///
    /// The three device seams are registered **before** the screen opens, so
    /// the repository's own `register()` — which installs the real
    /// `image_picker`, `file_picker` and permission prompt — finds them already
    /// there and leaves them alone. That is the same `isRegistered` guard
    /// radiology and the profile screen have always relied on, pointed at a
    /// test rather than at a build with no plugin in it.
    Future<PatientDocumentsRobot> openPortal(
      WidgetTester tester, {
      ImageSource images = const StubGalleryImageSource(),
      PatientDocumentFileSource files = const StubPdfFileSource(),
      MediaPermissionGate permissions = const GrantedMediaPermissions(),
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

      Get.put<ImageSource>(images, permanent: true);
      Get.put<PatientDocumentFileSource>(files, permanent: true);
      Get.put<MediaPermissionGate>(permissions, permanent: true);
      addTearDown(() {
        Get.delete<ImageSource>(force: true);
        Get.delete<PatientDocumentFileSource>(force: true);
        Get.delete<MediaPermissionGate>(force: true);
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

      // The photo library answers with the same prescription under the same
      // name every time, which is exactly the case §21 is about: an upload that
      // looked like it stalled, and a second tap.
      await documents.addFromGallery();
      await documents.assertOnReview();
      await documents.backToList();

      await documents.addFromGallery();
      await documents.assertOnReview();

      // Told, not refused, and not silently swallowed either. A patient who
      // pressed the button twice needs to know which of those happened.
      await documents.seeReportedAsDuplicate();
      documents.seeNoTechnicalDetail();
    });

    testWidgets('a page photographed from too far away is told to be retaken',
        (tester) async {
      final documents = await openPortal(
        tester,
        images: const TooSmallImageSource(),
      );

      await documents.openFromDashboard();
      await documents.addFromGallery();
      await documents.assertOnReview();

      // §5. The quality check runs before OCR, so what comes back is an
      // instruction rather than a confidence score about the wrong characters.
      await documents.seeMessage(containing: 'too small to read');
      await documents.seeMessage(containing: 'holding the camera closer');
      documents.seeNoTechnicalDetail();
    });

    testWidgets('a PDF goes up as a PDF', (tester) async {
      final documents = await openPortal(tester);

      await documents.openFromDashboard();
      await documents.addPdf();
      await documents.assertOnReview();

      // The field name and the media type are the two things this route judges
      // an upload on, and both are stated rather than inferred: `FileInterceptor
      // ('file')` reads that name and nothing else, and Dio types a part it was
      // given no type for as `application/octet-stream`, which the route
      // refuses with a sentence about the file not being a photograph.
      final upload = documents.api.requireCall(
        'POST',
        '/api/patient-documents',
      );
      expect(upload.formFiles.keys, contains('file'));
      expect(upload.formFiles['file'], StubPdfFileSource.filename);
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

      // §22: the evidence is reachable, and it arrives over the authenticated
      // origin rather than as a signed bucket URL — `/original` names a host a
      // handset cannot resolve, and nothing that reached it would carry this
      // patient's token. Asserted on the route the screen actually takes, so
      // that a regression back to the signed link fails here rather than in
      // somebody's hand.
      documents.api.requireCall(
        'GET',
        '/api/patient-documents/:documentId/file',
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

    testWidgets('a device that says no says what to do instead',
        (tester) async {
      final documents = await openPortal(
        tester,
        permissions: const RefusedMediaPermissions(),
      );

      await documents.openFromDashboard();
      await documents.addFromGallery();

      // A refusal is **never** a null. The sentence is written for the patient
      // and names the way forward rather than the problem — which is the whole
      // reason `MediaAccess` throws instead of answering with nothing.
      await documents.seeUploadRefusal(containing: 'take a new photo instead');
      documents.api.requireNoCall('POST', '/api/patient-documents');
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
