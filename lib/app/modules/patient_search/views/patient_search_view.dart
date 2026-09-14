import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/patient_search_keys.dart';
import '../../../core/live_obx.dart';
import '../../../data/models/patient.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../patients/patient_routes.dart';
import '../controllers/patient_search_controller.dart';

/// The global patient lookup.
///
/// One field, autofocused, answered by the server. Everything else on the
/// screen is either a result or the short list of people this clinician has
/// already opened — see [PatientSearchController] for why that list belongs to
/// them and not to the device.
class PatientSearchView extends GetView<PatientSearchController> {
  const PatientSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root, so the controller is constructed even on the frame
    // where every reactive section below happens to draw nothing.
    final search = controller.search;

    return Scaffold(
      key: PatientSearchKeys.screen,
      appBar: const DetailHeader(
        title: 'Find a patient',
        subtitle: 'Name, MRN or phone number',
      ),
      body: BentoGround(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BentoSpace.page,
                  BentoSpace.action,
                  BentoSpace.page,
                  BentoSpace.action,
                ),
                child: MaxWidthBody(
                  child: SearchField(
                    fieldKey: PatientSearchKeys.field,
                    hint: 'Name, MRN or phone',
                    autofocus: true,
                    onChanged: search,
                  ),
                ),
              ),
              // `LiveObx`, not `Obx`: this controller is user-scoped and is
              // dropped part-way through sign-out, while this screen is still
              // mounted. A plain `Obx` rebuilding in that window throws
              // "controller not found" over the sign-in transition.
              Expanded(
                child: LiveObx<PatientSearchController>(
                  builder: (controller) => MaxWidthBody(
                    child: _Body(controller: controller),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final PatientSearchController controller;

  // Its own `Obx`. A child built inside `LiveObx`'s closure does not inherit
  // its subscription — the closure hands back a widget, and that widget's
  // `build` runs later, outside the observer — so a results list that read the
  // controller from here would paint once and never move again.
  @override
  Widget build(BuildContext context) => Obx(() => _body(context));

  Widget _body(BuildContext context) {
    if (controller.hasNoAccess) {
      return const _Panel(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not available to your role',
          message: 'Ask an administrator if you need to look patients up.',
        ),
      );
    }

    if (controller.hasLoadError) {
      return _Panel(
        child: ErrorRetryBanner(
          key: PatientSearchKeys.error,
          message: controller.rxLoadError.value!,
          onRetry: controller.retry,
        ),
      );
    }

    if (!controller.hasTerm) return _Recents(controller: controller);

    if (controller.isLoading && controller.results.isEmpty) {
      return const _Panel(child: BentoSkeleton(rows: 4, hasHeader: false));
    }

    if (controller.results.isEmpty) {
      return const _Panel(
        child: EmptyState(
          key: PatientSearchKeys.empty,
          icon: Icons.person_search_outlined,
          title: 'Nobody matches that',
          message: 'The register is searched by name, MRN and phone number.',
        ),
      );
    }

    return ListView.separated(
      key: PatientSearchKeys.results,
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        0,
        BentoSpace.page,
        BentoSpace.page,
      ),
      itemCount: controller.results.length,
      separatorBuilder: (context, index) => const Hairline(indent: 68),
      itemBuilder: (context, index) {
        final patient = controller.results[index];
        return _ResultRow(
          key: PatientSearchKeys.result(patient.id),
          patient: patient,
          controller: controller,
        );
      },
    );
  }
}

class _Recents extends StatelessWidget {
  const _Recents({required this.controller});

  final PatientSearchController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _recents(context));

  Widget _recents(BuildContext context) {
    if (controller.recents.isEmpty) {
      return const _Panel(
        child: EmptyState(
          key: PatientSearchKeys.prompt,
          icon: Icons.search_rounded,
          title: 'Search the register',
          message: 'Two characters of a name, an MRN or a phone number.',
        ),
      );
    }

    return ListView(
      key: PatientSearchKeys.recents,
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        0,
        BentoSpace.page,
        BentoSpace.page,
      ),
      children: [
        SectionHeader(
          title: 'Recently opened',
          actionLabel: 'Clear',
          onAction: controller.clearRecents,
        ),
        BentoCard(
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: Column(
            children: [
              for (var i = 0; i < controller.recents.length; i++) ...[
                if (i > 0) const Hairline(indent: 68),
                _ResultRow(
                  key: PatientSearchKeys.recent(controller.recents[i].id),
                  patient: controller.recents[i],
                  controller: controller,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: BentoSpace.section),
        Center(
          child: TextButton(
            key: PatientSearchKeys.clearRecents,
            onPressed: controller.clearRecents,
            child: const Text('Clear recent patients'),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    super.key,
    required this.patient,
    required this.controller,
  });

  final Patient patient;
  final PatientSearchController controller;

  @override
  Widget build(BuildContext context) {
    final facts = <String>[
      patient.age,
      if ((patient.gender ?? '').isNotEmpty) Formatters.label(patient.gender),
    ].where((fact) => fact.isNotEmpty && fact != '—').join(' · ');

    return PersonRow(
      name: patient.displayName,
      subtitle: patient.mrn.isEmpty ? null : 'MRN ${patient.mrn}',
      detail: facts,
      trailing: patient.isActive
          ? null
          : const StatusPill(
              status: 'inactive',
              label: 'Inactive',
              compact: true,
            ),
      onTap: () {
        controller.remember(patient);
        Get.toNamed<void>(
          PatientRoutes.hub,
          arguments: {'id': patient.id, 'patient': patient},
        );
      },
    );
  }
}

/// Centres one of the states that is not a list, at the page's own margin.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: BentoSpace.page),
        child: child,
      );
}
