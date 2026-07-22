import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../services/session_manager.dart';
import '../token_manager.dart';

/// Interceptor to automatically add the Authorization header
/// using the current access token from [TokenManager].
class AuthInterceptor extends Interceptor {
  const AuthInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenManager.accessToken;
    if (token != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      // Do not trigger logout when user is explicitly trying to login and credentials fail (401)
      if (!path.endsWith('/api/auth/login')) {
        Get.find<SessionManager>().handleInvalidToken();
      }
    }
    super.onError(err, handler);
  }
}
