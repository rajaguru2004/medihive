import 'package:get/get.dart';

import '../../../data/models/admission_model.dart';
import '../../../data/models/bed_model.dart';
import '../../../data/models/ward_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// The bed map for one ward.
///
/// Beds and admissions are fetched together and joined here rather than on the
/// server, because the two routes are the ones that exist — and because a bed
/// tile has to name its occupant, which the bed row alone does not carry.
class InpatientBedsGridController extends GetxController with LoadStateMixin {
  static InpatientBedsGridController get to =>
      Get.find<InpatientBedsGridController>();

  final _service = Get.find<InpatientService>();

  final wards = <WardModel>[].obs;
  final beds = <BedModel>[].obs;
  final selectedWardId = RxnString();
  final stateFilter = Rxn<BedState>();

  /// Admission by bed id, so a tile can name who is in it.
  final _occupants = <String, AdmissionModel>{}.obs;

  List<WardModel> get activeWards => wards.where((w) => w.isActive).toList();

  WardModel? get selectedWard => wards
      .firstWhereOrNull((w) => w.id == selectedWardId.value);

  /// Whether patient names may be drawn on this board.
  ///
  /// A bed map is often shown on a screen visible from a corridor or a waiting
  /// area, so the site can turn identifying text off and keep the map.
  bool get showNames => SettingsService.to.settings.showPatientNames;

  AdmissionModel? occupantOf(BedModel bed) => _occupants[bed.id];

  List<BedModel> get displayed {
    final rows = stateFilter.value == null
        ? beds.toList()
        : beds
            .where((b) => BedState.resolve(b.status) == stateFilter.value)
            .toList();

    // Bed number order, numerically where the numbers are numbers: "10" must
    // come after "9", and a lexicographic sort puts it after "1".
    rows.sort((a, b) {
      final na = int.tryParse(a.bedNumber.replaceAll(RegExp(r'\D'), ''));
      final nb = int.tryParse(b.bedNumber.replaceAll(RegExp(r'\D'), ''));
      if (na != null && nb != null && na != nb) return na.compareTo(nb);
      return a.bedNumber.compareTo(b.bedNumber);
    });
    return rows;
  }

  int countOf(BedState state) =>
      beds.where((b) => BedState.resolve(b.status) == state).length;

  @override
  void onReady() {
    super.onReady();
    final wardId = (Get.arguments as Map?)?['wardId'];
    if (wardId is String && wardId.isNotEmpty) selectedWardId.value = wardId;
    load();
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick('beds'), (_) {
        if (!isLoading) load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          final wardsResponse = await _service.fetchWards();
          wards.assignAll(
            envelopeRows(wardsResponse.data).map(WardModel.fromJson).toList(),
          );

          // Default to the first ward with beds in it rather than simply the
          // first: opening a bed map on an empty ward looks like a failure.
          if (selectedWard == null) {
            final preferred = activeWards
                    .firstWhereOrNull((w) => w.capacity > 0) ??
                activeWards.firstOrNull;
            selectedWardId.value = preferred?.id;
          }

          await _loadBedsAndOccupants();
        },
        fallback: "Couldn't load the bed map.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  Future<void> selectWard(String? wardId) async {
    selectedWardId.value = wardId;
    stateFilter.value = null;
    await runGuarded(
      _loadBedsAndOccupants,
      fallback: "Couldn't load that ward's beds.",
      silent: true,
    );
  }

  void filterByState(BedState? state) =>
      stateFilter.value = stateFilter.value == state ? null : state;

  Future<void> setBedState(BedModel bed, BedState state) async {
    // The API's vocabulary, which is not the enum's: `available`, not
    // `vacant`, and `maintenance` for anything out of service.
    final wire = switch (state) {
      BedState.vacant => 'available',
      BedState.occupied => 'occupied',
      BedState.reserved => 'reserved',
      BedState.blocked => 'maintenance',
    };

    try {
      final response = await _service.updateBedStatus(bed.id, wire);
      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        showBentoToast(
          envelopeMessage(response.data) ??
              "Couldn't update bed ${bed.bedNumber}.",
          tone: ToastTone.failure,
        );
        return;
      }

      showBentoToast('Bed ${bed.bedNumber} is now ${state.label.toLowerCase()}.');
      if (Get.isRegistered<DataBus>()) DataBus.to.changedBed();
      await load(silent: true);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't update bed ${bed.bedNumber}."),
        tone: ToastTone.failure,
      );
    }
  }

  Future<void> _loadBedsAndOccupants() async {
    final wardId = selectedWardId.value;
    if (wardId == null || wardId.isEmpty) {
      beds.clear();
      _occupants.clear();
      return;
    }

    final results = await Future.wait([
      _service.fetchBeds(wardId: wardId),
      _service.fetchAdmissions(),
    ]);

    beds.assignAll(
      envelopeRows(results[0].data).map(BedModel.fromJson).toList(),
    );

    _occupants
      ..clear()
      ..addEntries(
        envelopeRows(results[1].data)
            .map(AdmissionModel.fromJson)
            // Only live admissions claim a bed. A discharged one still names
            // the bed it was in, and letting it through paints an occupant
            // onto a bed that is free.
            .where((a) => a.status.trim().toLowerCase() == 'active')
            .where((a) => a.bedId.isNotEmpty)
            .map((a) => MapEntry(a.bedId, a)),
      );
  }
}
