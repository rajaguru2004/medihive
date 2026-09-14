import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/radiology_drafts.dart';
import '../../../data/models/radiology_order.dart';
import '../../../data/models/radiology_report.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/image_source.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';

/// One imaging order, and every way it can be moved along.
///
/// Tagged by order id rather than registered once, because the tablet shows a
/// detail beside the worklist: two windows of this screen can be alive at the
/// same time, on two different studies, and one controller between them would
/// show the second study's actions against the first study's header.
class RadiologyOrderDetailController extends GetxController with LoadStateMixin {
  RadiologyOrderDetailController({required this.orderId});

  final String orderId;

  final order = RadiologyOrder.empty.obs;

  /// A write in flight. Separate from [rxLoading] so acting on the order does
  /// not collapse it back to a skeleton under the thumb that pressed it.
  final isSaving = false.obs;

  /// True while a study image is on its way up.
  final isUploading = false.obs;

  /// What went wrong with the last action, in the words the server used.
  ///
  /// A banner on the screen rather than a toast: a refused action is something
  /// somebody has to do differently, and three seconds is not long enough to
  /// read why.
  final actionError = RxnString();

  /// The order id this screen was opened for.
  ///
  /// `Get.arguments` wins over the path so a caller that already holds the
  /// record does not have to round-trip it through a URL; the path is what a
  /// deep link and the route table carry.
  static String routeOrderId() {
    final args = Get.arguments;
    if (args is Map && args['orderId'] is String) {
      return args['orderId'] as String;
    }
    return Get.parameters['id'] ?? '';
  }

  /// The controller for one order, created if this is the first view of it.
  static RadiologyOrderDetailController forOrder(String id) {
    if (Get.isRegistered<RadiologyOrderDetailController>(tag: id) ||
        Get.isPrepared<RadiologyOrderDetailController>(tag: id)) {
      return Get.find<RadiologyOrderDetailController>(tag: id);
    }
    return Get.put(
      RadiologyOrderDetailController(orderId: id),
      tag: id,
    );
  }

  RadiologyReport? get report => order.value.report;

  List<RadiologyImage> get images => report?.images ?? const [];

  // ── What this account may do ──────────────────────────────────────────────
  //
  // Every one of these is a *hint*. The server authorises each request on its
  // own and the map in hand can be a minute older than the role it describes,
  // so each action below still handles the 403 that arrives anyway.

  bool _can(AccessVerb verb) =>
      Get.isRegistered<AccessService>() &&
      AccessService.to.can(Modules.radiology, verb);

  bool get canUpdate => _can(AccessVerb.update);
  bool get canCreate => _can(AccessVerb.create);

  String get _status => order.value.status.trim().toLowerCase();

  bool get _isClosed =>
      _status == RadiologyOrderStatus.cancelled ||
      _status == RadiologyOrderStatus.reported;

  bool get canSchedule =>
      canUpdate &&
      (_status == RadiologyOrderStatus.pending ||
          _status == RadiologyOrderStatus.scheduled);

  bool get canStart =>
      canUpdate &&
      (_status == RadiologyOrderStatus.pending ||
          _status == RadiologyOrderStatus.scheduled);

  /// The exam happened. Offered from the moment the patient is on the machine,
  /// and from `scheduled` too — a radiographer who forgot to press "start" has
  /// still done the study, and making them press two buttons in order is how a
  /// completed exam ends up recorded as never performed.
  bool get canMarkPerformed =>
      canUpdate &&
      (_status == RadiologyOrderStatus.inProgress ||
          _status == RadiologyOrderStatus.scheduled);

  bool get canCancel => canUpdate && !_isClosed;

  /// A study nobody has read yet, that has been done.
  bool get canWriteReport =>
      canCreate &&
      report == null &&
      (order.value.isPerformed ||
          _status == RadiologyOrderStatus.completed ||
          _status == RadiologyOrderStatus.inProgress);

  bool get canEditReport => canUpdate && report != null;

  /// Images hang off the report, which is the only place this backend stores
  /// them — so there has to be one before there is anywhere to put them.
  bool get canUploadImage => canCreate && report != null;

  @override
  void onReady() {
    super.onReady();
    load();

    // A report written on the form this screen pushed changes what this screen
    // says — its status, its timeline, and whether it carries a critical
    // finding. Heard on the bus rather than handed back through the route,
    // because the report form is also reachable from a deep link.
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick(RadiologyEntities.reports), (_) {
        if (!isLoading) load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          order.value = await RadiologyRepositories.orders.read(orderId);
        },
        fallback: "Couldn't load this imaging order.",
        silent: silent,
      );

  /// Named `reload` because `GetxController.refresh()` already exists, returns
  /// void, and an `onRefresh:` wired to it silently never awaits.
  Future<void> reload() => load(silent: true);

  // ── Moving the order along ────────────────────────────────────────────────

  /// Books the study for a day.
  Future<bool> schedule(DateTime when) => _patch(
        RadiologyOrderDraft(
          status: RadiologyOrderStatus.scheduled,
          scheduledDate: when,
        ).toUpdateJson(),
        failure: "Couldn't schedule this study.",
        success: 'Study scheduled.',
      );

  /// The patient is on the machine.
  Future<bool> start() => _patch(
        const RadiologyOrderDraft(status: RadiologyOrderStatus.inProgress)
            .toUpdateJson(),
        failure: "Couldn't start this study.",
        success: 'Study started.',
      );

  /// The exam has been done.
  ///
  /// `performedById` is sent explicitly, which the draft deliberately does not
  /// offer: the server stamps `reportedById` on its own but leaves this one to
  /// the client, so a study that nobody is recorded as having performed is the
  /// alternative. It is always the signed-in account and never a picked value
  /// — that distinction is the whole reason the draft declines the key.
  Future<bool> markPerformed() {
    final me = Get.isRegistered<AuthService>()
        ? (AuthService.to.currentUser?.id ?? '')
        : '';
    final performedAt = AppClock.now();

    return _patch(
      {
        ...RadiologyOrderDraft(
          status: RadiologyOrderStatus.completed,
          examPerformedAt: performedAt,
        ).toUpdateJson(),
        if (me.isNotEmpty) 'performedById': me,
      },
      failure: "Couldn't record this study as performed.",
      success: 'Study recorded as performed.',
    );
  }

  /// Stops the study, with the reason on the record.
  ///
  /// The reason is required by this screen rather than by the server: a
  /// cancelled imaging request with no reason on it is one the referring
  /// clinician has to telephone about.
  Future<bool> cancel(String reason) => _patch(
        RadiologyOrderDraft(
          status: RadiologyOrderStatus.cancelled,
          cancellationReason: reason,
        ).toUpdateJson(),
        failure: "Couldn't cancel this order.",
        success: 'Order cancelled.',
      );

  // ── Images ────────────────────────────────────────────────────────────────

  /// Posts one image and records it against the report.
  ///
  /// Two calls, because the backend files the object and answers with a URL
  /// but does not attach it to anything: the attachment is the PATCH that
  /// follows. An upload whose PATCH fails leaves an orphaned object in the
  /// bucket and no image on the report, which is why the failure is shown
  /// rather than swallowed.
  Future<bool> uploadImage(ImageOrigin origin) async {
    final current = report;
    if (current == null || isUploading.value) return false;

    actionError.value = null;
    isUploading.value = true;
    try {
      final picked = await Get.find<ImageSource>().pick(origin);
      if (picked == null) return false;

      final url = await RadiologyRepositories.reports.uploadImage(picked);
      if (url.isEmpty) {
        actionError.value = 'The server accepted the image but sent no '
            'address for it. Try again.';
        return false;
      }

      await RadiologyRepositories.reports.setImages(current.id, [
        ...current.images,
        RadiologyImage(url: url, caption: picked.filename),
      ]);
      await reload();
      return true;
    } on ApiForbiddenException catch (e) {
      actionError.value = "You don't have permission to attach images to a "
          'report.';
      AppLog.info('$runtimeType', 'upload refused: ${e.message}');
      return false;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'image upload failed', e, stack);
      actionError.value = parseErrorMessage(e, "Couldn't upload that image.");
      return false;
    } finally {
      isUploading.value = false;
    }
  }

  // ── The one write path ────────────────────────────────────────────────────

  /// Sends a PATCH, keeps the order on screen while it runs, and turns a
  /// refusal into a sentence.
  ///
  /// Returns whether it worked, so a sheet can close itself only on success —
  /// a sheet that closes over a failed write takes the error message with it.
  Future<bool> _patch(
    Map<String, dynamic> body, {
    required String failure,
    required String success,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    actionError.value = null;
    try {
      order.value = await RadiologyRepositories.orders.update(orderId, body);
      _lastMessage = success;
      return true;
    } on ApiForbiddenException catch (e) {
      // Gated on the access map and refused anyway: the map was stale. Not an
      // error banner's fault and not something a retry fixes.
      actionError.value = "You don't have permission to change this order.";
      AppLog.info('$runtimeType', 'order write refused: ${e.message}');
      return false;
    } catch (e, stack) {
      AppLog.error('$runtimeType', failure, e, stack);
      actionError.value = parseErrorMessage(e, failure);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  String _lastMessage = '';

  /// What to say after the write that just succeeded. Read once by the view,
  /// which owns every toast — a controller that raises its own is a controller
  /// that raises one in a widget test with no overlay under it.
  String takeSuccessMessage() {
    final message = _lastMessage;
    _lastMessage = '';
    return message;
  }
}
