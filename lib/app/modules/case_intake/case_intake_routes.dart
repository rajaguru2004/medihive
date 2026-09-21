import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import 'bindings/case_intake_binding.dart';
import 'views/case_intake_view.dart';

/// Where a clinician reads an intake a patient sent in.
///
/// **Not under `/patient`.** Every path in that tree is the portal — "`/patient`
/// is *you*", as `PatientPortalRoutes` puts it — and this is the other side of
/// the same document: somebody reading a case that is not theirs, from a chart
/// they opened. Putting it there would be one wrong import away from a
/// clinician's screen being gated as a patient's.
abstract final class CaseIntakeRoutes {
  /// One submitted intake.
  ///
  /// The id is in the path rather than in `Get.arguments` so the screen
  /// survives being reopened — a clinician who left the app mid-round comes
  /// back to a link, not to a controller that happens to still be in memory.
  static const String intakePattern = '/intakes/:submissionId';

  static String intake(String submissionId) => '/intakes/$submissionId';

  /// The parameter's name, spelled once.
  ///
  /// `:submissionId` and not `:id`, mirroring the server — where the
  /// distinction is load-bearing, because `PatientSelfGuard` overwrites a
  /// param called `id` with the caller's own patient id.
  static const String submissionIdParam = 'submissionId';
}

abstract final class CaseIntakePages {
  /// Gated on `case-taking: read`, which is the grant a doctor and a nurse
  /// hold — and, deliberately, the *only* case-taking grant they hold.
  ///
  /// Not on `create`, which is the portal discriminator: a patient holds that
  /// verb and this is not their screen. Reading their own case is
  /// `CaseReviewRoutes.review`, which shows the same document without the
  /// rules that fired.
  static List<GetMiddleware> get _clinical => [
        AuthMiddleware(
          module: Modules.caseTaking,
          moduleName: 'Patient intakes',
          verb: AccessVerb.read,
        ),
      ];

  static List<GetPage<dynamic>> get routes => [
        GetPage<dynamic>(
          name: CaseIntakeRoutes.intakePattern,
          page: () => const CaseIntakeView(),
          binding: CaseIntakeBinding(),
          middlewares: _clinical,
          transition: Transition.cupertino,
        ),
      ];
}

/// Opening one intake, from the chart it is filed on.
///
/// `unawaited`, like every other navigation in this app: **`await
/// Get.toNamed(...)` completes when the route is *popped***, not when the
/// screen opens, so a caller that awaits one waits for the reader to come
/// back.
abstract final class CaseIntakeNavigation {
  static void toIntake(String submissionId) {
    unawaited(
      Get.toNamed<void>(CaseIntakeRoutes.intake(submissionId)) ??
          Future<void>.value(),
    );
  }
}
