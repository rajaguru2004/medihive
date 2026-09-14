import 'package:dio/dio.dart';
// `FormData` is declared by both packages; GetX's belongs to its own HTTP
// client, which this app does not use.
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../models/drafts/patient_document_drafts.dart';
import '../models/patient_document.dart';
import '../network/endpoints.dart';
import '../services/file_picker_file_source.dart';
import '../services/file_source.dart';
import '../services/image_picker_image_source.dart';
import '../services/image_source.dart';
import '../services/media_access.dart';
import '../utils/api_envelope.dart';
import 'crud_repository.dart';

/// What the documents collection is called on the [DataBus].
///
/// A dashboard showing "you have added three documents" and a review screen
/// confirming one are two screens that both go stale on the other's write.
abstract final class PatientDocumentEntities {
  static const String documents = 'patient-documents';
}

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the patient's own documents
///
/// A [CrudRepository] for the two routes that are ordinary — list and read —
/// plus the three that are not. What is conspicuously absent is an update and
/// a delete: a document is evidence (§22), and the only write past the upload
/// is the patient saying that what was read out of it is right.
///
/// ## Three things this class is careful about
///
///   * **The field name is `file`.** `FileInterceptor('file')` reads that and
///     nothing else, so a part sent as `document` or `upload` arrives as no
///     file at all — and the route then answers with the sentence about the
///     file not being a photograph, which is a confusing thing to read when
///     you just took one.
///
///   * **The media type is stated, never inferred.** Dio types a byte part it
///     was given no type for as `application/octet-stream`, and this route's
///     `fileFilter` checks the mime rather than the filename. The seams both
///     carry the real type; this passes it through.
///
///   * **The size is refused before the send.** [DocumentUpload.isTooLarge] is
///     checked by the controller, not here, so the patient reads a sentence
///     about their photograph rather than watching ten megabytes climb over
///     clinic wifi to have the connection dropped at the far end.
/// ─────────────────────────────────────────────────────────────────────────────
class PatientDocumentsRepository extends CrudRepository<PatientDocument> {
  const PatientDocumentsRepository()
      : super(
          Endpoints.patientDocuments,
          PatientDocument.fromJson,
          PatientDocumentEntities.documents,
        );

  /// This patient's documents, newest first.
  ///
  /// No `patientId`: the route reads it off the bearer token and discards
  /// anything the query carried, which is what makes it safe to call from a
  /// screen that knows nothing about ids. No `orderBy` either — the DTO
  /// declares `orderDir` and orders by `uploadedAt` itself, and a field name
  /// it does not declare is a 400 for the whole request.
  Future<List<PatientDocument>> mine({
    String? status,
    String? sessionId,
    int limit = 50,
  }) async {
    final page = await list(
      PagedQuery(
        limit: limit,
        params: {
          if ((status ?? '').isNotEmpty) 'status': status,
          if ((sessionId ?? '').isNotEmpty) 'sessionId': sessionId,
        },
      ),
    );
    return page.items;
  }

  /// Sends a photograph or a PDF, and answers with the row it landed on.
  ///
  /// Returns **before the reading is done**, which is the server's design
  /// rather than a shortcut: a page costs about five seconds of recognition
  /// and fifteen of the extraction model, and a phone holding a multipart POST
  /// open for twenty seconds on a clinic's wifi is a request that fails for
  /// reasons that have nothing to do with the document. The row comes back at
  /// `uploaded`, and the caller polls [read] until the status leaves
  /// `processing`.
  Future<PatientDocument> send(
    DocumentUpload file, {
    PatientDocumentUploadDraft draft = const PatientDocumentUploadDraft(),
    ProgressCallback? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.filename,
        contentType: DioMediaType.parse(file.mimeType),
      ),
      ...draft.toFormFields(),
    });

    final envelope = await upload(
      Endpoints.patientDocuments.create,
      form,
      onProgress: onProgress,
    );
    return PatientDocument.fromJson(envelope.object);
  }

  /// A short-lived signed link to the original.
  ///
  /// Asked for at the moment the patient taps "See the original" and never
  /// held: the URL expires in five minutes, and one fetched at list time is
  /// one that has already stopped working by the time anybody wants it.
  Future<DocumentOriginal> original(String documentId) async {
    final response =
        await client.get(Endpoints.patientDocumentOriginal(documentId));
    return DocumentOriginal.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// The patient confirming that what was read out of this document is right.
  ///
  /// Sends **no body**. The route binds nothing from one, and under
  /// `forbidNonWhitelisted` a body with any key in it at all would be a 400 —
  /// there is no DTO for it to be whitelisted against.
  Future<PatientDocument> confirm(String documentId) =>
      action(Endpoints.patientDocumentVerify(documentId));
}

/// Asking the device for the camera or the photo library.
///
/// A seam for the same reason `ImageSource` and `FileSource` are seams: the
/// answer arrives over a platform channel, and a platform channel in a test is
/// a stub either way. It is narrower than those two, though, and the difference
/// matters — this one wraps a **system dialog**, which is drawn outside the
/// Flutter tree, so a device test that reaches it does not fail. It hangs, with
/// nothing on screen naming the cause, until the twelve-minute timeout.
///
/// `MediaAccess` stays the only thing in the app that talks to
/// `permission_handler`. This is one indirection in front of it, so that a test
/// can say "granted" or "refused" and drive both endings.
abstract interface class MediaPermissionGate {
  /// Throws a [MediaRefusal] — which carries finished copy in the patient's own
  /// register — unless [which] is granted.
  Future<void> require(MediaPermission which);
}

/// The implementation the app ships: the real prompt, through the one call site.
class DeviceMediaPermissions implements MediaPermissionGate {
  const DeviceMediaPermissions();

  @override
  Future<void> require(MediaPermission which) => MediaAccess.require(which);
}

/// The repository and the three device seams, registered once.
///
/// The **real** pickers, not the stubs — this is the first module in the app
/// where a person is actually expected to photograph something, and a seam
/// that answers every camera tap with a one-pixel PNG is a feature that looks
/// finished and is not. Registering them costs nothing at boot: neither
/// touches a platform channel until `pick` is called.
///
/// Guarded on `isRegistered` so a test can put its own in first and keep it —
/// which is how the flow tier drives the whole upload path without a method
/// channel, and how `radiology_repository.dart` and `settings_profile_binding`
/// have always let a stub stand in.
abstract final class PatientDocumentsRepositories {
  static const PatientDocumentsRepository instance =
      PatientDocumentsRepository();

  static void register() {
    if (!Get.isRegistered<ImageSource>()) {
      Get.put<ImageSource>(const ImagePickerImageSource(), permanent: true);
    }
    if (!Get.isRegistered<FileSource>()) {
      Get.put<FileSource>(const FilePickerFileSource(), permanent: true);
    }
    if (!Get.isRegistered<MediaPermissionGate>()) {
      Get.put<MediaPermissionGate>(
        const DeviceMediaPermissions(),
        permanent: true,
      );
    }
  }
}
