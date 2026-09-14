import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import 'patient_activate/bindings/patient_activate_binding.dart';
import 'patient_activate/views/patient_activate_view.dart';
import 'patient_case_pending/views/patient_case_pending_view.dart';
import 'patient_claim/bindings/patient_claim_binding.dart';
import 'patient_claim/views/patient_claim_view.dart';
import 'patient_consent/bindings/patient_consent_binding.dart';
import 'patient_consent/views/patient_consent_view.dart';
import 'patient_dashboard/bindings/patient_dashboard_binding.dart';
import 'patient_dashboard/views/patient_dashboard_view.dart';
import 'patient_language/bindings/patient_language_binding.dart';
import 'patient_language/views/patient_language_view.dart';

/// Route names for the patient portal.
///
/// **Not `PatientRoutes`.** That name is taken by `modules/patients/`, which is
/// the staff-facing register — `/patients/record` is a clinician reading
/// somebody else's chart, and `/patient` is a person reading their own. Two
/// classes called the same thing, one plural route away from each other, is a
/// wrong import nobody would notice in review.
///
/// Every path here is singular for that reason too: `/patient` is *you*.
abstract final class PatientPortalRoutes {
  /// Where a portal account's session opens. See `PatientShell`.
  static const String dashboard = '/patient';

  /// Choosing a language, then consenting. The two answers the interview needs
  /// before it can create a case session.
  static const String language = '/patient/language';
  static const String consent = '/patient/consent';

  /// The interview itself, which the case-taking phase owns.
  static const String caseTaking = '/patient/case';

  /// Getting in: a hospital card, then a password. Both are **public** — they
  /// are how somebody with no account gets one — so neither carries
  /// `AuthMiddleware`.
  static const String claim = '/patient/claim';
  static const String activate = '/patient/activate';
}

/// The portal's seven pages, ready to splice into the app's own table with one
/// line.
///
/// Two things travel with them:
///
///   * **Registration order is not load-bearing here**, unusually. Nothing in
///     this table takes a `:id`, so there is no parameterised pattern for a
///     literal sibling to be swallowed by — the trap `LabPages` and the
///     appointment routes each document. A route added later that does take
///     one goes *after* the literals, not before.
///
///   * **What each one is gated on.** The five signed-in screens ask for
///     `case-taking: create`, which is the verb only a patient holds — see
///     `PatientShell` for why that is the discriminator. Gating them on
///     `case-taking: read` instead would let a doctor and a nurse in, because
///     they are granted the read so they can see what a patient wrote.
abstract final class PatientPortalPages {
  /// What a portal screen needs: a session, and an account that is a patient.
  ///
  /// A staff member who deep-links here lands on the refusal screen rather
  /// than on a dashboard whose every request would come back 403 — which is
  /// the same rule the staff modules follow, pointed the other way.
  static List<GetMiddleware> get _portal => [
        AuthMiddleware(
          module: Modules.caseTaking,
          moduleName: 'Your health record',
          verb: AccessVerb.create,
        ),
      ];

  static List<GetPage<dynamic>> get routes => [
        GetPage<dynamic>(
          name: PatientPortalRoutes.dashboard,
          page: () => const PatientDashboardView(),
          binding: PatientDashboardBinding(),
          middlewares: _portal,
          transition: Transition.cupertino,
        ),
        GetPage<dynamic>(
          name: PatientPortalRoutes.language,
          page: () => const PatientLanguageView(),
          binding: PatientLanguageBinding(),
          middlewares: _portal,
          transition: Transition.cupertino,
        ),
        GetPage<dynamic>(
          name: PatientPortalRoutes.consent,
          page: () => const PatientConsentView(),
          binding: PatientConsentBinding(),
          middlewares: _portal,
          transition: Transition.cupertino,
        ),

        // The seam the interview lands on.
        //
        // The entry sequence has to end somewhere a patient can read, and
        // `/not-found` is not it. This screen says what happens next and gives
        // them their dashboard back; the case-taking phase replaces the one
        // `page:` builder below with its own view and deletes the file. The
        // route name, the middleware and the arguments it is handed
        // (`PatientEntry`) are already what that phase needs.
        GetPage<dynamic>(
          name: PatientPortalRoutes.caseTaking,
          page: () => const PatientCasePendingView(),
          middlewares: _portal,
          transition: Transition.cupertino,
        ),

        // ── Public ────────────────────────────────────────────────────────
        //
        // No middleware at all, and deliberately not `GuestMiddleware` either:
        // that one bounces a signed-in user to `/home`, which for a patient
        // who tapped the wrong thing would be the staff shell. Somebody who is
        // already signed in and opens Claim simply sees the form; claiming a
        // second record is refused by the server, which is where that decision
        // belongs.
        GetPage<dynamic>(
          name: PatientPortalRoutes.claim,
          page: () => const PatientClaimView(),
          binding: PatientClaimBinding(),
          transition: Transition.cupertino,
        ),
        GetPage<dynamic>(
          name: PatientPortalRoutes.activate,
          page: () => const PatientActivateView(),
          binding: PatientActivateBinding(),
          transition: Transition.cupertino,
        ),
      ];
}
