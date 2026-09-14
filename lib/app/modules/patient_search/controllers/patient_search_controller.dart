import 'package:get/get.dart';

import '../../../data/models/patient.dart';
import '../../../data/repositories/patient_repository.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/load_state.dart';

/// The global patient lookup.
///
/// Every other module opens a patient through this screen, so it does one
/// thing and does it against the server: `search` on `/api/patients` matches
/// first name, last name, MRN **and phone**, which is four indexes a client
/// cannot reproduce over one page of rows.
///
/// ## Recents are the current clinician's, and nobody else's
///
/// A ward tablet is handed over. The last person's lookups are a list of
/// patients they were interested in, which is information about their shift
/// and about those patients, and it has no business being on screen for
/// whoever picks the device up next.
///
/// So this controller is registered `permanent` — recents have to survive
/// leaving and reopening the screen or they are not recents — **and** with
/// `SessionManager.registerScoped`, which is the half that matters:
/// `Get.offAllNamed` does not dispose a permanent instance, so without it the
/// list would still be here after the next sign-in.
class PatientSearchController extends GetxController with LoadStateMixin {
  static PatientSearchController get to => Get.find<PatientSearchController>();

  final PatientRepository _repository = patientRepository;

  /// Below this the server would match most of the register, and the reader
  /// would scroll a page that tells them nothing.
  static const int minimumTerm = 2;

  /// How many looked-up patients are kept. Eight is a shift's worth of
  /// glances; a longer list stops being a shortcut and becomes a second list
  /// to read.
  static const int maxRecents = 8;

  final query = ''.obs;
  final results = <Patient>[].obs;
  final recents = <Patient>[].obs;

  /// Which request is the current one.
  ///
  /// The field debounces, but a slow first request and a fast second still
  /// land in the order the network chose — and a stale answer overwriting a
  /// fresher one puts somebody else's patient under the term on screen.
  int _sequence = 0;

  bool get hasTerm => query.value.trim().length >= minimumTerm;

  Future<void> search(String term) async {
    final text = term.trim();
    query.value = text;

    if (text.length < minimumTerm) {
      // Cancels whatever is in flight: its answer is about a term nobody is
      // looking at any more.
      _sequence++;
      results.clear();
      rxLoading.value = false;
      clearLoadError();
      rxNoAccess.value = false;
      rxFirstLoad.value = true;
      return;
    }

    final sequence = ++_sequence;
    await runGuarded(
      () async {
        final page = await _repository.list(
          PagedQuery(limit: 20, search: text, params: const {'status': 'all'}),
        );
        if (sequence != _sequence) return;
        results.assignAll(page.items);
      },
      fallback: "Couldn't search the register.",
    );
  }

  Future<void> retry() => search(query.value);

  /// Files a patient the clinician actually opened.
  ///
  /// Most recent first, deduplicated on id rather than on the object, because
  /// the same patient arriving from a search and from a row is two instances
  /// of one person.
  void remember(Patient patient) {
    if (patient.id.isEmpty) return;
    recents
      ..removeWhere((existing) => existing.id == patient.id)
      ..insert(0, patient);
    if (recents.length > maxRecents) {
      recents.removeRange(maxRecents, recents.length);
    }
  }

  void clearRecents() => recents.clear();
}
