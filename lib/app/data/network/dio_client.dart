import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'endpoints.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Centralised Dio Client
///
/// The single source of truth for every HTTP call. Register once in `main()`
/// with `Get.put(DioClient())`; reach it from a service with
/// `Get.find<DioClient>()`.
///
/// ```dart
/// final client = Get.find<DioClient>();
/// final res = await client.get(Endpoints.client.list);
/// ```
///
/// Constructing a bare `Dio()` anywhere else skips the bearer header, the 401
/// teardown and the logger — see `.agents/RULES.md` §3.
/// ─────────────────────────────────────────────────────────────────────────────
class DioClient {
  /// [adapter] replaces the transport that sits *below* the interceptor chain.
  ///
  /// The e2e harness passes an in-memory router here, so `AuthInterceptor`
  /// still attaches the real bearer header and a real 401 still routes into
  /// `SessionManager` — behaviour a `DioClient` subclass would skip entirely.
  DioClient({String? baseUrl, HttpClientAdapter? adapter}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? Endpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          // The default origin is an ngrok tunnel, and ngrok's free tier
          // answers anything it judges browser-like with an HTML interstitial
          // instead of forwarding it. `Accept: application/json` usually
          // avoids that, but "usually" is the problem: when it does fire, Dio
          // receives a 200 carrying HTML and the failure surfaces as a JSON
          // parse error, which reads as a corrupt API rather than a tunnel
          // that never passed the request through. This header is ngrok's
          // documented opt-out and is inert against every other server.
          'ngrok-skip-browser-warning': 'true',
        },
        // Let every status through to the caller rather than throwing on 4xx.
        // The envelope carries a usable message on a 409 validation failure,
        // and a thrown DioException would discard it before anyone read it.
        // 401 is the exception: it must throw so AuthInterceptor.onError runs.
        validateStatus: (status) =>
            status != null && status < 500 && status != 401,
      ),
    );

    if (adapter != null) _dio.httpClientAdapter = adapter;

    _attachInterceptors();
  }

  late final Dio _dio;

  /// The raw Dio instance, for `download` and anything the helpers below do
  /// not cover.
  Dio get dio => _dio;

  /// The server this client is pointed at. Read by the splash screen's
  /// diagnostics.
  String get baseUrl => _dio.options.baseUrl;

  // ── Interceptor setup ─────────────────────────────────────────────────────
  void _attachInterceptors() {
    // Token injection and 401 handling, registered first so the logger below
    // observes the final headers.
    _dio.interceptors.add(const AuthInterceptor());

    if (kDebugMode) {
      // Debug-only: it prints request and response bodies.
      _dio.interceptors.add(const LoggingInterceptor());
    }
  }

  // ── Convenience methods ───────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    /// Bytes sent so far, for an upload with a progress bar over it. Only
    /// meaningful for a multipart or stream body.
    ProgressCallback? onSendProgress,
  }) =>
      _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
    ProgressCallback? onSendProgress,
  }) =>
      _dio.patch<T>(
        path,
        data: data,
        options: options,
        onSendProgress: onSendProgress,
      );

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.delete<T>(path, data: data, options: options);
}
