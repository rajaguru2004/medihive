import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response;

import '../../core/app_log.dart';
import '../models/auth_user.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../utils/api_envelope.dart';
import '../utils/jwt_claims.dart';
import 'access_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Auth Service
///
/// Owns the session: the bearer token, the signed-in user, and the calls that
/// produce them.
///
/// The token lives in encrypted storage rather than in a static field. A
/// hospital app holds a credential that reaches patient data; a process-memory
/// token is also a token that is gone on every cold start, which is why the
/// app used to ask for a password every time it was backgrounded out.
///
/// Ending a session goes through `SessionManager`, never through
/// [clearSession] directly — see that class for why.
/// ─────────────────────────────────────────────────────────────────────────────
class AuthService extends GetxService {
  static AuthService get to => Get.find<AuthService>();

  static const _keyToken = 'auth_token';
  static const _keyRefresh = 'auth_refresh_token';
  static const _keyUser = 'auth_user';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _currentUser = Rxn<AuthUser>();
  final _accessToken = RxnString();
  String? _refreshToken;

  DioClient get _client => Get.find<DioClient>();

  bool get isAuthenticated => (_accessToken.value ?? '').isNotEmpty;
  AuthUser? get currentUser => _currentUser.value;
  String? get accessToken => _accessToken.value;

  /// The refresh token, for the re-auth path. Read rather than private
  /// because a token the app stores and cannot read is a token that cannot
  /// refresh anything.
  String? get refreshToken => _refreshToken;

  /// Reactive handle for widgets that follow the signed-in user.
  Rxn<AuthUser> get rxUser => _currentUser;

  // ── Sign-in ───────────────────────────────────────────────────────────────

  /// Exchanges a password for a token.
  ///
  /// Sent unauthenticated so that a 401 here reads as "wrong password" rather
  /// than tearing down a session the user does not have yet.
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Endpoints.login,
      data: {'email': email.trim(), 'password': password},
      options: AuthInterceptor.unauthenticated,
    );

    final envelope = ApiEnvelope.of(response).orThrow();
    final payload = envelope.object;

    final token = asAuthToken(payload);
    if (token.isEmpty) {
      // A 200 with no token is a backend contract break, not a user error.
      // Saying so plainly beats dropping the user on a blank sign-in form.
      throw const ApiException('Signed in, but the server sent no token.');
    }

    // This route answers `{accessToken, refreshToken, expiresIn, tokenType}`
    // and **no user**, so the shell has to be told who just signed in from
    // somewhere else: the token's own claims, replaced the moment
    // `AccessService.load` brings the real `/auth/me` payload back.
    final userJson = payload['user'];
    final claims = JwtClaims.decode(token);
    final user = switch ((userJson, claims)) {
      (final Map json, _) => AuthUser.fromJson(json.cast<String, dynamic>()),
      (_, final JwtClaims c) => AuthUser.fromClaims(c, fallbackEmail: email.trim()),
      _ => AuthUser(id: '', name: email.split('@').first, email: email.trim()),
    };

    await saveSession(
      user,
      token,
      refreshToken: (payload['refreshToken'] ?? payload['refresh_token'])
          ?.toString(),
    );

    // Straight on to `/auth/me`, because everything the shell needs beyond the
    // token is there: the real name, the access map that decides which tabs
    // exist, and the hospital's branding. Awaited rather than fired off —
    // painting the shell from an empty access map shows a clinician four tabs
    // and then eleven, which reads as the app changing its mind about them.
    //
    // It never throws, so a sign-in is not failed by a slow `/auth/me`.
    if (Get.isRegistered<AccessService>()) await AccessService.to.load();

    return _currentUser.value ?? user;
  }

  /// Pulls the token out of whichever shape this route answered with.
  ///
  /// The backend has used three: `accessToken` at the top level, nested under
  /// `token`, and a bare `token` string. All three still exist in the wild.
  static String asAuthToken(Map<String, dynamic> payload) {
    final direct = payload['accessToken'] ?? payload['access_token'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final nested = payload['token'];
    if (nested is Map) {
      final inner = nested['accessToken'] ?? nested['access_token'];
      if (inner != null) return inner.toString().trim();
    }
    return (nested ?? '').toString().trim();
  }

  /// Re-reads the signed-in user. Called after sign-in and on resume, so a
  /// role changed by an administrator takes effect without a reinstall.
  ///
  /// Delegates when [AccessService] is registered, which it is in the app.
  /// `/auth/me` answers with the user, their access map and their organisation
  /// together; two services each calling it is two round trips on a cold start
  /// and two places that decide what the payload means. `AccessService.load`
  /// is the one caller, and it writes the user back here.
  Future<AuthUser?> refreshCurrentUser() async {
    if (Get.isRegistered<AccessService>()) {
      await AccessService.to.load();
      return _currentUser.value;
    }

    try {
      final response = await _client.get(Endpoints.me);
      final envelope = ApiEnvelope.of(response);
      if (!envelope.success) return _currentUser.value;
      // `/auth/me` nests the user under `user` and hangs the access map and
      // the organisation beside it. `AccessService.load` is the caller that
      // uses all three; this one wants the user alone.
      final user = AuthUser.fromMePayload(envelope.object);
      if (user.isEmpty) return _currentUser.value;
      await updateCachedUser(user);
      return user;
    } catch (e, stack) {
      // A failed refresh is not a failed session: the token may still be good
      // and the cached user is still the right thing to show.
      AppLog.warn('AuthService', 'user refresh failed: $e');
      AppLog.debug('AuthService', stack.toString());
      return _currentUser.value;
    }
  }

  /// Tells the server to forget this token. Best effort — the local session is
  /// cleared either way, because a user who taps Sign out must end up signed
  /// out whatever the network is doing.
  Future<void> revokeToken() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) {
      // The route takes the refresh token in its body and rejects a request
      // without one, so there is nothing to send and nothing to revoke.
      return;
    }
    try {
      await _client.post(Endpoints.logout, data: {'refreshToken': refresh});
    } catch (e) {
      AppLog.warn('AuthService', 'token revoke failed: $e');
    }
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  /// Reads persisted credentials and restores the session on cold start.
  ///
  /// Never throws: unreadable storage means signed out, which is a screen the
  /// app already has, rather than a crash on launch.
  Future<void> tryRestoreSession() async {
    try {
      final token = await _storage.read(key: _keyToken);
      if (token == null || token.isEmpty) return;

      // A token that is already past its `exp` buys nothing: every request it
      // is attached to comes back 401, and the first one tears the session
      // down from an interceptor — after the shell has painted, so the user
      // watches their ward board appear and then vanish. Dropping it here
      // lands them on the sign-in screen directly.
      //
      // Only when the token actually says so: `decode` returns null for
      // anything that is not a readable JWT, and a session is not worth
      // discarding over a token this app could not parse.
      if (JwtClaims.decode(token)?.isExpired ?? false) {
        AppLog.info('AuthService', 'stored token had expired; signing out');
        await clearSession();
        return;
      }

      _accessToken.value = token;
      _refreshToken = await _storage.read(key: _keyRefresh);

      final cached = await _storage.read(key: _keyUser);
      if (cached != null && cached.isNotEmpty) {
        _currentUser.value =
            AuthUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
    } catch (e, stack) {
      AppLog.error('AuthService', 'session restore failed', e, stack);
      await clearSession();
    }
  }

  /// Persists the session.
  ///
  /// The bearer header is not set here: `AuthInterceptor` reads [accessToken]
  /// per request, so there is one source of truth and no stale header.
  Future<void> saveSession(
    AuthUser user,
    String token, {
    String? refreshToken,
  }) async {
    _currentUser.value = user;
    _accessToken.value = token;
    _refreshToken = refreshToken;
    await _storage.write(key: _keyToken, value: token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _keyRefresh, value: refreshToken);
    }
    await _storage.write(key: _keyUser, value: jsonEncode(user.toJson()));
  }

  Future<void> updateCachedUser(AuthUser user) async {
    _currentUser.value = user;
    await _storage.write(key: _keyUser, value: jsonEncode(user.toJson()));
  }

  /// Drops the session. **Call `SessionManager.endSession()` instead** —
  /// this leaves the app authenticated-looking with no token, and only the
  /// sign-in screen is allowed to be in that state.
  Future<void> clearSession() async {
    _currentUser.value = null;
    _accessToken.value = null;
    _refreshToken = null;
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefresh);
    await _storage.delete(key: _keyUser);
  }
}
