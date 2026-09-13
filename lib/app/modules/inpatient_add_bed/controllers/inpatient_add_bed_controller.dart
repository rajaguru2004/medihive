import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/ward_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// Add a bed to a ward.
class InpatientAddBedController extends GetxController with LoadStateMixin {
  static InpatientAddBedController get to =>
      Get.find<InpatientAddBedController>();

  final _service = Get.find<InpatientService>();

  final formKey = GlobalKey<FormState>();
  final bedNumberController = TextEditingController();

  final wards = <WardModel>[].obs;
  final wardId = RxnString();
  final type = 'Standard'.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// Bed types, and what the API calls each one.
  ///
  /// The map is the whole reason this is not a plain list: the UI says
  /// "ICU spec" and the API stores `icu`, and a screen that sends its own
  /// label creates a bed nothing can filter on.
  static const typeApiValues = <String, String>{
    'Standard': 'standard',
    'ICU spec': 'icu',
    'Electric adjustable': 'electric',
    'Pediatric crib': 'crib',
  };

  static List<String> get types => typeApiValues.keys.toList();

  List<WardModel> get activeWards => wards.where((w) => w.isActive).toList();

  WardModel? get ward =>
      wards.firstWhereOrNull((w) => w.id == wardId.value);

  @override
  void onReady() {
    super.onReady();

    final argument = Get.arguments;
    final incoming = argument is Map ? argument['wardId'] : null;
    if (incoming is String && incoming.isNotEmpty) wardId.value = incoming;

    loadWards();
  }

  Future<void> loadWards() => runGuarded(
        () async {
          final response = await _service.fetchWards();
          wards.assignAll(
            envelopeRows(response.data).map(WardModel.fromJson).toList(),
          );
          // Only default when the caller did not name a ward, and only when
          // there is exactly one — picking one of nine for somebody is how a
          // bed lands in the wrong ward.
          if (wardId.value == null && activeWards.length == 1) {
            wardId.value = activeWards.first.id;
          }
        },
        fallback: "Couldn't load the wards.",
      );

  String? validateBedNumber(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Give the bed a number';

    // Caught here rather than by the server, because the server's duplicate
    // error names a constraint and this names the bed.
    final taken = ward?.beds.any(
          (b) => b.bedNumber.trim().toLowerCase() == text.toLowerCase(),
        ) ??
        false;
    if (taken) return 'That bed number is already used in this ward';
    return null;
  }

  Future<void> save() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (wardId.value == null) {
      errorMessage.value = 'Choose which ward this bed is in.';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final number = bedNumberController.text.trim();

    try {
      final response = await _service.createBed(
        wardId: wardId.value!,
        bedNumber: number,
        type: typeApiValues[type.value] ?? 'standard',
        // A new bed is free. Creating it occupied would claim a patient is in
        // a bed that was invented ten seconds ago.
        status: 'available',
      );

      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        errorMessage.value =
            envelopeMessage(response.data) ?? "Couldn't add the bed.";
        return;
      }

      if (Get.isRegistered<DataBus>()) DataBus.to.changedBed();
      Get.back<void>();
      showBentoToast('Bed $number added to ${ward?.name ?? 'the ward'}.');
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't add the bed.");
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    bedNumberController.dispose();
    super.onClose();
  }
}
