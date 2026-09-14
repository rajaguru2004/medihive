import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/patients_keys.dart';
import '../../../core/window_class.dart';
import '../../../data/models/patient.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../patient_hub/views/patient_hub_view.dart';
import '../controllers/patients_controller.dart';
import '../patient_routes.dart';

/// The patient register.
///
/// Every list in every other module opens a patient, and this is the list that
/// is only about patients — so it is the plainest screen in the app on
/// purpose: who, which record, how old, and whether the record is still live.
///
/// On a tablet the hub sits beside it rather than on top of it. A clinician
/// working through a list of people is doing one job, and pushing and popping
/// a screen for each of them is the same job with an animation in the middle.
class PatientsView extends GetView<PatientsController> {
  const PatientsView({super.key, this.embedded = true});

  /// False when pushed as its own route rather than shown inside the shell.
  ///
  /// The difference is the header and the ground, nothing else — a screen that
  /// renders differently depending on where it is mounted is two screens
  /// pretending to be one.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Read first, and at the root: a `GetView` whose build never touches
    // `controller` never constructs its `lazyPut` instance, so `onInit` never
    // runs and the screen sits on an empty list forever.
    final register = _Register(controller: controller);

    final body = WindowClass.of(context).isTwoPane
        ? Obx(
            () => ListDetailScaffold(
              listPaneKey: PatientsKeys.listPane,
              detailPaneKey: PatientsKeys.detailPane,
              selectedId: controller.selectedId.value,
              list: register,
              placeholder: const EmptyState(
                icon: Icons.badge_outlined,
                title: 'No patient chosen',
                message: 'Pick somebody on the left to see their record here.',
              ),
              // Keyed by id so choosing another patient builds a new hub
              // rather than reusing the last one's controller and its rows.
              detailBuilder: (context, id) =>
                  PatientHubPane(key: ValueKey(id), patientId: id),
            ),
          )
        : register;

    if (embedded) return KeyedSubtree(key: PatientsKeys.screen, child: body);

    return Scaffold(
      key: PatientsKeys.screen,
      appBar: const DetailHeader(title: 'Patients'),
      body: BentoGround(child: body),
    );
  }
}

// ── The list ────────────────────────────────────────────────────────────────

class _Register extends StatelessWidget {
  const _Register({required this.controller});

  final PatientsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.items;
      final isTwoPane = WindowClass.of(context).isTwoPane;

      return BentoScreen(
        // The ground is painted once, by the shell or by this module's own
        // `Scaffold`. A tab that paints its own flat one on top leaves a seam
        // exactly where the two meet.
        ground: false,
        bottomClearance: false,
        onRefresh: () => controller.reload(silent: true),
        slivers: [
          BentoSection(
            top: BentoSpace.page,
            bottom: BentoSpace.action,
            child: _Controls(controller: controller),
          ),
          SliverToBoxAdapter(
            child: FilterChips<PatientStatusView>(
              options: PatientStatusView.values,
              selected: controller.status.value,
              labelOf: (value) => value.label,
              keyOf: (value) => PatientsKeys.statusFilter(value.name),
              onSelected: controller.showStatus,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: BentoSpace.header)),
          InfiniteList(
            key: PatientsKeys.list,
            phase: controller.phase.value,
            itemCount: rows.length,
            hasMore: controller.hasMore,
            loadingMore: controller.loadingMore.value,
            onLoadMore: controller.loadMore,
            error: controller.errorMessage.value,
            onRetry: controller.reload,
            separator: const Hairline(indent: 68),
            empty: _Empty(controller: controller),
            // On a two-pane window each row gets its own `Obx`, because a
            // sliver's children are built during layout rather than inside the
            // closure above — so a row reading `selectedId` from there would
            // subscribe to nothing and the list would never mark the open
            // patient.
            //
            // On a phone there is no selection to read, and an `Obx` whose
            // builder touches no observable **throws** rather than degrading:
            // `[Get] the improper use of a GetX has been detected`. That is
            // one error per row, and a register with no rows on it.
            itemBuilder: (context, index) {
              final patient = rows[index];
              if (!isTwoPane) {
                return _PatientRow(
                  key: PatientsKeys.row(patient.id),
                  patient: patient,
                  controller: controller,
                  isTwoPane: false,
                  selected: false,
                );
              }
              return Obx(
                () => _PatientRow(
                  key: PatientsKeys.row(patient.id),
                  patient: patient,
                  controller: controller,
                  isTwoPane: true,
                  selected: controller.selectedId.value == patient.id,
                ),
              );
            },
          ),
        ],
      );
    });
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final PatientsController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ListControls(
            searchKey: PatientsKeys.search,
            searchHint: 'Name, MRN or phone',
            onSearch: controller.search,
            onSort: () => _openSort(context, controller),
            sortKey: PatientsKeys.sortButton,
          ),
        ),
        // Absent, not disabled, for an account without `patients.create`.
        // A control that refuses to work is a question the person holding the
        // tablet has no way to answer.
        if (controller.canRegister) ...[
          const SizedBox(width: 8),
          CircleIconButton(
            key: PatientsKeys.registerButton,
            icon: Icons.person_add_alt_1_outlined,
            tooltip: 'Register patient',
            onTap: () => Get.toNamed<void>(PatientRoutes.form),
          ),
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.controller});

  final PatientsController controller;

  @override
  Widget build(BuildContext context) {
    final searching = controller.query.value.trim().isNotEmpty;
    final narrowed = controller.status.value != PatientStatusView.all;

    // Three different empties, and they are not the same sentence. "Nobody is
    // registered yet" over a filtered list is the single most common way an
    // app is reported to have lost somebody's data.
    if (searching) {
      return EmptyState(
        key: PatientsKeys.empty,
        icon: Icons.person_search_outlined,
        title: 'Nobody matches that',
        message: narrowed
            ? 'The register is searched by name, MRN and phone number — and '
                'this list is narrowed to ${controller.status.value.label
                    .toLowerCase()}.'
            : 'The register is searched by name, MRN and phone number.',
        // Only offered when there is a filter to lift. A "show everyone" that
        // leaves the search term in the field takes the blame for a list that
        // is still empty.
        actionLabel: narrowed ? 'Show everyone' : null,
        onAction:
            narrowed ? () => controller.showStatus(PatientStatusView.all) : null,
      );
    }

    if (narrowed) {
      return EmptyState(
        key: PatientsKeys.empty,
        icon: Icons.badge_outlined,
        title: 'No ${controller.status.value.label.toLowerCase()} patients',
        actionLabel: 'Show everyone',
        onAction: () => controller.showStatus(PatientStatusView.all),
      );
    }

    return EmptyState(
      key: PatientsKeys.empty,
      icon: Icons.badge_outlined,
      title: 'Nobody is registered yet',
      message: 'Patients registered at the front desk appear here.',
      actionLabel: controller.canRegister ? 'Register patient' : null,
      actionKey: PatientsKeys.registerFromEmpty,
      onAction: controller.canRegister
          ? () => Get.toNamed<void>(PatientRoutes.form)
          : null,
    );
  }
}

// ── One row ─────────────────────────────────────────────────────────────────

class _PatientRow extends StatelessWidget {
  const _PatientRow({
    super.key,
    required this.patient,
    required this.controller,
    required this.isTwoPane,
    required this.selected,
  });

  final Patient patient;
  final PatientsController controller;
  final bool isTwoPane;

  /// Marks the row the tablet's second pane is showing.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // `42y · Female`, and neither half invented: `Formatters.age` answers an
    // em-dash for a record with no date of birth rather than making the
    // patient a neonate, and `Formatters.label` turns the stored `female` into
    // a word somebody would say.
    final facts = <String>[
      patient.age,
      if ((patient.gender ?? '').isNotEmpty) Formatters.label(patient.gender),
    ].where((fact) => fact.isNotEmpty && fact != '—').join(' · ');

    return PersonRow(
      name: patient.displayName,
      subtitle: patient.mrn.isEmpty ? null : 'MRN ${patient.mrn}',
      detail: facts,
      selected: selected,
      trailing: patient.isActive
          ? null
          // The word as well as the tint. A record nobody may write to has to
          // say so before somebody starts typing into it.
          : const StatusPill(
              status: 'inactive',
              label: 'Inactive',
              compact: true,
            ),
      onTap: () {
        if (isTwoPane) {
          controller.select(patient.id);
          return;
        }
        Get.toNamed<void>(
          PatientRoutes.hub,
          arguments: controller.hubArgumentsFor(patient),
        );
      },
    );
  }
}

// ── Sort ────────────────────────────────────────────────────────────────────

Future<void> _openSort(BuildContext context, PatientsController controller) {
  return Get.bottomSheet<void>(
    SortSheet(
      options: controller.sortOptions,
      selected: controller.sort,
      optionKey: (option) => PatientsKeys.sortOption(
        option.field,
        descending: option.descending,
      ),
      onSelected: (option) {
        Get.back<void>();
        controller.applySort(option);
      },
    ),
    isScrollControlled: true,
  );
}
