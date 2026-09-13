import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../services/auth_service.dart';
import '../../services/session_manager.dart';

/// Marks a request that must not carry a bearer token and must not trigger a
/// session teardown on 401 — sign-in and token refresh.
///
/// Set via `Options(extra: {AuthInterceptor.skipAuthKey: true})`. This replaces
/// comparing `requestOptions.path` against a list of public paths, which
/// silently stops matching the moment a caller passes an absolute URL.
const String _skipAuthKey = 'skipAuth';

/// Attaches the bearer token to every outgoing request and routes 401s into
/// [SessionManager].
///
/// The token is read from [AuthService] per request rather than written onto
/// `dio.options.headers` at sign-in, so there is exactly one source of truth
/// and no way for the header to go stale after a re-auth.
class AuthInterceptor extends Interceptor {
  const AuthInterceptor();

  static const String skipAuthKey = _skipAuthKey;

  /// Options for endpoints that must be called unauthenticated.
  static Options get unauthenticated => Options(extra: {_skipAuthKey: true});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[_skipAuthKey] != true) {
      // DioClient is constructed before AuthService in main(), so the very
      // first request could land before registration.
      final token =
          Get.isRegistered<AuthService>() ? AuthService.to.accessToken : null;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthFailure = err.response?.statusCode == 401;
    final skipAuth = err.requestOptions.extra[_skipAuthKey] == true;

    if (isAuthFailure && !skipAuth && Get.isRegistered<SessionManager>()) {
      await SessionManager.to.endSession(reason: SessionEndReason.expired);
    }

    // Always propagate — callers still need to see the failure and stop their
    // own loading state.
    handler.next(err);
  }
}
