import 'package:get/get.dart';

import '../../../data/models/pre_triage_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/pre_triage_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// One screening.
///
/// Takes an id and fetches, rather than taking the model the list already has.
/// The list row is a snapshot from whenever the board last loaded; this screen
/// is where somebody decides what happens to a patient, so it reads the record
/// again. A model passed in is used only as the first paint, so the screen is
/// never blank while that fetch runs.
class PreTriageDetailsController extends GetxController with LoadStateMixin {
  static PreTriageDetailsController get to =>
      Get.find<PreTriageDetailsController>();

  final _service = PreTriageService.to;

  final screening = Rxn<PreTriageModel>();
  final isActing = false.obs;

  String? _id;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is PreTriageModel) {
      screening.value = argument;
      _id = argument.id;
    } else if (argument is Map) {
      final seed = argument['screening'];
      if (seed is PreTriageModel) screening.value = seed;
      final id = argument['id'];
      _id = id is String ? id : seed is PreTriageModel ? seed.id : null;
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (_id != null) load();
  }

  /// Whether this screening can still be acted on.
  bool get isOpen => screening.value?.status == 'screening';

  Future<void> load({bool silent = true}) => runGuarded(
        () async {
          final response = await _service.fetchScreeningById(_id!);
          final object = envelopeObject(response.data);
          if (object.isNotEmpty) {
            screening.value = PreTriageModel.fromJson(object);
          }
        },
        fallback: "Couldn't refresh this screening.",
        // Silent by default: the seeded model is already on screen, and
        // replacing it with a skeleton to fetch the same record reads as a
        // flicker rather than as progress.
        silent: silent,
      );

  /// Turns the screening into a patient record.
  Future<void> convertToPatient() async {
    final record = screening.value;
    if (record == null || isActing.value) return;

    isActing.value = true;
    try {
      final response = await _service.convertToPatient(record.id);
      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        showBentoToast(
          envelopeMessage(response.data) ??
              "Couldn't register ${record.fullName}.",
          tone: ToastTone.failure,
        );
        return;
      }

      showBentoToast('${record.fullName} is now a registered patient.');
      if (Get.isRegistered<DataBus>()) {
        DataBus.to.changed(['pre-triage', 'patients', DataBus.summary]);
      }
      await load();
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't register ${record.fullName}."),
        tone: ToastTone.failure,
      );
    } finally {
      isActing.value = false;
    }
  }

  Future<void> deleteScreening() async {
    final record = screening.value;
    if (record == null || isActing.value) return;

    isActing.value = true;
    try {
      final response = await _service.deleteScreening(record.id);
      if (!envelopeOk(response.data, statusCode: response.statusCode)) {
        showBentoToast(
          envelopeMessage(response.data) ?? "Couldn't delete the screening.",
          tone: ToastTone.failure,
        );
        return;
      }

      if (Get.isRegistered<DataBus>()) {
        DataBus.to.changedRecord('pre-triage');
      }
      Get.back<void>();
      showBentoToast('Screening deleted.');
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't delete the screening."),
        tone: ToastTone.failure,
      );
    } finally {
      isActing.value = false;
    }
  }
}
