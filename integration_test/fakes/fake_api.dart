/// An in-memory HTTP router that answers the app's requests during a flow test.
///
/// This is deliberately *not* a `DioClient` subclass. It is installed as an
/// `HttpClientAdapter` (see `fake_api_adapter.dart`), which sits **below**
/// Dio's interceptor chain — so `AuthInterceptor` attaches the real bearer
/// header, real `DioException`s carry real status codes into
/// `parseErrorMessage`, and a 401 still routes into `SessionManager`.
/// Subclassing `DioClient` skips all of that, and misses `put`/`patch`/
/// `delete`/`dio.download` besides.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef FakeHandler = FakeResponse Function(FakeRequest request);

/// One request the app made, as the fake saw it.
class FakeRequest {
  FakeRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
    this.pathParams = const {},
  });

  final String method;
  final Uri uri;
  final Map<String, dynamic> headers;

  /// Decoded JSON for a JSON body, a [FormDataSnapshot] for a multipart
  /// upload, the raw string when it is neither, or null for a bodyless
  /// request.
  final Object? body;

  /// Values captured from a `:name` segment in the matched route pattern.
  final Map<String, String> pathParams;

  String get path => uri.path;
  Map<String, String> get query => uri.queryParameters;

  /// Whether `AuthInterceptor` attached a bearer token to this request.
  ///
  /// Sign-in must be false here — it is sent with
  /// `AuthInterceptor.unauthenticated` so a 401 reads as "wrong password"
  /// rather than "expired session".
  bool get isAuthenticated {
    final auth = headers['authorization'] ?? headers['Authorization'];
    return auth != null && auth.toString().startsWith('Bearer ');
  }

  Map<String, dynamic> get jsonBody => (body as Map).cast<String, dynamic>();

  /// The text fields of a multipart body.
  ///
  /// Empty for a JSON request, so an assertion about an upload route reads the
  /// same whether or not a file came with it.
  Map<String, String> get formFields =>
      body is FormDataSnapshot ? (body as FormDataSnapshot).fields : const {};

  /// The filenames of a multipart body, by field name.
  Map<String, String> get formFiles =>
      body is FormDataSnapshot ? (body as FormDataSnapshot).files : const {};

  @override
  String toString() => '$method ${uri.path}';

  static Future<FakeRequest> capture(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    Object? body;
    if (options.data is FormData) {
      body = FormDataSnapshot.of(options.data as FormData);
    } else if (requestStream != null) {
      final chunks = await requestStream.toList();
      final bytes = chunks.expand((c) => c).toList();
      if (bytes.isNotEmpty) {
        final text = utf8.decode(bytes, allowMalformed: true);
        try {
          body = jsonDecode(text);
        } catch (_) {
          body = text;
        }
      }
    }
    return FakeRequest(
      method: options.method.toUpperCase(),
      uri: options.uri,
      headers: Map<String, dynamic>.from(options.headers),
      body: body,
    );
  }

  FakeRequest withPathParams(Map<String, String> params) => FakeRequest(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
        pathParams: params,
      );
}

/// The inspectable parts of a multipart upload, so an attachment flow can
/// assert what was sent without reconstructing the wire format.
class FormDataSnapshot {
  FormDataSnapshot(this.fields, this.files);

  final Map<String, String> fields;

  /// Field name to uploaded filename.
  final Map<String, String> files;

  static FormDataSnapshot of(FormData data) => FormDataSnapshot(
        {for (final e in data.fields) e.key: e.value},
        {for (final e in data.files) e.key: e.value.filename ?? ''},
      );

  @override
  String toString() => 'FormData(fields: $fields, files: $files)';
}

class FakeResponse {
  const FakeResponse(
    this.status,
    this.body, {
    this.latency = Duration.zero,
    this.bytes,
    this.contentType = Headers.jsonContentType,
  });

  /// The `{success, data, message}` envelope this backend sends.
  ///
  /// `data`, not `result`: `result` is a legacy key `ApiEnvelope` still
  /// tolerates, and a fixture written in the tolerated dialect tests the
  /// tolerance rather than the contract.
  factory FakeResponse.ok(Object? result, {String message = ''}) =>
      FakeResponse(200, {
        'success': true,
        'data': result,
        'message': message,
      });

  /// A paged collection, as the list routes answer.
  ///
  /// The rows sit one level deeper, under `data.data`, which is the shape
  /// every list controller in this app unwraps. Registering a bare list where
  /// the app expects a page is how a fixture passes its own test and the
  /// screen stays empty.
  ///
  /// The `meta` block carries **both** dialects, because the queue does.
  ///
  /// Most routes answer `{page, limit, total, totalPages, hasNextPage,
  /// hasPreviousPage}`; the queue adds the console's older `{currentPage,
  /// perPage, lastPage, prev, next}` in the same object. `Pagination.fromMeta`
  /// reads either, and a fixture that sent neither — as this one used to,
  /// with `{page, count, total}` — exercised only its fallbacks, so a board
  /// that stops after its first page would have passed.
  factory FakeResponse.page(
    List<Object?> rows, {
    int page = 1,
    int limit = 20,
    int? total,
    int? totalPages,
  }) {
    final count = total ?? rows.length;
    final pages =
        totalPages ?? (count <= limit ? 1 : (count + limit - 1) ~/ limit);
    return FakeResponse(200, {
      'success': true,
      'data': {
        'data': rows,
        'meta': {
          'page': page,
          'limit': limit,
          'total': count,
          'totalPages': pages,
          'hasNextPage': page < pages,
          'hasPreviousPage': page > 1,
          'currentPage': page,
          'perPage': limit,
          'lastPage': pages,
          'prev': page > 1 ? page - 1 : null,
          'next': page < pages ? page + 1 : null,
        },
      },
      'message': '',
    });
  }

  factory FakeResponse.fail(
    int status,
    String message, {
    String errorCode = '',
  }) =>
      FakeResponse(status, {
        'success': false,
        'data': null,
        'message': message,
        // `ApiEnvelope` reads this to tell a refusal apart from a fault; an
        // envelope without it makes every 4xx look the same to the app.
        'errorCode': errorCode,
      });

  factory FakeResponse.unauthorized([String message = 'Unauthorized']) =>
      FakeResponse.fail(401, message, errorCode: 'UNAUTHORIZED');

  /// The server refusing for lack of permission, in the words it actually
  /// uses.
  ///
  /// Its own factory because the app answers a 403 differently from every
  /// other failure — `ApiEnvelope.orThrow` raises `ApiForbiddenException`,
  /// `LoadStateMixin` routes it to `rxNoAccess`, and the screen shows a locked
  /// panel rather than a retry. A fixture that sent a plain 500 here would
  /// test the retry path and call it access control.
  factory FakeResponse.forbidden([
    String message = 'Insufficient permissions',
  ]) =>
      FakeResponse.fail(403, message, errorCode: 'FORBIDDEN');

  /// For `dio.download` — attachment and document-preview flows.
  factory FakeResponse.binary(
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) =>
      FakeResponse(
        200,
        null,
        bytes: Uint8List.fromList(data),
        contentType: contentType,
      );

  final int status;
  final Object? body;
  final Duration latency;
  final Uint8List? bytes;
  final String contentType;
}

class _Route {
  _Route(this.method, this.pattern, this.handler, {this.remaining});

  final String method;
  final String pattern;
  final FakeHandler handler;

  /// Null means unlimited. Counts down for one-shot routes, which is how a
  /// "fails once, succeeds on retry" flow is expressed.
  int? remaining;

  final List<String> _segments = [];

  List<String> get segments {
    if (_segments.isEmpty) {
      _segments.addAll(pattern.split('/').where((s) => s.isNotEmpty));
    }
    return _segments;
  }

  /// Returns the captured `:name` values, or null when this route does not
  /// match. Matching is on path only, so an absolute-URL download still hits
  /// its pattern regardless of host.
  Map<String, String>? match(String requestMethod, Uri uri) {
    if (remaining != null && remaining! <= 0) return null;
    if (method != requestMethod) return null;

    final parts = uri.path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length != segments.length) return null;

    final captured = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.startsWith(':')) {
        captured[seg.substring(1)] = parts[i];
      } else if (seg != parts[i]) {
        return null;
      }
    }
    return captured;
  }
}

class FakeApi {
  final List<_Route> _routes = [];
  final Map<String, Duration> _latency = {};

  /// Every request the app made, in order. This replaces mock verification.
  final List<FakeRequest> calls = [];

  /// Requests that matched no route. [assertNoUnstubbedCalls] turns these into
  /// a test failure, so a flow can never "pass" while silently losing half its
  /// data to unanswered requests.
  final List<FakeRequest> unstubbed = [];

  /// Requests currently in flight.
  ///
  /// Only the live tier maintains this (see `RecordingHttpClientAdapter`); the
  /// in-memory router answers synchronously, so it is always zero here. It is
  /// what lets `AppHarness.settle()` wait for a real server to go quiet instead
  /// of for a frame that merely looks quiet between two requests.
  int inflight = 0;

  /// Records a request that a real transport is answering.
  ///
  /// Deliberately *not* added to [unstubbed]: nothing was stubbed, and nothing
  /// should be. A live run has no fixtures by definition.
  void recordPassthrough(FakeRequest request) => calls.add(request);

  // ── Registration ──────────────────────────────────────────────────────────

  /// Registers a handler. Later registrations win, so a flow can override one
  /// endpoint of a world without rebuilding it.
  void on(String method, String pattern, FakeHandler handler) {
    _routes.insert(0, _Route(method.toUpperCase(), pattern, handler));
  }

  /// Registers a constant result inside the standard envelope.
  void json(String method, String pattern, Object? result, {int status = 200}) {
    on(
      method,
      pattern,
      (_) => status >= 400
          ? FakeResponse(status, result)
          : FakeResponse.ok(result),
    );
  }

  /// Registers a paged collection, the shape every list route answers with.
  void page(String method, String pattern, List<Object?> rows) {
    on(method, pattern, (_) => FakeResponse.page(rows));
  }

  /// Refuses this route the way the server refuses it: 403, with
  /// `errorCode: 'FORBIDDEN'`.
  ///
  /// The point of a role harness. An access map is a *hint* — the server
  /// authorises every request on its own, and a screen that hid a button on
  /// the map must still survive the 403 that arrives anyway, because the map
  /// in hand can be a minute older than the role it describes. Registered like
  /// any other route, so a flow refuses one endpoint of the world and leaves
  /// the rest coherent:
  ///
  /// ```dart
  /// AppHarness.bootSignedIn(
  ///   tester,
  ///   role: WorldRole.nurse,
  ///   overrides: (api) => api.forbid('DELETE', '/api/queue/:id'),
  /// );
  /// ```
  void forbid(
    String method,
    String pattern, {
    String message = 'Insufficient permissions',
  }) {
    on(method, pattern, (_) => FakeResponse.forbidden(message));
  }

  /// Answers this route with [status] for the rest of the test.
  ///
  /// For the error paths that are not 403: a 404 on a record deleted under the
  /// user, a 422 on a write the server validated, a 500 on a route that is
  /// down. [message] defaults to something the app can actually show, because
  /// a refusal with an empty message renders as "Request failed" and proves
  /// only that the screen has an error state.
  void failWith(
    String method,
    String pattern,
    int status, {
    String? message,
  }) {
    final body = FakeResponse.fail(
      status,
      message ?? _defaultMessageFor(status),
      errorCode: _defaultCodeFor(status),
    );
    on(method, pattern, (_) => body);
  }

  static String _defaultMessageFor(int status) => switch (status) {
        400 || 422 => 'That request was not valid.',
        401 => 'Unauthorized',
        403 => 'Insufficient permissions',
        404 => 'Not found',
        409 => 'That has already been done.',
        _ => 'Something went wrong',
      };

  static String _defaultCodeFor(int status) => switch (status) {
        400 || 422 => 'VALIDATION_ERROR',
        401 => 'UNAUTHORIZED',
        403 => 'FORBIDDEN',
        404 => 'NOT_FOUND',
        409 => 'CONFLICT',
        _ => 'INTERNAL_ERROR',
      };

  /// Answers with [status] exactly once, then falls through to whatever was
  /// registered before it. This is how error-then-retry flows are written.
  void failOnce(
    String method,
    String pattern, {
    int status = 500,
    String message = 'Something went wrong',
  }) {
    _routes.insert(
      0,
      _Route(
        method.toUpperCase(),
        pattern,
        (_) => FakeResponse.fail(status, message),
        remaining: 1,
      ),
    );
  }

  /// Holds the response back, so a test can assert a loading state is visible.
  void delay(String method, String pattern, Duration d) {
    _latency['${method.toUpperCase()} $pattern'] = d;
  }

  // ── Dispatch (called by FakeApiAdapter) ───────────────────────────────────

  ({FakeResponse response, Duration latency})? dispatch(FakeRequest request) {
    for (final route in _routes) {
      final params = route.match(request.method, request.uri);
      if (params == null) continue;

      if (route.remaining != null) route.remaining = route.remaining! - 1;

      final resolved = request.withPathParams(params);
      calls.add(resolved);
      final extra = _latency['${route.method} ${route.pattern}'];
      final response = route.handler(resolved);
      return (response: response, latency: extra ?? response.latency);
    }

    calls.add(request);
    unstubbed.add(request);
    return null;
  }

  // ── Assertions ────────────────────────────────────────────────────────────

  List<FakeRequest> callsTo(
    String method,
    String pattern, {
    bool Function(FakeRequest)? where,
  }) {
    final probe = _Route(method.toUpperCase(), pattern, (_) => throw 0);
    return calls
        .where((c) => probe.match(c.method, c.uri) != null)
        .where((c) => where == null || where(c))
        .toList();
  }

  int callCount(String method, String pattern) =>
      callsTo(method, pattern).length;

  /// Asserts exactly one matching call was made and returns it.
  ///
  /// [where] narrows by anything the request carries, which is how a screen's
  /// own request is told apart from another screen's request to the same
  /// route. The Overview asks `quote/list` for five recent quotes; the Quotes
  /// tab asks it for a page of twenty. Both are correct, and a bare route
  /// match would call the pair a double fetch.
  FakeRequest requireCall(
    String method,
    String pattern, {
    bool Function(FakeRequest)? where,
  }) {
    final matches = callsTo(method, pattern, where: where);
    if (matches.length != 1) {
      final narrowed = where == null ? '' : ' matching the given predicate';
      fail('Expected exactly one $method $pattern$narrowed, '
          'found ${matches.length}.\n'
          'Calls made:\n${_callLog()}');
    }
    return matches.first;
  }

  /// A request for one page of a list, told apart from a widget that fetches a
  /// handful of the same records for a summary.
  FakeRequest requirePageLoad(String pattern, {int items = 20}) => requireCall(
        'GET',
        pattern,
        where: (r) => r.query['items'] == '$items',
      );

  /// The **most recent** page of a list.
  ///
  /// For a flow that reloads: opening a tab fetches page one, and searching or
  /// filtering fetches it again with the new query. The last one is what the
  /// screen is showing, and the only one an assertion about a filter means.
  FakeRequest requireLastPageLoad(String pattern, {int items = 20}) {
    final matches = callsTo(
      'GET',
      pattern,
      where: (r) => r.query['items'] == '$items',
    );
    if (matches.isEmpty) {
      fail('Expected at least one page of GET $pattern, found none.\n'
          'Calls made:\n${_callLog()}');
    }
    return matches.last;
  }

  void requireNoCall(String method, String pattern) {
    final matches = callsTo(method, pattern);
    if (matches.isNotEmpty) {
      fail('Expected no $method $pattern, found ${matches.length}.\n'
          'Calls made:\n${_callLog()}');
    }
  }

  void assertNoUnstubbedCalls() {
    if (unstubbed.isEmpty) return;
    final missing = unstubbed.map((r) => '  ${r.method} ${r.path}').toSet();
    fail('The app made ${unstubbed.length} request(s) with no fixture:\n'
        '${missing.join('\n')}\n\n'
        'Register each one in the world this flow uses (see '
        'integration_test/scenarios/worlds/), or add a flow-local override '
        'with api.json(...). See .agents/RULES.md §8.5.');
  }

  String _callLog() => calls.isEmpty
      ? '  (none)'
      : calls.map((c) => '  ${c.method} ${c.path}').join('\n');

  void reset() {
    _routes.clear();
    _latency.clear();
    calls.clear();
    unstubbed.clear();
    inflight = 0;
  }
}
