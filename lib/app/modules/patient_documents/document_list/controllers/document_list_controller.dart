import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/app_log.dart';
import '../../../../core/i18n/patient_text.dart';
import '../../../../data/models/drafts/patient_document_drafts.dart';
import '../../../../data/models/patient_document.dart';
import '../../../../data/repositories/patient_documents_repository.dart';
import '../../../../data/services/file_source.dart';
import '../../../../data/services/image_source.dart';
import '../../../../data/services/media_access.dart';
import '../../../../data/services/patient_document_file_source.dart';
import '../../../../data/utils/error_handler.dart';
import '../../../../data/utils/load_state.dart';
import '../../patient_documents_navigation.dart';

/// Where the patient's documents come from, as three named ways in.
///
/// Named rather than a bool pair because the refusal copy differs: somebody who
/// declines the camera is told they can attach a photo they already have, and
/// somebody who declines their photo library is told they can take a new one.
/// A screen that asked "camera or not" could not say either.
enum DocumentOrigin { camera, gallery, file }

/// Everything the patient has handed over, and the three ways to hand over
/// another.
///
/// The upload is the whole screen. Two properties of it are worth stating,
/// because both are the difference between a feature and a feature that works
/// on a clinic's wifi:
///
///  * **The size is refused before the send.** The route answers an overrun by
///    dropping the connection, so a client that does not check shows a network
///    error for a photograph that is merely too big — and the patient retakes
///    it, larger, because nobody told them the size was the problem.
///
///  * **Progress carries a figure.** A spinner with no number on it reads as a
///    hung screen, and the second tap sends the photograph twice. The server
///    would report that honestly as a duplicate, which is better than nothing
///    and still worse than not doing it.
class DocumentListController extends GetxController with LoadStateMixin {
  DocumentListController() {
    // In the initialiser rather than the binding so the pickers are present
    // however this controller was constructed — a deep link opens the route
    // with its binding, but a screen reached from the dashboard's own card
    // arrives through the same constructor and must not find `Get.find`
    // throwing before a frame has painted.
    PatientDocumentsRepositories.register();
  }

  final PatientDocumentsRepository _repository =
      PatientDocumentsRepositories.instance;

  final RxList<PatientDocument> documents = <PatientDocument>[].obs;

  /// The interview this upload belongs to, when the patient came here from one.
  ///
  /// Carried on the upload so the questions can stop asking what the document
  /// already answers. Null from the dashboard, and dropped rather than sent
  /// empty — the server checks the session belongs to this patient and answers
  /// a blank one with "That case-taking session could not be found."
  final RxnString sessionId = RxnString();

  final RxBool isUploading = false.obs;

  /// 0…1 while a send is in flight.
  final RxDouble uploadProgress = 0.0.obs;

  /// Inline and persistent, never a toast. A size refusal has to stay on
  /// screen long enough to act on, and the action is "take it again".
  final RxnString uploadError = RxnString();

  @override
  void onReady() {
    super.onReady();
    // onReady, not onInit: the first widget to touch `controller` constructs
    // it, and a write during that build marks the building `Obx` dirty.
    final arguments = Get.arguments;
    if (arguments is Map && arguments['sessionId'] != null) {
      sessionId.value = '${arguments['sessionId']}';
    }
    unawaited(reload());
  }

  /// Re-reads the list.
  ///
  /// **Not `refresh()`.** `GetxController` already declares that name and it
  /// returns void, so an `onRefresh:` wired to it silently never awaits and the
  /// spinner snaps back before the request has left.
  Future<void> reload() => runGuarded(
        () async {
          documents.value = await _repository.mine();
        },
        fallback: PatientText.couldNotLoadDocuments,
      );

  /// Asks for a photograph or a file, and sends it.
  ///
  /// One method for all three origins, because everything after the picker is
  /// identical — and two code paths through one upload is one of them getting
  /// a fix the other does not.
  Future<void> add(DocumentOrigin origin) async {
    if (isUploading.value) return;
    uploadError.value = null;

    final DocumentUpload? chosen;
    try {
      chosen = await _pick(origin);
    } on MediaRefusal catch (refusal) {
      // A refusal is **never** a null. `MediaRefusal.message` is finished copy
      // in the patient's own register and goes on screen as it is — it is the
      // narrow exception to "never show an exception to a user", because this
      // one was written for them.
      uploadError.value = refusal.message;
      return;
    } catch (e, stack) {
      // The filename is deliberately not logged: a photograph of a
      // prescription is routinely saved under the patient's own name.
      AppLog.error('$runtimeType', 'choosing a document failed', e, stack);
      uploadError.value = parseErrorMessage(e, PatientText.couldNotOpenFile);
      return;
    }

    // Null and only null is somebody looking at the picker and backing out.
    // Not a failure, and not something to say anything about.
    if (chosen == null) return;

    if (chosen.isTooLarge) {
      uploadError.value = PatientText.fileTooLarge(chosen.sizeLabel);
      return;
    }

    await _send(chosen);
  }

  Future<DocumentUpload?> _pick(DocumentOrigin origin) async {
    switch (origin) {
      case DocumentOrigin.camera:
        await Get.find<MediaPermissionGate>().require(MediaPermission.camera);
        final image = await Get.find<ImageSource>().pick(ImageOrigin.camera);
        return image == null ? null : _fromImage(image);

      case DocumentOrigin.gallery:
        await Get.find<MediaPermissionGate>()
            .require(MediaPermission.photoLibrary);
        final image = await Get.find<ImageSource>().pick(ImageOrigin.gallery);
        return image == null ? null : _fromImage(image);

      case DocumentOrigin.file:
        // No permission call. A document picker on both platforms hands back
        // exactly what was chosen and asks for nothing broader, so a prompt
        // here would be the app asking for access it does not need.
        final file = await Get.find<PatientDocumentFileSource>().pick();
        return file == null ? null : _fromFile(file);
    }
  }

  static DocumentUpload _fromImage(PickedImage image) => DocumentUpload(
        bytes: image.bytes,
        filename: image.filename,
        mimeType: image.mimeType,
      );

  static DocumentUpload _fromFile(PickedFile file) => DocumentUpload(
        bytes: file.bytes,
        filename: file.filename,
        mimeType: file.mimeType,
      );

  Future<void> _send(DocumentUpload file) async {
    isUploading.value = true;
    uploadProgress.value = 0;

    try {
      final created = await _repository.send(
        file,
        draft: PatientDocumentUploadDraft(sessionId: sessionId.value),
        onProgress: (sent, total) {
          // Dio reports a total of -1 when the length is not known. Dividing
          // by it paints a bar that runs backwards.
          uploadProgress.value =
              total <= 0 ? 0 : (sent / total).clamp(0.0, 1.0);
        },
      );

      uploadProgress.value = 1;
      await reload();

      // Straight to the reading. The row comes back at `uploaded` and the
      // pipeline runs behind it, so the next screen is the one that waits —
      // and it is also the screen that tells the patient this is the same
      // document they already sent, which is the commonest thing to happen on
      // a second tap.
      PatientDocumentsNavigation.toReview(created.id);
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'document upload failed', e, stack);
      uploadError.value =
          parseErrorMessage(e, PatientText.couldNotSendDocument);
    } finally {
      isUploading.value = false;
    }
  }

  /// Opens one document's reading.
  void open(PatientDocument document) =>
      PatientDocumentsNavigation.toReview(document.id);
}
