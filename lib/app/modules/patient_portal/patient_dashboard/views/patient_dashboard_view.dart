import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/patient_text.dart';
import '../../../../core/keys/app_keys.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/services/settings_service.dart';
import '../../../../data/utils/formatters.dart';
import '../../../../theme/theme.dart';
import '../controllers/patient_dashboard_controller.dart';

/// The patient's own screen.
///
/// The spec's §3 sketch in `MediHive_Patient_Dashboard_AI_Case_Taking.md` is a
/// greeting, the four places a patient's information lives, and one card that
/// is plainly larger than the rest. That last part is the design: a first-time
/// patient in a waiting room is not browsing, they are looking for the thing
/// they were told to do, and a Start card that is one tile among five is a
/// card they will ask a receptionist about.
///
/// So the register is the patient one, not the ward one. Headings are
/// `title3`, nothing on the screen is set below 17, and every target is well
/// past the 48 the staff screens hold to — the same rules
/// `app_bento_conversation.dart` states for the interview, because this is the
/// screen immediately before it and a step down in density between the two
/// would read as two different apps.
class PatientDashboardView extends GetView<PatientDashboardController> {
  const PatientDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the top, before anything can decide not to. A `GetView` whose
    // build never touches `controller` never constructs it, so a `lazyPut`
    // controller's `onReady` — which is where this screen's fetch lives —
    // simply never runs.
    final c = controller;

    return Scaffold(
      key: PatientPortalKeys.dashboard,
      body: BentoScreen(
        bottomClearance: false,
        onRefresh: c.reload,
        slivers: [
          BentoSection(
            top: BentoSpace.page,
            child: _Greeting(controller: c),
          ),

          // The screen's own failure, above everything it would have filled in.
          BentoSection(
            bottom: 0,
            child: Obx(
              () => c.hasNoAccess
                  ? const _NotAPatientAccount()
                  : c.hasLoadError
                  ? ErrorRetryBanner(
                      key: PatientPortalKeys.dashboardError,
                      margin: EdgeInsets.zero,
                      message: c.rxLoadError.value ?? '',
                      onRetry: c.reload,
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          BentoSection(
            top: BentoSpace.section,
            bottom: 0,
            child: _StartCaseTakingCard(controller: c),
          ),

          // §39. Absent when there is nothing to say, which is the first
          // screen a patient ever sees; present the moment there is an
          // interview open or one already sent.
          BentoSection(
            top: BentoSpace.action,
            child: _YourCase(controller: c),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                BentoSpace.page,
                0,
                BentoSpace.page,
                BentoSpace.header,
              ),
              child: SectionHeader(title: 'Your appointments'),
            ),
          ),
          BentoSection(child: _Appointments(controller: c)),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                BentoSpace.page,
                0,
                BentoSpace.page,
                BentoSpace.header,
              ),
              child: SectionHeader(title: 'Your record'),
            ),
          ),
          BentoSection(child: _Record(controller: c)),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                BentoSpace.page,
                0,
                BentoSpace.page,
                BentoSpace.header,
              ),
              child: SectionHeader(title: 'Your documents'),
            ),
          ),
          BentoSection(child: _Documents(controller: c)),
        ],
      ),
    );
  }
}

/// Hello, and the way out.
///
/// The sign-out is a full 48 dp control on the first screen rather than buried
/// two taps down, because this app runs on hospital tablets as well as on
/// phones and the person holding one may be the fourth patient to use it this
/// morning.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Obx(() {
            final patient = controller.patient;
            return Column(
              key: PatientPortalKeys.greeting,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.isEmpty
                      // Before the record lands, and if it never does. A
                      // greeting that guesses a name is worse than one that
                      // does not use one.
                      ? 'Hello'
                      : 'Hello, ${patient.greetingName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: isDark
                      ? AppTextStyles.darkTitle1()
                      : AppTextStyles.lightTitle1(),
                ),
                const SizedBox(height: 4),
                Text(
                  SettingsService.to.settings.siteName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (isDark
                              ? AppTextStyles.darkCallout()
                              : AppTextStyles.lightCallout())
                          .copyWith(color: secondaryLabelColor(context)),
                ),
              ],
            );
          }),
        ),
        const SizedBox(width: BentoSpace.action),
        CircleIconButton(
          key: PatientPortalKeys.signOut,
          icon: Icons.logout_rounded,
          tooltip: 'Sign out',
          onTap: controller.signOut,
        ),
      ],
    );
  }
}

/// The primary action on the screen.
///
/// `hero: true` is the one card on a screen allowed to sit higher than its
/// siblings, and this is it. The teal is the brand as a **fill**, which is
/// what `DESIGN.md` §2.2 reserves it for — a call to action, never a status.
class _StartCaseTakingCard extends StatelessWidget {
  const _StartCaseTakingCard({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BentoCard(
      hero: true,
      padding: const EdgeInsets.all(BentoSpace.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_outlined,
                size: 22,
                color: brandInkColor(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tell us why you are here',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: isDark
                      ? AppTextStyles.darkTitle3()
                      : AppTextStyles.lightTitle3(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Answer some questions about your symptoms and your health before '
            'you see the doctor. You can speak, type or tap, and you can stop '
            'at any time.',
            style:
                (isDark ? AppTextStyles.darkBody() : AppTextStyles.lightBody())
                    .copyWith(
                      color: secondaryLabelColor(context),
                      height: 1.45,
                    ),
          ),
          const SizedBox(height: BentoSpace.section),
          // 56 rather than the kit's default, matching the conversation layer's
          // targets: this is the one thing on the screen a patient is meant to
          // press, and they may be doing it one-handed.
          SizedBox(
            height: 56,
            child: PrimaryBar(
              key: PatientPortalKeys.startCaseTaking,
              label: 'Start',
              icon: Icons.arrow_forward_rounded,
              onPressed: controller.startCaseTaking,
            ),
          ),
        ],
      ),
    );
  }
}

/// What is booked for them, and the way to ask for one more.
///
/// The booking control is outside the `Obx` branch above it on purpose: it is
/// the same offer whether the list is empty, full, or failed to load. A
/// patient whose appointments could not be fetched can still book one — the
/// two requests are unrelated — and hiding the button inside the error state
/// would take that away for a reason they would have no way to understand.
class _Appointments extends StatelessWidget {
  const _Appointments({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() {
          final error = controller.appointmentsError.value;
          if (error != null) {
            return ErrorRetryBanner(
              margin: EdgeInsets.zero,
              message: error,
              onRetry: controller.reload,
            );
          }

          if (controller.rxFirstLoad.value && controller.isLoading) {
            return const BentoCard(child: BentoSkeleton(rows: 2));
          }

          final rows = controller.ordered;
          if (rows.isEmpty) {
            return const BentoCard(
              child: EmptyState(
                key: PatientPortalKeys.appointmentsEmpty,
                compact: true,
                icon: Icons.event_available_outlined,
                title: 'Nothing booked',
                message:
                    'Nothing is booked for you yet. You can ask for an '
                    'appointment below, or answer the questions above.',
              ),
            );
          }

          return BentoCard(
            key: PatientPortalKeys.appointments,
            padding: const EdgeInsets.symmetric(
              vertical: BentoSpace.listCardPad,
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  _AppointmentRow(appointment: rows[i]),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: BentoSpace.action),
        SecondaryBar(
          key: PatientPortalKeys.bookAppointment,
          label: 'Ask for an appointment',
          icon: Icons.event_available_outlined,
          onPressed: controller.bookAppointment,
        ),
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.to;
    final when = Formatters.relativeDay(appointment.appointmentDate);
    final at = appointment.formattedTime(
      use24Hour: settings.settings.use24HourClock,
    );

    return BentoRow(
      key: PatientPortalKeys.appointment(appointment.id),
      icon: Icons.event_outlined,
      title: '$when at $at',
      // The doctor's name, and what the visit is about when the booking
      // carried one. Never ellipsised down to something ambiguous: a clinic
      // name a patient half-recognises is a patient at the wrong desk.
      subtitle: [
        if (appointment.doctor.fullName.isNotEmpty) appointment.doctor.fullName,
        if (appointment.chiefComplaint.isNotEmpty) appointment.chiefComplaint,
      ].join(' · '),
      subtitleMaxLines: 2,
      showChevron: false,
      trailing: StatusPill(status: appointment.status, compact: true),
    );
  }
}

/// The identity the hospital holds. Read-only, and said so.
///
/// A patient cannot edit their own record from here and should not be offered
/// a control that implies they can — changing a date of birth is a front-desk
/// job with a document in hand. What the screen owes them instead is the
/// ability to *notice* it is wrong, which is why the fields are on screen
/// rather than behind a tap.
class _Record extends StatelessWidget {
  const _Record({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.rxFirstLoad.value && controller.isLoading) {
        return const BentoCard(child: BentoSkeleton(rows: 3));
      }

      final patient = controller.patient;
      if (patient.isEmpty) return const SizedBox.shrink();

      return BentoCard(
        key: PatientPortalKeys.record,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow(label: 'Name', value: patient.fullName),
            // The number printed on their card, and the one thing on this
            // screen they may be asked to read out at a desk.
            FactRow(label: 'Hospital number', value: patient.mrn),
            FactRow(
              label: 'Date of birth',
              value: patient.dateOfBirth == null
                  ? 'Not recorded'
                  : SettingsService.to.date(patient.dateOfBirth),
            ),
            if ((patient.bloodGroup ?? '').isNotEmpty)
              FactRow(label: 'Blood group', value: patient.bloodGroup!),
            if ((patient.phonePrimary ?? '').isNotEmpty)
              FactRow(label: 'Phone', value: patient.phonePrimary!),
            const SizedBox(height: BentoSpace.action),
            Text(
              'If anything here is wrong, tell the desk when you arrive — they '
              'can change it.',
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
      );
    });
  }
}

/// What has happened to the answers this patient has already given. §39.
///
/// Three states and no fourth, because there is no fourth the app can know:
/// an interview open, a case sent from this device, or nothing to say. The
/// middle one is the reason `PatientCaseService` exists —
/// `sessions/current` finds sessions that are still open, so it answers a
/// submitted case with the same null it answers a patient who never started.
class _YourCase extends StatelessWidget {
  const _YourCase({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final receipt = controller.submission;
      final open = controller.openCase.value;
      if (receipt == null && open == null) return const SizedBox.shrink();

      final sent = receipt != null;
      final when = receipt?.submittedAt;

      return BentoCard(
        key: CaseReviewKeys.dashboardCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  sent
                      ? Icons.mark_email_read_outlined
                      : Icons.pending_actions_outlined,
                  size: 20,
                  color: sent
                      ? semanticInk(context, AppColors.success)
                      : brandInkColor(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sent
                        ? PatientText.caseSent
                        : 'You have answers we have not sent yet',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).brightness == Brightness.dark
                        ? AppTextStyles.darkTitle3()
                        : AppTextStyles.lightTitle3(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sent
                  ? PatientText.caseSentBody
                  : 'You can read them back, change anything that is not '
                        'right, and send them when you are ready.',
              style:
                  (Theme.of(context).brightness == Brightness.dark
                          ? AppTextStyles.darkBody()
                          : AppTextStyles.lightBody())
                      .copyWith(
                        color: secondaryLabelColor(context),
                        height: 1.45,
                      ),
            ),
            if (sent && when != null) ...[
              const SizedBox(height: 6),
              Text(
                '${SettingsService.to.date(when)} · '
                '${SettingsService.to.time(when)}',
                style:
                    (Theme.of(context).brightness == Brightness.dark
                            ? AppTextStyles.darkFootnote()
                            : AppTextStyles.lightFootnote())
                        .copyWith(color: tertiaryLabelColor(context)),
              ),
            ],
            const SizedBox(height: BentoSpace.section),
            SecondaryBar(
              key: CaseReviewKeys.openFromDashboard,
              label: sent ? 'See what you sent' : PatientText.reviewTitle,
              icon: Icons.fact_check_outlined,
              onPressed: controller.openCaseReview,
            ),
          ],
        ),
      );
    });
  }
}

/// The prescriptions, reports and letters a patient brought with them.
///
/// The card keeps `PatientPortalKeys.documents` in **both** states — full and
/// empty — because it is the section, not the empty message. A key that moved
/// when the first document arrived would be a key every assertion about this
/// part of the screen had to branch on.
class _Documents extends StatelessWidget {
  const _Documents({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final error = controller.documentsError.value;
      final rows = controller.documents;

      return BentoCard(
        key: PatientPortalKeys.documents,
        padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(BentoSpace.listPad),
                child: Text(
                  error,
                  style:
                      (Theme.of(context).brightness == Brightness.dark
                              ? AppTextStyles.darkSubheadline()
                              : AppTextStyles.lightSubheadline())
                          .copyWith(color: secondaryLabelColor(context)),
                ),
              )
            else if (rows.isEmpty)
              EmptyState(
                compact: true,
                icon: Icons.description_outlined,
                title: PatientText.noDocumentsYet,
                message: PatientText.noDocumentsYetBody,
              )
            else
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                // Unkeyed on purpose: the same document has a keyed row on
                // the documents screen, and two widgets sharing one key while
                // that screen is pushed over this one is a `find.byKey` that
                // cannot say which it found.
                BentoRow(
                  icon: Icons.description_outlined,
                  title: rows[i].kind.label,
                  // The server's own sentence about it. Two lines, because it
                  // is a sentence and half a sentence is a status nobody can
                  // act on.
                  subtitle: rows[i].message,
                  subtitleMaxLines: 2,
                  showChevron: false,
                ),
              ],
            const Hairline(indent: BentoSpace.listPad),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BentoSpace.listPad,
                BentoSpace.action,
                BentoSpace.listPad,
                4,
              ),
              child: SecondaryBar(
                key: PatientDocumentsKeys.openFromDashboard,
                label: PatientText.addADocument,
                icon: Icons.add_a_photo_outlined,
                onPressed: controller.openDocuments,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// What a signed-in account that is **not** a patient sees here.
///
/// Reachable by deep link, and by an administrator ticking a permission on a
/// staff role that only makes sense for a patient. `GET /patient-auth/me`
/// answers that account with a 403 — there is no patient record behind their
/// user — and `LoadStateMixin` routes it here rather than to the retry banner,
/// because nothing is broken and trying again cannot help.
class _NotAPatientAccount extends StatelessWidget {
  const _NotAPatientAccount();

  @override
  Widget build(BuildContext context) {
    return const BentoCard(
      child: EmptyState(
        icon: Icons.badge_outlined,
        title: 'This account is not a patient record',
        message:
            'These screens are for patients reading their own record. '
            'Sign out and sign back in with your own account.',
      ),
    );
  }
}
