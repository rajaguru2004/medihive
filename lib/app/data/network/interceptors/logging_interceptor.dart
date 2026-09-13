import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/app_log.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Logging Interceptor
///
/// Logs every Dio request / response / error to the debug console:
/// METHOD · URL · headers · query · request body · response body.
///
/// Debug builds only (`kDebugMode`), and zero overhead in release — the guard
/// is on the way in, so a release build does not even format the strings.
///
/// Request and response are logged **together**, on the response, so two
/// concurrent calls cannot interleave into one unreadable block. The cost is
/// that an in-flight request is invisible until it lands; a request that never
/// lands surfaces as a timeout error, which is logged.
/// ─────────────────────────────────────────────────────────────────────────────
class LoggingInterceptor extends Interceptor {
  const LoggingInterceptor();

  /// Whether a request is logged at all.
  ///
  /// Tied to [AppLog.enabled] so one switch silences the app and its HTTP
  /// traffic together — which is what the e2e harness wants: a 30-flow suite
  /// buries its own failure output under request dumps otherwise.
  static bool get _on => kDebugMode && AppLog.enabled;

  /// Bodies longer than this are truncated. A misconfigured proxy will happily
  /// return a megabyte of HTML, and `debugPrint` will happily spend a second
  /// rendering it.
  static const int maxBodyLength = 2000;

  // ── ANSI colour helpers ───────────────────────────────────────────────────
  static const _reset = '\x1B[0m';
  static const _green = '\x1B[32m';
  static const _red = '\x1B[31m';
  static const _yellow = '\x1B[33m';
  static const _bold = '\x1B[1m';

  static const _divider =
      '──────────────────────────────────────────────────────';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Wait for the response or the error, then log both together.
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_on) {
      _print(
        options: response.requestOptions,
        response: response,
        status: response.statusCode,
        isError: false,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_on) {
      _print(
        options: err.requestOptions,
        response: err.response,
        status: err.response?.statusCode,
        isError: true,
        dioError: err,
      );
    }
    handler.next(err);
  }

  void _print({
    required RequestOptions options,
    required bool isError,
    Response? response,
    int? status,
    DioException? dioError,
  }) {
    final method = options.method.toUpperCase();
    final colour =
        isError ? _red : ((status != null && status < 400) ? _green : _yellow);
    final statusStr = status?.toString() ?? 'N/A';
    final title = isError ? 'ERROR' : 'API';

    debugPrint(
      '$colour$_bold\n╔ $title [$method] [HTTP $statusStr] $_divider$_reset',
    );
    debugPrint('$colour║ URL     : ${options.uri}$_reset');

    if (options.headers.isNotEmpty) {
      debugPrint('$colour║ HEADERS :$_reset');
      options.headers.forEach((k, v) {
        // Never print the bearer token, even in debug — it ends up in logcat,
        // where anything else on the device with log access can read it, and
        // in a screen recording of a debug session.
        final value = _isSensitive(k) ? '<redacted>' : v;
        debugPrint('$colour║   $k: $value$_reset');
      });
    }

    if (options.queryParameters.isNotEmpty) {
      // Redacted the same way a body is: reverse geocoding puts the Maps key
      // in the query string, and a query string is the easiest thing in a log
      // to copy by accident.
      final query = {
        for (final entry in options.queryParameters.entries)
          entry.key: _secretKeys.contains(entry.key.toLowerCase())
              ? '<redacted>'
              : entry.value,
      };
      debugPrint('$colour║ QUERY   : $query$_reset');
    }

    if (options.data != null) {
      debugPrint('$colour║ REQ BODY:$_reset');
      debugPrint('$colour║   ${_formatBody(options.data, redact: true)}$_reset');
    }

    if (isError) {
      debugPrint('$colour║ ERR TYPE: ${dioError?.type}$_reset');
      debugPrint('$colour║ ERR MSG : ${dioError?.message}$_reset');
    }

    if (response?.data != null) {
      debugPrint('$colour║ RES BODY:$_reset');
      debugPrint('$colour║   ${_formatBody(response!.data)}$_reset');
    }

    debugPrint('$colour╚$_divider$_reset');
  }

  static bool _isSensitive(String header) => const {
        'authorization',
        'cookie',
        'set-cookie',
        'x-auth-token',
        // The site's Google Maps key, on the place-search call. Not a
        // session credential, but a billable one that anybody reading a
        // console log could spend.
        'x-goog-api-key',
      }.contains(header.toLowerCase());

  /// Keys whose values never reach the console, at any nesting depth.
  static const _secretKeys = {
    'password',
    'newpassword',
    'confirmpassword',
    'token',
    'otp',
    'accesstoken',
    'refreshtoken',
    'key',
    'resettoken',
  };

  String _formatBody(dynamic data, {bool redact = false}) {
    if (data == null) return 'null';
    final rendered = redact ? _redacted(data) : data;
    final text = rendered.toString();
    return text.length > maxBodyLength
        ? '${text.substring(0, maxBodyLength)}…'
        : text;
  }

  /// Replaces secret values in a request body before it is printed.
  ///
  /// The login body is `{email, password}` and the OTP body is `{userId, otp}`
  /// — both would otherwise print credentials in full.
  dynamic _redacted(dynamic data) {
    if (data is Map) {
      return {
        for (final entry in data.entries)
          entry.key: _secretKeys.contains(entry.key.toString().toLowerCase())
              ? '<redacted>'
              : _redacted(entry.value),
      };
    }
    if (data is List) return data.map(_redacted).toList();
    return data;
  }
}
