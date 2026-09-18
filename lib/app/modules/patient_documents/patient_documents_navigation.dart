import 'dart:async';

import 'package:get/get.dart';

import 'document_review/controllers/document_review_controller.dart';
import 'patient_documents_routes.dart';

/// Moving between the two document screens, in one place.
///
/// Every one of these is `unawaited`, and that is the point of the file rather
/// than an aside. **`await Get.toNamed(...)` does not complete when the screen
/// opens — it completes when the route is *popped*.** A controller that awaits
/// one sits in an unfinished async call for as long as the patient is on the
/// next screen, and the `finally` it was relying on to clear an uploading flag
/// does not run until they come back. It has cost this codebase a debugging
/// session already; collecting the navigations here means it can only be got
/// wrong once.
abstract final class PatientDocumentsNavigation {
  /// From anywhere a patient can add a document.
  ///
  /// [sessionId] attaches whatever they add to an interview in progress, so
  /// the questions can stop asking what the document already answers.
  static void toDocuments({String? sessionId}) {
    unawaited(
      Get.toNamed<void>(
            PatientDocumentsRoutes.list,
            arguments: sessionId == null ? null : {'sessionId': sessionId},
          ) ??
          Future<void>.value(),
    );
  }

  /// To one document's reading.
  ///
  /// `toNamed` and not `offNamed`: back from a document belongs on the list it
  /// came from, including straight after an upload — a patient who has just
  /// sent three prescriptions wants the third one's reading on top of the two
  /// they already checked, not instead of them.
  static void toReview(String documentId) {
    unawaited(
      Get.toNamed<void>(PatientDocumentsRoutes.review(documentId)) ??
          Future<void>.value(),
    );
  }

  /// From a duplicate onto the copy that actually holds the reading.
  ///
  /// `offNamed`, and this is the one place that differs from [toReview]: the
  /// duplicate has nothing on it — no extraction, no facts, because the
  /// pipeline never ran for it — so leaving it on the stack means a back tap
  /// returns to a screen the patient has already been told is empty, and they
  /// have to press twice to reach the list. Replacing it makes back mean the
  /// list, which is where they came from.
  static void toFirstCopy(String documentId) {
    // Deleted before the jump, and this is the part that is not obvious.
    //
    // `DocumentReviewController` is registered by **type**, so the screen being
    // opened resolves the instance this screen is already using rather than
    // building a new one. `documentId` reads the route parameter live and would
    // therefore be right, but nothing would re-read it: `onReady` fires once
    // per instance, so the first copy's screen would sit there showing the
    // duplicate's `document.value` — the empty row the patient just left.
    //
    // Removing it first makes the binding's `lazyPut` build a fresh one, which
    // loads the document it was actually opened for.
    Get.delete<DocumentReviewController>(force: true);
    unawaited(
      Get.offNamed<void>(PatientDocumentsRoutes.review(documentId)) ??
          Future<void>.value(),
    );
  }
}
