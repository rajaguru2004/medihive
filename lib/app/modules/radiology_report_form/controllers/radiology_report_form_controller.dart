import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/app_log.dart';
import '../../../data/models/drafts/radiology_drafts.dart';
import '../../../data/models/radiology_order.dart';
import '../../../data/models/radiology_report.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';

/// Writing or amending a radiologist's read.
///
/// Two rules on this screen are not stylistic:
///
///   * **a critical finding needs its text and a name.** A read that found
///     something the ward must act on, with nobody recorded as having been
///     told, is the state a hospital escalates from. The switch therefore
///     opens two required fields and stamps the time.
///   * **a report that is already `final` cannot be quietly rewritten.** It
///     has been signed and acted on, so a change to it is an *amendment*, and
///     an amendment carries the reason it was made.
class RadiologyReportFormController extends GetxController with LoadStateMixin {
  static RadiologyReportFormController get to =>
      Get.find<RadiologyReportFormController>();

  /// The shortest amendment reason worth recording. "typo" is five; anything
  /// shorter is somebody getting past the field rather than answering it.
  static const int minAmendmentReason = 5;

  final formKey = GlobalKey<FormState>();

  final techniqueController = TextEditingController();
  final findingsController = TextEditingController();
  final impressionController = TextEditingController();
  final recommendationsController = TextEditingController();
  final criticalFindingsController = TextEditingController();
  final notifiedToController = TextEditingController();
  final comparisonNotesController = TextEditingController();
  final amendmentController = TextEditingController();

  final hasCriticalFindings = false.obs;
  final comparedWithPrevious = false.obs;
  final status = RadiologyReportStatus.draft.obs;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();
  final invalidFields = 0.obs;

  /// The order this read belongs to. Set on both paths — from the arguments
  /// when writing, from the report when amending.
  String orderId = '';

  /// Empty while writing a new report.
  String reportId = '';

  /// The order, for the header. Loaded so a report opened from a deep link
  /// still says whose study it is.
  final order = RadiologyOrder.empty.obs;

  /// What the server currently holds. Kept so the form can tell an amendment
  /// from an edit to a draft — the segmented control's value cannot, because
  /// it is what the user wants rather than what is stored.
  final stored = Rxn<RadiologyReport>();

  bool get isEditing => reportId.isNotEmpty;

  /// True when the stored report has been signed. Saving then records an
  /// amendment rather than an edit.
  bool get isAmending {
    final current = stored.value;
    if (current == null) return false;
    return current.isFinal || current.isAmended;
  }

  @override
  void onInit() {
    super.onInit();
    // The arguments, not the network. `isEditing` decides the header, which is
    // outside the screen's `Obx` and therefore painted exactly once — resolved
    // in `onReady` it would title an amendment "Write report" for good.
    final args = Get.arguments;
    if (args is Map) {
      final incomingOrder = args['orderId'];
      final incomingReport = args['reportId'];
      if (incomingOrder is String) orderId = incomingOrder;
      if (incomingReport is String) reportId = incomingReport;
    }
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          if (isEditing) {
            final report = await RadiologyRepositories.reports.read(reportId);
            stored.value = report;
            if (orderId.isEmpty) orderId = report.orderId;
            _fill(report);
          }

          if (orderId.isNotEmpty) {
            order.value = await RadiologyRepositories.orders.read(orderId);
          }
        },
        fallback: "Couldn't load this report.",
      );

  void _fill(RadiologyReport report) {
    techniqueController.text = report.technique ?? '';
    findingsController.text = report.findings ?? '';
    impressionController.text = report.impression ?? '';
    recommendationsController.text = report.recommendations ?? '';
    criticalFindingsController.text = report.criticalFindings ?? '';
    notifiedToController.text = report.criticalNotifiedTo ?? '';
    comparisonNotesController.text = report.comparisonNotes ?? '';
    hasCriticalFindings.value = report.hasCriticalFindings;
    comparedWithPrevious.value = report.comparedWithPrevious;
    // A signed report's segment is shown as `final` even though saving sends
    // `amended`: the control says what state the read is in, and "draft" on a
    // report the ward has already acted on would be a lie.
    status.value = report.isDraft
        ? RadiologyReportStatus.draft
        : RadiologyReportStatus.isFinal;
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateTechnique(String? value) => (value ?? '').trim().isEmpty
      ? 'Say how the study was acquired.'
      : null;

  String? validateFindings(String? value) =>
      (value ?? '').trim().isEmpty ? 'Findings are required.' : null;

  String? validateImpression(String? value) => (value ?? '').trim().isEmpty
      ? 'An impression is what the referring clinician reads.'
      : null;

  /// Only asked when the switch is on — which is the point of the switch.
  String? validateCriticalFindings(String? value) {
    if (!hasCriticalFindings.value) return null;
    return (value ?? '').trim().isEmpty
        ? 'Say what the critical finding is.'
        : null;
  }

  String? validateNotifiedTo(String? value) {
    if (!hasCriticalFindings.value) return null;
    return (value ?? '').trim().isEmpty
        ? 'Name who was told. A critical finding nobody was told about is the '
            'failure this field exists to prevent.'
        : null;
  }

  String? validateAmendment(String? value) {
    if (!isAmending) return null;
    final reason = (value ?? '').trim();
    if (reason.length < minAmendmentReason) {
      return 'Say why this signed report is being changed '
          '($minAmendmentReason characters or more).';
    }
    return null;
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  /// Writes the read and answers with true when it went through.
  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    if (!(formKey.currentState?.validate() ?? false)) {
      invalidFields.value = _invalidCount();
      return false;
    }
    invalidFields.value = 0;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      if (isEditing) {
        await RadiologyRepositories.reports.update(
          reportId,
          _draft().toUpdateJson(),
        );
      } else {
        // Two calls, and deliberately.
        //
        // `CreateRadiologyReportDto` accepts the body of the read and nothing
        // else: `status`, `criticalNotifiedTo` and `criticalNotifiedAt` are
        // update-only, and a create that sent them would be a 400 for the
        // whole report. So the read is written as the draft the server makes
        // it, and anything the create route cannot carry follows immediately.
        final created = await RadiologyRepositories.reports.create(
          _draft().toCreateJson(),
        );
        final follow = _draft(forCreatedReport: true).toUpdateJson();
        if (follow.isNotEmpty) {
          await RadiologyRepositories.reports.update(created.id, follow);
        }
      }
      return true;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'report save failed', e, stack);
      errorMessage.value = parseErrorMessage(e, "Couldn't save this report.");
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// The read, as the drafts spell it.
  ///
  /// [forCreatedReport] narrows it to the keys the create route could not
  /// take, so the PATCH that follows a create is not a second full write of
  /// the same text.
  RadiologyReportDraft _draft({bool forCreatedReport = false}) {
    final critical = hasCriticalFindings.value;
    final told = notifiedToController.text.trim();

    // Stamped by this screen rather than by the server, which does not:
    // `criticalNotifiedAt` is whatever the client sends. It is set the moment
    // a name is recorded, because "who was told" and "when" are one fact.
    final notifiedAt = critical && told.isNotEmpty
        ? (stored.value?.criticalNotifiedAt ?? AppClock.now())
        : null;

    final outgoingStatus = isAmending
        ? RadiologyReportStatus.amended
        : status.value;

    if (forCreatedReport) {
      return RadiologyReportDraft(
        criticalNotifiedTo: critical ? told : null,
        criticalNotifiedAt: notifiedAt,
        // Only when it is not the draft the server already made it.
        status: outgoingStatus == RadiologyReportStatus.draft
            ? null
            : outgoingStatus,
      );
    }

    return RadiologyReportDraft(
      orderId: isEditing ? null : orderId,
      technique: techniqueController.text,
      findings: findingsController.text,
      impression: impressionController.text,
      recommendations: recommendationsController.text,
      // The flag is what every screen reads, and it is a `bool`, so `false`
      // travels where a blanked string would not: `draftBody` drops empty
      // strings precisely so a PATCH cannot wipe a field the form never
      // touched. Switching the toggle off therefore says "not critical" and
      // leaves the old text in the column unread rather than half-erasing the
      // record.
      hasCriticalFindings: critical,
      criticalFindings: critical ? criticalFindingsController.text : null,
      comparedWithPrevious: comparedWithPrevious.value,
      comparisonNotes:
          comparedWithPrevious.value ? comparisonNotesController.text : null,
      criticalNotifiedTo: critical ? told : null,
      criticalNotifiedAt: notifiedAt,
      status: outgoingStatus,
      amendmentReason: isAmending ? amendmentController.text : null,
    );
  }

  int _invalidCount() {
    var count = 0;
    if (techniqueController.text.trim().isEmpty) count++;
    if (findingsController.text.trim().isEmpty) count++;
    if (impressionController.text.trim().isEmpty) count++;
    if (hasCriticalFindings.value) {
      if (criticalFindingsController.text.trim().isEmpty) count++;
      if (notifiedToController.text.trim().isEmpty) count++;
    }
    if (isAmending &&
        amendmentController.text.trim().length < minAmendmentReason) {
      count++;
    }
    return count;
  }

  @override
  void onClose() {
    techniqueController.dispose();
    findingsController.dispose();
    impressionController.dispose();
    recommendationsController.dispose();
    criticalFindingsController.dispose();
    notifiedToController.dispose();
    comparisonNotesController.dispose();
    amendmentController.dispose();
    super.onClose();
  }
}
