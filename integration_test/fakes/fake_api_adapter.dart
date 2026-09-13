import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fake_api.dart';

/// Installs [FakeApi] as Dio's transport.
///
/// Substituting the adapter rather than the client keeps the whole interceptor
/// chain live: the bearer header is attached for real, and a 401 returned here
/// produces a genuine `DioException` that `AuthInterceptor.onError` sees and
/// routes into `SessionManager` — the single most important cross-cutting
/// behaviour in the app, and one a stubbed client cannot reach.
class FakeApiAdapter implements HttpClientAdapter {
  FakeApiAdapter(this.api);

  final FakeApi api;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = await FakeRequest.capture(options, requestStream);
    final result = api.dispatch(request);

    if (result == null) {
      // 501 rather than a thrown error: the app's own error handling should
      // run so the test sees the real failure UI. `AppHarness.dispose()` is
      // what turns the missing fixture into a test failure, with the full
      // list.
      return ResponseBody.fromString(
        jsonEncode({
          'success': false,
          'data': null,
          'message': 'FakeApi: no fixture for ${request.method} ${request.path}',
        }),
        501,
        headers: _jsonHeaders,
      );
    }

    if (result.latency > Duration.zero) {
      await Future<void>.delayed(result.latency);
    }

    final response = result.response;
    if (response.bytes != null) {
      return ResponseBody.fromBytes(
        response.bytes!,
        response.status,
        headers: {
          Headers.contentTypeHeader: [response.contentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: _jsonHeaders,
    );
  }

  static const _jsonHeaders = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}
