import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import 'bindings/case_review_binding.dart';
import 'views/case_review_view.dart';

/// Where the finished case is read back and sent.
abstract final class CaseReviewRoutes {
  /// Singular, like every other portal path: `/patient` is *you*.
  ///
  /// No `:sessionId` in it. The screen resolves the session three ways — the
  /// argument the interview hands over, the case this device already sent, and
  /// failing both, "the interview you have open" — so a patient coming back to
  /// their dashboard reaches the right one without the phone having to carry
  /// an id in a link.
  static const String review = '/patient/review';
}

abstract final class CaseReviewPages {
  /// Gated on the verb only a patient holds — the same discriminator
  /// `PatientShell` uses. A clinician reads a finished intake through the
  /// submission on the patient record, which is what it is for; these routes
  /// refuse a staff caller on the server anyway, with a sentence saying as
  /// much.
  static List<GetMiddleware> get _portal => [
        AuthMiddleware(
          module: Modules.caseTaking,
          moduleName: 'Your answers',
          verb: AccessVerb.create,
        ),
      ];

  static List<GetPage<dynamic>> get routes => [
        GetPage<dynamic>(
          name: CaseReviewRoutes.review,
          page: () => const CaseReviewView(),
          binding: CaseReviewBinding(),
          middlewares: _portal,
          transition: Transition.cupertino,
        ),
      ];
}

/// Opening the review, from the dashboard or from the end of the interview.
///
/// `unawaited`, like every other navigation in the portal: **`await
/// Get.toNamed(...)` completes when the route is *popped***, so a controller
/// that awaits one sits in an unfinished async call for as long as the patient
/// is on the next screen.
abstract final class CaseReviewNavigation {
  /// [sessionId] is what the interview hands over when it runs out of
  /// questions. Omitted from the dashboard, where the screen resolves the open
  /// session itself.
  static void toReview({String? sessionId}) {
    unawaited(
      Get.toNamed<void>(
            CaseReviewRoutes.review,
            arguments: sessionId == null ? null : {'sessionId': sessionId},
          ) ??
          Future<void>.value(),
    );
  }
}
