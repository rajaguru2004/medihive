import 'package:get/get.dart';

import '../../../data/models/ward_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// The estate's headline numbers.
class InpatientStats {
  const InpatientStats({
    this.totalBeds = 0,
    this.occupiedBeds = 0,
    this.availableBeds = 0,
    this.todayAdmissions = 0,
    this.todayDischarges = 0,
    this.occupancyRate = 0,
  });

  final int totalBeds;
  final int occupiedBeds;
  final int availableBeds;
  final int todayAdmissions;
  final int todayDischarges;
  final double occupancyRate;

  /// Beds accounted for by neither of the two counts the server sends.
  ///
  /// Reserved and blocked beds are the difference, and a ward board that
  /// silently folds them into "available" is a board that offers a bed nobody
  /// can use.
  int get otherBeds {
    final rest = totalBeds - occupiedBeds - availableBeds;
    return rest > 0 ? rest : 0;
  }

  factory InpatientStats.fromJson(Map<String, dynamic> json) => InpatientStats(
        totalBeds: (json['totalBeds'] as num?)?.toInt() ?? 0,
        occupiedBeds: (json['occupiedBeds'] as num?)?.toInt() ?? 0,
        availableBeds: (json['availableBeds'] as num?)?.toInt() ?? 0,
        todayAdmissions: (json['todayAdmissions'] as num?)?.toInt() ?? 0,
        todayDischarges: (json['todayDischarges'] as num?)?.toInt() ?? 0,
        occupancyRate: (json['occupancyRate'] as num?)?.toDouble() ?? 0,
      );
}

/// The inpatient estate: capacity, wards, and the way into the bed map.
///
/// The previous version of this controller drove four sub-screens by asking
/// each of their controllers to refresh whenever its own tab changed. That is
/// backwards — a parent reaching into four children is how one tab switch
/// costs four requests — so each sub-screen now owns its own data and hears
/// about changes through the `DataBus`.
class InpatientController extends GetxController with LoadStateMixin {
  static InpatientController get to => Get.find<InpatientController>();

  final _service = Get.find<InpatientService>();

  final stats = const InpatientStats().obs;
  final wards = <WardModel>[].obs;

  List<WardModel> get activeWards =>
      wards.where((w) => w.isActive).toList();

  /// Wards at or over capacity. What a bed manager is looking for.
  List<WardModel> get fullWards =>
      activeWards.where((w) => w.availableBeds <= 0).toList();

  @override
  void onReady() {
    super.onReady();
    load();
    if (Get.isRegistered<DataBus>()) {
      for (final entity in const ['beds', 'wards', 'admissions']) {
        ever<int>(DataBus.to.tick(entity), (_) {
          if (!isLoading) load(silent: true);
        });
      }
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          final results = await Future.wait([
            _service.fetchStats(),
            _service.fetchWards(),
          ]);

          final statsBody = results[0].data;
          if (statsBody is Map && statsBody['success'] == true) {
            final payload = statsBody['data'];
            if (payload is Map) {
              stats.value =
                  InpatientStats.fromJson(payload.cast<String, dynamic>());
            }
          }

          final wardsBody = results[1].data;
          if (wardsBody is Map && wardsBody['success'] == true) {
            final rows = wardsBody['data'];
            if (rows is List) {
              wards.assignAll(
                rows
                    .whereType<Map>()
                    .map((e) => WardModel.fromJson(e.cast<String, dynamic>()))
                    .toList(),
              );
            }
          }
        },
        fallback: "Couldn't load the ward estate.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  /// Takes a ward out of service.
  ///
  /// Not a delete: an inactive ward keeps its history, its beds and its past
  /// admissions, and a bed manager reactivates it when the refurbishment is
  /// done.
  Future<void> deactivateWard(WardModel ward) async {
    try {
      final response = await _service.updateWardStatus(ward.id, false);
      final body = response.data;
      final envelope = body is Map ? body.cast<String, dynamic>() : null;

      if (envelope?['success'] != true) {
        showBentoToast(
          envelope?['message'] as String? ??
              "Couldn't take ${ward.name} out of service.",
          tone: ToastTone.failure,
        );
        return;
      }

      showBentoToast('${ward.name} is out of service.');
      if (Get.isRegistered<DataBus>()) DataBus.to.changedBed();
      await load(silent: true);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't take ${ward.name} out of service."),
        tone: ToastTone.failure,
      );
    }
  }
}
