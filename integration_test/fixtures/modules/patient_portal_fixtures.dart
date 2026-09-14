/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the patient portal, in fixtures
///
/// One patient, and she is already in this world: Ifeoma Balogun is `p-1`, she
/// is on the clinic board, she has appointments and she was recently seen. The
/// portal is her reading her own record, which is the only arrangement that
/// lets a flow walk from a clinician's view of somebody to that person's view
/// of themselves and find the same facts on both.
///
/// ## The claim route is stateful here, and it has to be
///
/// `POST /patient-auth/claim` **answers identically whether or not the MRN
/// exists**. That is the property the whole feature's copy is built around, so
/// a fixture that returned a token for the right card and a 404 for the wrong
/// one would be testing an API this backend deliberately does not have — and
/// the app's honest, non-leaking refusal copy would never be reached by
/// anything.
///
/// So this issues a token of the same shape for anything, remembers privately
/// which card it was issued against, and refuses at **activation** — 401 with
/// `PATIENT_PORTAL_CLAIM_INVALID`, which is what the live API answers,
/// verified against it. A flow can therefore drive both endings without the
/// fake ever leaking through the response the server does not leak through.
///
/// Tokens are minted per install rather than per library, so one flow's spent
/// claim is not visible to the next flow in the same file.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';
import '../fake_jwt.dart';
import '../world_roles.dart';

/// The card Ifeoma Balogun is holding. Matches `p-1` in `world.dart` — the
/// same MRN the register shows a receptionist and the same date of birth.
const String kPortalMrn = '10421';
const String kPortalDateOfBirth = '1991-04-12';

/// A card that matches nothing. Same shape as a real one, because the point of
/// the pair is that the *client* cannot tell them apart.
const String kUnknownMrn = '99999';

/// Registers every route the portal calls. Called from `World.install`.
void installPatientPortalFixtures(FakeApi api) {
  // Claim token → the card it was issued against. Private to the fake, the way
  // the real table is private to the server.
  final issued = <String, ({String mrn, String dateOfBirth})>{};
  final spent = <String>{};
  var counter = 0;

  api.on('POST', '/api/patient-auth/claim', (request) {
    final body = request.body is Map ? request.jsonBody : const {};
    // Fixed length whatever was asked for. A token whose length varied with
    // whether the record existed would be exactly the oracle the route was
    // designed to close, and a client could read it.
    final token = 'claim-${(counter++).toString().padLeft(38, '0')}';
    issued[token] = (
      mrn: '${body['mrn'] ?? ''}',
      dateOfBirth: '${body['dateOfBirth'] ?? ''}',
    );

    final expiresAt = AppClock.now().toUtc().add(const Duration(minutes: 10));
    return FakeResponse.ok({
      'claimToken': token,
      'expiresAt': expiresAt.toIso8601String(),
      'expiresInSeconds': 600,
    });
  });

  api.on('POST', '/api/patient-auth/activate', (request) {
    final body = request.body is Map ? request.jsonBody : const {};
    final token = '${body['claimToken'] ?? ''}';
    final card = issued[token];

    // Every refusal is a 401 with one of the claim error codes, which is what
    // the live API answers — checked against it. The app must show the same
    // sentence for all of them.
    if (card == null || spent.contains(token)) {
      return FakeResponse.fail(
        401,
        'That link is no longer valid. Please start again.',
        errorCode: spent.contains(token)
            ? 'PATIENT_PORTAL_CLAIM_CONSUMED'
            : 'PATIENT_PORTAL_CLAIM_INVALID',
      );
    }
    // Matched on the record number, and on the date of birth being *present*
    // rather than on its value.
    //
    // The server matches both exactly and the app sends both — `dateOfBirth`
    // as a calendar day, which `write_contract_test.dart` pins, because
    // converting it to UTC first moves it back a day in a UTC+ zone. Demanding
    // the exact day here as well would buy nothing and cost every flow: the
    // field opens a Material calendar, so reaching 1991 from a frozen clock in
    // 2026 means driving a date picker back through four hundred months, which
    // tests the picker and not the portal.
    if (card.mrn != kPortalMrn || card.dateOfBirth.isEmpty) {
      return FakeResponse.fail(
        401,
        'That link is no longer valid. Please start again.',
        errorCode: 'PATIENT_PORTAL_CLAIM_INVALID',
      );
    }

    spent.add(token);

    // The ordinary token pair and **no user**, exactly as `/auth/login`
    // answers. A fixture that sent a user here would skip the path the app
    // actually takes — naming the person from the token's own claims and then
    // replacing them from `/auth/me`.
    return FakeResponse.ok({
      'accessToken': fakeJwtFor(WorldRole.patient),
      'refreshToken': 'fake-refresh-token',
      'expiresIn': kFakeJwtLifetime.inSeconds,
      'tokenType': 'Bearer',
    });
  });

  // The caller's own record and portal state. No query is honoured, because
  // the route honours none: `PatientSelfGuard` discards any id the caller
  // sends and reads the `patientId` on the bearer token.
  api.on('GET', '/api/patient-auth/me', (_) => FakeResponse.ok(_portalState));
}

/// `GET /api/patient-auth/me`, in the shape `PatientPortalStateResponseDto`
/// declares — a narrow projection of the record, plus whether it has a login.
const Map<String, Object?> _portalState = {
  'patient': {
    'id': 'p-1',
    'mrn': kPortalMrn,
    'firstName': 'Ifeoma',
    'middleName': null,
    'lastName': 'Balogun',
    'dateOfBirth': '${kPortalDateOfBirth}T00:00:00.000Z',
    'gender': 'Female',
    'bloodGroup': 'O+',
    'phonePrimary': '+44 7700 900121',
    'email': 'i.balogun@example.org',
  },
  'portal': {
    'isLinked': true,
    'userId': 'u-10',
    'email': 'i.balogun@example.org',
    // Null even on a linked record: the live seed links the demo patient
    // without a claim being spent, and a screen that read this as "is this
    // claimed" would get it wrong. `isLinked` is the test.
    'activatedAt': null,
  },
};
