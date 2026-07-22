import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';

/// Logs every request URL + headers + body and every response/error body
/// to the Flutter debug console.  Active **only** in debug builds.
///
/// Registered automatically by [AppDioClient].
class AppLogInterceptor extends Interceptor {
  const AppLogInterceptor();

  // ─── Request ──────────────────────────────────────────────────────────────
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('\n╔══════════════════════════════════════════════');
      debugPrint('║  ➤ REQUEST');
      debugPrint('║  Method : ${options.method}');
      debugPrint('║  URL    : ${options.uri}');
      _printHeaders(options.headers);
      _printBody('Body', options.data);
      _printBody('Query', options.queryParameters);
      debugPrint('╚══════════════════════════════════════════════\n');
    }
    super.onRequest(options, handler);
  }

  // ─── Response ─────────────────────────────────────────────────────────────
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('\n╔══════════════════════════════════════════════');
      debugPrint('║  ✅ RESPONSE');
      debugPrint(
          '║  Status : ${response.statusCode} ${response.statusMessage}');
      debugPrint('║  URL    : ${response.requestOptions.uri}');
      _printBody('Data', response.data);
      debugPrint('╚══════════════════════════════════════════════\n');
    }
    super.onResponse(response, handler);
  }

  // ─── Error ────────────────────────────────────────────────────────────────
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('\n╔══════════════════════════════════════════════');
      debugPrint('║  ❌ ERROR');
      debugPrint('║  Type   : ${err.type}');
      debugPrint('║  URL    : ${err.requestOptions.uri}');
      debugPrint('║  Status : ${err.response?.statusCode}');
      debugPrint('║  Message: ${err.message}');
      _printBody('Error Body', err.response?.data);
      debugPrint('╚══════════════════════════════════════════════\n');
    }
    super.onError(err, handler);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _printHeaders(Map<String, dynamic> headers) {
    if (headers.isEmpty) return;
    debugPrint('║  Headers:');
    headers.forEach((k, v) => debugPrint('║    $k: $v'));
  }

  void _printBody(String label, dynamic body) {
    if (body == null) return;
    final raw = body.toString();
    if (raw.isEmpty || raw == '{}' || raw == '[]') return;
    // Chunk long bodies so Android logcat doesn't truncate
    const chunkSize = 800;
    debugPrint('║  $label:');
    for (var i = 0; i < raw.length; i += chunkSize) {
      debugPrint(
        '║    ${raw.substring(i, i + chunkSize > raw.length ? raw.length : i + chunkSize)}',
      );
    }
  }
}
