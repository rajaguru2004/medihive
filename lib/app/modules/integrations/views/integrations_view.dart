import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/integrations_keys.dart';
import '../../../data/models/machine_integration.dart';
import '../../../data/repositories/integrations_repository.dart';
import '../../../theme/theme.dart';
import '../controllers/integrations_controller.dart';
import '../device_status.dart';
import '../integrations_routes.dart';
import 'integrations_rows.dart';

/// The instrument link.
///
/// Three views of one relationship: the machines this site talks to, what they
/// have sent that nobody has matched to a patient yet, and the way results get
/// in from a machine with no live link at all.
///
/// Nothing on this screen is red. Every state it shows is a job for whoever
/// looks after the equipment, and red in this app is reserved for a
/// deteriorating patient or a fault in the app itself — see `device_status.dart`.
class IntegrationsView extends GetView<IntegrationsController> {
  const IntegrationsView({super.key, this.embedded = true});

  /// True inside the shell's tab stack, false when this screen was pushed.
  ///
  /// The difference is the header and the ground, nothing else. The shell draws
  /// both for a tab, and the one action the pushed header carries has its own
  /// place in the body — so it is not lost for the account that gets the tab.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`. A `GetView` whose build never touches
    // `controller` never constructs the lazyPut one, and nothing ever loads.
    final hub = controller;

    final body = Obx(() {
      if (hub.isLoading && hub.rxFirstLoad.value) {
        return _IntegrationsSkeleton(embedded: embedded);
      }

      return BentoScreen(
        key: IntegrationsKeys.screen,
        onRefresh: hub.reload,
        bottomClearance: false,
        // The shell already paints the washed ground; a tab that paints its own
        // on top leaves a seam exactly where the two meet.
        ground: !embedded,
        slivers: [
          if (hub.hasNoAccess)
            const BentoSection(
              top: BentoSpace.page,
              child: EmptyState(
                key: IntegrationsKeys.locked,
                icon: Icons.lock_outline_rounded,
                title: 'The instrument link is not part of your role',
                message: 'An administrator can give your account access to the '
                    'devices this site talks to and the results they send.',
              ),
            )
          else ...[
            if (hub.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  key: IntegrationsKeys.error,
                  message: hub.rxLoadError.value!,
                  onRetry: hub.load,
                ),
              ),
            _figures(hub, top: hub.hasLoadError ? 0 : null),
            BentoSection(
              child: BentoSegmented<IntegrationsSegment>(
                key: IntegrationsKeys.segmented,
                options: IntegrationsSegment.values,
                selected: hub.segment.value,
                onSelected: hub.show,
                labelOf: _segmentLabel,
                keyOf: (segment) => IntegrationsKeys.segment(segment.name),
              ),
            ),
            ...switch (hub.segment.value) {
              IntegrationsSegment.devices => _deviceSlivers(hub),
              IntegrationsSegment.queue => _queueSlivers(hub),
              IntegrationsSegment.upload => _uploadSlivers(context, hub),
            },
          ],
        ],
      );
    });

    if (embedded) return body;

    return Scaffold(
      appBar: DetailHeader(
        title: 'Integrations',
        subtitle: 'Devices, results and imports',
        // Absent, not disabled, for an account that may not register one.
        action: hub.canCreate
            ? CircleIconButton(
                key: IntegrationsKeys.deviceAdd,
                icon: Icons.add_rounded,
                tooltip: 'Register a device',
                onTap: _openDeviceForm,
              )
            : null,
      ),
      body: body,
    );
  }

  // ── The figures ───────────────────────────────────────────────────────────

  Widget _figures(IntegrationsController hub, {double? top}) {
    final attention = hub.needingAttention;
    final unmatched = hub.unmatchedRows;

    return BentoSection(
      top: top ?? BentoSpace.page,
      child: FigureGrid(
        figures: [
          Figure(
            label: 'Devices',
            value: '${hub.machines.length}',
            icon: Icons.memory_outlined,
            onTap: () => hub.show(IntegrationsSegment.devices),
          ),
          Figure(
            // Amber when there is one, and the row's own ink when there is not.
            // Never red: a machine that has stopped talking is somebody's
            // morning, not somebody's emergency.
            label: 'Not talking',
            value: '$attention',
            icon: Icons.link_off_rounded,
            color: attention > 0 ? AppColors.warning : null,
            onTap: () => hub.show(IntegrationsSegment.devices),
          ),
          Figure(
            label: 'In the queue',
            value: '${hub.queue.length}',
            icon: Icons.inbox_outlined,
            onTap: () => hub.show(IntegrationsSegment.queue),
          ),
          Figure(
            label: 'Need a person',
            value: '$unmatched',
            icon: Icons.person_search_outlined,
            color: unmatched > 0 ? AppColors.warning : null,
            onTap: () => hub.show(IntegrationsSegment.queue),
          ),
        ],
      ),
    );
  }

  // ── Devices ───────────────────────────────────────────────────────────────

  List<Widget> _deviceSlivers(IntegrationsController hub) {
    final rows = hub.devices;

    return [
      SliverToBoxAdapter(
        child: FilterChips<String>(
          key: IntegrationsKeys.deviceFilters,
          options: const [_anyState, ...DeviceLink.filterOptions],
          selected: hub.linkFilter.value ?? _anyState,
          labelOf: (state) =>
              state == _anyState ? 'All devices' : DeviceLink.ofStatus(state).label,
          keyOf: (state) => IntegrationsKeys.deviceFilter(
            state == _anyState ? 'all' : state,
          ),
          onSelected: (state) =>
              hub.filterDevices(state == _anyState ? null : state),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: BentoSpace.header)),
      // The action the shell's header has nowhere to put. Only when embedded —
      // the pushed screen carries it in its own header, and two copies under
      // one key is a test that cannot say which it tapped.
      if (embedded && hub.canCreate)
        BentoSection(
          bottom: BentoSpace.header,
          child: PrimaryBar(
            key: IntegrationsKeys.deviceAdd,
            label: 'Register a device',
            icon: Icons.add_rounded,
            onPressed: _openDeviceForm,
          ),
        ),
      if (rows.isEmpty)
        BentoSection(
          child: EmptyState(
            key: IntegrationsKeys.deviceEmpty,
            icon: Icons.memory_outlined,
            title: hub.isDeviceFiltered
                ? 'No device is in that state'
                : 'No device is wired in yet',
            message: hub.isDeviceFiltered
                ? 'Every device this site has registered is in one of the '
                    'other states.'
                : 'An analyser has to be registered here before the results it '
                    'sends can reach a patient record.',
            actionLabel: hub.isDeviceFiltered ? 'All devices' : null,
            onAction:
                hub.isDeviceFiltered ? () => hub.filterDevices(null) : null,
          ),
        )
      else
        BentoSection(
          child: BentoCard(
            key: IntegrationsKeys.deviceList,
            padding:
                const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  DeviceRow(
                    key: IntegrationsKeys.device(rows[i].id),
                    machine: rows[i],
                    onTap: hub.canUpdate ? () => _openDeviceForm(rows[i]) : null,
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  // ── The results queue ─────────────────────────────────────────────────────

  List<Widget> _queueSlivers(IntegrationsController hub) {
    final rows = hub.queue;
    final unmatched = hub.unmatchedRows;

    return [
      SliverToBoxAdapter(
        child: FilterChips<String>(
          key: IntegrationsKeys.queueFilters,
          options: const [_anyState, ...ResultsQueueStatus.all],
          selected: hub.queueFilter.value ?? _anyState,
          labelOf: (status) =>
              status == _anyState ? 'Everything' : QueueState.labelOf(status),
          keyOf: (status) => IntegrationsKeys.queueFilter(
            status == _anyState ? 'all' : status,
          ),
          onSelected: (status) =>
              hub.filterQueue(status == _anyState ? null : status),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: BentoSpace.header)),
      if (unmatched > 0)
        BentoSection(
          bottom: BentoSpace.header,
          child: NoticeBanner(
            message: unmatched == 1
                ? 'One result has not reached a patient. This backend matches a '
                    'sample once, as it arrives — correct the identifier at the '
                    'bench and send the file again.'
                : '$unmatched results have not reached a patient. This backend '
                    'matches a sample once, as it arrives — correct the '
                    'identifiers at the bench and send the file again.',
            icon: Icons.person_search_outlined,
            // Amber. Nobody is unwell because a tube was mislabelled; somebody
            // has a job to do.
            tint: AppColors.warning,
          ),
        ),
      if (rows.isEmpty)
        BentoSection(
          child: EmptyState(
            key: IntegrationsKeys.queueEmpty,
            icon: Icons.inbox_outlined,
            title: hub.isQueueFiltered
                ? 'Nothing is in that state'
                : 'Nothing is waiting',
            message: hub.isQueueFiltered
                ? 'Results in the other states are still on this queue.'
                : 'Results a machine sends arrive here on their way to a '
                    "patient's record.",
            actionLabel: hub.isQueueFiltered ? 'Everything' : null,
            onAction: hub.isQueueFiltered ? () => hub.filterQueue(null) : null,
          ),
        )
      else
        BentoSection(
          child: BentoCard(
            key: IntegrationsKeys.queueList,
            padding:
                const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  QueueRow(
                    key: IntegrationsKeys.queueRow(rows[i].id),
                    row: rows[i],
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  // ── Sending a file ────────────────────────────────────────────────────────

  List<Widget> _uploadSlivers(
    BuildContext context,
    IntegrationsController hub,
  ) {
    if (!hub.canCreate) {
      return const [
        BentoSection(
          child: EmptyState(
            key: IntegrationsKeys.uploadLocked,
            icon: Icons.lock_outline_rounded,
            title: 'Importing results is not part of your role',
            message: 'You can read what the machines have sent. Bringing a '
                'file in is a separate permission an administrator grants.',
          ),
        ),
      ];
    }

    final file = hub.pickedFile.value;
    final summary = hub.lastUpload.value;
    final failure = hub.uploadError.value;

    return [
      BentoSection(
        child: BentoCard(
          key: IntegrationsKeys.uploadCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Bring results in from a file'),
              Text(
                'For a machine with no live link: export its results and send '
                'the file here. CSV, Excel, HL7 or plain text, up to 10 MB.',
                style: Theme.of(context).brightness == Brightness.dark
                    ? AppTextStyles.darkFootnote()
                    : AppTextStyles.lightFootnote(),
              ),
              const SizedBox(height: BentoSpace.action),
              if (file == null)
                SecondaryBar(
                  key: IntegrationsKeys.uploadPick,
                  label: 'Choose a file',
                  icon: Icons.attach_file_rounded,
                  onPressed: hub.isUploading.value ? null : hub.pickFile,
                )
              else ...[
                InsetSurface(
                  key: IntegrationsKeys.uploadChosen,
                  child: BentoRow(
                    title: file.filename,
                    subtitle: file.sizeLabel,
                    icon: Icons.description_outlined,
                    padding: EdgeInsets.zero,
                    trailing: hub.isUploading.value
                        ? null
                        : CircleIconButton(
                            key: IntegrationsKeys.uploadClear,
                            icon: Icons.close_rounded,
                            tooltip: 'Choose a different file',
                            onTap: hub.clearFile,
                          ),
                  ),
                ),
                const SizedBox(height: BentoSpace.action),
                AsyncPicker<String>(
                  fieldKey: IntegrationsKeys.uploadDevice,
                  label: 'Sent by',
                  valueLabel: hub.uploadDeviceLabel,
                  placeholder: 'Leave blank for a manual import',
                  hint: 'Which machine these results came off, if you know. '
                      'Blank files under this site’s manual import.',
                  enabled: !hub.isUploading.value,
                  options: [
                    for (final device in hub.uploadDevices)
                      PickerOption<String>(
                        value: device.id,
                        label: device.displayName,
                        sublabel: DeviceKind.labelOf(device.machineType),
                        color: DeviceLink.of(device).color,
                      ),
                  ],
                  onSelected: (value) => hub.uploadDeviceId.value = value,
                ),
                const SizedBox(height: BentoSpace.action),
                if (hub.isUploading.value) ...[
                  _progress(context, hub),
                  const SizedBox(height: BentoSpace.action),
                ],
                PrimaryBar(
                  key: IntegrationsKeys.uploadSend,
                  label: 'Send to the queue',
                  icon: Icons.cloud_upload_outlined,
                  busy: hub.isUploading.value,
                  onPressed: () => _send(hub),
                ),
              ],
            ],
          ),
        ),
      ),
      if (failure != null)
        BentoSection(
          top: 0,
          child: ErrorRetryBanner(
            key: IntegrationsKeys.uploadError,
            title: "That file didn't go",
            message: failure,
            // The file is still chosen, so the retry is one tap. When it is not
            // — a file refused before it was ever held — there is nothing to
            // retry and the banner says only what went wrong.
            onRetry: file == null || hub.isUploading.value
                ? null
                : () => _send(hub),
          ),
        ),
      if (!summary.isEmpty)
        BentoSection(top: 0, child: _summary(hub, summary)),
    ];
  }

  Widget _progress(BuildContext context, IntegrationsController hub) {
    final fraction = hub.uploadProgress.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      key: IntegrationsKeys.uploadProgress,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UsedBar(fraction: fraction, color: AppColors.acuityStandard),
        const SizedBox(height: 6),
        Text(
          'Sending — ${(fraction * 100).round()}%',
          style: isDark
              ? AppTextStyles.darkCaption1()
              : AppTextStyles.lightCaption1(),
        ),
      ],
    );
  }

  /// What the server made of the file.
  ///
  /// Rows read and rows queued are two different numbers, and so are "queued"
  /// and "reached a patient" — the route parses, then tries to match every row.
  /// A card that said only "uploaded" would hide the half that needs somebody.
  Widget _summary(IntegrationsController hub, ResultsUploadSummary summary) {
    return BentoCard(
      key: IntegrationsKeys.uploadSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: summary.fileName.isEmpty ? 'Last import' : summary.fileName,
            actionLabel: 'See the queue',
            onAction: () => hub.show(IntegrationsSegment.queue),
          ),
          FactRow(
            label: 'Rows read',
            value: '${summary.parsedRows} of ${summary.totalRows}',
            dense: true,
          ),
          FactRow(
            label: 'Added to the queue',
            value: '${summary.queued}',
            dense: true,
          ),
          FactRow(
            label: 'Matched a patient',
            value: '${summary.matched}',
            dense: true,
          ),
          if (summary.needsReview > 0)
            FactRow(
              label: 'Need a person',
              value: '${summary.needsReview}',
              valueColor: AppColors.warning,
              dense: true,
            ),
          if (summary.failed > 0)
            FactRow(
              label: 'Matched nobody',
              value: '${summary.failed}',
              valueColor: AppColors.warning,
              dense: true,
            ),
          if (summary.parseErrors.isNotEmpty) ...[
            const SizedBox(height: BentoSpace.action),
            NoticeBanner(
              message: summary.parseErrors.length == 1
                  ? summary.parseErrors.first
                  : '${summary.parseErrors.length} lines in that file could '
                      'not be read.',
              icon: Icons.rule_rounded,
              tint: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _send(IntegrationsController hub) async {
    if (!await hub.sendFile()) return;
    final summary = hub.lastUpload.value;
    showBentoToast(
      summary.queued == 1
          ? 'One result added to the queue.'
          : '${summary.queued} results added to the queue.',
      tone: summary.needsAttention ? ToastTone.info : ToastTone.success,
    );
  }

  void _openDeviceForm([MachineIntegration? machine]) => Get.toNamed<void>(
        IntegrationsRoutes.machineEdit,
        // Handed over rather than looked up: the row this screen is already
        // holding is the whole record, and `GET /machines/:id` would fetch it
        // again to fill a form that is already on screen.
        arguments: machine == null ? null : {'machine': machine},
      );

  /// The empty string is "no filter" — a sentinel rather than a nullable
  /// selection, because `FilterChips` compares options by equality and null is
  /// not one of them.
  static const String _anyState = '';

  static String _segmentLabel(IntegrationsSegment segment) => switch (segment) {
        IntegrationsSegment.devices => 'Devices',
        IntegrationsSegment.queue => 'Results',
        IntegrationsSegment.upload => 'Upload',
      };
}

class _IntegrationsSkeleton extends StatelessWidget {
  const _IntegrationsSkeleton({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BentoScreen(
      bottomClearance: false,
      ground: !embedded,
      slivers: const [
        BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 2)),
        BentoSection(child: BentoSkeleton(rows: 5)),
      ],
    );
  }
}
