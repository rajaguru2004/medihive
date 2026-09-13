/// Reading the raw-`Response` services that predate `CrudRepository`.
///
/// `ApiEnvelope` is the right way to unwrap this backend and every new call
/// goes through it. These helpers exist for the services in
/// `data/services/` that still hand controllers a bare `Response`, and they
/// encode the two shapes those routes answer with:
///
///   * a paged collection — `{success, data: {data: [...], meta}}`
///   * a plain collection or object — `{success, data: [...]}` / `{...}`
///
/// Reading only one of the two is how a screen renders an empty list against
/// a perfectly good 200, which is the single most common bug in the code this
/// replaced.
library;

/// The rows in a collection response, whichever shape it came in.
List<Map<String, dynamic>> envelopeRows(dynamic body) {
  if (body is! Map) return const [];
  if (body['success'] != true) return const [];

  final payload = body['data'] ?? body['result'];
  final rows = payload is Map ? payload['data'] : payload;
  if (rows is! List) return const [];

  return rows.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

/// The object in a single-record response.
Map<String, dynamic> envelopeObject(dynamic body) {
  if (body is! Map) return const {};
  if (body['success'] != true) return const {};

  final payload = body['data'] ?? body['result'];
  return payload is Map ? payload.cast<String, dynamic>() : const {};
}

/// Whether a write succeeded, tolerating the three ways this backend says so:
/// a 200 with `success: true`, a bare 200, and a 204.
bool envelopeOk(dynamic body, {int? statusCode}) {
  if (statusCode == 204) return true;
  if (body is Map) return body['success'] == true;
  return statusCode == 200;
}

/// The server's own message, when it sent one worth showing.
String? envelopeMessage(dynamic body) {
  if (body is! Map) return null;
  final message = (body['message'] ?? body['msg'])?.toString().trim();
  return (message == null || message.isEmpty) ? null : message;
}
