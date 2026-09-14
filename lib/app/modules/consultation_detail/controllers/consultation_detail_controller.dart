import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/models/consultation_record.dart';
import '../../../data/models/json.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/models/vitals_reading.dart';
import '../../../data/repositories/clinical_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/formatters.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../consultations/consultation_routes.dart';

/// One consultation, as the encounter left it.
///
/// The record and everything it produced arrive together: `GET
/// /api/consultations/:id` populates the prescriptions and both kinds of order,
/// and neither order route accepts a `consultationId` filter — so this is one
/// request rather than three, and the joins are the server's rather than the
/// app's guess at them.
class ConsultationDetailController extends GetxController with LoadStateMixin {
  static ConsultationDetailController get to =>
      Get.find<ConsultationDetailController>();

  static const _consultations = ConsultationRepository();

  final record = Rxn<ConsultationRecord>();
  final isActing = false.obs;

  String _id = '';

  String get id => _id;

  // ── Access ────────────────────────────────────────────────────────────────
  //
  // Hints, not permissions. Every write below still handles the 403 that can
  // arrive anyway, because the map in hand can be older than the role.

  bool _can(String module, AccessVerb verb) =>
      !Get.isRegistered<AccessService>() ||
      AccessService.to.can(module, verb);

  bool get canUpdate => _can(Modules.consultations, AccessVerb.update);
  bool get canDelete => _can(Modules.consultations, AccessVerb.delete);
  bool get canOrderLab => _can(Modules.laboratory, AccessVerb.create);
  bool get canOrderImaging => _can(Modules.radiology, AccessVerb.create);
  bool get canInvoice => _can(Modules.billing, AccessVerb.create);

  /// Whether this account has anything at all to do here. False means the
  /// screen shows a sentence instead of an empty row of buttons.
  bool get hasActions =>
      canUpdate || canDelete || canOrderLab || canOrderImaging || canInvoice;

  // ── Site conventions ──────────────────────────────────────────────────────

  static SiteSettings get _site => Get.isRegistered<SettingsService>()
      ? SettingsService.to.settings
      : SiteSettings.empty;

  String formatDate(DateTime? value) =>
      value == null ? '—' : Formatters.date(value, pattern: _site.dateFormat);

  // ── The record ────────────────────────────────────────────────────────────

  String get patientName =>
      record.value?.consultation.patient.fullName.trim().isNotEmpty ?? false
          ? record.value!.consultation.patient.fullName
          : 'this patient';

  String get patientId => record.value?.consultation.patientId ?? '';

  /// The observations, judged once. The same object the form builds while the
  /// readings are typed, so the warning here is the warning there.
  VitalsReading get reading {
    final consultation = record.value?.consultation;
    return consultation == null
        ? const VitalsReading()
        : VitalsReading.ofConsultation(consultation);
  }

  /// The coded diagnosis. The column holds JSON text, so a read comes back as a
  /// string however it was written.
  List<String> get icdCodes =>
      asStringList(record.value?.consultation.icd10Codes);

  /// What this visit is called, in words.
  ///
  /// `follow_up` and `followup` both arrive from this backend and neither is a
  /// word. A visit type is a category, not a clinical state, so it takes one
  /// neutral tint and the word carries it.
  String get visitTypeLabel {
    final raw = record.value?.consultation.visitType ?? '';
    return switch (raw.trim().toLowerCase().replaceAll('_', '')) {
      'followup' => 'Follow-up',
      'outpatient' => 'Outpatient',
      'inpatient' => 'Inpatient',
      'emergency' => 'Emergency',
      '' => '—',
      _ => Formatters.label(raw),
    };
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _id = ConsultationRoutes.idFrom(Get.arguments, Get.parameters);
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          record.value = await _consultations.record(_id);
        },
        fallback: "Couldn't open that consultation.",
      );

  /// Never `refresh()` — `GetxController.refresh()` exists and returns void, so
  /// an `onRefresh:` wired to it silently never awaits.
  Future<void> reload() => load();

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Removes the record.
  ///
  /// The route answers **204 with an empty body**; `ApiEnvelope` reads a 2xx
  /// with nothing in it as a success with a null payload, which is what makes
  /// this not throw on every successful delete.
  Future<void> remove() async {
    if (isActing.value) return;
    isActing.value = true;
    try {
      await _consultations.delete(_id);
      Get.back<void>();
      showBentoToast("$patientName's consultation is deleted.");
    } on ApiForbiddenException catch (e) {
      showBentoToast(e.message, tone: ToastTone.failure);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't delete that consultation."),
        tone: ToastTone.failure,
      );
    } finally {
      isActing.value = false;
    }
  }

  /// What another module needs to raise something against this encounter.
  Map<String, dynamic> get linkArguments => {
        'patientId': patientId,
        'consultationId': _id,
      };
}
