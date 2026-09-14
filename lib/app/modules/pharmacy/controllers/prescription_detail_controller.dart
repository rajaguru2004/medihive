import 'package:get/get.dart';

import '../../../core/keys/pharmacy_keys.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/pharmacy_drafts.dart';
import '../../../data/models/prescription.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/pharmacy_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../pharmacy_routes.dart';

/// One prescription, as the counter reads it.
///
/// There is no `GET /api/pharmacy/prescriptions/:id` — the module mounts the
/// collection and nothing under it — so a record handed over in `Get.arguments`
/// is used as it stands, and a deep link falls back to finding it in the list.
/// That fallback is a whole collection for one row, which is why the hub always
/// passes the record it already has.
class PrescriptionDetailController extends GetxController with LoadStateMixin {
  static PrescriptionDetailController get to =>
      Get.find<PrescriptionDetailController>();

  final _service = PharmacyService.instance;

  final prescription = Prescription.empty.obs;
  final cancelling = false.obs;

  /// The id this screen was opened for, whether by path or by argument.
  late final String id = _resolveId();

  bool get canUpdate =>
      AccessService.to.can(Modules.pharmacy, AccessVerb.update);

  /// Nothing to dispense once it is cancelled or already fully out.
  bool get canDispense =>
      canUpdate && prescription.value.isOutstanding && !prescription.value.isEmpty;

  /// True when the id resolved to nothing — a link to a prescription that has
  /// since been deleted, or a bad path.
  bool get isMissing => isIdle && prescription.value.isEmpty;

  @override
  void onInit() {
    super.onInit();
    final handed = _handedOver();
    if (handed != null) prescription.value = handed;
  }

  @override
  void onReady() {
    super.onReady();
    // Only when nothing was handed over. Refetching a record the caller just
    // read would cost a round trip to learn what the screen is already showing.
    if (prescription.value.isEmpty) load();
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          if (id.isEmpty) return;
          final rows = await _service.prescriptions();
          prescription.value = rows.firstWhere(
            (row) => row.id == id,
            orElse: () => Prescription.empty,
          );
        },
        fallback: "Couldn't load that prescription.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  /// Opens the dispense screen, carrying the record so it does not have to be
  /// found again.
  void openDispense() {
    final record = prescription.value;
    if (record.isEmpty) return;
    Get.toNamed<void>(
      PharmacyRoutes.dispenseFor(record.id),
      arguments: {'prescription': record},
    );
  }

  /// Cancels the prescription after a confirm that names the patient.
  ///
  /// Not a delete: a cancelled prescription stays on the patient's record, and
  /// the counter needs to be able to see that it was written and not handed
  /// over.
  Future<void> cancel() async {
    final record = prescription.value;
    if (record.isEmpty || cancelling.value) return;

    final confirmed = await Get.dialog<bool>(
      ConfirmDialog(
        title: 'Cancel this prescription?',
        message: 'Nothing is dispensed for ${record.patient.displayName}, and '
            'the prescription stays on their record as cancelled.',
        confirmLabel: 'Cancel prescription',
        cancelLabel: 'Keep it',
        destructive: true,
        confirmKey: PharmacyKeys.cancelConfirm,
      ),
    );
    if (confirmed != true) return;

    cancelling.value = true;
    try {
      await _service.updatePrescription(
        record.id,
        const PrescriptionDraft(status: 'cancelled'),
      );
      // The screen behind this one is unchanged and there is nothing to retry,
      // which is the one case a toast is the right shape for.
      showBentoToast('Prescription cancelled.');
      await load(silent: true);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't cancel that prescription."),
        tone: ToastTone.failure,
      );
    } finally {
      cancelling.value = false;
    }
  }

  Prescription? _handedOver() {
    final args = Get.arguments;
    if (args is Prescription) return args;
    if (args is Map && args['prescription'] is Prescription) {
      return args['prescription'] as Prescription;
    }
    return null;
  }

  String _resolveId() {
    final handed = _handedOver();
    if (handed != null && handed.id.isNotEmpty) return handed.id;
    final fromPath = Get.parameters['id'];
    if (fromPath != null && fromPath.isNotEmpty) return fromPath;
    final args = Get.arguments;
    if (args is Map && args['id'] is String) return args['id'] as String;
    return '';
  }
}
