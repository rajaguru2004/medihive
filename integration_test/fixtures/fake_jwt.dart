/// Mints the access tokens the fake server hands out.
///
/// **Unsigned, deliberately** — the header says `{"alg":"none"}` and the
/// signature segment is empty. The app never verifies one: `JwtClaims.decode`
/// base64-decodes the payload and treats what it finds as a *hint*, because
/// the server authorises every request itself. Signing here would buy the
/// suite nothing and would need a key the harness has no business holding.
///
/// It still has to be a real three-segment JWT. `JwtClaims.decode` returns null
/// for anything else, and null is how the app tells "this is not a token I can
/// read" from "this token claims nothing" — which is why the old `fake-token`
/// string exercised neither the expiry check on restore nor the claims
/// fallback in `AccessService`.
library;

import 'dart:convert';

import 'package:medihive/app/core/app_clock.dart';

import 'world_roles.dart';

/// The default life of a minted token.
///
/// A shift's length, so no flow ever trips the expiry check by accident. The
/// clock is frozen by the harness, so this is deterministic.
const Duration kFakeJwtLifetime = Duration(hours: 8);

/// Builds a token for [role], with that role's own claims.
///
/// Pass a negative [lifetime] for a token that is already past its `exp` —
/// `AuthService.tryRestoreSession` drops one of those before the shell paints,
/// which is the behaviour a cold-start-with-a-stale-session flow is about.
String fakeJwtFor(
  WorldRole role, {
  Duration lifetime = kFakeJwtLifetime,
}) =>
    fakeJwt(
      sub: role.id,
      email: role.email,
      roles: [role.roleName],
      permissions: role.permissions,
      organizationId: WorldRole.organizationId,
      lifetime: lifetime,
    );

/// Builds a token from claims given directly, for a flow that needs one the
/// seeded roles do not describe.
String fakeJwt({
  required String sub,
  required String email,
  Iterable<String> roles = const [],
  Iterable<String> permissions = const [],
  String organizationId = WorldRole.organizationId,
  Duration lifetime = kFakeJwtLifetime,
}) {
  // Every timestamp comes off `AppClock`, which the harness freezes. Wall-clock
  // time here would make the same test mint a different token on every run, and
  // an expiry test pass or fail depending on when it was started.
  final issuedAt = AppClock.now().toUtc();

  final header = _segment({'alg': 'none', 'typ': 'JWT'});
  final payload = _segment({
    'sub': sub,
    'email': email,
    'roles': roles.toList(),
    'permissions': permissions.toList(),
    'organizationId': organizationId,
    // The refresh token carries `type: 'refresh'`; a server that accepts either
    // where it means one is the bug this claim exists to make visible.
    'type': 'access',
    // Seconds since the epoch, not milliseconds — reading `exp` as
    // milliseconds puts every expiry in January 1970, which expires every token
    // the moment it is minted.
    'iat': _epochSeconds(issuedAt),
    'exp': _epochSeconds(issuedAt.add(lifetime)),
  });

  // The empty third segment is load-bearing: `JwtClaims.decode` requires
  // exactly three, and `header.payload` alone is not a JWT to it.
  return '$header.$payload.';
}

/// How long a minted token claims to last, for the `expiresIn` field of the
/// sign-in response.
int fakeJwtExpiresIn([Duration lifetime = kFakeJwtLifetime]) =>
    lifetime.inSeconds;

/// Base64url with the padding stripped, which is how a JWT is written on the
/// wire. `JwtClaims` puts it back with `base64Url.normalize`.
String _segment(Map<String, Object?> claims) =>
    base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');

int _epochSeconds(DateTime instant) =>
    instant.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
