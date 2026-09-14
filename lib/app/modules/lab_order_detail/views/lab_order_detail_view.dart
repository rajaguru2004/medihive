import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/laboratory_keys.dart';
import '../../../data/models/lab_order.dart';
import '../../../data/models/lab_result.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../laboratory/lab_status.dart';
import '../../laboratory/laboratory_routes.dart';
import '../controllers/lab_order_detail_controller.dart';

/// One laboratory order, and everything that can be done to it.
class LabOrderDetailView extends GetView<LabOrderDetailController> {
  const LabOrderDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`; a `GetView` that never touches it never
    // builds the controller, and `onReady` never runs.
    final detail = controller;

    return Scaffold(
      key: LaboratoryKeys.orderDetailScreen,
      // `DetailHeader` is a `PreferredSizeWidget` and an `Obx` is not, so the
      // reactive half sits inside a `PreferredSize` of the same height. The
      // title is worth the wrapper: a deep link arrives with nothing but an
      // id, and a header reading "Lab order" for the whole first load is a
      // screen that cannot say which order it is.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Obx(
          () => DetailHeader(
            title: detail.order.value.orderNumber.isEmpty
                ? 'Lab order'
                : detail.order.value.orderNumber,
            subtitle: Formatters.dateTime(detail.order.value.orderDate),
          ),
        ),
      ),
      body: Obx(() {
        if (detail.isLoading && detail.rxFirstLoad.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 5)),
            ],
          );
        }

        if (detail.hasNoAccess) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Not available to your role',
                  message: 'Ask an administrator if you need to work lab '
                      'orders.',
                ),
              ),
            ],
          );
        }

        if (detail.missing.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'That order is not here',
                  message: 'Open it from the laboratory worklist — it may have '
                      'been cancelled, or it belongs to another site.',
                ),
              ),
            ],
          );
        }

        return _body(context, detail);
      }),
    );
  }

  Widget _body(BuildContext context, LabOrderDetailController detail) {
    final order = detail.order.value;
    final critical = detail.unhandledCritical;
    final byTest = detail.resultsByTest;

    return BentoScreen(
      onRefresh: detail.reload,
      bottomClearance: false,
      slivers: [
        if (detail.hasLoadError)
          BentoSection(
            top: BentoSpace.page,
            child: ErrorRetryBanner(
              message: detail.rxLoadError.value!,
              onRetry: detail.load,
            ),
          ),
        BentoSection(
          top: detail.hasLoadError ? 0 : BentoSpace.page,
          bottom: BentoSpace.header,
          child: RecordHeader(
            title: order.orderNumber,
            subtitle: order.clinicalIndication,
            status: LabOrderStatus.labelOf(order.status),
            statusColor: LabOrderStatus.colorOf(order.status),
            secondaryStatus: LabPriority.labelOf(order.priority),
            secondaryStatusColor: LabPriority.colorOf(order.priority),
            actions: _actions(context, detail),
          ),
        ),
        if (critical.isNotEmpty)
          BentoSection(
            bottom: BentoSpace.header,
            child: KeyedSubtree(
              key: LaboratoryKeys.criticalBanner,
              child: NoticeBanner(
                // The word, not only the colour. A red figure alone is unread
                // by a colour-blind clinician, by a printed handover sheet and
                // by anybody standing more than a metre from the screen.
                message: critical.length == 1
                    ? 'Critical result on ${critical.first.testName}. '
                        'Somebody has to be told — a list refresh will not do '
                        'it.'
                    : '${critical.length} critical results on this order. '
                        'Somebody has to be told — a list refresh will not do '
                        'it.',
                icon: Icons.priority_high_rounded,
                tint: AppColors.acuityCritical,
              ),
            ),
          ),
        if ((order.rejectionReason ?? '').isNotEmpty)
          BentoSection(
            bottom: BentoSpace.header,
            child: NoticeBanner(
              message: 'Sample rejected: ${order.rejectionReason}',
              icon: Icons.report_problem_outlined,
              // Amber. A sample that could not be run is work to redo, not a
              // patient in trouble.
              tint: AppColors.warning,
            ),
          ),
        BentoSection(
          bottom: BentoSpace.header,
          child: BentoCard(
            child: PatientIdentityBand(
              name: order.patient.displayName,
              mrn: order.patient.mrn,
              age: order.patient.age,
              sex: Formatters.label(order.patient.gender),
              extra: (order.accessionNumber ?? '').isEmpty
                  ? null
                  : 'Accession ${order.accessionNumber}',
            ),
          ),
        ),
        BentoSection(
          bottom: BentoSpace.header,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionHeader(
                title: order.tests.length == 1
                    ? '1 test'
                    : '${order.tests.length} tests',
              ),
              BentoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: BentoSpace.cardPad,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (order.tests.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: EmptyState(
                          compact: true,
                          icon: Icons.science_outlined,
                          title: 'No tests on this order',
                        ),
                      )
                    else
                      for (var i = 0; i < order.tests.length; i++) ...[
                        if (i > 0) const Hairline(),
                        _OrderedTestRow(
                          key: LaboratoryKeys.orderedTest(
                            order.tests[i].testId,
                          ),
                          order: order,
                          test: order.tests[i],
                          result: byTest[order.tests[i].testId],
                          detail: detail,
                        ),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
        BentoSection(
          child: BentoCard(
            padding: const EdgeInsets.symmetric(
              vertical: BentoSpace.listCardPad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactRow(
                  label: 'Requested',
                  value: Formatters.dateTime(order.orderDate),
                ),
                if ((order.clinicalIndication ?? '').isNotEmpty) ...[
                  const Hairline(indent: BentoSpace.listPad),
                  FactRow(
                    label: 'Indication',
                    value: order.clinicalIndication!,
                    stacked: order.clinicalIndication!.length > 28,
                  ),
                ],
                if ((order.provisionalDiagnosis ?? '').isNotEmpty) ...[
                  const Hairline(indent: BentoSpace.listPad),
                  FactRow(
                    label: 'Provisional diagnosis',
                    value: order.provisionalDiagnosis!,
                    stacked: order.provisionalDiagnosis!.length > 28,
                  ),
                ],
                if (order.sampleCollectedAt != null) ...[
                  const Hairline(indent: BentoSpace.listPad),
                  FactRow(
                    label: 'Sample taken',
                    value: Formatters.dateTime(order.sampleCollectedAt),
                  ),
                ],
                if ((order.notes ?? '').isNotEmpty) ...[
                  const Hairline(indent: BentoSpace.listPad),
                  FactRow(
                    label: 'Notes',
                    value: order.notes!,
                    stacked: order.notes!.length > 28,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The actions this account may take on this order, in this state.
  ///
  /// Absent rather than disabled: a greyed control is a promise that the right
  /// account could use it, and this list is already the answer to "what can
  /// happen next".
  List<Widget> _actions(
    BuildContext context,
    LabOrderDetailController detail,
  ) =>
      [
        if (detail.canCollect)
          RecordAction(
            key: LaboratoryKeys.collectSample,
            icon: Icons.science_outlined,
            label: 'Collect sample',
            onPressed: () => openCollectSheet(context, detail),
          ),
        if (detail.canReject)
          RecordAction(
            key: LaboratoryKeys.rejectSample,
            icon: Icons.block_rounded,
            label: 'Reject sample',
            destructive: true,
            onPressed: () => openRejectSheet(context, detail),
          ),
        if (detail.canComplete)
          RecordAction(
            key: LaboratoryKeys.completeOrder,
            icon: Icons.check_circle_outline_rounded,
            label: 'Complete',
            onPressed: () => _confirmComplete(context, detail),
          ),
      ];

  Future<void> _confirmComplete(
    BuildContext context,
    LabOrderDetailController detail,
  ) async {
    final unverified = detail.results.where((r) => !r.isVerified).length;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Complete ${detail.order.value.orderNumber}?',
      message: unverified == 0
          ? 'The order closes and the results are reported to the requester.'
          : '$unverified result${unverified == 1 ? '' : 's'} '
              '${unverified == 1 ? 'has' : 'have'} not been verified yet. '
              'The order closes and the results are reported as they stand.',
      confirmLabel: 'Complete',
    );
    if (confirmed) await detail.completeOrder();
  }
}

/// One ordered test, with whatever has come back for it.
class _OrderedTestRow extends StatelessWidget {
  const _OrderedTestRow({
    super.key,
    required this.order,
    required this.test,
    required this.result,
    required this.detail,
  });

  final LabOrder order;
  final LabOrderTest test;
  final LabResult? result;
  final LabOrderDetailController detail;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entered = result;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      test.testName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: isDark
                          ? AppTextStyles.darkCallout()
                          : AppTextStyles.lightCallout(),
                    ),
                    if ((test.testCode ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        test.testCode!,
                        style: AppFonts.numeric(
                          fontSize: 12,
                          color: tertiaryLabelColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                status: test.urgency ?? order.priority,
                label: LabPriority.labelOf(test.urgency ?? order.priority),
                color: LabPriority.colorOf(test.urgency ?? order.priority),
                compact: true,
              ),
            ],
          ),
          if (entered == null) ...[
            if (detail.canEnterResults) ...[
              const SizedBox(height: 10),
              SecondaryBar(
                key: LaboratoryKeys.enterResult(test.testId),
                label: 'Enter result',
                icon: Icons.edit_note_rounded,
                onPressed: () => Get.toNamed<void>(
                  LabRoutes.resultNew,
                  arguments: {
                    'orderId': order.id,
                    'orderNumber': order.orderNumber,
                    'testId': test.testId,
                    'testName': test.testName,
                  },
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Waiting on a result.',
                style: AppFonts.text(
                  fontSize: 12.5,
                  color: tertiaryLabelColor(context),
                ),
              ),
            ],
          ] else
            _ResultBlock(result: entered, detail: detail),
        ],
      ),
    );
  }
}

/// The reading itself, and what is true about it.
class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.result, required this.detail});

  final LabResult result;
  final LabOrderDetailController detail;

  @override
  Widget build(BuildContext context) {
    // Critical is the app's one alarm colour; anything merely out of range is
    // amber. A normal result is the primary ink and no colour at all.
    final tone = result.isCritical
        ? AppColors.acuityCritical
        : (result.isAbnormal || !LabResultFlag.isNormal(result.flag)
            ? AppColors.acuityUrgent
            : null);

    return Padding(
      key: LaboratoryKeys.resultRow(result.id),
      padding: const EdgeInsets.only(top: 10),
      child: InsetSurface(
        radius: BentoRadius.control,
        padding: const EdgeInsets.all(12),
        color: wellColor(context),
        bordered: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: VitalFigure(
                    value: result.resultValue,
                    unit: result.unit,
                    tone: tone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      if (LabResultFlag.labelOf(result.flag).isNotEmpty)
                        StatusPill(
                          status: result.flag!,
                          label: LabResultFlag.labelOf(result.flag),
                          color: LabResultFlag.colorOf(result.flag),
                          compact: true,
                        ),
                      if (result.isCritical)
                        // The word "Critical" travels with the colour, and the
                        // pill keeps its glyph so it survives a greyscale
                        // printout of the board.
                        const StatusPill(
                          status: 'critical',
                          label: 'Critical',
                          color: AppColors.acuityCritical,
                          icon: Icons.priority_high_rounded,
                        ),
                      StatusPill(
                        status: result.isVerified ? 'verified' : 'unverified',
                        label: result.isVerified ? 'Verified' : 'Unverified',
                        color: result.isVerified
                            ? AppColors.acuityStable
                            : AppColors.acuityReview,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                'Reference ${result.referenceDisplay}',
                if (result.enteredAt != null)
                  'entered ${Formatters.elapsed(result.enteredAt)} ago',
              ].join(' · '),
              style: AppFonts.text(
                fontSize: 12,
                color: tertiaryLabelColor(context),
              ),
            ),
            if ((result.comment ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                result.comment!,
                style: AppFonts.text(
                  fontSize: 12.5,
                  height: 1.35,
                  color: secondaryLabelColor(context),
                ),
              ),
            ],
            if (!result.isVerified && detail.canUpdate) ...[
              const SizedBox(height: 10),
              SecondaryBar(
                key: LaboratoryKeys.verifyResult(result.id),
                label: 'Verify result',
                icon: Icons.verified_outlined,
                onPressed: () => detail.verifyResult(result),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Logs the sample against the order.
Future<void> openCollectSheet(
  BuildContext context,
  LabOrderDetailController detail,
) =>
    Get.bottomSheet<void>(
      _AccessionSheet(detail: detail),
      isScrollControlled: true,
    );

/// Refuses a sample, with the reason the requester needs.
Future<void> openRejectSheet(
  BuildContext context,
  LabOrderDetailController detail,
) =>
    Get.bottomSheet<void>(
      _RejectSheet(detail: detail),
      isScrollControlled: true,
    );

class _AccessionSheet extends StatefulWidget {
  const _AccessionSheet({required this.detail});

  final LabOrderDetailController detail;

  @override
  State<_AccessionSheet> createState() => _AccessionSheetState();
}

class _AccessionSheetState extends State<_AccessionSheet> {
  final _accession = TextEditingController();

  @override
  void dispose() {
    _accession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      title: 'Collect sample',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSection(
            bottom: 12,
            child: BentoInput(
              fieldKey: LaboratoryKeys.accessionField,
              label: 'Accession number',
              controller: _accession,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              hint: 'The barcode on the tube. Leave it blank and the '
                  'laboratory assigns one.',
            ),
          ),
          SheetSection(
            bottom: 10,
            child: PrimaryBar(
              key: LaboratoryKeys.accessionConfirm,
              label: 'Log the sample',
              icon: Icons.science_outlined,
              onPressed: () {
                final value = _accession.text.trim();
                Get.back<void>();
                widget.detail.collectSample(accession: value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.detail});

  final LabOrderDetailController detail;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      // Required, and required here rather than on the server: a rejection
      // with no reason on it is a sample somebody has to take again without
      // knowing what to do differently.
      setState(() => _error = 'Say why it cannot be run');
      return;
    }
    Get.back<void>();
    widget.detail.rejectSample(reason);
  }

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      title: 'Reject sample',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSection(
            bottom: 12,
            child: BentoInput(
              fieldKey: LaboratoryKeys.rejectReasonField,
              label: 'Reason',
              controller: _reason,
              required: true,
              autofocus: true,
              maxLines: 2,
              error: _error,
              textCapitalization: TextCapitalization.sentences,
              hint: 'Haemolysed, insufficient volume, unlabelled',
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),
          SheetSection(
            bottom: 10,
            child: SecondaryBar(
              key: LaboratoryKeys.rejectConfirm,
              label: 'Reject the sample',
              icon: Icons.block_rounded,
              destructive: true,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
