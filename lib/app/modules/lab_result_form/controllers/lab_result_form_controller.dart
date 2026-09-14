import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/drafts/lab_drafts.dart';
import '../../../data/models/lab_test.dart';
import '../../../data/services/laboratory_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../laboratory/lab_status.dart';

/// Entering one result against one ordered test.
class LabResultFormController extends GetxController with LoadStateMixin {
  static LabResultFormController get to => Get.find<LabResultFormController>();

  static const LaboratoryService _lab = LaboratoryService();

  /// A qualitative result's two answers, stored as the words themselves —
  /// `resultValue` is a text column precisely so it can hold `Negative`.
  static const List<String> qualitativeAnswers = ['Positive', 'Negative'];

  final formKey = GlobalKey<FormState>();

  final valueController = TextEditingController();
  final unitController = TextEditingController();
  final commentController = TextEditingController();

  final flag = LabResultFlag.normal.obs;
  final isAbnormal = false.obs;
  final isCritical = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// The catalogue entry behind the ordered test — where the result type, the
  /// unit and the reference ranges live. `LabOrder.tests` carries only the
  /// name and the code, because it is a snapshot of what was asked for.
  final test = LabTest.empty.obs;

  String orderId = '';
  String orderNumber = '';
  String testId = '';
  String testName = '';

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final args = argument is Map ? argument : const {};

    orderId = _stringArg(args['orderId']);
    orderNumber = _stringArg(args['orderNumber']);
    testId = _stringArg(args['testId']);
    testName = _stringArg(args['testName']);
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(loadTest());
  }

  /// `numeric`, `text`, `positive_negative`, `select` — what shape the value
  /// field takes. Falls back to free text, which accepts everything the column
  /// can hold.
  String get resultType => (test.value.resultType ?? '').trim().toLowerCase();

  bool get isNumeric => resultType == 'numeric';

  bool get isQualitative => resultType == 'positive_negative';

  /// The ranges to put beside the input, so the person typing can see what
  /// they are typing against.
  List<LabReferenceRange> get referenceRanges => test.value.referenceRanges;

  /// The catalogue's own unit, for the toast and the hint.
  String get catalogueUnit => (test.value.unit ?? '').trim();

  Future<void> loadTest() => runGuarded(
        () async {
          final page = await _lab.tests.list(const PagedQuery(limit: 100));
          final match =
              page.items.firstWhereOrNull((entry) => entry.id == testId);
          if (match == null) return;

          test.value = match;
          // Prefilled, not fixed: the unit on the report is the unit the
          // analyser printed, and a site that runs the same assay two ways
          // has to be able to say so.
          if (unitController.text.trim().isEmpty) {
            unitController.text = match.unit ?? '';
          }
        },
        fallback: "Couldn't load that test's reference ranges.",
      );

  // ── The three things that must agree ──────────────────────────────────────
  //
  // A flag of `N` stored beside `isAbnormal: true` is a result that reads
  // normal on one screen and abnormal on the next. They are one statement said
  // three ways, so setting any of them settles the other two.

  void setFlag(String value) {
    flag.value = value;
    if (LabResultFlag.isNormal(value)) {
      isAbnormal.value = false;
      isCritical.value = false;
      return;
    }
    isAbnormal.value = true;
  }

  void setAbnormal(bool value) {
    isAbnormal.value = value;
    if (value) {
      if (LabResultFlag.isNormal(flag.value)) {
        flag.value = LabResultFlag.abnormal;
      }
      return;
    }
    // Nothing can be critical and within range at once.
    isCritical.value = false;
    flag.value = LabResultFlag.normal;
  }

  /// Critical forces abnormal on, and never the other way round: a value
  /// serious enough to telephone the ward is by definition out of range, and a
  /// result stored critical-but-normal is one a report would print as fine.
  void setCritical(bool value) {
    isCritical.value = value;
    if (!value) return;
    isAbnormal.value = true;
    if (LabResultFlag.isNormal(flag.value)) {
      flag.value = LabResultFlag.abnormal;
    }
  }

  void chooseAnswer(String answer) => valueController.text = answer;

  String? validateValue(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the result';
    if (isNumeric && double.tryParse(text) == null) {
      // Only for a test the catalogue calls numeric. The column holds `>1000`
      // and `Negative` as well, and rejecting those on every test would make
      // half the catalogue unenterable.
      return 'That is not a number — use a text test for "<0.5" or "Negative"';
    }
    return null;
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (orderId.isEmpty || testId.isEmpty) {
      errorMessage.value =
          'This result is not attached to an order. Open it from the order.';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final draft = LabResultDraft(
      orderId: orderId,
      testId: testId,
      resultValue: valueController.text,
      resultUnit: unitController.text,
      isAbnormal: isAbnormal.value,
      isCritical: isCritical.value,
      flag: flag.value,
      comment: commentController.text,
    );

    try {
      await _lab.results.create(draft.toCreateJson());
      final critical = isCritical.value;
      Get.back<void>();
      showBentoToast(
        critical
            ? 'Critical result saved for $testName. Tell the ward — this list '
                'will not.'
            : 'Result saved for $testName.',
        tone: critical ? ToastTone.info : ToastTone.success,
        // Longer, because it asks for something to be done rather than
        // reporting that something was.
        duration: Duration(seconds: critical ? 6 : 3),
      );
    } on ApiForbiddenException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = parseErrorMessage(e, "Couldn't save that result.");
    } finally {
      isSubmitting.value = false;
    }
  }

  static String _stringArg(Object? value) =>
      value is String ? value.trim() : '';

  @override
  void onClose() {
    valueController.dispose();
    unitController.dispose();
    commentController.dispose();
    super.onClose();
  }
}
