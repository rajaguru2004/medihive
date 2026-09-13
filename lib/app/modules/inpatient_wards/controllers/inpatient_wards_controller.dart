import 'package:get/get.dart';

import '../../../data/models/ward_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// Every ward, including the ones out of service.
///
/// The overview shows only active wards because that is what a bed manager
/// plans against; this screen is where the estate is *managed*, so an inactive
/// ward has to be visible to be brought back.
class InpatientWardsController extends GetxController with LoadStateMixin {
  static InpatientWardsController get to =>
      Get.find<InpatientWardsController>();

  final _service = Get.find<InpatientService>();

  final wards = <WardModel>[].obs;
  final showInactive = false.obs;

  List<WardModel> get displayed {
    final rows =
        showInactive.value ? wards.toList() : wards.where((w) => w.isActive).toList();
    // Fullest first: the ward with no beds left is the one somebody is about
    // to have a problem with.
    rows.sort((a, b) => a.availableBeds.compareTo(b.availableBeds));
    return rows;
  }

  int get inactiveCount => wards.where((w) => !w.isActive).length;

  @override
  void onReady() {
    super.onReady();
    load();
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick('wards'), (_) {
        if (!isLoading) load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          final response = await _service.fetchWards();
          wards.assignAll(
            envelopeRows(response.data).map(WardModel.fromJson).toList(),
          );
        },
        fallback: "Couldn't load the wards.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  void toggleInactive() => showInactive.toggle();

  Future<void> setActive(WardModel ward, {required bool active}) async {
    try {
      final response = await _service.updateWardStatus(ward.id, active);
      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        showBentoToast(
          envelopeMessage(response.data) ?? "Couldn't update ${ward.name}.",
          tone: ToastTone.failure,
        );
        return;
      }

      showBentoToast(
        active
            ? '${ward.name} is back in service.'
            : '${ward.name} is out of service.',
      );
      if (Get.isRegistered<DataBus>()) DataBus.to.changedBed();
      await load(silent: true);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't update ${ward.name}."),
        tone: ToastTone.failure,
      );
    }
  }
}
