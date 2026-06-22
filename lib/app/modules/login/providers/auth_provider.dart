import 'package:dio/dio.dart';

import '../../../network/app_dio_client.dart';
import '../../../network/endpoints.dart';

class AuthProvider {
  final _dio = AppDioClient.instance;

  /// POST /api/auth/login
  /// Returns the full response data map on success.
  /// Throws [DioException] on failure — caller handles UX.
  Future<Response> login({
    required String email,
    required String password,
  }) =>
      _dio.post(
        Endpoints.login,
        data: {'email': email, 'password': password},
      );

  /// GET /api/auth/me/access
  Future<Response> getMyAccess(String accessToken) => _dio.get(
        Endpoints.meAccess,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
}
