import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../network/app_dio_client.dart';
import '../network/endpoints.dart';
import '../network/token_manager.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find();

  bool get isAuthenticated => TokenManager.isAuthenticated;

  final _dio = AppDioClient.instance;

  /// POST /api/auth/login
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
