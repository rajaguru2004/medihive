/// The four route names the patients module needs registered.
///
/// Declared here rather than in `Routes` because `lib/app/routes/` belongs to
/// another stream; these are the strings that table should carry, and every
/// navigation inside this module already reads them, so wiring them up is one
/// edit there and none here.
///
/// **`/patients/record` rather than `/patients/:id`.** GetX resolves a named
/// route against a tree of segments, and a `:id` parameter registered at that
/// position matches `search` and `edit` too — so the hub would swallow both
/// siblings and open with `id: 'search'`. The id travels in `Get.arguments`
/// instead, which is how every other detail screen in this app receives one.
abstract final class PatientRoutes {
  /// The register. Already in the route table, pointing at a placeholder.
  static const String registry = '/patients';

  /// The global lookup every other module opens a patient through.
  static const String search = '/patients/search';

  /// Register a new patient, or edit one — `{'id': …}` for the edit.
  static const String form = '/patients/edit';

  /// The hub — `{'id': …}`, optionally `{'patient': Patient}` to paint the
  /// identity band before the record lands.
  static const String hub = '/patients/record';

  /// The id, out of whatever shape a caller passed.
  ///
  /// Accepts the bare string as well as the map, because half the call sites
  /// in an app like this are written as `arguments: patient.id` and a screen
  /// that only reads the map opens on a blank record with no error.
  static String idFrom(Object? arguments) {
    if (arguments is String) return arguments;
    if (arguments is Map && arguments['id'] != null) {
      return arguments['id'].toString();
    }
    return '';
  }
}
