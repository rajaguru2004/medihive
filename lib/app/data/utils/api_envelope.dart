import 'package:dio/dio.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — API envelope
///
/// Every endpoint answers in the same wrapper:
///
/// ```json
/// { "success": true, "message": "", "data": … , "timestamp": "…", "path": "…" }
/// ```
///
/// and every failure in its mirror, with `errorCode` beside the message. What
/// sits under `data` comes in three shapes, and this class is the one place
/// that fact is resolved:
///
///   * an object — a single record;
///   * a bare array — most of the collections in this API;
///   * `{data: [...], meta: {…}}` — the paged collections.
///
/// `result` is accepted beside `data` because a few older handlers still answer
/// that way, and a 200 carrying `success: false` is a real thing this backend
/// returns, so unwrapping checks the flag and not just the status code.
///
/// The status code is kept on the envelope, and that is load-bearing:
/// `DioClient.validateStatus` passes everything below 500 except 401, so a
/// **403 arrives here as an ordinary response** rather than as a thrown
/// `DioException`. Nothing else in the app is in a position to notice.
/// ─────────────────────────────────────────────────────────────────────────────
class ApiEnvelope {
  const ApiEnvelope({
    required this.success,
    required this.result,
    required this.message,
    this.statusCode,
    this.errorCode = '',
    this.validationErrors = const {},
    this.pagination,
    this.isEmptyCollection = false,
  });

  final bool success;
  final dynamic result;
  final String message;

  /// The HTTP status, kept because the client does not throw on 4xx. Without
  /// it a 403 and a business-rule refusal are the same object.
  final int? statusCode;

  /// The backend's machine-readable reason — `FORBIDDEN`, `VALIDATION_ERROR`,
  /// `DB_UNIQUE_CONSTRAINT`. For deciding what to do; the message is for
  /// showing.
  final String errorCode;

  /// Field → what was wrong with it, on a validation 400.
  ///
  /// The server answers `message: 'Validation failed'` and puts the useful
  /// half here, so an envelope that keeps only the message tells a user their
  /// write was rejected and not which field to fix. `parseErrorMessage` joins
  /// them back together.
  final Map<String, List<String>> validationErrors;

  final Pagination? pagination;

  /// True when the server said "nothing matched" rather than "something broke".
  ///
  /// This backend answers an empty `list` or `listAll` with **203** and an
  /// empty `search` with **202**, both carrying `success: false` — so a client
  /// that trusts the flag alone shows an error banner to a user whose only
  /// crime is having no invoices yet.
  final bool isEmptyCollection;

  /// The request was refused for lack of permission.
  ///
  /// A screen shows this rather than an error banner: a retry cannot fix it,
  /// and "something went wrong" over a ward's billing tab sends a nurse to IT
  /// for a role they were never meant to have.
  bool get isForbidden => statusCode == 403;

  /// The record is gone — deleted under the user, or never existed.
  bool get isNotFound => statusCode == 404;

  static ApiEnvelope of(Response<dynamic> response) => ApiEnvelope.from(
        response.data,
        status: response.statusCode,
        fallbackMessage: 'Request failed (HTTP ${response.statusCode}).',
      );

  factory ApiEnvelope.from(
    dynamic body, {
    int? status,
    String fallbackMessage = 'Request failed.',
  }) {
    final isSuccessStatus = status != null && status >= 200 && status < 300;

    // A 204, and the empty 200 a couple of handlers answer with. Dio hands
    // both over as null or as an empty string, and reading that as "not a map,
    // therefore broken" is how a successful delete reports a failure and the
    // row stays on screen.
    if (body == null || (body is String && body.trim().isEmpty)) {
      return ApiEnvelope(
        success: isSuccessStatus,
        result: null,
        message: isSuccessStatus ? '' : fallbackMessage,
        statusCode: status,
      );
    }

    // A collection with no envelope around it. Not the documented shape, but
    // cheaper to tolerate here than to debug once on a screen.
    if (body is List) {
      return ApiEnvelope(
        success: isSuccessStatus,
        result: body,
        message: '',
        statusCode: status,
      );
    }

    if (body is! Map) {
      // A proxy's HTML error page, or a bare string. Nothing usable inside.
      return ApiEnvelope(
        success: false,
        result: null,
        message: fallbackMessage,
        statusCode: status,
      );
    }

    final map = body.cast<String, dynamic>();
    // `data` is this backend's key; `result` is what a handful of older
    // handlers still answer with. Reading only one of them is how a screen
    // renders an empty list against a perfectly good 200.
    final payload = map.containsKey('data') ? map['data'] : map['result'];

    // A paged collection is `{data: {data: [...], meta: {…}}}` and a plain one
    // is `{data: [...]}`. Lifting the rows out here is what lets every caller
    // read `objects` without knowing which kind of list it asked for — and
    // reaching into `data['data']` at a call site is exactly the habit
    // `.agents/RULES.md` §3.1 bans.
    var result = payload;
    Pagination? pagination;
    if (payload is Map && payload['data'] is List) {
      result = payload['data'];
      pagination = Pagination.fromMeta(payload['meta']);
    } else if (map['pagination'] is Map) {
      // The older sibling key, still answered by a few routes.
      pagination = Pagination.fromMeta(map['pagination']);
    }

    // An empty collection, not a failure. Keyed on the payload being a list as
    // well as the status, so a 202 that carries a real message still throws
    // with its message intact.
    final isEmptyCollection = (status == 202 || status == 203) && result is List;

    return ApiEnvelope(
      success: map['success'] == true || isEmptyCollection,
      result: result,
      // `msg` as well as `message`. Two core routes — changing your own
      // password among them — answer with `{msg: "…"}` and no envelope at all,
      // and reading only `message` turns "Enter the same password twice" into
      // a blank "Request failed."
      message: (map['message'] ?? map['msg'] ?? '').toString(),
      statusCode: status,
      errorCode: (map['errorCode'] ?? '').toString(),
      validationErrors: _validationErrors(map['errors']),
      pagination: pagination,
      isEmptyCollection: isEmptyCollection,
    );
  }

  /// The payload as an object, or an empty map when the endpoint answered with
  /// `null` — which it does for a successful delete.
  Map<String, dynamic> get object =>
      result is Map ? (result as Map).cast<String, dynamic>() : const {};

  /// The payload as a list, or empty. Tolerates the single-object form some
  /// list endpoints return when there is exactly one match.
  List<Map<String, dynamic>> get objects {
    if (result is List) {
      return (result as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (result is Map) return [(result as Map).cast<String, dynamic>()];
    return const [];
  }

  /// Maps [objects] through a model constructor.
  List<T> listOf<T>(T Function(Map<String, dynamic>) fromJson) =>
      objects.map(fromJson).toList();

  /// Throws unless the call succeeded. Use at the top of a service method so
  /// the controller's `catch` sees one exception family.
  ///
  /// The two that get their own type are the two a screen reacts to rather
  /// than reports: a 403 becomes a locked panel, a 404 becomes "that record is
  /// gone". Everything else is an [ApiException] carrying the server's words.
  ApiEnvelope orThrow() {
    if (success) return this;

    final text = message.isEmpty ? 'Request failed.' : message;
    if (isForbidden) {
      throw ApiForbiddenException(
        message.isEmpty ? "You don't have permission to do that." : message,
        errorCode: errorCode,
      );
    }
    if (isNotFound) {
      throw ApiNotFoundException(
        message.isEmpty ? 'That record no longer exists.' : message,
        errorCode: errorCode,
      );
    }
    throw ApiException(
      text,
      statusCode: statusCode,
      errorCode: errorCode,
      fieldErrors: validationErrors,
    );
  }

  static Map<String, List<String>> _validationErrors(dynamic raw) {
    if (raw is! Map || raw.isEmpty) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): entry.value is List
            ? (entry.value as List).map((m) => m.toString()).toList()
            : [entry.value.toString()],
    };
  }

  @override
  String toString() =>
      'ApiEnvelope(success: $success, status: $statusCode, '
      'message: "$message", result: ${result.runtimeType}'
      '${isEmptyCollection ? ', empty collection' : ''})';
}

/// One page of a list endpoint, with its models already built.
class PagedResult<T> {
  const PagedResult({required this.items, required this.pagination});

  final List<T> items;
  final Pagination pagination;

  static PagedResult<T> empty<T>() =>
      PagedResult<T>(items: const [], pagination: Pagination.none);

  bool get isEmpty => items.isEmpty;
  bool get hasMore => pagination.hasMore;
  int get page => pagination.page;

  /// The same page with another page's items appended — how an infinite list
  /// grows without losing the pagination of the newest response.
  PagedResult<T> followedBy(PagedResult<T> next) => PagedResult<T>(
        items: [...items, ...next.items],
        pagination: next.pagination,
      );

  @override
  String toString() => 'PagedResult(${items.length} of ${pagination.count})';
}

/// Everything this backend's list endpoints accept, and nothing else.
///
/// That second half is the point. Validation runs `whitelist` with
/// `forbidNonWhitelisted`, so **any** parameter the DTO does not declare is a
/// 400 — not an ignored key. The vocabulary here was `items`, `sortBy`,
/// `sortValue`, `q`, `fields`, `filter`, `equal` and `filters`, and every one
/// of those rejected the whole request.
///
/// Per-resource filters go through [params], which the caller owns: a screen
/// knows `status=waiting` is a queue parameter, and this class has no business
/// guessing.
class PagedQuery {
  const PagedQuery({
    this.page = 1,
    this.limit = 20,
    this.orderBy,
    this.orderDir,
    this.search,
    this.params = const {},
  }) : assert(
          orderDir == null || orderDir == 'asc' || orderDir == 'desc',
          "orderDir is 'asc' or 'desc'; anything else is a 400",
        );

  final int page;

  /// Rows per round trip. The web console pages ten at a time behind numbered
  /// controls; a phone scrolls, so it asks for more.
  ///
  /// Never zero: the DTO declares `@Min(1)`, and the server caps it at 100
  /// whatever is sent.
  final int limit;

  /// The field to order by — `createdAt`, `total`, `name`.
  final String? orderBy;

  /// `asc` or `desc`.
  final String? orderDir;

  /// Free-text search. Which columns it matches is the server's decision.
  final String? search;

  /// This resource's own filters — `status`, `wardId`, `role`, `date`.
  ///
  /// Passed through verbatim, nulls dropped. A key this route's DTO does not
  /// declare is a 400, so the screen that knows the route owns this map.
  final Map<String, dynamic> params;

  PagedQuery copyWith({
    int? page,
    int? limit,
    String? orderBy,
    String? orderDir,
    String? search,
    Map<String, dynamic>? params,
  }) =>
      PagedQuery(
        page: page ?? this.page,
        limit: limit ?? this.limit,
        orderBy: orderBy ?? this.orderBy,
        orderDir: orderDir ?? this.orderDir,
        search: search ?? this.search,
        params: params ?? this.params,
      );

  /// The next page of the same query.
  PagedQuery next() => copyWith(page: page + 1);

  /// The same query, back at the first page. What a filter or sort change asks
  /// for — page four of the old result has nothing to do with the new one.
  PagedQuery reset() => copyWith(page: 1);

  Map<String, dynamic> toQueryParameters() => {
        'page': page,
        'limit': limit,
        'orderBy': ?orderBy,
        'orderDir': ?orderDir,
        if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
        for (final entry in params.entries)
          if (entry.value != null) entry.key: entry.value,
      };

  @override
  String toString() => 'PagedQuery(${toQueryParameters()})';
}

/// A page of a list endpoint.
class Pagination {
  const Pagination({
    required this.page,
    required this.pages,
    required this.count,
    this.limit = 0,
    bool? hasNext,
  }) : _hasNext = hasNext;

  final int page;
  final int pages;

  /// Rows in the whole collection, not on this page.
  final int count;

  final int limit;

  /// What the server said about a next page, when it said anything. Trusted
  /// over the arithmetic below it: the server knows about rows added since.
  final bool? _hasNext;

  static const Pagination none = Pagination(page: 1, pages: 1, count: 0);

  bool get hasMore => _hasNext ?? page < pages;

  /// Reads the `meta` block in either dialect.
  ///
  /// Most routes answer `{page, limit, total, totalPages, hasNextPage,
  /// hasPreviousPage}`; the queue also carries the console's older
  /// `{currentPage, perPage, lastPage, prev, next}` in the same object. Reading
  /// one dialect and not the other is how a board that has three pages stops
  /// after the first.
  ///
  /// A bare array carries no meta at all, and reads as one complete page.
  static Pagination fromMeta(dynamic raw) {
    if (raw is! Map) return none;

    int at(String key, String legacyKey, {int fallback = 0}) {
      final value = raw[key] ?? raw[legacyKey];
      return int.tryParse('$value') ?? fallback;
    }

    final page = at('page', 'currentPage', fallback: 1);
    final pages = at('totalPages', 'lastPage', fallback: 1);

    // `hasNextPage` when the route speaks the standard dialect; `next` — the
    // number of the next page, or null — when it speaks the queue's.
    final hasNext = raw['hasNextPage'] is bool
        ? raw['hasNextPage'] as bool
        : (raw.containsKey('next') ? raw['next'] != null : null);

    return Pagination(
      page: page == 0 ? 1 : page,
      pages: pages == 0 ? 1 : pages,
      count: at('total', 'count'),
      limit: at('limit', 'perPage'),
      hasNext: hasNext,
    );
  }

  @override
  String toString() => 'Pagination(page $page of $pages, $count total)';
}

/// A failure the server described in words the user can be shown.
///
/// Distinct from `DioException`, which carries transport failures. Both are
/// funnelled into one string by `parseErrorMessage`.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.errorCode = '',
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;
  final String errorCode;

  /// Field → what was wrong with it, when the server rejected a write on
  /// validation. Joined into the shown sentence by `parseErrorMessage`.
  final Map<String, List<String>> fieldErrors;

  @override
  String toString() => message;
}

/// The server refused: this account may not do that.
///
/// Its own type because a screen answers it differently from every other
/// failure — a locked panel rather than a retry. See `LoadStateMixin`, which
/// routes it to `rxNoAccess` and deliberately raises no error banner.
class ApiForbiddenException extends ApiException {
  const ApiForbiddenException(
    super.message, {
    super.errorCode = 'FORBIDDEN',
  }) : super(statusCode: 403);
}

/// The record is gone. Its own type so a detail screen can pop back to its
/// list instead of showing a retry for something that will never be there.
class ApiNotFoundException extends ApiException {
  const ApiNotFoundException(
    super.message, {
    super.errorCode = 'NOT_FOUND',
  }) : super(statusCode: 404);
}
