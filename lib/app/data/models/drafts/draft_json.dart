/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Write-draft serialisation
///
/// The backend validates every request body with `whitelist +
/// forbidNonWhitelisted`. A key that is not on the DTO is not ignored: it is a
/// 400, and a 400 on an admission is a patient who does not get admitted while
/// somebody reads a stack trace.
///
/// So a draft never spreads a model onto a request. It lists the keys its DTO
/// accepts, by hand, and `write_contract_test.dart` checks that list against
/// the DTO file it was copied from — which turns "a field drifted" from a 400
/// on a ward into a failing unit test.
///
/// These three helpers are the whole of the serialisation policy.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// The body a write actually sends.
///
/// Drops what the API would reject or misread, and nothing else:
///
///  * **null** — a field the form never touched. Sending it would blank a
///    stored value on a PATCH.
///  * **a blank string** — the same thing, typed. Strings are trimmed first,
///    so a field holding only spaces reads as untouched.
///  * **an empty list or map** — `items: []` passes this backend's validators
///    and creates an invoice with no lines on it, which is worse than the 400
///    a missing key gets, because nobody notices.
///
/// `false` and `0` are values, never absences: `hasInsurance: false` is a
/// clinical statement, and `waitBreachMinutes: 0` is documented as "turn the
/// breach flag off".
Map<String, dynamic> draftBody(Map<String, dynamic> fields) {
  final out = <String, dynamic>{};
  for (final entry in fields.entries) {
    final value = _clean(entry.value);
    if (value == null) continue;
    out[entry.key] = value;
  }
  return out;
}

/// Null for anything that should not be sent; the cleaned value otherwise.
Object? _clean(Object? value) {
  if (value == null) return null;

  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  if (value is Map) {
    final nested = <String, dynamic>{};
    value.forEach((key, child) {
      final cleaned = _clean(child);
      if (cleaned != null) nested[key.toString()] = cleaned;
    });
    return nested.isEmpty ? null : nested;
  }

  if (value is Iterable) {
    final items = value.map(_clean).whereType<Object>().toList();
    return items.isEmpty ? null : items;
  }

  return value;
}

/// A moment, as an unambiguous instant.
///
/// UTC with the `Z` on it, because a local ISO string with no offset is read
/// by the server in the server's zone — and a sample collected at 00:30 in
/// Addis lands on the previous day in a database running UTC.
String? isoInstant(DateTime? value) => value?.toUtc().toIso8601String();

/// A calendar day, as `yyyy-MM-dd`.
///
/// Deliberately **not** converted to UTC first. A date of birth or an
/// appointment date is a day somebody picked on a calendar, and converting
/// 1990-05-15 in a UTC+ zone to an instant and back moves it to the 14th.
String? isoDay(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-$month-$day';
}
