import 'dart:async';

import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/machine_integration.dart';
import '../../../data/models/results_queue_item.dart';
import '../../../data/repositories/integrations_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/file_source.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../device_status.dart';

/// The three things this screen is ever doing.
enum IntegrationsSegment {
  /// The analysers and machines this site talks to.
  devices,

  /// What they have sent that nobody has matched to a patient yet.
  queue,

  /// A file from a machine with no live link.
  upload,
}

/// The instrument link.
///
/// The devices and the queue are fetched together on arrival and kept, because
/// the segments are one screen to the person using them: somebody checks what
/// arrived, walks to the analyser and comes back, and a segment that refetched
/// on every tap would cost a round trip for each of those glances.
///
/// Filters are the exception. Both lists are narrowed by the **server** —
/// `MachineQueryDto.status` and `ResultsQueueQueryDto.status` — so changing one
/// refetches that list and nothing else.
class IntegrationsController extends GetxController with LoadStateMixin {
  IntegrationsController() : repository = _resolveRepository();

  static IntegrationsController get to => Get.find<IntegrationsController>();

  /// The repository, registering it if nothing has yet.
  ///
  /// In the initialiser list rather than the binding because this controller is
  /// also `Get.put` straight into the shell's destination table, where there is
  /// no binding to run first — and a `Get.find` there throws before the tab has
  /// painted a frame.
  static IntegrationsRepository _resolveRepository() {
    IntegrationsRepositories.register();
    return IntegrationsRepositories.instance;
  }

  final IntegrationsRepository repository;

  final segment = IntegrationsSegment.devices.obs;

  final machines = <MachineIntegration>[].obs;
  final queue = <ResultsQueueItem>[].obs;

  /// Null is "every state", which is what the first chip in each row sets.
  final linkFilter = RxnString();
  final queueFilter = RxnString();

  /// True while a filtered refetch is in flight. Separate from [rxLoading],
  /// which drives the first-load skeleton: a filter that blanked the board on
  /// every tap would be unusable.
  final filtering = false.obs;

  // ── The upload ────────────────────────────────────────────────────────────

  /// The file somebody chose, **kept across a failed send**.
  ///
  /// Cleared only when the server has taken it. A retry that started by asking
  /// for the file again is a retry nobody makes on a ward, and the second
  /// attempt is the one that usually works — this route is reached over the
  /// same wifi the analyser dropped off.
  final pickedFile = Rxn<PickedFile>();

  /// Which device the file came off, when whoever is sending it knows. Optional
  /// on the route; see [IntegrationsRepository.uploadResults].
  final uploadDeviceId = RxnString();

  final isUploading = false.obs;

  /// 0…1 while a send is in flight. A spinner with no figure on it reads as a
  /// hung screen, and the second tap sends the file twice.
  final uploadProgress = 0.0.obs;

  /// Inline and persistent, never a toast — the chosen file is still on screen
  /// and the retry is attached to this.
  final uploadError = RxnString();

  final lastUpload = ResultsUploadSummary.empty.obs;

  // ── Access ────────────────────────────────────────────────────────────────
  //
  // Each still handles the 403 that arrives anyway: an access map in hand can
  // be a minute older than the role it describes.

  bool _can(AccessVerb verb) =>
      Get.isRegistered<AccessService>() &&
      AccessService.to.can(Modules.integrations, verb);

  /// Registering a device and importing a file are the same grant on the
  /// server: both routes ask for `INTEGRATION_CREATE`.
  bool get canCreate => _can(AccessVerb.create);

  bool get canUpdate => _can(AccessVerb.update);
  bool get canDelete => _can(AccessVerb.delete);

  // ── What the screen reads ─────────────────────────────────────────────────

  /// The devices as they are read: **anything wrong first**, then the rest,
  /// each group still in the order the server sent it.
  ///
  /// Sorted here rather than asked for, because the route orders by
  /// `createdAt desc` and reads no `orderBy` — so a board worked by
  /// registration date buries the analyser that stopped talking this morning
  /// under six that are fine.
  ///
  /// Decorated with the index on the way in because `List.sort` is **not
  /// stable** in Dart: without it two connected machines swap places on every
  /// rebuild, and a list that reorders under a reader's thumb is one they stop
  /// trusting.
  List<MachineIntegration> get devices {
    final decorated = [
      for (var i = 0; i < machines.length; i++)
        (at: i, link: DeviceLink.of(machines[i]), machine: machines[i]),
    ]..sort((a, b) {
        final byRank = a.link.rank.compareTo(b.link.rank);
        return byRank != 0 ? byRank : a.at.compareTo(b.at);
      });
    return [for (final row in decorated) row.machine];
  }

  /// How many devices somebody has to do something about.
  int get needingAttention =>
      machines.where((m) => DeviceLink.of(m).needsAttention).length;

  /// Rows nobody could put a name to, or that need a person to choose between
  /// two candidates.
  int get unmatchedRows =>
      queue.where((row) => !row.isMatched || row.needsReview).length;

  bool get isDeviceFiltered => linkFilter.value != null;
  bool get isQueueFiltered => queueFilter.value != null;

  // ── Loading ───────────────────────────────────────────────────────────────

  @override
  void onReady() {
    super.onReady();
    // In `onReady` and not `onInit`: `runGuarded` raises its loading flag
    // synchronously, and a write to an observable while the view that reads it
    // is still building marks the building `Obx` dirty.
    unawaited(load());

    if (Get.isRegistered<DataBus>()) {
      for (final entity in const [
        IntegrationEntities.machines,
        IntegrationEntities.resultsQueue,
      ]) {
        // Silent: the board somebody is reading stays on screen rather than
        // collapsing to a skeleton under their thumb. This is also how a device
        // saved on the form behind this screen, and a file this screen itself
        // just sent, both come back — one path rather than two.
        ever<int>(DataBus.to.tick(entity), (_) => unawaited(load(silent: true)));
      }
    }
  }

  /// Everything the hub shows, in one round of requests.
  ///
  /// A second caller **awaits the load already running** rather than being
  /// dropped. One upload ticks two entities this screen listens to, so the
  /// alternative is either three overlapping reloads or a caller that returns
  /// before the list it was waiting for has landed.
  Future<void> load({bool silent = false}) {
    final running = _inFlight;
    if (running != null) return running;

    final future = _load(silent: silent).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void>? _inFlight;

  Future<void> _load({required bool silent}) => runGuarded(
        () async {
          final results = await Future.wait([
            repository.machines(status: linkFilter.value),
            repository.queue(status: queueFilter.value),
          ]);
          machines.assignAll(results[0] as List<MachineIntegration>);
          queue.assignAll(results[1] as List<ResultsQueueItem>);
        },
        fallback: "Couldn't load the instrument link.",
        silent: silent,
      );

  /// Pull-to-refresh. Never named `refresh()` — `GetxController` already has one
  /// that returns void, so an `onRefresh:` wired to it never awaits.
  Future<void> reload() => load(silent: true);

  void show(IntegrationsSegment next) => segment.value = next;

  // ── Filters ───────────────────────────────────────────────────────────────

  Future<void> filterDevices(String? status) async {
    if (status == linkFilter.value) return;
    linkFilter.value = status;
    await _refetch(
      () async => machines.assignAll(
        await repository.machines(status: status),
      ),
      "Couldn't filter the devices.",
    );
  }

  Future<void> filterQueue(String? status) async {
    if (status == queueFilter.value) return;
    queueFilter.value = status;
    await _refetch(
      () async => queue.assignAll(await repository.queue(status: status)),
      "Couldn't filter the results queue.",
    );
  }

  Future<void> _refetch(Future<void> Function() body, String fallback) async {
    filtering.value = true;
    try {
      await body();
    } catch (e, stack) {
      // Inline, not a toast: the list on screen is now older than the filter
      // above it, and a message that vanishes in three seconds leaves somebody
      // reading the wrong rows without knowing.
      _recordFailure(e, stack, fallback);
    } finally {
      filtering.value = false;
    }
  }

  // ── The upload ────────────────────────────────────────────────────────────

  /// Asks for a file and holds it until it is sent.
  ///
  /// A null answer is somebody backing out of the picker, which is not a
  /// failure and must not clear the file they chose a moment ago.
  Future<void> pickFile() async {
    if (isUploading.value) return;
    uploadError.value = null;

    try {
      final chosen = await Get.find<FileSource>().pick();
      if (chosen == null) return;

      if (chosen.isTooLarge) {
        // Refused here rather than by the route, which answers a size overrun
        // by dropping the connection — the app then shows a network error for
        // a file that is merely too big.
        uploadError.value = 'That file is ${chosen.sizeLabel}. This import '
            'takes files up to 10 MB — split it and send the parts.';
        return;
      }

      pickedFile.value = chosen;
      lastUpload.value = ResultsUploadSummary.empty;
    } catch (e, stack) {
      // The filename is deliberately not logged: an analyser export is
      // routinely named after the patient or the accession it holds.
      AppLog.error('$runtimeType', 'choosing a results file failed', e, stack);
      uploadError.value = parseErrorMessage(e, "Couldn't open that file.");
    }
  }

  /// Drops the chosen file. The one control that does — a failed send keeps it.
  void clearFile() {
    if (isUploading.value) return;
    pickedFile.value = null;
    uploadError.value = null;
    uploadProgress.value = 0;
  }

  /// Sends the chosen file, and answers whether the server took it.
  ///
  /// Returns a bool so the view can raise its toast only on success — a screen
  /// that congratulates somebody over a failed import is a screen that loses a
  /// morning's results.
  Future<bool> sendFile() async {
    final file = pickedFile.value;
    if (file == null || isUploading.value) return false;

    isUploading.value = true;
    uploadProgress.value = 0;
    uploadError.value = null;

    try {
      final summary = await repository.uploadResults(
        file,
        machineIntegrationId: uploadDeviceId.value,
        onProgress: (sent, total) {
          // Dio reports a total of -1 when the length is not known. Dividing by
          // it paints a bar that runs backwards.
          uploadProgress.value = total <= 0 ? 0 : (sent / total).clamp(0.0, 1.0);
        },
      );

      lastUpload.value = summary;
      // Only now. Everything above this line can fail, and the file has to
      // survive it.
      pickedFile.value = null;
      uploadProgress.value = 1;

      // The queue is one of the two entities the repository announced, so this
      // screen's own `ever` has already asked for the rows. Awaited here so a
      // caller — and a flow — sees the queue this import landed on rather than
      // the one before it.
      await load(silent: true);
      return true;
    } on ApiForbiddenException catch (e) {
      // Gated on the access map and refused anyway: the map was stale. Not an
      // error banner's fault and not something a retry fixes.
      uploadError.value = "You don't have permission to import results.";
      AppLog.info('$runtimeType', 'results upload refused: ${e.message}');
      return false;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'results upload failed', e, stack);
      uploadError.value = parseErrorMessage(e, "Couldn't send that file.");
      return false;
    } finally {
      isUploading.value = false;
    }
  }

  /// The devices a file can be attributed to — everything this site has
  /// registered, whatever state its link is in. A machine that is not talking
  /// is exactly the one somebody is carrying a USB stick from.
  List<MachineIntegration> get uploadDevices => machines;

  String? get uploadDeviceLabel {
    final id = uploadDeviceId.value;
    if (id == null) return null;
    final device = machines.firstWhereOrNull((m) => m.id == id);
    return device?.displayName;
  }

  /// Records a failure from a filtered refetch the way [runGuarded] records one
  /// from a full load, so both land in the same inline banner.
  ///
  /// A 403 here is the server answering correctly rather than a fault — the
  /// same distinction `LoadStateMixin` draws — so it locks the panel instead of
  /// raising a retry nobody's role can satisfy.
  void _recordFailure(Object error, StackTrace stack, String fallback) {
    if (error is ApiForbiddenException) {
      rxNoAccess.value = true;
      AppLog.info('$runtimeType', 'access refused: ${error.message}');
      return;
    }
    rxLoadError.value = parseErrorMessage(error, fallback);
    AppLog.error('$runtimeType', fallback, error, stack);
  }
}
