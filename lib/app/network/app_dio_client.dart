import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'interceptors/app_log_interceptor.dart';
import 'interceptors/auth_interceptor.dart';

/// Singleton Dio instance for the entire MediHive app.
///
/// Usage (in any provider / repository):
///   final _dio = AppDioClient.instance;
///   final response = await _dio.get('/patients');
///
/// Base URL, timeouts, and headers are configured here once.
/// All interceptors (logging, auth, error) are registered here.
class AppDioClient {
  AppDioClient._();

  static Dio? _instance;

  static Dio get instance {
    _instance ??= _create();
    return _instance!;
  }

  /// Call once in main() or a binding if you need to reset / reconfigure.
  static void reset() => _instance = null;

  // ─── Factory ──────────────────────────────────────────────────────────────
  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.medhive.skillhiveinnovations.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    _addInterceptors(dio);
    return dio;
  }

  static void _addInterceptors(Dio dio) {
    // 1. Custom structured logger (always first)
    dio.interceptors.add(const AppLogInterceptor());

    // 2. pretty_dio_logger — rich colorized output in debug only
    if (kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: false,
          maxWidth: 100,
          // Filter out health-check pings from logs
          filter: (options, args) =>
              !options.path.contains('/health'),
        ),
      );
    }

    // 3. Auth interceptor — add token injection here
    dio.interceptors.add(const AuthInterceptor());

    // 4. Retry / error interceptor placeholder
    // dio.interceptors.add(RetryInterceptor(dio));
  }
}
