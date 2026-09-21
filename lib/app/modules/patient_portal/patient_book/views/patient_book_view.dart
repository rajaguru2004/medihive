import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/patient_text.dart';
import '../../../../core/keys/patient_portal_keys.dart';
import '../../../../data/models/doctor_model.dart';
import '../../../../theme/theme.dart';
import '../controllers/patient_book_controller.dart';

/// A patient asking for an appointment.
///
/// The register is the portal's, not the ward's: nothing is set below 17,
/// every target is past 48, and the three cards are three questions in the
/// order somebody would be asked them at a desk — who, when, why. The desk's
/// own booking form is denser on purpose; a step down in density between the
/// dashboard and this screen would read as two different apps.
class PatientBookView extends GetView<PatientBookController> {
  const PatientBookView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of build. A `GetView` whose build never touches
    // `controller` never constructs its `lazyPut` controller, and the screen
    // sits on a skeleton forever waiting for an `onReady` that cannot fire.
    final c = controller;

    return Scaffold(
      appBar: const DetailHeader(title: 'Book an appointment'),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (c.isLoading && c.rxFirstLoad.value) {
              return const Padding(
                padding: EdgeInsets.all(BentoSpace.page),
                child: BentoSkeleton(rows: 4),
              );
            }

            if (c.hasNoAccess) {
              return const Padding(
                padding: EdgeInsets.all(BentoSpace.page),
                child: EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Not your booking to make',
                  message:
                      'This account cannot book appointments. If you are '
                      'a patient here, ask the desk to link your record.',
                ),
              );
            }

            return _Body(controller: c);
          }),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final PatientBookController controller;

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
                  key: PatientPortalKeys.book,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Obx(() {
                      if (!controller.hasLoadError) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: BentoSpace.action,
                        ),
                        child: ErrorRetryBanner(
                          margin: EdgeInsets.zero,
                          message: controller.rxLoadError.value ?? '',
                          onRetry: controller.load,
                        ),
                      );
                    }),

                    Obx(() {
                      final message = controller.errorMessage.value;
                      if (message == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: BentoSpace.action,
                        ),
                        child: NoticeBanner(
                          key: PatientPortalKeys.bookError,
                          message: message,
                          icon: Icons.error_outline_rounded,
                          tint: AppColors.error,
                        ),
                      );
                    }),

                    const _EmergencyNotice(),
                    const SizedBox(height: BentoSpace.section),
                    _WhoCard(controller: controller),
                    const SizedBox(height: BentoSpace.section),
                    _WhenCard(controller: controller),
                    const SizedBox(height: BentoSpace.section),
                    _WhyCard(controller: controller),
                  ],
                ),
              ),
            ),
          ),
          _BookBar(controller: controller),
        ],
      ),
    );
  }
}

/// What this screen is not for.
///
/// Above the form rather than under the button, because somebody who needs to
/// read it is not going to reach the bottom of a booking form first. Amber and
/// not red: red in this app means a deteriorating patient, and a line of
/// guidance is not one. `DESIGN.md` §2.2 and `.agents/RULES.md` §0.
class _EmergencyNotice extends StatelessWidget {
  const _EmergencyNotice();

  @override
  Widget build(BuildContext context) {
    return const NoticeBanner(
      message:
          'If you are very unwell or this cannot wait, do not book here '
          '— come to the hospital or call for help.',
      icon: Icons.warning_amber_rounded,
      tint: AppColors.warning,
    );
  }
}

// ── Who ─────────────────────────────────────────────────────────────────────

class _WhoCard extends StatelessWidget {
  const _WhoCard({required this.controller});

  final PatientBookController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Who you would like to see',
      children: [
        Obx(
          () => AsyncPicker<DoctorModel>(
            fieldKey: PatientPortalKeys.bookDoctor,
            label: 'Doctor',
            required: true,
            valueLabel: controller.doctor.value?.fullName,
            placeholder: 'Choose a doctor',
            error: controller.doctorError,
            emptyMessage: 'No doctors are taking bookings here yet',
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
}

// ── When ────────────────────────────────────────────────────────────────────

class _WhenCard extends StatelessWidget {
  const _WhenCard({required this.controller});

  final PatientBookController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'When',
      children: [
        Obx(
          () => DateField(
            fieldKey: PatientPortalKeys.bookDate,
            label: 'Day',
            required: true,
            value: controller.date.value,
            format: controller.formatDate,
            error: controller.dateError,
            firstDate: controller.firstBookableDay,
            lastDate: controller.lastBookableDay,
            onChanged: controller.chooseDate,
          ),
        ),
        Obx(() {
          final chosen = controller.doctor.value;
          return BentoPicker(
            fieldKey: PatientPortalKeys.bookTime,
            label: 'Time',
            required: true,
            // Absent choices rather than a disabled field: until a doctor is
            // chosen there is no day to show, and a picker that opens on an
            // empty sheet reads as a broken screen.
            enabled: chosen != null,
            value: controller.time.value == null
                ? null
                : controller.formatSlot(controller.time.value),
            placeholder: chosen == null
                ? 'Choose a doctor first'
                : 'Choose a time',
            error: controller.timeError,
            hint: controller.isLoadingSlots.value
                ? 'Checking what is free…'
                : 'Times already taken are not shown',
            icon: Icons.schedule_rounded,
            onTap: () => _openSlots(context, controller),
          );
        }),

        // The state the screen most needs to be honest about: a full day and a
        // day whose availability could not be read look the same to a patient,
        // and only one of them means "try another day". `isDayFull` is false
        // while the read is in flight and false if it failed, so this only
        // ever appears when the clinic really has nothing left.
        Obx(() {
          if (controller.doctor.value == null || !controller.isDayFull) {
            return const SizedBox.shrink();
          }
          return const Padding(
            padding: EdgeInsets.only(top: BentoSpace.header),
            child: NoticeBanner(
              key: PatientPortalKeys.bookNoSlots,
              message:
                  'This doctor has nothing left on that day. Try another '
                  'day, or another doctor.',
              icon: Icons.event_busy_outlined,
            ),
          );
        }),
      ],
    );
  }
}

/// The slots left in this clinician's day.
///
/// A sheet of rows rather than a grid of chips: every entry is a 48 dp target
/// with the time written the way the site writes it, and the value it carries
/// is the exact string the request will send — so what somebody taps and what
/// the server stores are the same thing.
Future<void> _openSlots(
  BuildContext context,
  PatientBookController controller,
) {
  final chosen = controller.time.value;
  final offered = controller.slots;

  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Choose a time',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offered.isEmpty)
            const SheetSection(
              child: NoticeBanner(
                message:
                    'There are no times left on that day. Close this and '
                    'choose another day.',
                icon: Icons.event_busy_outlined,
              ),
            )
          else
            for (final slot in offered)
              SheetRow(
                key: PatientPortalKeys.bookSlot(slot),
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

  final PatientBookController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'What it is about',
      children: [
        Obx(
          () => BentoField(
            label: 'Is this your first visit?',
            child: BentoSegmented<String>(
              options: PatientBookController.visitTypes.keys.toList(),
              selected: controller.visitType.value,
              labelOf: (value) =>
                  PatientBookController.visitTypes[value] ?? value,
              onSelected: controller.setVisitType,
            ),
          ),
        ),
        Obx(
          () => BentoInput(
            fieldKey: PatientPortalKeys.bookReason,
            label: 'What would you like to be seen about?',
            controller: controller.reasonController,
            validator: controller.validateReason,
            required: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            // Said where the text is rather than in a banner at the top: the
            // patient needs to know these are their own words carried over at
            // the moment they are reading them, not three cards earlier.
            hint: controller.reasonFromCase.value
                ? PatientText.reasonFromYourAnswers
                : 'In your own words. The doctor reads this before you arrive.',
          ),
        ),
      ],
    );
  }
}

// ── The bar ─────────────────────────────────────────────────────────────────

class _BookBar extends StatelessWidget {
  const _BookBar({required this.controller});

  final PatientBookController controller;

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
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldErrorSummary(count: controller.missingCount),
              if (controller.missingCount > 0)
                const SizedBox(height: BentoSpace.header),
              PrimaryBar(
                key: PatientPortalKeys.bookSubmit,
                label: 'Ask for this appointment',
                icon: Icons.event_available_outlined,
                busy: controller.isSubmitting.value,
                onPressed: controller.submit,
              ),
              const SizedBox(height: BentoSpace.header),
              // The one thing a patient must not misread about this screen.
              // The booking is created as `scheduled`, which the hospital then
              // confirms — so a button that said "Book" and a screen that said
              // nothing else would promise a slot the clinic has not agreed to
              // yet.
              Text(
                'The hospital will confirm your appointment. You will see it '
                'on your own screen either way.',
                textAlign: TextAlign.center,
                style:
                    (Theme.of(context).brightness == Brightness.dark
                            ? AppTextStyles.darkSubheadline()
                            : AppTextStyles.lightSubheadline())
                        .copyWith(
                          color: secondaryLabelColor(context),
                          height: 1.4,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
