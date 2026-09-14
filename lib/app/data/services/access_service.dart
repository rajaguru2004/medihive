import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response;

import '../../core/app_clock.dart';
import '../../core/app_log.dart';
import '../models/access_map.dart';
import '../models/auth_user.dart';
import '../models/site_settings.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../utils/api_envelope.dart';
import '../utils/jwt_claims.dart';
import 'auth_service.dart';
import 'settings_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — who may see what
///
/// Holds the access map and keeps it fresh. One service rather than a field on
/// `AuthService` because it has its own lifetime: it is re-read on resume, it
/// survives a token refresh, and it is the thing a shell asks before it decides
/// which tabs exist.
///
/// [load] is the app's **only** caller of `GET /auth/me`, and that route
/// answers with three things at once — the user, their access map and their
/// organisation. Splitting them across three services would be three round
/// trips on a cold start over ward wifi, so this one call fans out: the user
/// goes to `AuthService`, the branding to `SettingsService`, the map stays
/// here.
///
/// It never throws. An app that cannot read its access map is an app that shows
/// fewer buttons; an app that crashes on launch because a permissions endpoint
/// was slow is one nobody can use at all.
/// ─────────────────────────────────────────────────────────────────────────────
class AccessService extends GetxService {
  static AccessService get to => Get.find<AccessService>();

  /// Beside `auth_token` and `auth_user`, and cleared with them.
  static const _keyAccess = 'auth_access';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _map = AccessMap.empty.obs;
  DateTime? _loadedAt;

  DioClient get _client => Get.find<DioClient>();

  AccessMap get map => _map.value;

  /// Reactive handle for a shell that rebuilds its destinations when the map
  /// changes — a role edited by an administrator takes effect on the next
  /// refresh rather than on the next reinstall.
  Rx<AccessMap> get rx => _map;

  /// When the map last came from the server. Null when it came from storage or
  /// from a token, which is what [refreshIfStale] keys on.
  DateTime? get loadedAt => _loadedAt;

  bool can(String module, AccessVerb verb) => _map.value.can(module, verb);
  bool canRead(String module) => can(module, AccessVerb.read);

  /// Whether this account can change anything in [module] — the test a form,
  /// a swipe action or a floating action button asks.
  bool canWrite(String module) => _map.value.of(module).canWrite;

  /// True when this account has a screen in this app that works at all.
  bool get isUsable => _map.value.isUsable;

  // ── Loading ───────────────────────────────────────────────────────────────

  /// Reads the persisted map, so a cold start paints the right tabs before the
  /// network answers.
  ///
  /// Never throws: unreadable storage means an empty map, which shows fewer
  /// tabs for one round trip rather than failing to launch.
  Future<void> restore() async {
    try {
      final cached = await _storage.read(key: _keyAccess);
      if (cached == null || cached.isEmpty) return;
      final decoded = jsonDecode(cached);
      if (decoded is Map) {
        _map.value = AccessMap.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (e, stack) {
      AppLog.error('AccessService', 'access restore failed', e, stack);
    }
  }

  /// Re-reads the access map, and the user and branding that travel with it.
  ///
  /// Four sources, best first. Each fallback exists because the one above it
  /// has actually failed in the field:
  ///
  ///   1. `/auth/me` — the whole picture in one round trip;
  ///   2. `/auth/me/access` — the map alone, when the first route is 500ing;
  ///   3. the token's own `permissions` claim, when the network is gone but
  ///      the session is not;
  ///   4. nothing, which shows a signed-in user a shell with no modules —
  ///      honest, and recoverable by pulling to refresh.
  Future<void> load() async {
    if (!_isAuthenticated) {
      _map.value = AccessMap.empty;
      return;
    }

    if (await _loadFromMe()) return;
    if (await _loadFromAccessRoute()) return;
    _loadFromToken();
  }

  /// Reloads when the map is older than [maxAge].
  ///
  /// Called on resume. Five minutes because the cost of being wrong is a button
  /// that 403s, not a wrong clinical figure — and re-reading permissions on
  /// every foreground is a request per glance at a ward tablet.
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final last = _loadedAt;
    if (last != null && AppClock.now().difference(last) < maxAge) return;
    await load();
  }

  /// Drops the map. Called from `SessionManager.endSession`, so the next
  /// clinician on a shared ward tablet does not inherit the previous one's
  /// modules for the frame before their own map lands.
  Future<void> clear() async {
    _map.value = AccessMap.empty;
    _loadedAt = null;
    try {
      await _storage.delete(key: _keyAccess);
    } catch (e) {
      AppLog.warn('AccessService', 'clearing stored access failed: $e');
    }
  }

  // ── The three sources ─────────────────────────────────────────────────────

  Future<bool> _loadFromMe() async {
    try {
      final response = await _client.get(Endpoints.me);
      final envelope = ApiEnvelope.of(response);
      if (!envelope.success) {
        AppLog.warn('AccessService', 'me unavailable: ${envelope.message}');
        return false;
      }

      final payload = envelope.object;
      final access = payload['access'];
      if (access is Map) {
        await _adopt(AccessMap.fromJson(access.cast<String, dynamic>()));
      }

      // The other two thirds of this response, handed to the services that own
      // them. Guarded rather than assumed: a unit test may register this
      // service alone.
      final user = AuthUser.fromMePayload(payload);
      if (!user.isEmpty && Get.isRegistered<AuthService>()) {
        await AuthService.to.updateCachedUser(user);
      }

      final organization = payload['organization'];
      if (organization is Map && Get.isRegistered<SettingsService>()) {
        SettingsService.to.adopt(
          SiteSettings.fromOrganization(organization.cast<String, dynamic>()),
        );
      }

      return access is Map;
    } catch (e, stack) {
      AppLog.warn('AccessService', 'me failed: $e');
      AppLog.debug('AccessService', stack.toString());
      return false;
    }
  }

  Future<bool> _loadFromAccessRoute() async {
    try {
      final response = await _client.get(Endpoints.meAccess);
      final envelope = ApiEnvelope.of(response);
      if (!envelope.success) return false;
      final next = AccessMap.fromJson(envelope.object);
      if (next.isEmpty) return false;
      await _adopt(next);
      return true;
    } catch (e) {
      AppLog.warn('AccessService', 'access route failed: $e');
      return false;
    }
  }

  /// The offline fallback: the token lists what it was granted.
  ///
  /// Not persisted and [loadedAt] is left null, so the next [refreshIfStale]
  /// still goes to the server. A token minted before an administrator changed
  /// a role is stale, and caching stale authority is how somebody keeps a tab
  /// they were removed from.
  void _loadFromToken() {
    final claims = JwtClaims.decode(_token);
    if (claims == null) {
      _map.value = AccessMap.empty;
      return;
    }
    _map.value = AccessMap.fromPermissions([
      ...claims.permissions,
      // `SUPER_ADMIN` is a role, not a permission, and it is the one role the
      // map reads.
      ...claims.roles,
    ]);
    AppLog.info('AccessService', 'access map rebuilt from the token');
  }

  Future<void> _adopt(AccessMap next) async {
    _map.value = next;
    _loadedAt = AppClock.now();
    try {
      await _storage.write(key: _keyAccess, value: jsonEncode(next.toJson()));
    } catch (e) {
      // A map we hold and cannot persist still works for this session.
      AppLog.warn('AccessService', 'persisting access failed: $e');
    }
  }

  bool get _isAuthenticated =>
      Get.isRegistered<AuthService>() && AuthService.to.isAuthenticated;

  String? get _token =>
      Get.isRegistered<AuthService>() ? AuthService.to.accessToken : null;
}
