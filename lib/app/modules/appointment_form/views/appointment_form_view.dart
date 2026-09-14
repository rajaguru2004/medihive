import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/appointment_form_keys.dart';
import '../../../core/unsaved_changes.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/patient_ref.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/appointment_form_controller.dart';

/// Booking a clinic slot.
///
/// Six answers in the order a desk gives them: who, with whom, when, how long,
/// what kind of visit, and what has brought them in. The slots on offer come
/// from this site's own working hours, so a clinic that opens at seven can book
/// its first hour.
class AppointmentFormView extends GetView<AppointmentFormController> {
  const AppointmentFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of build, deliberately: a `GetView` whose build never
    // touches `controller` never constructs its `lazyPut` controller, and the
    // screen sits on a skeleton forever while `onReady` waits to be called.
    final isEditing = controller.isEditing;

    return UnsavedChangesGuard(
      isDirty: () => controller.isDirty,
      child: Scaffold(
        appBar: DetailHeader(
          title: isEditing ? 'Edit appointment' : 'Book appointment',
        ),
        body: BentoGround(
          child: SafeArea(
            child: Obx(() {
              if (controller.isLoading && controller.rxFirstLoad.value) {
                return const Padding(
                  padding: EdgeInsets.all(BentoSpace.page),
                  child: BentoSkeleton(rows: 4),
                );
              }

              if (controller.hasNoAccess) {
                return const Padding(
                  padding: EdgeInsets.all(BentoSpace.page),
                  child: EmptyState(
                    key: AppointmentFormKeys.noAccess,
                    icon: Icons.lock_outline_rounded,
                    title: 'Not your booking to make',
                    message: 'This account can read the clinic list but not '
                        'change it.',
                  ),
                );
              }

              return _Body(controller: controller, isEditing: isEditing);
            }),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.isEditing});

  final AppointmentFormController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BentoSpace.page),
              child: MaxWidthBody(
                maxWidth: 520,
                child: Column(
                  key: AppointmentFormKeys.screen,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.hasLoadError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: BentoSpace.action),
                        child: ErrorRetryBanner(
                          message: controller.rxLoadError.value!,
                          onRetry: controller.load,
                        ),
                      ),

                    Obx(() {
                      final message = controller.errorMessage.value;
                      if (message == null) return const SizedBox.shrink();
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: BentoSpace.action),
                        child: NoticeBanner(
                          key: AppointmentFormKeys.error,
                          message: message,
                          icon: Icons.error_outline_rounded,
                          tint: AppColors.error,
                        ),
                      );
                    }),

                    _WhoCard(controller: controller, isEditing: isEditing),
                    const SizedBox(height: BentoSpace.section),
                    _WhenCard(controller: controller),
                    const SizedBox(height: BentoSpace.section),
                    _WhyCard(controller: controller),
                  ],
                ),
              ),
            ),
          ),
          _SaveBar(controller: controller, isEditing: isEditing),
        ],
      ),
    );
  }
}

// ── Who ─────────────────────────────────────────────────────────────────────

class _WhoCard extends StatelessWidget {
  const _WhoCard({required this.controller, required this.isEditing});

  final AppointmentFormController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Who',
      children: [
        Obx(() {
          final chosen = controller.patient.value;
          return AsyncPicker<PatientRef>(
            fieldKey: AppointmentFormKeys.patient,
            label: 'Patient',
            required: true,
            // A booking cannot be moved to another patient — the update DTO has
            // no `patientId` — so on an edit the field states the fact rather
            // than offering a choice the server would refuse.
            enabled: !isEditing,
            valueLabel: chosen == null || chosen.isEmpty
                ? null
                : '${chosen.displayName} · MRN ${chosen.mrn}',
            error: controller.patientError,
            hint: isEditing
                ? 'A booking stays with the patient it was made for'
                : null,
            searchHint: 'Search by name or MRN',
            onSearch: _searchPatients,
            onSelected: controller.choosePatient,
          );
        }),
        Obx(
          () => AsyncPicker<DoctorModel>(
            fieldKey: AppointmentFormKeys.doctor,
            label: 'Clinician',
            required: true,
            valueLabel: controller.doctor.value?.fullName,
            error: controller.doctorError,
            emptyMessage: 'No clinicians are listed for this site',
            options: [
              for (final doctor in controller.doctors)
                PickerOption<DoctorModel>(
                  value: doctor,
                  label: doctor.fullName,
                  sublabel: doctor.specialization,
                ),
            ],
            onSelected: controller.chooseDoctor,
          ),
        ),
      ],
    );
  }

  Future<List<PickerOption<PatientRef>>> _searchPatients(String query) async {
    final rows = await controller.searchPatients(query);
    return [
      for (final row in rows)
        PickerOption<PatientRef>(
          value: row,
          label: row.displayName,
          sublabel: 'MRN ${row.mrn} · ${row.age}',
        ),
    ];
  }
}

// ── When ────────────────────────────────────────────────────────────────────

class _WhenCard extends StatelessWidget {
  const _WhenCard({required this.controller});

  final AppointmentFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'When',
      children: [
        Obx(
          () => DateField(
            fieldKey: AppointmentFormKeys.date,
            label: 'Date',
            required: true,
            value: controller.date.value,
            format: controller.formatDate,
            onChanged: controller.chooseDate,
          ),
        ),
        Obx(
          () => BentoPicker(
            fieldKey: AppointmentFormKeys.time,
            label: 'Time',
            required: true,
            value: controller.time.value == null
                ? null
                : controller.formatSlot(controller.time.value),
            placeholder: 'Choose a slot',
            error: controller.timeError,
            hint: 'Clinic hours '
                '${controller.formatSlot(controller.openingTime)}–'
                '${controller.formatSlot(controller.closingTime)}',
            icon: Icons.schedule_rounded,
            onTap: () => _openSlots(context, controller),
          ),
        ),
        Obx(
          () => BentoField(
            label: 'Duration',
            hint: 'minutes',
            child: BentoSegmented<int>(
              options: AppointmentFormController.durations,
              selected: controller.duration.value,
              labelOf: (minutes) => '$minutes',
              keyOf: AppointmentFormKeys.duration,
              onSelected: controller.setDuration,
            ),
          ),
        ),
      ],
    );
  }
}

/// The slots this site's diary actually has.
///
/// A sheet rather than a wheel: the list is short enough to read, and every
/// entry is the exact string the request will carry, so what somebody taps and
/// what the server stores are the same thing.
Future<void> _openSlots(
  BuildContext context,
  AppointmentFormController controller,
) {
  final chosen = controller.time.value;

  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Time',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.slots.isEmpty)
            const SheetSection(
              child: NoticeBanner(
                message: 'This site has no clinic hours set, so there are no '
                    'slots to offer. Set them in the admin console.',
                icon: Icons.schedule_outlined,
                tint: AppColors.warning,
              ),
            )
          else
            for (final slot in controller.slots)
              SheetRow(
                key: AppointmentFormKeys.slot(slot),
                icon: Icons.schedule_rounded,
                label: controller.formatSlot(slot),
                selected: slot == chosen,
                onTap: () {
                  controller.chooseSlot(slot);
                  Get.back<void>();
                },
              ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

// ── Why ─────────────────────────────────────────────────────────────────────

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.controller});

  final AppointmentFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Why',
      children: [
        Obx(
          () => BentoField(
            label: 'Visit type',
            child: BentoSegmented<String>(
              options: AppointmentFormController.types.keys.toList(),
              selected: controller.type.value,
              labelOf: (value) =>
                  AppointmentFormController.types[value] ??
                  Formatters.label(value),
              keyOf: AppointmentFormKeys.type,
              onSelected: controller.setType,
            ),
          ),
        ),
        BentoInput(
          fieldKey: AppointmentFormKeys.complaint,
          label: 'Chief complaint',
          controller: controller.complaintController,
          validator: controller.validateComplaint,
          required: true,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          hint: 'What the clinician will see first',
        ),
        BentoInput(
          fieldKey: AppointmentFormKeys.notes,
          label: 'Notes',
          controller: controller.notesController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}

// ── The bar ─────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller, required this.isEditing});

  final AppointmentFormController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        0,
        BentoSpace.page,
        BentoSpace.page,
      ),
      child: MaxWidthBody(
        maxWidth: 520,
        child: Obx(() {
          // Absent, not disabled. A save button that cannot save is a button
          // somebody presses twice before reading the message under it.
          if (!controller.canSave) {
            return const NoticeBanner(
              key: AppointmentFormKeys.noAccess,
              message: 'This account can read the clinic list but not change '
                  'it. Ask an administrator if that is wrong.',
              icon: Icons.lock_outline_rounded,
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldErrorSummary(count: controller.missingCount),
              if (controller.missingCount > 0)
                const SizedBox(height: BentoSpace.header),
              PrimaryBar(
                key: AppointmentFormKeys.save,
                label: isEditing ? 'Save changes' : 'Book appointment',
                icon: isEditing ? null : Icons.event_available_outlined,
                busy: controller.isSubmitting.value,
                onPressed: controller.submit,
              ),
            ],
          );
        }),
      ),
    );
  }
}
