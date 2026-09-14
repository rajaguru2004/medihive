import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/app_clock.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/lab_drafts.dart';
import '../../../data/models/lab_order.dart';
import '../../../data/models/lab_result.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/laboratory_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../laboratory/lab_status.dart';

/// One laboratory order: where the sample got to, and what came back.
class LabOrderDetailController extends GetxController with LoadStateMixin {
  static LabOrderDetailController get to =>
      Get.find<LabOrderDetailController>();

  static const LaboratoryService _lab = LaboratoryService();

  final order = LabOrder.empty.obs;
  final results = <LabResult>[].obs;

  /// True when the order could not be found at all — a stale deep link, or a
  /// record somebody removed. Distinct from an error: there is nothing to
  /// retry.
  final missing = false.obs;

  /// Guards the action bar while a write is in flight, so a double tap does
  /// not log a sample twice.
  final isWorking = false.obs;

  late final String id;

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final args = argument is Map ? argument : const {};

    final passed = args['order'];
    if (passed is LabOrder) order.value = passed;

    // The route parameter first: it is the only source a deep link has. The
    // argument is the fast path — the worklist already holds the whole record,
    // so the screen paints before the refetch lands.
    final fromArgs = args['orderId'];
    id = Get.parameters['id'] ??
        (fromArgs is String && fromArgs.isNotEmpty ? fromArgs : order.value.id);
  }

  @override
  void onReady() {
    super.onReady();
    load();

    if (Get.isRegistered<DataBus>()) {
      // How this screen hears that the result form saved something. Never by
      // reaching into that controller, and never by awaiting `Get.toNamed` —
      // which completes when the pushed route is *popped* and hangs anything
      // that then wants to pop it.
      //
      // Guarded on the writes this screen makes itself: those already reload
      // when they finish, and a second pass would be the same two requests
      // again.
      ever<int>(DataBus.to.tick(LabResultRepository.entityName), (_) {
        if (isWorking.value || isLoading) return;
        load(silent: true);
      });
    }
  }

  bool get canUpdate =>
      AccessService.to.can(Modules.laboratory, AccessVerb.update);

  bool get canCreateResult =>
      AccessService.to.can(Modules.laboratory, AccessVerb.create);

  /// Results keyed by the test they belong to, for pairing with the ordered
  /// tests the order carries.
  Map<String, LabResult> get resultsByTest => {
        for (final result in results) result.testId: result,
      };

  /// Results that are critical and that nobody has signed off yet.
  ///
  /// Unverified deliberately: a critical value that a senior has already seen
  /// and released is a result, not an alarm, and leaving the banner up after
  /// it is handled is how a banner becomes wallpaper.
  List<LabResult> get unhandledCritical =>
      results.where((r) => r.isCritical && !r.isVerified).toList();

  bool get canCollect =>
      canUpdate && order.value.status == LabOrderStatus.pending;

  bool get canReject => canUpdate && LabOrderStatus.isOpen(order.value.status);

  /// Completing is a claim that every result is in. Offered only once at least
  /// one is, and only while the order is still open.
  bool get canComplete =>
      canUpdate &&
      LabOrderStatus.isOpen(order.value.status) &&
      order.value.status != LabOrderStatus.pending &&
      results.isNotEmpty;

  /// A result may be entered once there is a sample to run it on.
  bool get canEnterResults =>
      canCreateResult &&
      LabOrderStatus.isOpen(order.value.status) &&
      order.value.status != LabOrderStatus.pending;

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          missing.value = false;

          final known = order.value.orderNumber;
          final fetched = await _lab.orders.find(
            id,
            orderNumber: known.isEmpty ? null : known,
          );
          if (fetched != null) {
            order.value = fetched;
          } else if (order.value.isEmpty) {
            missing.value = true;
            return;
          }

          results.assignAll(await _lab.results.forOrder(id));
        },
        fallback: "Couldn't load that order.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  /// Logs the sample against the order.
  ///
  /// [accession] is sent, and this backend may replace it: on the move to
  /// `sample_collected` it mints its own unique accession when the order has
  /// none and drops the client's value when it already has one. The toast
  /// reads back whatever was actually stored, so nobody walks away with a
  /// number that is only on their screen.
  Future<void> collectSample({String accession = ''}) => _patchOrder(
        LabOrderDraft(
          status: LabOrderStatus.sampleCollected,
          sampleCollectedAt: AppClock.now(),
          sampleCollectedById: AuthService.to.currentUser?.id,
          accessionNumber: accession,
        ),
        onDone: () {
          final stored = order.value.accessionNumber ?? '';
          showBentoToast(
            stored.isEmpty
                ? 'Sample logged.'
                : 'Sample logged — accession $stored.',
          );
        },
      );

  Future<void> rejectSample(String reason) => _patchOrder(
        LabOrderDraft(
          status: LabOrderStatus.rejected,
          rejectionReason: reason,
        ),
        onDone: () => showBentoToast(
          'Sample rejected. The requester has to send another.',
          tone: ToastTone.info,
        ),
      );

  Future<void> completeOrder() => _patchOrder(
        const LabOrderDraft(status: LabOrderStatus.completed),
        onDone: () => showBentoToast('Order completed.'),
      );

  /// Signs off one result.
  ///
  /// The server fills the verifier from the token and completes the order once
  /// every result on it is verified, so this screen reloads rather than
  /// assuming what changed.
  Future<void> verifyResult(LabResult result) async {
    if (isWorking.value) return;
    isWorking.value = true;
    try {
      await _lab.results.update(
        result.id,
        LabResultDraft(
          verifiedAt: AppClock.now(),
          verifiedById: AuthService.to.currentUser?.id,
        ).toUpdateJson(),
      );
      await load(silent: true);
      showBentoToast('Result verified.');
    } on ApiForbiddenException catch (e) {
      showBentoToast(e.message, tone: ToastTone.failure);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't verify that result."),
        tone: ToastTone.failure,
      );
    } finally {
      isWorking.value = false;
    }
  }

  Future<void> _patchOrder(
    LabOrderDraft draft, {
    required VoidCallback onDone,
  }) async {
    if (isWorking.value) return;
    isWorking.value = true;
    try {
      await _lab.orders.update(id, draft.toUpdateJson());
      await load(silent: true);
      onDone();
    } on ApiForbiddenException catch (e) {
      // The button was drawn from the access map, which can be a minute older
      // than the role it describes. A refusal is a sentence, not a crash.
      showBentoToast(e.message, tone: ToastTone.failure);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't update that order."),
        tone: ToastTone.failure,
      );
    } finally {
      isWorking.value = false;
    }
  }
}
