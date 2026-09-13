import 'dart:convert';

import 'package:dio/dio.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — API envelope
///
/// Every endpoint answers in the same wrapper:
///
/// ```json
/// { "success": true, "data": { … }, "message": "" }
/// ```
///
/// with pagination, when present, hanging off a sibling `pagination` key. The
/// payload is under `data`, and `result` is accepted beside it because a few
/// older handlers still answer that way — a detail worth resolving once here
/// rather than rediscovering in each service.
///
/// A 200 response with `success: false` is a real thing this backend returns
/// (a validation failure comes back as 409 but some handlers answer 200), so
/// unwrapping must check the flag and not just the status code.
/// ─────────────────────────────────────────────────────────────────────────────
class ApiEnvelope {
  const ApiEnvelope({
    required this.success,
    required this.result,
    required this.message,
    this.pagination,
    this.isEmptyCollection = false,
  });

  final bool success;
  final dynamic result;
  final String message;
  final Pagination? pagination;

  /// True when the server said "nothing matched" rather than "something broke".
  ///
  /// This backend answers an empty `list` or `listAll` with **203** and an
  /// empty `search` with **202**, both carrying `success: false` — so a client
  /// that trusts the flag alone shows an error banner to a user whose only
  /// crime is having no invoices yet.
  final bool isEmptyCollection;

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
    if (body is! Map) {
      // A proxy's HTML error page, or a bare string. Nothing usable inside.
      return ApiEnvelope(
        success: false,
        result: null,
        message: fallbackMessage,
      );
    }
    final map = body.cast<String, dynamic>();
    // `data` is this backend's key; `result` is what a handful of older
    // handlers still answer with. Reading only one of them is how a screen
    // renders an empty list against a perfectly good 200.
    final result = map.containsKey('data') ? map['data'] : map['result'];

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
      pagination: Pagination.maybe(map['pagination']),
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

  /// Throws [ApiException] unless the call succeeded. Use at the top of a
  /// service method so the controller's `catch` sees one exception type.
  ApiEnvelope orThrow() {
    if (success) return this;
    throw ApiException(message.isEmpty ? 'Request failed.' : message);
  }

  @override
  String toString() =>
      'ApiEnvelope(success: $success, message: "$message", '
      'result: ${result.runtimeType}'
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

/// Everything the backend's list endpoints accept, in one object.
///
/// The query shape is shared by all six entities, so building it once here
/// means a controller states *what* it wants rather than re-deriving the
/// parameter names — and the two that are easy to get wrong (`filters`, and
/// the `filter`/`equal` pair that must travel together) are enforced.
class PagedQuery {
  const PagedQuery({
    this.page = 1,
    this.items = 20,
    this.sortBy,
    this.sortValue,
    this.q,
    this.fields,
    this.filter,
    this.equal,
    this.filters = const {},
  });

  final int page;

  /// The web portal pages ten at a time behind numbered controls. A phone
  /// scrolls, so it asks for more per round trip.
  final int items;

  final String? sortBy;

  /// 1 ascending, -1 descending.
  final int? sortValue;

  /// Free-text search, with [fields] naming where to look.
  final String? q;
  final String? fields;

  /// A single exact-match pair. Both or neither: the backend answers 403 when
  /// one arrives without the other.
  final String? filter;
  final String? equal;

  /// Multi-value filters, sent as one JSON object.
  final Map<String, List<String>> filters;

  PagedQuery copyWith({
    int? page,
    int? items,
    String? sortBy,
    int? sortValue,
    String? q,
    String? fields,
    String? filter,
    String? equal,
    Map<String, List<String>>? filters,
  }) =>
      PagedQuery(
        page: page ?? this.page,
        items: items ?? this.items,
        sortBy: sortBy ?? this.sortBy,
        sortValue: sortValue ?? this.sortValue,
        q: q ?? this.q,
        fields: fields ?? this.fields,
        filter: filter ?? this.filter,
        equal: equal ?? this.equal,
        filters: filters ?? this.filters,
      );

  /// The next page of the same query.
  PagedQuery next() => copyWith(page: page + 1);

  /// The same query, back at the first page. What a filter or sort change asks
  /// for — page four of the old result has nothing to do with the new one.
  PagedQuery reset() => copyWith(page: 1);

  Map<String, dynamic> toQueryParameters() => {
        'page': page,
        'items': items,
        'sortBy': ?sortBy,
        'sortValue': ?sortValue,
        if (q != null && q!.trim().isNotEmpty) ...{
          'q': q!.trim(),
          'fields': fields ?? 'name',
        },
        // Sent together or not at all.
        if (filter != null && equal != null) ...{
          'filter': filter,
          'equal': equal,
        },
        // Encoded once, by Dio. Pre-encoding here produces a double-escaped
        // string that Express decodes into something `JSON.parse` rejects.
        if (filters.isNotEmpty) 'filters': jsonEncode(filters),
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
  });

  final int page;
  final int pages;
  final int count;

  static const Pagination none = Pagination(page: 1, pages: 1, count: 0);

  bool get hasMore => page < pages;

  static Pagination? maybe(dynamic raw) {
    if (raw is! Map) return null;
    int at(String key) => int.tryParse('${raw[key]}') ?? 0;
    return Pagination(
      page: at('page') == 0 ? 1 : at('page'),
      pages: at('pages') == 0 ? 1 : at('pages'),
      count: at('count'),
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
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
