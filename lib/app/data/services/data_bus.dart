import 'package:get/get.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what changed, and who needs to know
///
/// The shell keeps every tab alive (see `LazyIndexedStack`), which is what
/// makes switching between them instant and is also how a screen goes stale:
/// admit a patient from the queue, tab over to Inpatient, and the ward board
/// is the one that loaded ten minutes ago.
///
/// Refetching on every tab switch would fix it and cost a request each time
/// somebody glances at a screen, plus their place in a long list. So instead
/// each write says what it touched, and a screen that was away while its own
/// entity changed reloads **when it is next looked at** — and only then.
///
/// Writes announce themselves from `CrudRepository`, not from call sites, so a
/// new screen is covered the day it is written rather than the day somebody
/// remembers to add it.
/// ─────────────────────────────────────────────────────────────────────────────
class DataBus extends GetxService {
  static DataBus get to => Get.find<DataBus>();

  /// Bumped once per write, per entity. An `RxInt` rather than a stream so a
  /// listener registered after the fact does not have to replay anything — it
  /// only ever needs to know that the number moved.
  final Map<String, RxInt> _ticks = {};

  RxInt tick(String entity) => _ticks.putIfAbsent(entity, () => 0.obs);

  /// Announces that [entities] changed on the server.
  ///
  /// More than one is normal: admitting a patient writes an admission, moves
  /// a bed and takes somebody off the queue.
  void changed(Iterable<String> entities) {
    for (final entity in entities) {
      final key = entity.trim();
      if (key.isEmpty) continue;
      tick(key).value++;
    }
  }

  /// The whole census moved — every figure on the dashboard is suspect.
  static const summary = 'summary';

  /// Announces a clinical write, and the summaries that follow from it.
  ///
  /// Every list in this app is per-entity, but the dashboard is not: it counts
  /// admissions, appointments, queue entries and screenings together, so it
  /// has to hear about all four.
  void changedRecord(String entity) => changed([entity, summary]);

  /// A bed moved. Beds, wards and admissions are one object seen three ways,
  /// so a write to any of them invalidates the other two.
  void changedBed() =>
      changed(['beds', 'wards', 'admissions', summary]);
}
