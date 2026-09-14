/// The consultation module's three route names.
///
/// Declared here rather than in `Routes` because `lib/app/routes/` belongs to
/// another stream; these are the strings that table should carry, and every
/// navigation inside the consultation screens already reads them.
///
/// **Registration order matters.** `ParseRouteTree` answers with the *first*
/// registered page whose pattern matches, and `/consultations/:id` matches
/// `/consultations/edit` too. Register [form] **before** [detail], or every
/// attempt to write a consultation opens a detail screen for one called "edit".
abstract final class ConsultationRoutes {
  /// The log. The same path `Routes.CONSULTATIONS` already holds.
  static const String log = '/consultations';

  /// Write a consultation, or edit one.
  ///
  /// `{'id': …}` for the edit; `{'patientId': …}` and `{'appointmentId': …}` to
  /// open one already attached to the encounter that prompted it.
  static const String form = '/consultations/edit';

  /// One consultation. The pattern, with its parameter; use [detailFor] to
  /// build a concrete path.
  static const String detail = '/consultations/:id';

  static String detailFor(String id) => '/consultations/$id';

  /// The id, out of whatever shape a caller passed — the captured path
  /// parameter, the map a push sends, or the bare string.
  static String idFrom(Object? arguments, [Map<String, String?>? parameters]) {
    if (arguments is String && arguments.isNotEmpty) return arguments;
    if (arguments is Map && arguments['id'] != null) {
      return arguments['id'].toString();
    }
    return parameters?['id'] ?? '';
  }
}
