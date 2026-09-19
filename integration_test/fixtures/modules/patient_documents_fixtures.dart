/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the documents a patient hands over, in fixtures
///
/// Ifeoma Balogun is `p-1` in this world, and these are the papers she brought
/// with her: a prescription that was read, and a photograph that was not.
///
/// ## Why this fixture holds state
///
/// §21 is the reason. A duplicate is **recorded and reported, never refused**,
/// and a stateless `POST` that answered every upload with a fresh row would let
/// a screen pass that never tells a patient they have sent the same
/// prescription twice — which is the commonest thing that happens when an
/// upload looks like it has stalled and somebody presses the button again. So
/// the fake keeps the sha-shaped key of every file it has taken, exactly as the
/// server keeps a sha256, and answers the second copy with a row pointing at
/// the first.
///
/// Four server behaviours are reproduced because the screen's design depends on
/// each of them, and flattening any one would let the corresponding defect
/// through:
///
///   * **a document lands `needs_review` and is never auto-verified** — the
///     only transition out of it is `POST /verify`;
///   * **the two confidences are separate measured numbers**, on the row, and
///     never blended;
///   * **absence comes back as a presence with the server's own wording** —
///     `not_assessed` and "This document does not mention allergies", never an
///     empty array for the client to interpret;
///   * **a refusal is a written sentence**, verbatim from
///     `pipeline/messages.ts`, with no engine name in it.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:medihive/app/core/app_clock.dart';
import 'package:medihive/app/data/repositories/patient_documents_repository.dart';
import 'package:medihive/app/data/services/file_source.dart';
import 'package:medihive/app/data/services/image_source.dart';
import 'package:medihive/app/data/services/media_access.dart';
import 'package:medihive/app/data/services/patient_document_file_source.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../fakes/fake_api.dart';
import '../documents/document_bytes.dart';

/// The prescription that was read, and the one every review assertion is about.
const String kReadableDocumentId = 'doc-1';

/// The photograph that could not be read.
const String kUnreadableDocumentId = 'doc-2';

/// The medicine the model was **sure** about: printed clearly, found verbatim
/// in the page text.
const String kGroundedMedication = 'Metformin';

/// The medicine it was not. Flagged `uncertain` by the model *and* absent from
/// the OCR text, which are two independent reasons to put a "check this" mark
/// beside it — and the row a correction is tested against.
const String kUncertainMedication = 'Amlodipin';

/// What the patient types instead.
const String kCorrectedMedication = 'Amlodipine 5 mg';

/// §27's worked example, verbatim from `pipeline/messages.ts`. A patient who
/// wanted to know whether to take another photograph is told to.
const String kUnreadableMessage =
    "We couldn't read this document clearly. Please upload a clearer image.";

/// §5's sentence, verbatim from `pipeline/messages.ts`: what to do, not what
/// went wrong.
const String kTooSmallMessage =
    'This image is too small to read. Please take the photo again, holding the '
    'camera closer so the page fills the frame.';

/// §21's sentence, verbatim.
const String kDuplicateMessage =
    'You have already uploaded this document. We have kept it with the first '
    'copy rather than adding it twice.';

/// §2's: found, and explicitly **not** verified.
const String kAwaitingReviewMessage =
    'We found some information in this document. Please check that it is '
    'correct before it is added to your medical history.';

/// The §19 sentence the whole feature turns on. Never "no known allergies".
const String kAllergySilence = 'This document does not mention allergies';

/// §20's own wording for a difference against the record.
const String kContradictionMessage =
    'This document contains information that differs from your current record. '
    'Please review it.';

/// Where a signed original resolves to.
///
/// A host that cannot be reached, deliberately: the screen's job is to ask for
/// the link and render an image widget, and a fixture pointing at something
/// real would make the assertion depend on a network. `Image.network`'s
/// `errorBuilder` is the path that then runs, which is the one worth having
/// covered anyway.
const String kOriginalUrl =
    'https://storage.invalid/patient-documents/doc-1.png?signature=abc';

/// Registers every route the two document screens call.
///
/// Installed by `World.install` for **every** flow, not only this module's.
/// `GET /api/patient-documents` is now on a shared path — the patient's own
/// dashboard reads it, and so does the case review screen — and
/// `AppHarness.dispose` fails any test that touches an unfixtured endpoint. A
/// module that registers its routes only in its own flow leaves that landmine
/// for every other flow that renders the same screen.
///
/// [withDocuments] is off by default because **a patient with nothing uploaded
/// is the normal starting state**, and a shared world should answer with the
/// ordinary case. The documents flow turns it on, which is the pattern the rest
/// of `world.dart` follows: one coherent world, and a flow that needs one
/// endpoint different overrides that endpoint.
///
/// State is per install, so one flow's uploads are invisible to the next flow
/// in the same file — and later registrations win, so a flow installing this
/// again with [withDocuments] replaces the shared answer wholesale.
void installPatientDocumentsFixtures(FakeApi api, {bool withDocuments = false}) {
  final held = <String, Map<String, Object?>>{
    if (withDocuments) kReadableDocumentId: _readable(),
    if (withDocuments) kUnreadableDocumentId: _unreadable(),
  };

  /// Filename to the id of the first row that carried it. The fake's stand-in
  /// for the server's sha256 index, and it behaves the same way: identical
  /// bytes arriving twice produce a second row that points at the first.
  final byFile = <String, String>{};
  var uploads = 0;

  api.on('GET', '/api/patient-documents', (request) {
    final status = request.query['status'];
    final rows = held.values
        .where((row) => status == null || row['status'] == status)
        .toList();
    return FakeResponse.page(rows);
  });

  api.on('POST', '/api/patient-documents', (request) {
    final filename = request.formFiles['file'] ?? '';
    final original = byFile[filename];

    uploads++;
    final id = 'doc-new-$uploads';

    if (original != null) {
      // §21: a row, with a sentence, pointing at the first copy. Not a 409 and
      // not a silent no-op — the patient pressed the button and something has
      // to have happened.
      held[id] = _row(
        id: id,
        status: 'uploaded',
        message: kDuplicateMessage,
        isDuplicate: true,
        duplicateOfId: original,
        sessionId: request.formFields['sessionId'],
      );
      return FakeResponse.ok(held[id]);
    }

    byFile[filename] = id;

    if (filename == TooSmallImageSource.filename) {
      // §5. The quality check runs before OCR, so a thumbnail never reaches the
      // recogniser at all — and what comes back is a sentence about holding the
      // camera closer rather than a confidence score about the wrong
      // characters.
      held[id] = _row(
        id: id,
        status: 'rejected_quality',
        message: kTooSmallMessage,
        sessionId: request.formFields['sessionId'],
      );
      return FakeResponse.ok(held[id]);
    }

    // The pipeline is instant here. The server's own `uploaded` → `processing`
    // → `needs_review` walk is reproduced by the poll fixture below, which a
    // flow installs over this one when it wants to see the waiting screen.
    held[id] = _readable(
      id: id,
      sessionId: request.formFields['sessionId'],
    );
    return FakeResponse.ok(held[id]);
  });

  api.on('GET', '/api/patient-documents/:documentId', (request) {
    final row = held[request.pathParams['documentId']];
    return row == null
        ? FakeResponse.fail(
            404,
            'That document could not be found.',
            errorCode: 'PATIENT_DOCUMENT_NOT_FOUND',
          )
        : FakeResponse.ok(row);
  });

  api.on('GET', '/api/patient-documents/:documentId/original', (_) {
    return FakeResponse.ok({
      'url': kOriginalUrl,
      'expiresInSeconds': 300,
      'expiresAt':
          AppClock.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
      'mimeType': 'image/png',
    });
  });

  // The original itself, and unlike every other route here, not an envelope.
  //
  // `GET /api/patient-documents/:documentId/file` streams the stored object
  // back through the API with the **row's** own `Content-Type` on it
  // (`patient-documents.controller.ts` sets the header from
  // `service.streamOriginal`), because the signed URL `/original` hands out
  // names the bucket's host, which a phone cannot resolve and `Image.network`
  // would reach without a bearer token anyway. So this is the route the app
  // takes, and a fixture answering JSON here would be testing a contract the
  // server does not have.
  //
  // These are the same bytes the gallery stub hands the uploader, so the page
  // the patient is shown as evidence is the page the extraction was read out
  // of. It matters that they decode: the controller refuses an empty body as a
  // failure, and `Image.memory` on rubbish throws inside the render pass,
  // where the exception surfaces as an unrelated test failure.
  api.on('GET', '/api/patient-documents/:documentId/file', (_) {
    return FakeResponse.binary(kPrescriptionPng, contentType: 'image/png');
  });

  api.on('POST', '/api/patient-documents/:documentId/verify', (request) {
    final id = request.pathParams['documentId'] ?? '';
    final row = held[id];
    if (row == null) {
      return FakeResponse.fail(
        404,
        'That document could not be found.',
        errorCode: 'PATIENT_DOCUMENT_NOT_FOUND',
      );
    }
    if (row['status'] != 'needs_review') {
      // The server's own refusal, which is why the app hides the control
      // rather than offering it and catching this.
      return FakeResponse.fail(
        400,
        'There is nothing to confirm on this document yet.',
        errorCode: 'PATIENT_DOCUMENT_NOT_READY',
      );
    }
    held[id] = {
      ...row,
      'status': 'verified',
      'verifiedAt': AppClock.now().toIso8601String(),
      'message': 'Thank you. You have confirmed this information, and it is '
          'now part of your medical history.',
    };
    return FakeResponse.ok(held[id]);
  });
}

/// A document that is still being read, then is not.
///
/// Installed over the plain fixture by the flow that wants §28's processing
/// screen: the first read answers `processing`, every one after it answers the
/// finished row. That is the shape the poll has to cope with, and a fixture
/// that answered `needs_review` immediately would leave it untested.
void installProcessingDocumentFixture(FakeApi api) {
  var reads = 0;
  api.on('GET', '/api/patient-documents/:documentId', (request) {
    final id = request.pathParams['documentId'] ?? kReadableDocumentId;
    reads++;
    return FakeResponse.ok(
      reads <= 1
          ? _row(
              id: id,
              status: 'processing',
              message: "We're reading your document now. This usually takes "
                  'less than a minute.',
            )
          : _readable(id: id),
    );
  });
}

/// The prescription, read.
Map<String, Object?> _readable({
  String id = kReadableDocumentId,
  String? sessionId,
}) =>
    _row(
      id: id,
      status: 'needs_review',
      message: kAwaitingReviewMessage,
      sessionId: sessionId,
      docType: 'prescription',
      docTypeConfidence: 0.92,
      // Two measurements of two different things, side by side and never
      // averaged. 0.97 is what the fixtures in the backend's own suite read at.
      ocrConfidence: 0.97,
      extractionConfidence: 0.5,
      extraction: _extraction,
    );

/// The photograph that was not.
Map<String, Object?> _unreadable() => _row(
      id: kUnreadableDocumentId,
      status: 'rejected_quality',
      message: kUnreadableMessage,
      ocrConfidence: 0.21,
    );

Map<String, Object?> _row({
  required String id,
  required String status,
  required String message,
  String? sessionId,
  String? docType,
  double? docTypeConfidence,
  double? ocrConfidence,
  double? extractionConfidence,
  Map<String, Object?>? extraction,
  bool isDuplicate = false,
  String? duplicateOfId,
}) =>
    {
      'id': id,
      'patientId': 'p-1',
      'sessionId': sessionId,
      'mimeType': 'image/png',
      'byteSize': 184320,
      'pageCount': 1,
      'status': status,
      'docType': docType,
      'docTypeConfidence': docTypeConfidence,
      'ocrEngine': 'rapidocr',
      'ocrConfidence': ocrConfidence,
      'extractionConfidence': extractionConfidence,
      'extraction': extraction,
      'visionFallbackUsed': false,
      'isDuplicate': isDuplicate,
      'duplicateOfId': duplicateOfId,
      'message': message,
      'uploadedAt': AppClock.now().toIso8601String(),
      'processedAt': AppClock.now().toIso8601String(),
      'verifiedAt': null,
    };

/// The §26 envelope, in the shape `document-pipeline.service.ts` stores.
///
/// Two medicines and no allergy section — which is the case §19 is about, and
/// the reason `facts.allergies` carries a sentence rather than an empty array
/// for the client to interpret.
const Map<String, Object?> _extraction = {
  'document': {
    'type': 'prescription',
    'date': '2026-02-28',
    'facility': 'Meridian Family Medicine',
    'author': null,
  },
  'patient': {'name': 'Ifeoma Balogun', 'identifier': '10421'},
  'medications': [
    {
      'name': kGroundedMedication,
      'strength': '500 mg',
      'dose': '1 tablet',
      'frequency': 'twice a day',
      'route': 'by mouth',
      'duration': '30 days',
      'instructions': 'with food',
      'startDate': null,
      'stopDate': null,
      'uncertain': false,
    },
    {
      'name': kUncertainMedication,
      'strength': '5 mg',
      'dose': '1 tablet',
      'frequency': 'at night',
      'route': 'by mouth',
      'duration': null,
      'instructions': null,
      'startDate': null,
      'stopDate': null,
      // §12: the model saw the ambiguity and says so rather than choosing the
      // likeliest reading.
      'uncertain': true,
    },
  ],
  'investigations': <Object>[],
  'diagnosesRecorded': ['Type 2 diabetes mellitus'],
  'procedures': <Object>[],
  'followUp': ['Review in three months'],
  // Empty, and this is the whole point: the document has no allergy section.
  'allergies': <Object>[],
  'admission': null,
  'facts': {
    'allergies': {
      'presence': 'not_assessed',
      // The server's own wording. A client that rebuilt this line from the
      // presence is a client one refactor away from "No known allergies".
      'label': kAllergySilence,
      'values': <Object>[],
    },
    'medications': {
      'presence': 'recorded',
      'label': 'Recorded',
      'values': [kGroundedMedication, kUncertainMedication],
    },
    'diagnoses': {
      'presence': 'recorded',
      'label': 'Recorded',
      'values': ['Type 2 diabetes mellitus'],
    },
    'procedures': {
      'presence': 'not_assessed',
      'label': 'This document does not mention procedures',
      'values': <Object>[],
    },
    'investigations': {
      'presence': 'not_assessed',
      'label': 'This document does not include test results',
      'values': <Object>[],
    },
  },
  'sources': [
    {
      'field': 'medications[0].name',
      'value': kGroundedMedication,
      'source': 'uploaded_document',
      'documentId': kReadableDocumentId,
      'page': 1,
      'grounded': true,
      'ocrConfidence': 0.97,
      'verification': 'unverified',
    },
    {
      'field': 'medications[1].name',
      'value': kUncertainMedication,
      'source': 'uploaded_document',
      'documentId': kReadableDocumentId,
      'page': 1,
      // Not found verbatim in the page text — a recogniser dropping a
      // character, or a model filling in a name it half-recognised.
      'grounded': false,
      'ocrConfidence': 0.97,
      'verification': 'unverified',
    },
  ],
  'ungrounded': [kUncertainMedication],
  'contradictions': [
    {
      'topic': 'medications',
      'kind': 'absent_from_record',
      'documentValue': 'Metformin 500 mg',
      'recordValues': ['Amlodipine 5mg'],
      // True, so this reads as a difference rather than as a first entry.
      'recordHadEntries': true,
      'message': kContradictionMessage,
    },
  ],
  'confidence': {
    'ocr': 0.97,
    'ocrSource': 'measured',
    'extraction': 0.5,
    'extractionSource': 'derived',
  },
  'verificationStatus': 'unverified',
};

/// The photo library, answering with the prescription from the backend's own
/// fixtures.
///
/// **Not** `StubImageSource`, whose one-pixel PNG is sixty-nine bytes: the
/// server's quality check refuses an image that small with a written sentence
/// about holding the camera closer, so the placeholder could only ever
/// exercise the refusal — and an upload of sixty-nine bytes produces no
/// progress bar anybody can watch.
///
/// The filename is fixed, which is the point for §21: a second pick answers
/// with the same bytes under the same name, which is what the duplicate check
/// on the server is looking at.
class StubGalleryImageSource implements ImageSource {
  const StubGalleryImageSource();

  static const String filename = 'prescription.png';

  @override
  Future<PickedImage?> pick(ImageOrigin origin) async => PickedImage(
        bytes: kPrescriptionPng,
        filename: filename,
        mimeType: 'image/png',
      );
}

/// A page photographed from too far away.
///
/// §5's case, and the reason the quality check runs **before** OCR rather than
/// after: a recogniser handed a thumbnail comes back at plausible confidence
/// about the wrong characters, and no number downstream can separate that from
/// a good read.
class TooSmallImageSource implements ImageSource {
  const TooSmallImageSource();

  static const String filename = 'too-small.png';

  @override
  Future<PickedImage?> pick(ImageOrigin origin) async => PickedImage(
        bytes: kTooSmallPng,
        filename: filename,
        mimeType: 'image/png',
      );
}

/// A PDF, for the third way in.
///
/// `StubFileSource` answers with a CSV, which is right for the analyser import
/// it was written for and is exactly what this route refuses. This is the same
/// prescription as a PDF, out of the backend's own fixtures.
class StubPdfFileSource implements PatientDocumentFileSource {
  const StubPdfFileSource();

  static const String filename = 'prescription.pdf';

  @override
  Future<PickedFile?> pick() async => PickedFile(
        bytes: kPrescriptionPdf,
        filename: filename,
        mimeType: 'application/pdf',
      );
}

/// Somebody who opens the picker and backs out.
///
/// Null and **only** null means that, which is the contract both seams keep and
/// the reason a denied permission throws instead. A screen that treated the two
/// alike would show the person who declined the camera the same nothing it
/// shows the person who changed their mind.
class CancelledFileSource implements PatientDocumentFileSource {
  const CancelledFileSource();

  @override
  Future<PickedFile?> pick() async => null;
}

/// The device saying yes, without a system dialog nothing in a test can tap.
///
/// A permission prompt is drawn **outside** the Flutter tree, so a device test
/// that reaches one does not fail — it hangs, with nothing on screen naming the
/// cause, until the twelve-minute timeout. This is the seam that keeps the
/// prompt in the app and out of the run.
class GrantedMediaPermissions implements MediaPermissionGate {
  const GrantedMediaPermissions();

  @override
  Future<void> require(MediaPermission which) async {}
}

/// The device saying no, in the words the patient actually reads.
///
/// `MediaRefusal` is the one exception to "never show an exception to a user":
/// it is not a raw error, it is finished copy that happens to travel on the
/// error channel because `Future<T?>` leaves no other one free.
class RefusedMediaPermissions implements MediaPermissionGate {
  const RefusedMediaPermissions();

  @override
  Future<void> require(MediaPermission which) async {
    throw MediaRefusal(
      MediaAccess.refusalFor(which, PermissionStatus.denied)?.message ?? '',
    );
  }
}
