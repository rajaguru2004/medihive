import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import 'document_list/bindings/document_list_binding.dart';
import 'document_list/views/document_list_view.dart';
import 'document_review/bindings/document_review_binding.dart';
import 'document_review/views/document_review_view.dart';

/// Route names for the patient's own documents.
///
/// Under `/patient` because these are portal screens: a person reading what
/// they themselves handed over. `/patients/...` is the staff register, and the
/// one-letter difference between the two is why `PatientPortalRoutes` exists
/// under that name rather than as a second `PatientRoutes`.
abstract final class PatientDocumentsRoutes {
  /// Everything they have added, and the three ways to add another.
  static const String list = '/patient/documents';

  /// One document, and what was read out of it.
  ///
  /// The id is in the path rather than in `Get.arguments` so that the screen
  /// survives being reopened — a patient who left the app while a document was
  /// being read comes back to a notification-shaped deep link, not to a
  /// controller that still happens to be in memory.
  static const String reviewPattern = '/patient/documents/:documentId';

  static String review(String documentId) => '/patient/documents/$documentId';

  /// The parameter's name, read by the controller.
  ///
  /// Spelled once. `:documentId` rather than `:id` mirrors the server, where
  /// the distinction is load-bearing — `PatientSelfGuard` overwrites a param
  /// called `id` with the caller's own patient id, which made every one of
  /// these routes answer its own owner with "not found".
  static const String documentIdParam = 'documentId';
}

/// The two document pages, ready to splice into the app's table.
///
/// **Registration order is load-bearing here**, unlike the rest of the portal:
/// GetX answers with the first pattern that matches, so the literal `list`
/// goes before the parameterised review or `/patient/documents` opens as a
/// document whose id is the empty string.
abstract final class PatientDocumentsPages {
  /// Gated on the verb only a patient holds.
  ///
  /// Not on `patient-documents: create`, which several staff roles also hold —
  /// a receptionist may scan a referral letter on somebody's behalf, and these
  /// screens are not where they would do it. `case-taking: create` is the
  /// discriminator `PatientShell` uses for exactly this reason: it is the one
  /// grant that means "this account is a person filing their own history".
  ///
  /// A staff member who deep-links here lands on the refusal screen rather
  /// than on a list whose every request comes back "Say which patient this
  /// document belongs to."
  static List<GetMiddleware> get _portal => [
        AuthMiddleware(
          module: Modules.caseTaking,
          moduleName: 'Your documents',
          verb: AccessVerb.create,
        ),
      ];

  static List<GetPage<dynamic>> get routes => [
        GetPage<dynamic>(
          name: PatientDocumentsRoutes.list,
          page: () => const DocumentListView(),
          binding: DocumentListBinding(),
          middlewares: _portal,
          transition: Transition.cupertino,
        ),
        GetPage<dynamic>(
          name: PatientDocumentsRoutes.reviewPattern,
          page: () => const DocumentReviewView(),
          binding: DocumentReviewBinding(),
          middlewares: _portal,
          transition: Transition.cupertino,
        ),
      ];
}
