import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response;

import '../../core/app_log.dart';
import '../models/auth_user.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../utils/api_envelope.dart';

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

    final userJson = payload['user'];
    final user = userJson is Map
        ? AuthUser.fromJson(userJson.cast<String, dynamic>())
        : AuthUser(id: '', name: email.split('@').first, email: email);

    await saveSession(
      user,
      token,
      refreshToken: (payload['refreshToken'] ?? payload['refresh_token'])
          ?.toString(),
    );
    return user;
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
  Future<AuthUser?> refreshCurrentUser() async {
    try {
      final response = await _client.get(Endpoints.me);
      final envelope = ApiEnvelope.of(response);
      if (!envelope.success) return _currentUser.value;
      final user = AuthUser.fromJson(envelope.object);
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
    try {
      await _client.post(Endpoints.logout);
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
