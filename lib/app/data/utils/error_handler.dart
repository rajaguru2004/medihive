import 'package:dio/dio.dart';

import 'api_envelope.dart';

/// Longest message we will hand to a toast or a banner. Misconfigured proxies
/// sometimes echo a whole stack trace back in the body; without a cap that
/// fills the screen and hides the buttons underneath it.
const int _maxMessageLength = 200;

/// Turns anything throwable into one sentence a user can be shown.
///
/// Handles every body shape the backend and the infrastructure in front of it
/// can produce: the `{success, result, message}` envelope, a `message` that is
/// a validation array rather than a string, an HTML error page from nginx, or
/// no body at all on a timeout.
String parseErrorMessage(
  dynamic error, [
  String fallback = 'Something went wrong. Please try again.',
]) {
  if (error is ApiException) {
    final fields = _joinFieldErrors(error.fieldErrors);
    return _clamp(fields ?? error.message, fallback);
  }

  if (error is DioException) {
    final response = error.response;
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map) {
        // A rejected write names the field. The server answers a validation
        // failure with `message: 'Validation failed'` — which tells a user
        // nothing they can act on — and puts the part that matters under
        // `errors`.
        final fields = _joinFieldErrors(data['errors']);
        if (fields != null) return _clamp(fields, fallback);

        // `msg` as well: two core routes answer with that key and no envelope.
        final message = data['message'] ?? data['msg'];
        if (message is String) {
          return _clamp(message, fallback);
        } else if (message is List) {
          // These land in a toast a few lines tall — join with commas, not
          // newlines, so the list reads as a sentence rather than eating the
          // whole pill with one item per line.
          return _clamp(message.join(', '), fallback);
        } else if (message != null) {
          return _clamp(message.toString(), fallback);
        }
      }
      // Non-Map bodies (an HTML error page, a bare string) carry nothing worth
      // showing a user — fall through to the status-code branch.
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to answer. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return "Can't reach the server. Check your internet connection.";
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badCertificate:
        return "The server's security certificate could not be verified.";
      case DioExceptionType.badResponse:
        final statusCode = response?.statusCode;
        return switch (statusCode) {
          401 => 'Your session has expired. Please sign in again.',
          403 => "You don't have permission to do that.",
          404 => 'That record no longer exists.',
          409 => 'That request was rejected. Please check the details and try again.',
          500 => 'The server hit an error (500). Please try again shortly.',
          502 => 'The server is unavailable (502). Please try again shortly.',
          503 => 'The server is down for maintenance (503).',
          504 => 'The server timed out (504). Please try again shortly.',
          _ => 'The server returned an error${statusCode == null ? '' : ' ($statusCode)'}.',
        };
      case DioExceptionType.unknown:
        break;
    }
  }

  if (error != null && error.toString().contains('SocketException')) {
    return "Can't reach the server. Check your internet connection.";
  }

  return fallback;
}

/// The field messages of a validation failure, as one sentence.
///
/// Each message already begins with its field name (`email must be an email`),
/// so the key is not repeated in front of it. Joined with commas rather than
/// newlines: these land in a toast a few lines tall, and one item per line eats
/// the whole pill.
///
/// Returns null when there is nothing to join, so a caller can fall through to
/// the generic message rather than showing an empty string.
String? _joinFieldErrors(dynamic errors) {
  if (errors is! Map || errors.isEmpty) return null;
  final messages = <String>[];
  for (final value in errors.values) {
    if (value is List) {
      messages.addAll(value.map((m) => m.toString().trim()));
    } else if (value != null) {
      messages.add(value.toString().trim());
    }
  }
  messages.removeWhere((m) => m.isEmpty);
  return messages.isEmpty ? null : messages.join(', ');
}

String _clamp(String message, String fallback) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return fallback;
  if (trimmed.length <= _maxMessageLength) return trimmed;
  return '${trimmed.substring(0, _maxMessageLength)}…';
}
