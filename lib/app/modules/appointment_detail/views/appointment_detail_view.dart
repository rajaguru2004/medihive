import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/appointment_detail_keys.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/repositories/clinical_repository.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../appointments/appointment_routes.dart';
import '../controllers/appointment_detail_controller.dart';

/// One booking.
///
/// Who, when, with whom — and then the ladder, because the question a clinic
/// desk opens this screen with is "where has this got to", and the answer is an
/// order rather than a colour.
class AppointmentDetailView extends GetView<AppointmentDetailController> {
  const AppointmentDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Appointment'),
      body: Obx(() {
        final booking = controller.appointment.value;

        if (booking == null) {
          return Padding(
            padding: const EdgeInsets.all(BentoSpace.page),
            child: controller.isLoading
                ? const BentoSkeleton(rows: 4)
                : EmptyState(
                    key: AppointmentDetailKeys.missing,
                    icon: Icons.event_busy_outlined,
                    title: 'That appointment is not here',
                    message: controller.rxLoadError.value,
                    actionLabel: 'Go back',
                    onAction: Get.back,
                  ),
          );
        }

        return BentoScreen(
          key: AppointmentDetailKeys.screen,
          onRefresh: controller.reload,
          bottomClearance: false,
          slivers: [
            if (controller.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  key: AppointmentDetailKeys.error,
                  message: controller.rxLoadError.value!,
                  onRetry: controller.load,
                ),
              ),

            BentoSection(
              top: controller.hasLoadError ? 0 : BentoSpace.page,
              bottom: BentoSpace.header,
              child: _Header(controller: controller, booking: booking),
            ),

            BentoSection(
              bottom: BentoSpace.header,
              child: _Facts(controller: controller, booking: booking),
            ),

            BentoSection(
              bottom: BentoSpace.header,
              child: _Timeline(controller: controller),
            ),

            BentoSection(
              child: _Actions(controller: controller),
            ),
          ],
        );
      }),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.booking});

  final AppointmentDetailController controller;
  final AppointmentModel booking;

  @override
  Widget build(BuildContext context) {
    return RecordHeader(
      title: booking.patient.displayName,
      subtitle: '${controller.formatDate(booking.appointmentDate)} · '
          '${controller.formatSlot(booking.appointmentTime)}',
      status: CaseStatus.labelOf(booking.status),
      statusColor: CaseStatus.colorOf(booking.status),
      actions: [
        if (controller.canUpdate)
          RecordAction(
            key: AppointmentDetailKeys.edit,
            icon: Icons.edit_outlined,
            label: 'Edit',
            onPressed: () => Get.toNamed<void>(
              AppointmentRoutes.form,
              arguments: {'id': booking.id},
            ),
          ),
        if (controller.canDelete)
          RecordAction(
            key: AppointmentDetailKeys.delete,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            destructive: true,
            onPressed: () => _confirmDelete(context, controller),
          ),
      ],
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  AppointmentDetailController controller,
) async {
  final confirmed = await ConfirmDialog.show(
    context,
    title: 'Delete ${controller.patientName}’s appointment?',
    message: 'The booking is removed from the clinic list and from every '
        'report that counts it. The slot is freed. This cannot be undone.',
    confirmLabel: 'Delete',
    cancelLabel: 'Keep it',
    destructive: true,
    confirmKey: AppointmentDetailKeys.deleteConfirm,
  );
  if (confirmed) await controller.remove();
}

// ── Facts ───────────────────────────────────────────────────────────────────

class _Facts extends StatelessWidget {
  const _Facts({required this.controller, required this.booking});

  final AppointmentDetailController controller;
  final AppointmentModel booking;

  @override
  Widget build(BuildContext context) {
    final patient = booking.patient;

    return BentoCard(
      key: AppointmentDetailKeys.facts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PatientIdentityBand(
            name: patient.displayName,
            mrn: patient.mrn,
            age: patient.age,
            sex: patient.gender,
          ),
          const SizedBox(height: 14),
          const Hairline(),
          const SizedBox(height: 6),
          FactRow(
            label: 'Clinician',
            value: booking.doctor.fullName.trim().isEmpty
                ? 'Not assigned'
                : booking.doctor.fullName,
          ),
          FactRow(label: 'Visit type', value: booking.formattedType),
          FactRow(
            label: 'Duration',
            value: '${booking.durationMinutes} minutes',
          ),
          if (booking.chiefComplaint.trim().isNotEmpty)
            FactRow(
              label: 'Complaint',
              value: booking.chiefComplaint,
              stacked: true,
            ),
          if (booking.notes.trim().isNotEmpty)
            FactRow(label: 'Notes', value: booking.notes, stacked: true),
        ],
      ),
    );
  }
}

// ── The ladder ──────────────────────────────────────────────────────────────

/// Where the booking has got to, as an order rather than as a colour.
///
/// Each step carries its word and, where the server stamped one, its time — so
/// the state survives a colour-blind reader, a printed record, and a glance
/// across a corridor.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.controller});

  final AppointmentDetailController controller;

  @override
  Widget build(BuildContext context) {
    final steps = controller.timeline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Progress'),
        BentoCard(
          key: AppointmentDetailKeys.timeline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++)
                _Step(
                  step: steps[i],
                  isLast: i == steps.length - 1,
                  controller: controller,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.isLast,
    required this.controller,
  });

  final AppointmentStep step;
  final bool isLast;
  final AppointmentDetailController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A step the booking ended on rather than passed through is amber: a
    // cancellation is an administrative fact, not a deteriorating patient.
    final tone = step.terminal
        ? AppColors.warning
        : step.done
            ? AppColors.acuityStable
            : AppColors.acuityDischarged;

    final at = step.at;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: StatusMark(
                  color: step.done ? tone : hairlineColor(context),
                  size: 9,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: SizedBox(
                    width: 1,
                    child: ColoredBox(color: hairlineColor(context)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: step.done
                        ? (isDark
                            ? AppTextStyles.darkCallout(
                                weight: FontWeight.w600,
                              )
                            : AppTextStyles.lightCallout(
                                weight: FontWeight.w600,
                              ))
                        : (isDark
                            ? AppTextStyles.darkCallout()
                            : AppTextStyles.lightCallout()),
                  ),
                  if (at != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.dateMedium(at)} · '
                      '${controller.formatSlot(_clock(at))}',
                      style: isDark
                          ? AppTextStyles.darkCaption1()
                          : AppTextStyles.lightCaption1(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A stamped instant as the `"HH:mm"` the site's clock formatter reads, so a
  /// timeline and a booking's own time are written the same way.
  static String _clock(DateTime at) {
    final local = at.toLocal();
    return ClinicSchedule.clockOf(local.hour * 60 + local.minute);
  }
}

// ── What next ───────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final AppointmentDetailController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.canUpdate && !controller.canDelete) {
      return const NoticeBanner(
        key: AppointmentDetailKeys.noAccess,
        message: 'This account can read the clinic list but not change it.',
        icon: Icons.lock_outline_rounded,
      );
    }

    if (controller.isFinishedWith) {
      return NoticeBanner(
        key: AppointmentDetailKeys.closedNotice,
        message: switch (controller.status) {
          AppointmentStatus.completed =>
            'This appointment has been seen and is closed. Write up what '
                'happened as a consultation.',
          AppointmentStatus.cancelled =>
            'This appointment was cancelled. Rebooking is a new appointment.',
          _ => 'Nobody attended this appointment. Rebooking is a new '
              'appointment.',
        },
        icon: Icons.lock_outline_rounded,
      );
    }

    final steps = controller.nextSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'What next'),
        BentoCard(
          padding: const EdgeInsets.symmetric(
            vertical: BentoSpace.listCardPad,
            horizontal: 6,
          ),
          child: Column(
            children: [
              for (final step in steps)
                SheetRow(
                  key: AppointmentDetailKeys.action(step),
                  icon: _iconOf(step),
                  label: AppointmentDetailController.labelOfStep(step),
                  sublabel: AppointmentDetailController.captionOfStep(step),
                  onTap: () => controller.moveTo(step),
                ),
              if (controller.canReschedule)
                SheetRow(
                  key: AppointmentDetailKeys.reschedule,
                  icon: Icons.event_repeat_rounded,
                  label: 'Move to another slot',
                  sublabel: 'A new day or time, and the booking says so',
                  onTap: () => _openReschedule(context, controller),
                ),
              if (controller.canCancel) ...[
                const Hairline(indent: BentoSpace.listPad),
                SheetRow(
                  key: AppointmentDetailKeys.cancel,
                  icon: Icons.event_busy_outlined,
                  label: 'Cancel appointment',
                  sublabel: 'The slot is released',
                  destructive: true,
                  onTap: () => _openCancel(context, controller),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static IconData _iconOf(String status) => switch (status) {
        AppointmentStatus.confirmed => Icons.task_alt_rounded,
        AppointmentStatus.checkedIn => Icons.how_to_reg_outlined,
        AppointmentStatus.inProgress => Icons.play_arrow_rounded,
        AppointmentStatus.completed => Icons.check_circle_outline_rounded,
        AppointmentStatus.noShow => Icons.person_off_outlined,
        _ => Icons.arrow_forward_rounded,
      };
}

// ── Reschedule ──────────────────────────────────────────────────────────────

/// A new day and a new time, chosen together.
///
/// Both in one sheet because both go in one request: a reschedule that sends
/// the date without the time leaves a booking at 09:00 on a day the clinic has
/// nobody at 09:00.
Future<void> _openReschedule(
  BuildContext context,
  AppointmentDetailController controller,
) async {
  final booking = controller.appointment.value;
  if (booking == null) return;

  final chosen = await Get.bottomSheet<_Slot>(
    _RescheduleSheet(
      controller: controller,
      initialDate: booking.appointmentDate.toLocal(),
      initialTime: booking.appointmentTime,
    ),
    isScrollControlled: true,
  );
  if (chosen == null) return;
  await controller.reschedule(date: chosen.date, time: chosen.time);
}

/// A day and a time, together, because neither is a reschedule on its own.
class _Slot {
  const _Slot(this.date, this.time);

  final DateTime date;
  final String time;
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({
    required this.controller,
    required this.initialDate,
    required this.initialTime,
  });

  final AppointmentDetailController controller;
  final DateTime initialDate;
  final String initialTime;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late DateTime _date = widget.initialDate;
  late String? _time = widget.initialTime.trim().isEmpty
      ? null
      : widget.initialTime.trim();

  bool _showErrors = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return SheetShell(
      title: 'Move this appointment',
      child: SheetSection(
        bottom: BentoSpace.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DateField(
              fieldKey: AppointmentDetailKeys.rescheduleDate,
              label: 'New date',
              required: true,
              value: _date,
              format: controller.formatDate,
              firstDate: AppointmentDetailController.today(),
              onChanged: (value) {
                if (value != null) setState(() => _date = value);
              },
            ),
            BentoPicker(
              fieldKey: AppointmentDetailKeys.rescheduleTime,
              label: 'New time',
              required: true,
              value: _time == null ? null : controller.formatSlot(_time),
              placeholder: 'Choose a slot',
              error: _showErrors && _time == null ? 'Choose a time' : null,
              icon: Icons.schedule_rounded,
              onTap: _pickTime,
            ),
            const SizedBox(height: BentoSpace.action),
            PrimaryBar(
              key: AppointmentDetailKeys.rescheduleSave,
              label: 'Move appointment',
              icon: Icons.event_repeat_rounded,
              onPressed: () {
                if (_time == null) {
                  setState(() => _showErrors = true);
                  return;
                }
                Get.back<_Slot>(result: _Slot(_date, _time!));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final controller = widget.controller;
    final picked = await Get.bottomSheet<String>(
      SheetShell(
        title: 'New time',
        scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final slot in controller.slots)
              SheetRow(
                key: AppointmentDetailKeys.rescheduleSlot(slot),
                icon: Icons.schedule_rounded,
                label: controller.formatSlot(slot),
                selected: slot == _time,
                onTap: () => Get.back<String>(result: slot),
              ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }
}

// ── Cancel ──────────────────────────────────────────────────────────────────

/// The reason first, then the confirm.
///
/// A reason is required because a cancelled slot with no reason on it is a slot
/// nobody can audit, and the clinic's own no-show figures depend on telling the
/// two apart. The confirm comes after the sheet has closed: a dialog raised
/// from inside a sheet is dismissed along with it.
Future<void> _openCancel(
  BuildContext context,
  AppointmentDetailController controller,
) async {
  final reason = await Get.bottomSheet<String>(
    const _CancelSheet(),
    isScrollControlled: true,
  );
  if (reason == null || reason.trim().isEmpty) return;
  if (!context.mounted) return;

  final confirmed = await ConfirmDialog.show(
    context,
    title: 'Cancel ${controller.patientName}’s appointment?',
    message: 'The slot is released and the booking is marked cancelled with '
        'the reason you gave. Rebooking is a new appointment.',
    confirmLabel: 'Cancel appointment',
    cancelLabel: 'Keep it',
    destructive: true,
    confirmKey: AppointmentDetailKeys.cancelConfirm,
  );
  if (confirmed) await controller.cancel(reason.trim());
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet();

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _reason = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      title: 'Why is it being cancelled?',
      child: SheetSection(
        bottom: BentoSpace.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BentoInput(
              fieldKey: AppointmentDetailKeys.cancelReason,
              label: 'Reason',
              controller: _reason,
              required: true,
              maxLines: 3,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              error: _showError ? 'Say why this slot is being released' : null,
              hint: 'Stored on the booking, and read by whoever asks later',
            ),
            const SizedBox(height: BentoSpace.action),
            PrimaryBar(
              key: AppointmentDetailKeys.cancelSave,
              label: 'Continue',
              onPressed: () {
                final text = _reason.text.trim();
                if (text.isEmpty) {
                  setState(() => _showError = true);
                  return;
                }
                Get.back<String>(result: text);
              },
            ),
          ],
        ),
      ),
    );
  }
}
