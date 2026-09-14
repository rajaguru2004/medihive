import 'dart:async';

import 'package:get/get.dart';

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
}
