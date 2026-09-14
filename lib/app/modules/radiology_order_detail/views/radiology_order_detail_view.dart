import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/keys/radiology_keys.dart';
import '../../../data/models/radiology_order.dart';
import '../../../data/models/radiology_report.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/services/image_source.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../radiology/radiology_routes.dart';
import '../../radiology/views/radiology_shared.dart';
import '../controllers/radiology_order_detail_controller.dart';

/// One imaging order: who it is for, what was asked for, where it has got to,
/// and what can be done to it next.
///
/// A `StatefulWidget` rather than a `GetView` because the controller is tagged
/// by order id: the tablet shows this beside the worklist, so two studies can
/// be on screen in one session and a single untagged controller would answer
/// for both.
class RadiologyOrderDetailView extends StatefulWidget {
  const RadiologyOrderDetailView({
    super.key,
    this.orderId,
    this.embedded = false,
  });

  /// Null when this is the routed screen, which takes the id from the path.
  /// Set when it is the detail pane of the worklist.
  final String? orderId;

  /// True in the worklist's second pane, which already has a header above it.
  final bool embedded;

  @override
  State<RadiologyOrderDetailView> createState() =>
      _RadiologyOrderDetailViewState();
}

class _RadiologyOrderDetailViewState extends State<RadiologyOrderDetailView> {
  late final String _id;
  late final RadiologyOrderDetailController _controller;

  /// Whether this widget created the controller, and therefore owes it a
  /// disposal. The routed copy is created by the binding and torn down with
  /// the route; the pane's is not.
  late final bool _owns;

  @override
  void initState() {
    super.initState();
    _id = widget.orderId ?? RadiologyOrderDetailController.routeOrderId();
    _owns = !(Get.isRegistered<RadiologyOrderDetailController>(tag: _id) ||
        Get.isPrepared<RadiologyOrderDetailController>(tag: _id));
    _controller = RadiologyOrderDetailController.forOrder(_id);
  }

  @override
  void dispose() {
    if (_owns) {
      final id = _id;
      // After this frame. Deleting a controller while an `Obx` above is still
      // being torn down throws from inside a dispose nobody is holding, and
      // the message names the overlay rather than this screen.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Get.delete<RadiologyOrderDetailController>(tag: id),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      if (_controller.isLoading && _controller.rxFirstLoad.value) {
        return const BentoScreen(
          bottomClearance: false,
          slivers: [
            BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 6)),
          ],
        );
      }

      if (_controller.hasNoAccess) {
        return const BentoScreen(
          bottomClearance: false,
          slivers: [
            BentoSection(
              top: BentoSpace.page,
              child: EmptyState(
                key: RadiologyKeys.orderDetailLocked,
                icon: Icons.lock_outline_rounded,
                title: 'Imaging is not part of your role',
                message: 'An administrator can give your account access to it.',
              ),
            ),
          ],
        );
      }

      final order = _controller.order.value;

      return BentoScreen(
        key: RadiologyKeys.orderDetail,
        onRefresh: _controller.reload,
        bottomClearance: false,
        ground: !widget.embedded,
        slivers: [
          if (_controller.hasLoadError)
            BentoSection(
              top: BentoSpace.page,
              child: ErrorRetryBanner(
                key: RadiologyKeys.orderDetailError,
                message: _controller.rxLoadError.value!,
                onRetry: _controller.load,
              ),
            ),

          BentoSection(
            top: _controller.hasLoadError ? 0 : BentoSpace.page,
            bottom: BentoSpace.header,
            child: _Header(order: order),
          ),

          // ── Who ─────────────────────────────────────────────────────────
          BentoSection(
            bottom: BentoSpace.header,
            child: InsetSurface(
              padding: const EdgeInsets.all(14),
              child: PatientIdentityBand(
                name: order.patient.displayName,
                mrn: order.patient.mrn,
                age: order.patient.age,
                sex: order.patient.gender,
                extra: Formatters.dateMedium(order.orderDate),
              ),
            ),
          ),

          // ── A read that found something ─────────────────────────────────
          //
          // Above the exam and above the actions, because it is the only thing
          // on this screen that is about the patient deteriorating.
          if (order.hasCriticalFindings)
            BentoSection(
              bottom: BentoSpace.header,
              child: NoticeBanner(
                key: RadiologyKeys.orderCritical,
                message: _criticalMessage(order.report!),
                icon: Icons.priority_high_rounded,
                tint: AppColors.acuityCritical,
              ),
            ),

          if (_controller.actionError.value != null)
            BentoSection(
              bottom: BentoSpace.header,
              child: NoticeBanner(
                message: _controller.actionError.value!,
                icon: Icons.error_outline_rounded,
                tint: AppColors.error,
              ),
            ),

          // ── What can be done next ───────────────────────────────────────
          //
          // Above the record rather than under it. Somebody opens an order to
          // move it along — book it, start it, mark it performed, write the
          // read — and this used to sit under the exam, the clinical detail,
          // the timeline, the report and the image strip, which on a phone is
          // three screens of scrolling to reach the one button they came for.
          BentoSection(
            bottom: BentoSpace.header,
            child: _Actions(controller: _controller),
          ),

          // ── What was asked for ──────────────────────────────────────────
          BentoSection(bottom: BentoSpace.header, child: _ExamCard(order: order)),

          if (_hasClinicalDetail(order))
            BentoSection(
              bottom: BentoSpace.header,
              child: _ClinicalCard(order: order),
            ),

          // ── Where it has got to ─────────────────────────────────────────
          BentoSection(
            bottom: BentoSpace.header,
            child: _Timeline(order: order),
          ),

          if (order.report != null)
            BentoSection(
              bottom: BentoSpace.header,
              child: _ReportCard(report: order.report!),
            ),

          if (_controller.images.isNotEmpty)
            BentoSection(
              bottom: BentoSpace.header,
              child: _Images(images: _controller.images),
            ),

        ],
      );
    });

    if (widget.embedded) return body;

    return Scaffold(
      appBar: const DetailHeader(title: 'Imaging order'),
      body: BentoGround(child: SafeArea(child: MaxWidthBody(child: body))),
    );
  }
}

String _criticalMessage(RadiologyReport report) {
  final finding = (report.criticalFindings ?? '').trim();
  final told = (report.criticalNotifiedTo ?? '').trim();
  final when = report.criticalNotifiedAt;

  final head = finding.isEmpty
      ? 'This read carries a critical finding.'
      : 'Critical finding: $finding';

  // Who was told and when, or the fact that nobody has been. The second is the
  // state a ward escalates from, and it is the reason this banner exists.
  final tail = told.isEmpty || when == null
      ? ' Nobody is recorded as having been told.'
      : ' $told was told at ${Formatters.dateTime(when)}.';

  return '$head$tail';
}

bool _hasClinicalDetail(RadiologyOrder order) =>
    (order.clinicalIndication ?? '').trim().isNotEmpty ||
    (order.provisionalDiagnosis ?? '').trim().isNotEmpty ||
    (order.relevantHistory ?? '').trim().isNotEmpty ||
    (order.notes ?? '').trim().isNotEmpty;

/// The order's own line: its number, what was asked for, and the two states it
/// carries at once.
class _Header extends StatelessWidget {
  const _Header({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    final urgency = order.urgency.trim().toLowerCase();

    return RecordHeader(
      title: order.orderNumber.isEmpty ? 'Imaging order' : order.orderNumber,
      subtitle: order.exam.displayName.isEmpty
          ? order.examName
          : order.exam.displayName,
      status: radiologyStatusLabel(order.status),
      statusColor: radiologyStatusColor(order.status),
      secondaryStatus: urgency == RadiologyUrgency.routine || urgency.isEmpty
          ? null
          : radiologyUrgencyLabel(urgency),
      secondaryStatusColor: radiologyUrgencyColor(urgency),
    );
  }
}

/// What the machine is being asked to do, and what the patient has to do first.
class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    final exam = order.exam;
    final prep = (exam.preparationInstructions ?? '').trim();

    return BentoCard(
      padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: SectionHeader(title: 'Exam', padding: EdgeInsets.zero),
          ),
          FactRow(label: 'Exam', value: order.examName),
          if ((exam.examCode ?? '').trim().isNotEmpty)
            FactRow(label: 'Code', value: exam.examCode!),
          if ((exam.modality ?? '').trim().isNotEmpty)
            FactRow(label: 'Modality', value: exam.modality!),
          if ((exam.bodyPart ?? '').trim().isNotEmpty)
            FactRow(label: 'Body part', value: exam.bodyPart!),
          if (exam.estimatedDuration != null)
            FactRow(
              label: 'On the machine',
              value: '${exam.estimatedDuration} min',
            ),
          FactRow(
            label: 'Contrast',
            value: exam.contrastRequired ? 'Required' : 'Not required',
          ),
          if (prep.isNotEmpty)
            FactRow(label: 'Preparation', value: prep, stacked: true),
        ],
      ),
    );
  }
}

/// Why the study was asked for. The half of the request a radiologist reads
/// before looking at anything.
class _ClinicalCard extends StatelessWidget {
  const _ClinicalCard({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: SectionHeader(title: 'Request', padding: EdgeInsets.zero),
          ),
          if ((order.clinicalIndication ?? '').trim().isNotEmpty)
            FactRow(
              label: 'Indication',
              value: order.clinicalIndication!,
              stacked: true,
            ),
          if ((order.provisionalDiagnosis ?? '').trim().isNotEmpty)
            FactRow(
              label: 'Provisional diagnosis',
              value: order.provisionalDiagnosis!,
              stacked: true,
            ),
          if ((order.relevantHistory ?? '').trim().isNotEmpty)
            FactRow(
              label: 'History',
              value: order.relevantHistory!,
              stacked: true,
            ),
          if ((order.notes ?? '').trim().isNotEmpty)
            FactRow(label: 'Notes', value: order.notes!, stacked: true),
        ],
      ),
    );
  }
}

/// The five moments a study passes through, and which of them have happened.
///
/// Dates rather than ticks: "when was this scanned" is the question a ward
/// rings about, and a tick does not answer it.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final RadiologyOrder order;

  @override
  Widget build(BuildContext context) {
    String at(DateTime? value, String unset) =>
        value == null ? unset : Formatters.dateTime(value);

    return BentoCard(
      key: RadiologyKeys.orderTimeline,
      padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: SectionHeader(title: 'Progress', padding: EdgeInsets.zero),
          ),
          FactRow(label: 'Ordered', value: at(order.orderDate, '—')),
          FactRow(
            label: 'Scheduled',
            value: at(order.scheduledDate, 'Not scheduled'),
          ),
          FactRow(
            label: 'Performed',
            value: at(order.examPerformedAt, 'Not performed'),
          ),
          FactRow(
            label: 'Reported',
            value: at(
              order.report?.reportedAt ?? order.reportCreatedAt,
              'Not reported',
            ),
          ),
          if (order.status.trim().toLowerCase() ==
              RadiologyOrderStatus.cancelled)
            FactRow(
              label: 'Cancelled',
              value: (order.cancellationReason ?? '').trim().isEmpty
                  ? 'No reason recorded'
                  : order.cancellationReason!,
              stacked: true,
            ),
        ],
      ),
    );
  }
}

/// The read, as a referring clinician would want it: the impression first.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final RadiologyReport report;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: 'Report',
                    padding: EdgeInsets.zero,
                  ),
                ),
                StatusPill(
                  status: report.status,
                  color: radiologyReportStatusColor(report.status),
                  label: Formatters.label(report.status),
                  compact: true,
                ),
              ],
            ),
          ),
          // Never truncated: an impression cut at "no evidence of" reverses
          // its own meaning.
          if ((report.impression ?? '').trim().isNotEmpty)
            FactRow(
              label: 'Impression',
              value: report.impression!,
              stacked: true,
            ),
          if ((report.findings ?? '').trim().isNotEmpty)
            FactRow(label: 'Findings', value: report.findings!, stacked: true),
          if ((report.technique ?? '').trim().isNotEmpty)
            FactRow(label: 'Technique', value: report.technique!, stacked: true),
          if ((report.recommendations ?? '').trim().isNotEmpty)
            FactRow(
              label: 'Recommendations',
              value: report.recommendations!,
              stacked: true,
            ),
          if (report.comparedWithPrevious)
            FactRow(
              label: 'Compared with previous',
              value: (report.comparisonNotes ?? '').trim().isEmpty
                  ? 'Yes'
                  : report.comparisonNotes!,
              stacked: true,
            ),
          if ((report.amendmentReason ?? '').trim().isNotEmpty)
            FactRow(
              label: 'Amended because',
              value: report.amendmentReason!,
              stacked: true,
            ),
        ],
      ),
    );
  }
}

/// The study's images, as a strip of thumbnails.
class _Images extends StatelessWidget {
  const _Images({required this.images});

  final List<RadiologyImage> images;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      key: RadiologyKeys.images,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Images', padding: EdgeInsets.zero),
          Wrap(
            spacing: BentoSpace.action,
            runSpacing: BentoSpace.action,
            children: [
              for (final image in images)
                _Thumbnail(key: RadiologyKeys.image(image.url), image: image),
            ],
          ),
        ],
      ),
    );
  }
}

/// The projection where the study named one, the filename otherwise — a
/// thumbnail with nothing under it is one nobody can ask for by name.
String _labelOf(RadiologyImage image) {
  final view = (image.view ?? '').trim();
  return view.isNotEmpty ? view : (image.caption ?? '').trim();
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({super.key, required this.image});

  final RadiologyImage image;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InsetSurface(
            radius: BentoRadius.small,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BentoRadius.small),
              child: SizedBox(
                width: 96,
                height: 96,
                child: Image.network(
                  Endpoints.fileUrl(image.url),
                  fit: BoxFit.cover,
                  // A study that will not load must still read as a study:
                  // an unhandled image error throws from inside `build`, and
                  // the screen it takes down is the one holding the report.
                  errorBuilder: (context, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 22,
                      color: tertiaryLabelColor(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_labelOf(image).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _labelOf(image),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.text(
                  fontSize: 12,
                  color: tertiaryLabelColor(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Everything this account can do to this order, and nothing it cannot.
///
/// Controls are **absent** rather than disabled: a greyed button is a promise
/// the server is going to break, and a clinician who taps it learns to distrust
/// the screen rather than to ask for the permission.
class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final RadiologyOrderDetailController controller;

  @override
  Widget build(BuildContext context) {
    // Its own observer: this widget is *constructed* inside the screen's `Obx`
    // and *built* outside it, so a `busy` read there would never be subscribed
    // and the bar would not go quiet while a write is in flight.
    return Obx(() => _bar(context));
  }

  Widget _bar(BuildContext context) {
    final busy = controller.isSaving.value || controller.isUploading.value;

    final secondary = <Widget>[
      if (controller.canStart)
        SecondaryBar(
          key: RadiologyKeys.actionStart,
          label: 'Start the study',
          icon: Icons.play_arrow_rounded,
          onPressed: busy ? null : () => _run(controller, controller.start()),
        ),
      if (controller.canSchedule)
        SecondaryBar(
          key: RadiologyKeys.actionSchedule,
          label: 'Schedule',
          icon: Icons.event_available_outlined,
          onPressed: busy ? null : () => _openScheduleSheet(controller),
        ),
      if (controller.canUploadImage)
        SecondaryBar(
          key: RadiologyKeys.actionUpload,
          label: 'Upload image',
          icon: Icons.add_photo_alternate_outlined,
          onPressed: busy
              ? null
              // One origin, because this build's [ImageSource] is a stub with
              // nothing to choose between. The camera-or-gallery sheet belongs
              // with the real picker, behind the same interface.
              : () => _upload(controller),
        ),
      if (controller.canCancel)
        SecondaryBar(
          key: RadiologyKeys.actionCancel,
          label: 'Cancel this order',
          icon: Icons.cancel_outlined,
          destructive: true,
          onPressed: busy ? null : () => _openCancelSheet(controller),
        ),
    ];

    final primary = _primaryAction(controller, busy: busy);

    if (primary == null && secondary.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.lock_outline_rounded,
        title: 'Nothing to do here',
        message: 'This order is closed, or your role does not change imaging '
            'orders.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Next', padding: EdgeInsets.zero),
        ?primary,
        for (final action in secondary)
          Padding(
            padding: const EdgeInsets.only(top: BentoSpace.action),
            child: action,
          ),
      ],
    );
  }

  /// The step the study is actually waiting on. One button, at the top,
  /// because a screen offering six equal actions makes somebody read all six
  /// to find the one they came for.
  Widget? _primaryAction(
    RadiologyOrderDetailController controller, {
    required bool busy,
  }) {
    if (controller.canMarkPerformed) {
      return PrimaryBar(
        key: RadiologyKeys.actionPerformed,
        label: 'Mark performed',
        icon: Icons.done_all_rounded,
        busy: controller.isSaving.value,
        onPressed: busy ? null : () => _run(controller, controller.markPerformed()),
      );
    }
    if (controller.canWriteReport) {
      return PrimaryBar(
        key: RadiologyKeys.actionReport,
        label: 'Write report',
        icon: Icons.edit_note_rounded,
        onPressed: busy
            ? null
            : () => Get.toNamed<void>(
                  RadiologyRoutes.reportNew,
                  arguments: {'orderId': controller.orderId},
                ),
      );
    }
    if (controller.canEditReport) {
      return PrimaryBar(
        key: RadiologyKeys.actionReport,
        label: 'Edit report',
        icon: Icons.edit_note_rounded,
        onPressed: busy
            ? null
            : () => Get.toNamed<void>(
                  RadiologyRoutes.reportEdit,
                  arguments: {
                    'orderId': controller.orderId,
                    'reportId': controller.report!.id,
                  },
                ),
      );
    }
    return null;
  }
}

// ── Acting on the order ─────────────────────────────────────────────────────

/// Says so when a write worked.
///
/// The controller records the sentence and the view raises it, so a controller
/// driven by a unit test never reaches for an overlay that is not there — and
/// a failed write says nothing here, because it has already put its reason in
/// a banner that does not disappear after three seconds.
Future<void> _run(
  RadiologyOrderDetailController controller,
  Future<bool> write,
) async {
  if (!await write) return;
  final message = controller.takeSuccessMessage();
  if (message.isNotEmpty) showBentoToast(message);
}

Future<void> _upload(RadiologyOrderDetailController controller) async {
  final ok = await controller.uploadImage(ImageOrigin.gallery);
  if (ok) showBentoToast('Image attached to the report.');
}

Future<void> _openScheduleSheet(RadiologyOrderDetailController controller) {
  final chosen = Rxn<DateTime>(controller.order.value.scheduledDate);

  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Schedule this study',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSection(
            bottom: BentoSpace.action,
            child: Obx(
              () => DateField(
                fieldKey: RadiologyKeys.scheduleDate,
                label: 'Date',
                required: true,
                value: chosen.value,
                format: SettingsService.to.date,
                // A study cannot be booked into the past, and a slip of one
                // digit is how an order lands on a day that has gone.
                // `AppClock`, not `DateTime.now()`: the clock is frozen under
                // test, and a floor taken from wall time would sit in the
                // future of every fixture.
                firstDate: AppClock.now().subtract(const Duration(days: 1)),
                onChanged: (value) => chosen.value = value,
              ),
            ),
          ),
          SheetSection(
            child: Obx(
              () => PrimaryBar(
                key: RadiologyKeys.scheduleConfirm,
                label: 'Schedule',
                busy: controller.isSaving.value,
                enabled: chosen.value != null,
                onPressed: chosen.value == null
                    ? null
                    : () async {
                        final ok = await controller.schedule(chosen.value!);
                        // Only on success: a sheet that closes over a failed
                        // write takes the reason away with it.
                        if (ok) {
                          Get.back<void>();
                          showBentoToast(controller.takeSuccessMessage());
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openCancelSheet(RadiologyOrderDetailController controller) {
  final reason = TextEditingController();
  final entered = ''.obs;

  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Cancel this order',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSection(
            bottom: BentoSpace.action,
            child: BentoInput(
              fieldKey: RadiologyKeys.cancelReason,
              label: 'Why',
              required: true,
              maxLines: 3,
              controller: reason,
              hint: 'The referring clinician reads this instead of ringing.',
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) => entered.value = value,
            ),
          ),
          SheetSection(
            child: Obx(
              () => PrimaryBar(
                key: RadiologyKeys.cancelConfirm,
                label: 'Cancel the order',
                busy: controller.isSaving.value,
                enabled: entered.value.trim().isNotEmpty,
                onPressed: entered.value.trim().isEmpty
                    ? null
                    : () async {
                        final ok = await controller.cancel(entered.value.trim());
                        if (ok) {
                          Get.back<void>();
                          showBentoToast(controller.takeSuccessMessage());
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  ).whenComplete(reason.dispose);
}
