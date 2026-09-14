import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/patient_hub_keys.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/lab_result.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';
import '../../appointments/appointment_routes.dart';
import '../../billing/billing_routes.dart';
import '../../consultations/consultation_routes.dart';
import '../../laboratory/laboratory_routes.dart';
import '../../patients/patient_routes.dart';
import '../../radiology/radiology_routes.dart';
import '../controllers/patient_hub_controller.dart';

part 'patient_hub_tabs.dart';

/// The patient hub — the screen a clinician lands on from everywhere else.
///
/// One identity band, seven tabs, and a rule that runs through all of it: each
/// tab loads on its own and fails on its own. A hospital hands different
/// modules to different roles, so a ward nurse opening this record gets a 403
/// on the ledger and a 200 on everything else — and a screen with one load
/// state would show her a locked panel over a record she is entitled to read.
class PatientHubView extends GetView<PatientHubController> {
  const PatientHubView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root. A `GetView` whose build never touches `controller`
    // never constructs its `lazyPut` instance, so `onReady` never fires and
    // the hub sits empty forever.
    final hub = controller;

    return Scaffold(
      appBar: DetailHeader(
        title: 'Patient',
        action: Obx(() {
          final patient = hub.patient.value;
          if (patient.isEmpty ||
              !AccessService.to.can(Modules.patients, AccessVerb.update)) {
            return const SizedBox.shrink();
          }
          return CircleIconButton(
            key: PatientHubKeys.action('edit'),
            icon: Icons.edit_outlined,
            tooltip: 'Edit patient',
            onTap: () => Get.toNamed<void>(
              PatientRoutes.form,
              arguments: {'id': patient.id},
            ),
          );
        }),
      ),
      body: BentoGround(child: PatientHubBody(controller: hub)),
    );
  }
}

/// The hub in the tablet's second pane.
///
/// Its own instance, tagged by patient id and disposed with the pane: two
/// patients can be open at once — one beside the list, one pushed over it —
/// and a single untagged controller would hand both the same record.
///
/// The parent keys this widget by id, so choosing somebody else builds a new
/// `State` and the two lifecycle hooks below do the swap.
class PatientHubPane extends StatefulWidget {
  const PatientHubPane({super.key, required this.patientId, this.seed});

  final String patientId;
  final Patient? seed;

  @override
  State<PatientHubPane> createState() => _PatientHubPaneState();
}

class _PatientHubPaneState extends State<PatientHubPane> {
  late PatientHubController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      PatientHubController(forPatientId: widget.patientId, seed: widget.seed),
      tag: widget.patientId,
    );
  }

  @override
  void dispose() {
    // `force`, because a tagged instance put from a widget is not owned by any
    // route's binding and nothing else will ever drop it — a ward tablet left
    // on the register would otherwise accumulate one controller per patient
    // anybody looked at.
    Get.delete<PatientHubController>(tag: widget.patientId, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PatientHubBody(controller: _controller);
}

/// Everything below the header, shared by the pushed screen and the pane.
class PatientHubBody extends StatelessWidget {
  const PatientHubBody({super.key, required this.controller});

  final PatientHubController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tab = controller.tab.value;

      return BentoScreen(
        key: PatientHubKeys.screen,
        // The ground is painted once, by the pushed screen's own `Scaffold` or
        // by the shell behind the pane.
        ground: false,
        bottomClearance: false,
        onRefresh: controller.reload,
        slivers: [
          BentoSection(
            top: BentoSpace.page,
            bottom: BentoSpace.header,
            child: _Band(controller: controller),
          ),
          if (controller.hasLoadError)
            BentoSection(
              bottom: BentoSpace.header,
              child: ErrorRetryBanner(
                key: PatientHubKeys.error,
                message: controller.rxLoadError.value!,
                onRetry: controller.loadPatient,
              ),
            ),
          _QuickActions(controller: controller),
          SliverToBoxAdapter(
            child: FilterChips<PatientHubTab>(
              key: PatientHubKeys.tabs,
              options: PatientHubTab.values,
              selected: tab,
              labelOf: (value) => value.label,
              keyOf: (value) => PatientHubKeys.tab(value.name),
              onSelected: controller.showTab,
            ),
          ),
          BentoSection(
            top: BentoSpace.header,
            child: _TabShell(controller: controller, tab: tab),
          ),
        ],
      );
    });
  }
}

// ── The identity band ───────────────────────────────────────────────────────

class _Band extends StatelessWidget {
  const _Band({required this.controller});

  final PatientHubController controller;

  // Its own `Obx`, and every sibling below has one too.
  //
  // A child constructed inside a parent's `Obx` builder does **not** inherit
  // its subscription: the closure returns a widget, and that widget's `build`
  // runs later, outside the observer. So a section that reads an observable
  // has to own the `Obx` that watches it — otherwise the record lands, nothing
  // is marked dirty, and the band sits on skeletons forever.
  @override
  Widget build(BuildContext context) => Obx(() => _band(context));

  Widget _band(BuildContext context) {
    final patient = controller.patient.value;

    if (patient.isEmpty && controller.isLoading) {
      return const BentoCard(
        hero: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ShimmerBox(width: 180, height: 20),
            SizedBox(height: 10),
            ShimmerBox(width: 110, height: 12),
            SizedBox(height: 8),
            ShimmerBox(width: 140, height: 12),
          ],
        ),
      );
    }

    final words = controller.stateInWords;

    return BentoCard(
      key: PatientHubKeys.band,
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PatientIdentityBand(
            name: controller.bandName,
            mrn: patient.mrn,
            age: patient.age,
            sex: (patient.gender ?? '').isEmpty
                ? null
                : Formatters.label(patient.gender),
            acuityCode: controller.bandAcuityCode,
          ),
          // The state as a sentence, under the pill that colours it. Colour
          // and rank and word — a band that carried only the pill would be
          // unreadable to a colour-blind reader and to every screenshot.
          if (words.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Hairline(),
            const SizedBox(height: 10),
            Text(
              words,
              style: AppFonts.text(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: secondaryLabelColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Quick actions ───────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});

  final PatientHubController controller;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: Obx(() => _tiles(context)));

  Widget _tiles(BuildContext context) {
    final patient = controller.patient.value;
    if (patient.isEmpty) return const SizedBox.shrink();

    final access = AccessService.to;
    // Passed to every destination. Three of them do not read it yet — their
    // forms predate the hub — and it costs nothing to hand over, so the day
    // one of them starts pre-filling is a change in that module alone.
    final arguments = {'patientId': patient.id, 'patient': patient};

    // Every one of these opens the screen that does the job, with the patient
    // already chosen. Labels are short enough to sit on a tile without being
    // cut: "Book appointme…" is a tile that reads as broken, and a truncated
    // word is the one thing a label may never be.
    final actions = <_HubAction>[
      if (access.can(Modules.queue, AccessVerb.create))
        const _HubAction(
          name: 'queue',
          label: 'Add to queue',
          icon: Icons.groups_outlined,
          route: Routes.ADD_TO_QUEUE,
        ),
      if (access.can(Modules.appointments, AccessVerb.create))
        const _HubAction(
          name: 'book',
          label: 'Book visit',
          icon: Icons.event_outlined,
          route: AppointmentRoutes.form,
        ),
      if (access.can(Modules.inpatient, AccessVerb.create))
        const _HubAction(
          name: 'admit',
          label: 'Admit',
          icon: Icons.local_hotel_outlined,
          route: Routes.INPATIENT_ADMIT,
        ),
      if (access.can(Modules.consultations, AccessVerb.create))
        const _HubAction(
          name: 'consult',
          label: 'Consultation',
          icon: Icons.description_outlined,
          route: ConsultationRoutes.form,
        ),
      if (access.can(Modules.laboratory, AccessVerb.create))
        const _HubAction(
          name: 'lab',
          label: 'Order lab',
          icon: Icons.science_outlined,
          route: LabRoutes.orderNew,
        ),
      if (access.can(Modules.radiology, AccessVerb.create))
        const _HubAction(
          name: 'imaging',
          label: 'Order imaging',
          icon: Icons.monitor_heart_outlined,
          route: RadiologyRoutes.orderNew,
        ),
      if (access.can(Modules.billing, AccessVerb.create))
        const _HubAction(
          name: 'invoice',
          label: 'New invoice',
          icon: Icons.receipt_long_outlined,
          route: BillingRoutes.invoiceNew,
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: PatientHubKeys.quickActions,
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        0,
        BentoSpace.page,
        BentoSpace.section,
      ),
      child: Wrap(
        spacing: BentoSpace.action,
        runSpacing: BentoSpace.action,
        children: [
          for (final action in actions)
            SizedBox(
              width: 104,
              child: QuickActionTile(
                key: PatientHubKeys.action(action.name),
                icon: action.icon,
                label: action.label,
                onTap: () =>
                    Get.toNamed<void>(action.route, arguments: arguments),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubAction {
  const _HubAction({
    required this.name,
    required this.label,
    required this.icon,
    required this.route,
  });

  final String name;
  final String label;
  final IconData icon;
  final String route;
}

// ── The tab, and the four states it can be in ───────────────────────────────

class _TabShell extends StatelessWidget {
  const _TabShell({required this.controller, required this.tab});

  final PatientHubController controller;
  final PatientHubTab tab;

  /// Its own `Obx`, and the one that matters most: every read below —
  /// `isTabDenied`, `isTabLoading`, `tabError`, and the item lists `_content`
  /// looks at — happens inside this closure, so the tab redraws the moment its
  /// own sections move and stays still while the other six are loading.
  @override
  Widget build(BuildContext context) => Obx(() => _tab(context));

  Widget _tab(BuildContext context) {
    final name = tab.name;

    // Every collection this tab is built from was refused. No retry and no
    // red: nothing is broken, the answer will not change, and the only useful
    // next step is a person rather than a button.
    if (controller.isTabDenied(tab)) {
      return EmptyState(
        key: PatientHubKeys.noAccess(name),
        icon: Icons.lock_outline_rounded,
        title: 'Not available to your role',
        message: 'Ask an administrator if you need to see this part of the '
            'record.',
      );
    }

    final content = _content(context);
    final hasContent = content != null;

    if (!hasContent && controller.isTabLoading(tab)) {
      return const BentoSkeleton(rows: 3, hasHeader: false);
    }

    final error = controller.tabError(tab);
    if (!hasContent && error != null) {
      return ErrorRetryBanner(
        key: PatientHubKeys.tabError(name),
        message: error,
        onRetry: () => controller.showTab(tab, force: true),
      );
    }

    final notice = controller.tabNotice(tab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notice != null) ...[
          NoticeBanner(
            key: PatientHubKeys.partialAccess(name),
            message: notice,
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        if (error != null) ...[
          ErrorRetryBanner(
            key: PatientHubKeys.tabError(name),
            message: error,
            onRetry: () => controller.showTab(tab, force: true),
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        content ?? _empty(name),
      ],
    );
  }

  /// The tab's own content, or null when there is nothing to show yet.
  Widget? _content(BuildContext context) => switch (tab) {
        PatientHubTab.summary => _Summary(controller: controller),
        PatientHubTab.visits =>
          controller.visits.isEmpty ? null : _Visits(controller: controller),
        PatientHubTab.vitals => controller.latestConsultation == null
            ? null
            : _Vitals(controller: controller),
        PatientHubTab.orders =>
          controller.labOrders.items.isEmpty &&
                  controller.radiologyOrders.items.isEmpty
              ? null
              : _Orders(controller: controller),
        PatientHubTab.results =>
          controller.results.isEmpty ? null : _Results(controller: controller),
        PatientHubTab.prescriptions => controller.prescriptions.items.isEmpty
            ? null
            : _Prescriptions(controller: controller),
        PatientHubTab.billing => controller.invoices.items.isEmpty
            ? null
            : _Billing(controller: controller),
      };

  Widget _empty(String name) => EmptyState(
        key: PatientHubKeys.tabEmpty(name),
        compact: true,
        icon: switch (tab) {
          PatientHubTab.visits => Icons.event_note_outlined,
          PatientHubTab.vitals => Icons.favorite_border_rounded,
          PatientHubTab.orders => Icons.assignment_outlined,
          PatientHubTab.results => Icons.science_outlined,
          PatientHubTab.prescriptions => Icons.medication_outlined,
          PatientHubTab.billing => Icons.receipt_long_outlined,
          PatientHubTab.summary => Icons.badge_outlined,
        },
        title: switch (tab) {
          PatientHubTab.visits => 'No visits recorded',
          PatientHubTab.vitals => 'No observations recorded',
          PatientHubTab.orders => 'Nothing has been ordered',
          PatientHubTab.results => 'No results yet',
          PatientHubTab.prescriptions => 'Nothing has been prescribed',
          PatientHubTab.billing => 'Nothing has been billed',
          PatientHubTab.summary => 'Nothing on file',
        },
      );
}
