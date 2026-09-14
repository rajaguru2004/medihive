/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — JSON reading helpers
///
/// Every model in this app is hand-written, and every one of them has to
/// survive the same three facts about this backend:
///
///   * a reference field is either an id string or the populated document,
///     depending on whether that route calls `.populate()`;
///   * a number arrives as a number, a numeric string, or `null`;
///   * a field added after a site was provisioned is simply absent.
///
/// These read defensively so a model never throws on a shape it did not expect
/// — a screen showing a blank field is recoverable, a screen that failed to
/// parse is not.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:convert';

/// A string, with `null`, `'null'` and `'undefined'` all reading as empty.
String asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null' || text == 'undefined') return fallback;
  return text;
}

String? asStringOrNull(dynamic value) {
  final text = asString(value);
  return text.isEmpty ? null : text;
}

/// A number from a number or a numeric string.
double asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(asString(value)) ?? fallback;
}

int asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(asString(value)) ?? fallback;
}

/// A flag from a bool, a number, or any of the strings people store in Mongo.
bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (asString(value).toLowerCase()) {
    'true' || '1' || 'yes' || 'on' => true,
    'false' || '0' || 'no' || 'off' => false,
    _ => fallback,
  };
}

DateTime? asDate(dynamic value) {
  if (value is DateTime) return value;
  final text = asString(value);
  return text.isEmpty ? null : DateTime.tryParse(text);
}

/// A nested object, or an empty map.
Map<String, dynamic> asMap(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

/// A list, whether it arrived as one or as a JSON string holding one.
///
/// This backend stores several list columns as text and hands them back
/// unparsed: an invoice's `items`, an order's `tests`, a study's `images`, a
/// consultation's `icd10Codes`, a patient's `allergies`, a test's
/// `referenceRanges`. A model that reads those with `value is List` sees a
/// String, returns empty, and the screen shows a prescription with no drugs on
/// it — silently, against a perfectly good 200.
///
/// A string that is not JSON at all reads as a single entry rather than as
/// nothing. `allergies: "penicillin"` is one allergy, and an allergy this app
/// drops on the floor is the worst possible way to be tidy.
List<dynamic> asJsonList(dynamic value) {
  if (value is List) return value;
  if (value is Map) return [value];

  final text = asString(value);
  if (text.isEmpty) return const [];

  if (text.startsWith('[') || text.startsWith('{')) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded;
      if (decoded is Map) return [decoded];
    } on FormatException {
      // Text that merely looks like JSON. Fall through and keep it whole.
    }
  }
  return [text];
}

/// A list of objects, tolerating the single-object form, a JSON string, and
/// nulls inside.
List<Map<String, dynamic>> asMapList(dynamic value) => asJsonList(value)
    .whereType<Map>()
    .map((e) => e.cast<String, dynamic>())
    .toList();

/// A list of strings — codes, allergies, tags — from any of the shapes above.
List<String> asStringList(dynamic value) => asJsonList(value)
    .map(asString)
    .where((entry) => entry.isNotEmpty)
    .toList();

/// Maps a list of objects through a model constructor.
List<T> asModelList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) =>
    asMapList(value).map(fromJson).toList();

/// The id of a reference field, however the route chose to send it.
///
/// `client` is a bare id string on a list route and the whole populated
/// document on a read route; both have to answer the same question here.
String asRefId(dynamic value) {
  if (value is Map) return asString(value['_id']);
  return asString(value);
}

/// The populated document of a reference field, or null when only an id came
/// back. Lets a row render `client.name` when it is available and fall back
/// without a second request when it is not.
Map<String, dynamic>? asRefObject(dynamic value) {
  if (value is Map && value['_id'] != null) return value.cast<String, dynamic>();
  return null;
}

/// A model from a reference field, when it was populated.
T? asRefModel<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  final object = asRefObject(value);
  return object == null ? null : fromJson(object);
}

/// Drops the keys the API rejects or ignores on a write.
///
/// The create and update routes spread the request body straight onto the
/// document, so a payload echoing back `_id`, `created` or a populated
/// reference either fails validation or overwrites a server-owned field.
Map<String, dynamic> writable(Map<String, dynamic> data) {
  const serverOwned = {'_id', '__v', 'created', 'updated', 'removed'};
  return {
    for (final entry in data.entries)
      if (!serverOwned.contains(entry.key) && entry.value != null)
        entry.key: entry.value,
  };
}
