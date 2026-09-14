/// The clinic's three route names.
///
/// Declared here rather than in `Routes` because `lib/app/routes/` belongs to
/// another stream; these are the strings that table should carry, and every
/// navigation inside the appointment screens already reads them, so wiring them
/// up is one edit there and none here.
///
/// **Registration order matters.** `ParseRouteTree` answers with the *first*
/// registered page whose pattern matches, and `/appointments/:id` matches
/// `/appointments/edit` and `/appointments/create` too. Register [form] — and
/// the existing `APPOINTMENT_CREATE` — **before** [detail], or every attempt to
/// book opens a detail screen for an appointment called "edit".
abstract final class AppointmentRoutes {
  /// The clinic board. The same path `Routes.APPOINTMENTS` already holds.
  static const String board = '/appointments';

  /// Book a new appointment, or edit one — `{'id': …}` for the edit,
  /// `{'patientId': …}` to open with the patient already chosen.
  static const String form = '/appointments/edit';

  /// One booking. The pattern, with its parameter; use [detailFor] to build a
  /// concrete path.
  static const String detail = '/appointments/:id';

  /// The detail path for one booking.
  static String detailFor(String id) => '/appointments/$id';

  /// The id, out of whatever shape a caller passed.
  ///
  /// Three shapes, because all three happen: the path parameter GetX captured
  /// from [detail], the map a push inside the app sends, and the bare string
  /// half the call sites in an app like this are written with. A screen that
  /// reads only one of them opens on a blank record with no error.
  static String idFrom(Object? arguments, [Map<String, String?>? parameters]) {
    if (arguments is String && arguments.isNotEmpty) return arguments;
    if (arguments is Map && arguments['id'] != null) {
      return arguments['id'].toString();
    }
    return parameters?['id'] ?? '';
  }
}
