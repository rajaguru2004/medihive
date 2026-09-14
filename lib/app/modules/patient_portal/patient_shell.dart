import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../data/services/access_service.dart';
import '../../routes/app_pages.dart';
import 'patient_portal_routes.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — which shell an account belongs in
///
/// This app now has two. The staff shell is a ward board with a tab bar;
/// the portal is one patient's own screen. Landing in the wrong one is not a
/// cosmetic error: a patient dropped into the staff shell is shown a Clinic
/// tab listing every appointment in the hospital, and `GET /api/appointments`
/// really does answer that request for a portal account — checked against the
/// live API. The staff shell has no idea it is being read by a patient.
///
/// ## Why this reads the access map and not the role name
///
/// `.agents/RULES.md` §0.1 is explicit, and `ShellLayout.resolve` already
/// works this way: roles are customisable in this product, so a hospital can
/// define `TRIAGE_NURSE`, or rename `PATIENT`, or run the portal from a role
/// called something else entirely. A test on `role == 'PATIENT'` breaks the
/// first time any of that happens, and it breaks *silently* — the account
/// still signs in, it just signs in to the wrong app.
///
/// ## What the map actually says
///
/// A portal account's map, from the live API:
///
/// ```text
/// appointments        CR
/// dashboard           R
/// case-taking         CRU
/// patient-documents   CRU
/// everything else     ----      (present as keys, every flag false)
/// ```
///
/// Two facts in there separate it from every staff account, and [isPortalAccount]
/// asks for both:
///
///  1. **It can create a case-taking record.** Only the portal role is granted
///     that verb. A doctor and a nurse hold `CASE_TAKING_READ` — they read the
///     intake a patient wrote — and deliberately nothing more, because an
///     intake a clinician can rewrite stops being evidence of what the patient
///     said. The server agrees from the other side: `@PatientScope()` resolves
///     the write against the `patientId` on the bearer token, so the verb is
///     inert for anybody who is not a patient.
///
///  2. **The patient register is closed to it.** `patients: read` is the first
///     thing every staff role in the seed is granted, custom ones included,
///     because a clinician who cannot look a patient up cannot do their job.
///     An account that can file its own history and cannot read anybody else's
///     record is the person, not the hospital.
///
/// Neither on its own is enough. A super admin holds every verb in the
/// catalogue including the first, which is why the flag is checked before
/// anything else; and the second is a property half the app's error states
/// share, so it cannot carry the decision alone.
///
/// ## Where it is asked
///
/// Three places, and they are the three ways into an authenticated session:
/// sign-in (`LoginController`), a cold start on a restored token
/// (`SplashController`), and any other arrival at `/home` — a deep link, the
/// unknown-route screen's way out, a signed-in user hitting `/login` — which
/// [PatientShellMiddleware] catches at the route itself. The first two mean
/// the staff shell is never built for a patient at all; the third is the net
/// underneath.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class PatientShell {
  /// True when this account is a patient reading their own record.
  ///
  /// Conservative by construction: an empty or half-loaded map answers false,
  /// which lands on the staff shell — the behaviour every build before this
  /// one had. A wrong answer in that direction is a screen a clinician can
  /// still navigate out of. The other direction locks somebody out of the ward
  /// board they are standing in front of.
  static bool isPortalAccount(AccessMap access) {
    if (access.isSuperAdmin) return false;
    if (!access.can(Modules.caseTaking, AccessVerb.create)) return false;
    return !access.can(Modules.patients, AccessVerb.read);
  }

  /// Where this account's session opens.
  static String landingRoute(AccessMap access) =>
      isPortalAccount(access) ? PatientPortalRoutes.dashboard : Routes.HOME;

  /// The same question, asked of the live access map.
  ///
  /// Guarded on registration so a unit test or a screenshot harness that has
  /// not put the service up gets "no" rather than an exception.
  static String get currentLanding => Get.isRegistered<AccessService>()
      ? landingRoute(AccessService.to.map)
      : Routes.HOME;
}

/// Keeps a patient off the staff shell however they arrived at it.
///
/// Sits on the `/home` page beside its `AuthMiddleware`. The two entry points
/// that matter — sign-in and a cold start — resolve the landing for
/// themselves and never push `/home` at all, so in normal use this never
/// fires. It is here for the ways in that bypass both: a deep link, a shortcut
/// saved before the account was claimed, `GuestMiddleware` bouncing a
/// signed-in user off `/login`, and the unknown-route screen's "Go to today".
///
/// Every one of those is a `const RouteSettings(name: Routes.HOME)` written
/// somewhere that has no idea two shells exist, and chasing them individually
/// is how one gets missed.
class PatientShellMiddleware extends GetMiddleware {
  PatientShellMiddleware();

  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AccessService>()) return null;
    if (!PatientShell.isPortalAccount(AccessService.to.map)) return null;
    return const RouteSettings(name: PatientPortalRoutes.dashboard);
  }
}
