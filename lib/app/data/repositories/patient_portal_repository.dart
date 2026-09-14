import 'package:get/get.dart' hide Response;

import '../models/appointment_model.dart';
import '../models/auth_user.dart';
import '../models/drafts/patient_portal_drafts.dart';
import '../models/patient_portal_state.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../services/access_service.dart';
import '../services/auth_service.dart';
import '../utils/api_envelope.dart';
import '../utils/jwt_claims.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the patient's side of the API
///
/// Not a [CrudRepository]: there is no collection here. Three of these four
/// calls are the patient's own identity — claim it, activate it, read it — and
/// the fourth is the one staff collection a portal account is granted, asked
/// for **only its own rows**.
///
/// That last point is the important one. `GET /api/appointments` is a staff
/// route, and asked without a `patientId` it answers with *every* appointment
/// the hospital has today — checked against the live API, not assumed. A
/// portal account holds `APPOINTMENT_READ`, so the request succeeds. The
/// scoping is therefore the app's to get right on this route, and [myAppointments]
/// is the only place in the portal allowed to ask it.
/// ─────────────────────────────────────────────────────────────────────────────
class PatientPortalRepository {
  const PatientPortalRepository();

  DioClient get _client => Get.find<DioClient>();

  // ── Getting in ────────────────────────────────────────────────────────────

  /// Exchanges an MRN and a date of birth for a short-lived claim token.
  ///
  /// Sent unauthenticated, like sign-in, so a 401 reads as a refusal of these
  /// details rather than as an expired session being torn down.
  ///
  /// **This never fails for an MRN that does not exist.** The server issues a
  /// token of the same shape and lifetime either way, deliberately, so that a
  /// script cannot use this route to find out which record numbers are real.
  /// The refusal, if there is one, arrives at [activate].
  Future<PatientClaim> claim(PatientClaimDraft draft) async {
    final response = await _client.post(
      Endpoints.patientClaim,
      data: draft.toCreateJson(),
      options: AuthInterceptor.unauthenticated,
    );
    return PatientClaim.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// Spends the claim token: sets a password and signs the patient in.
  ///
  /// Answers with the ordinary token pair and **no user**, exactly as
  /// `POST /auth/login` does, so the session is adopted the same way — see
  /// [_adoptSession].
  Future<AuthUser> activate(PatientActivationDraft draft) async {
    final response = await _client.post(
      Endpoints.patientActivate,
      data: draft.toCreateJson(),
      options: AuthInterceptor.unauthenticated,
    );
    return _adoptSession(ApiEnvelope.of(response).orThrow().object);
  }

  /// Puts a freshly minted token pair into the session.
  ///
  /// Mirrors the tail of `AuthService.signIn`, and for the same reasons: this
  /// route sends no user, so the person is named from the token's own claims
  /// and replaced the moment `AccessService.load` brings `/auth/me` back.
  /// `load` is awaited rather than fired off because the access map is what
  /// decides which shell this account lands in, and a landing resolved from an
  /// empty map puts a patient in the staff one for a frame.
  Future<AuthUser> _adoptSession(Map<String, dynamic> payload) async {
    final token = AuthService.asAuthToken(payload);
    if (token.isEmpty) {
      // A 200 with no token is a backend contract break, not a user error.
      throw const ApiException('Your account was set up, but the server sent '
          'no sign-in. Try signing in with your email and new password.');
    }

    final claims = JwtClaims.decode(token);
    final user = claims == null
        ? const AuthUser(id: '', name: '', email: '')
        : AuthUser.fromClaims(claims);

    await AuthService.to.saveSession(
      user,
      token,
      refreshToken:
          (payload['refreshToken'] ?? payload['refresh_token'])?.toString(),
    );

    if (Get.isRegistered<AccessService>()) await AccessService.to.load();
    return AuthService.to.currentUser ?? user;
  }

  // ── Once they are in ──────────────────────────────────────────────────────

  /// The caller's own record and portal state.
  ///
  /// No parameters: the route reads the `patientId` on the bearer token and
  /// discards anything else, which is what makes it safe to call from a screen
  /// that knows nothing about ids.
  Future<PatientPortalState> portalState() async {
    final response = await _client.get(Endpoints.patientPortalMe);
    return PatientPortalState.fromJson(
      ApiEnvelope.of(response).orThrow().object,
    );
  }

  /// One patient's appointments, newest first.
  ///
  /// `patientId` is not optional here in any sense that matters — see the note
  /// at the top of this class. `AppointmentQueryDto` declares `page`, `limit`
  /// and `patientId`; it declares no ordering, so sending `orderBy` would be a
  /// 400 for the whole request. That is why this builds its own parameter map
  /// rather than going through `PagedQuery`.
  Future<List<AppointmentModel>> myAppointments(String patientId) async {
    final response = await _client.get(
      Endpoints.appointments.list,
      queryParameters: {'patientId': patientId, 'page': 1, 'limit': 50},
    );
    return ApiEnvelope.of(response)
        .orThrow()
        .listOf(AppointmentModel.fromJson);
  }
}
