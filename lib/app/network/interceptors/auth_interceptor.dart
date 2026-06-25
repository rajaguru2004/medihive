import 'package:dio/dio.dart';
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
}
