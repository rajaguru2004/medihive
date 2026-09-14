import 'dart:convert';

import '../../core/app_clock.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what the access token says about itself
///
/// A JWT's payload is base64url-encoded JSON that anybody holding the token can
/// read. This reads it and **verifies nothing**: no signature check, no issuer
/// check, no audience check. It is a *hint*, in exactly the sense
/// `AuthUser.permissions` is a hint — the server decides, and every screen that
/// acts on what it finds here must still handle the 401 or 403 that follows.
///
/// It earns its place twice:
///
///   * `POST /auth/login` answers with a token and **no user object**, so the
///     app has to name the person it just signed in from somewhere;
///   * a cold start holding an expired token otherwise spends a round trip
///     discovering that, tears the session down from a 401 handler, and shows
///     "your session expired" *after* painting a shell.
///
/// Never logged. The payload carries the subject's id and email.
/// ─────────────────────────────────────────────────────────────────────────────
class JwtClaims {
  const JwtClaims({
    this.sub = '',
    this.email = '',
    this.roles = const {},
    this.permissions = const {},
    this.organizationId = '',
    this.expiresAt,
  });

  /// The user's id.
  final String sub;

  final String email;

  /// Role names — `SUPER_ADMIN`, `DOCTOR`. Shown, and used to spot a super
  /// admin; never used to decide a specific action.
  final Set<String> roles;

  /// `PATIENT_READ`, `PRE_TRIAGE_CREATE`, … The fallback the access map is
  /// rebuilt from when `/auth/me` cannot be reached.
  final Set<String> permissions;

  final String organizationId;

  /// The `exp` claim, as a moment. Null when the token carries no expiry,
  /// which reads as "cannot tell" rather than "never expires".
  final DateTime? expiresAt;

  static const JwtClaims empty = JwtClaims();

  bool get isEmpty => sub.isEmpty && email.isEmpty;

  /// Whether this token is past its own expiry.
  ///
  /// Reads [AppClock] rather than `DateTime.now()` so a test can pin the moment
  /// and exercise both sides of the boundary. False when there is no `exp`:
  /// refusing to use a token because it did not say when it dies would sign
  /// out every user of a backend that stops sending the claim.
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return !AppClock.now().toUtc().isBefore(expiry);
  }

  /// Reads [token]'s payload, or null when it is not a readable JWT.
  ///
  /// Null rather than [empty] on failure, so a caller can tell "this is not a
  /// JWT" — which the e2e harness's `fake-token` is — from "this is a JWT that
  /// claims nothing".
  static JwtClaims? decode(String? token) {
    final raw = (token ?? '').trim();
    if (raw.isEmpty) return null;

    final segments = raw.split('.');
    // header.payload.signature. Anything else is not a JWT, and guessing at it
    // is how a random opaque token gets read as a set of permissions.
    if (segments.length != 3) return null;

    final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (decoded is! Map) return null;
      payload = decoded.cast<String, dynamic>();
    } catch (_) {
      // Deliberately broad and deliberately silent: a malformed token is a
      // signed-out user, not a crash on launch, and its contents must never
      // reach a log.
      return null;
    }

    return JwtClaims(
      sub: _text(payload['sub'] ?? payload['userId'] ?? payload['id']),
      email: _text(payload['email']),
      roles: _strings(payload['roles'] ?? payload['role']),
      permissions: _strings(payload['permissions']),
      organizationId: _text(payload['organizationId'] ?? payload['orgId']),
      // `exp` is seconds since the epoch, not milliseconds. Reading it as
      // milliseconds puts every expiry in January 1970 and expires every token
      // the moment it is issued.
      expiresAt: _seconds(payload['exp']),
    );
  }

  static String _text(dynamic value) => (value ?? '').toString().trim();

  static Set<String> _strings(dynamic value) {
    if (value is List) {
      return {
        for (final entry in value) _text(entry),
      }..removeWhere((entry) => entry.isEmpty);
    }
    final single = _text(value);
    return single.isEmpty ? const {} : {single};
  }

  static DateTime? _seconds(dynamic value) {
    final seconds = value is num ? value.toInt() : int.tryParse(_text(value));
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  @override
  String toString() =>
      'JwtClaims(roles: ${roles.length}, permissions: ${permissions.length}, '
      'expires: ${expiresAt?.toIso8601String() ?? 'never stated'})';
}
