import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/modules/patient_portal/patient_portal_routes.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The patient portal: the dashboard a patient lands on, and the four screens
/// that get them there.
///
/// One robot for five screens, the way `PreTriageRobot` covers three: they are
/// one task. A flow walking claim → activate → dashboard → language → consent
/// should not have to hold five objects to do it, and the assertions that
/// matter are about the journey rather than about any one screen.
final class PatientPortalRobot extends Robot {
  PatientPortalRobot(super.harness);

  @override
  String? get route => PatientPortalRoutes.dashboard;

  @override
  Key get anchor => PatientPortalKeys.dashboard;

  // ── Where a session opens ─────────────────────────────────────────────────

  /// "This account is in the portal, and not in the staff shell."
  ///
  /// Both halves, deliberately. The route alone would pass for a portal screen
  /// pushed **on top of** a shell that had already been built underneath it —
  /// which is exactly the failure this feature exists to prevent, and which
  /// looks identical from the top of the stack.
  Future<void> assertOnPortal() async {
    await assertVisible();
    expect(
      find.byKey(HomeKeys.screen),
      findsNothing,
      reason: 'the staff shell was built underneath the portal, so this '
          'patient has a ward board one back-gesture away',
    );
  }

  /// "This account is in the staff shell." The other side of the same
  /// decision, so a flow can prove the landing is resolved rather than
  /// hardcoded.
  Future<void> assertOnStaffShell() async {
    await tester.pumpUntilFound(find.byKey(HomeKeys.screen));
    expect(Get.currentRoute, Routes.HOME);
    expect(find.byKey(PatientPortalKeys.dashboard), findsNothing);
  }

  // ── The dashboard ─────────────────────────────────────────────────────────

  /// The greeting names the patient rather than the account.
  void seeGreeting(String name) {
    expect(
      find.descendant(
        of: find.byKey(PatientPortalKeys.greeting),
        matching: find.textContaining(name),
      ),
      findsOneWidget,
      reason: 'expected the greeting to name $name',
    );
  }

  /// One of their appointments is on the screen.
  Future<void> seeAppointment(String id) async {
    await tester.scrollToKey(PatientPortalKeys.appointment(id));
    expect(find.byKey(PatientPortalKeys.appointment(id)), findsOneWidget);
  }

  /// An appointment that belongs to somebody else is **not**.
  ///
  /// The assertion this screen most needs: `GET /api/appointments` is a staff
  /// route and a portal account is granted the read, so asked without a
  /// `patientId` it answers with the whole hospital's day. Scrolled first,
  /// because a sliver below the fold is not built and "not there" would
  /// otherwise be free.
  Future<void> seeNoAppointment(String id) async {
    await tester.scrollToKey(PatientPortalKeys.documents);
    expect(find.byKey(PatientPortalKeys.appointment(id)), findsNothing);
  }

  Future<void> seeRecord() async {
    await tester.scrollToKey(PatientPortalKeys.record);
    expect(find.byKey(PatientPortalKeys.record), findsOneWidget);
  }

  Future<void> seeDocuments() async {
    await tester.scrollToKey(PatientPortalKeys.documents);
    expect(find.byKey(PatientPortalKeys.documents), findsOneWidget);
  }

  // ── The entry sequence ────────────────────────────────────────────────────

  Future<void> startCaseTaking() async {
    await tester.tapKey(PatientPortalKeys.startCaseTaking);
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.language));
    await settle();
  }

  Future<void> assertOnLanguage() async {
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.language));
    expect(Get.currentRoute, PatientPortalRoutes.language);
  }

  /// Every one of [codes] is a row somebody can tap.
  ///
  /// By code rather than by the native name, and the reason is the thing this
  /// screen exists for: `find.text('தமிழ்')` passes on a build that renders
  /// every glyph as a box, because the string is in the tree either way.
  /// Whether the script *draws* is a screenshot's job, not a flow's, and a flow
  /// that pretended to check it would be the reason nobody took the screenshot.
  void seeLanguages(List<String> codes) {
    for (final code in codes) {
      expect(
        find.byKey(PatientPortalKeys.languageOption(code)),
        findsOneWidget,
        reason: 'the picker offers no row for "$code"',
      );
    }
  }

  /// The chosen language cannot be answered out loud, and the screen says so
  /// where it is chosen rather than six screens later.
  void seeLanguageCannotBeSpoken() {
    expect(
      find.byKey(PatientPortalKeys.languageVoiceNotice),
      findsOneWidget,
      reason: 'a language with no transcriber was offered with no warning',
    );
  }

  void seeLanguageCanBeSpoken() {
    expect(find.byKey(PatientPortalKeys.languageVoiceNotice), findsNothing);
  }

  Future<void> chooseLanguage(String code) async {
    await tester.tapKey(PatientPortalKeys.languageOption(code));
    await settle();
  }

  Future<void> continueFromLanguage() async {
    await tester.tapKey(PatientPortalKeys.languageContinue);
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.consent));
    await settle();
  }

  Future<void> assertOnConsent() async {
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.consent));
    expect(Get.currentRoute, PatientPortalRoutes.consent);
  }

  /// The four things a patient is told before they are asked anything.
  ///
  /// By the words rather than by four keys: the promise is that these
  /// *sentences* are on screen, and a key per point would let the copy be
  /// deleted while the test went on passing.
  void seeConsentTold() {
    expect(find.byKey(PatientPortalKeys.consentPoints), findsOneWidget);
    for (final phrase in const [
      'write down what you say',
      'A doctor reads it',
      'not a diagnosis',
      'stop at any time',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(PatientPortalKeys.consentPoints),
          matching: find.textContaining(phrase),
        ),
        findsOneWidget,
        reason: 'the consent screen no longer says "$phrase"',
      );
    }
  }

  /// Both answers are real controls, not a button and a link.
  void seeConsentAsksRatherThanAssumes() {
    expect(find.byKey(PatientPortalKeys.consentAgree), findsOneWidget);
    expect(find.byKey(PatientPortalKeys.consentDecline), findsOneWidget);
  }

  Future<void> agreeToConsent() async {
    await tester.tapKey(PatientPortalKeys.consentAgree);
    await settle();
  }

  Future<void> declineConsent() async {
    await tester.tapKey(PatientPortalKeys.consentDecline);
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.dashboard));
    await settle();
  }

  /// Consent answered; the questions have started.
  ///
  /// The anchor is the interview's own, not the portal's: this robot walks the
  /// entry sequence and hands over here. Everything that happens on the
  /// interview belongs to `CaseTakingRobot`.
  Future<void> assertOnCaseHandoff() async {
    await tester.pumpUntilFound(find.byKey(CaseTakingKeys.screen));
    expect(Get.currentRoute, PatientPortalRoutes.caseTaking);
  }

  // ── Booking ───────────────────────────────────────────────────────────────

  /// From the dashboard's appointments section into the booking screen.
  Future<void> openBooking() async {
    await tester.scrollToKey(PatientPortalKeys.bookAppointment);
    await tester.tapKey(PatientPortalKeys.bookAppointment);
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.book));
    await settle();
  }

  Future<void> assertOnBooking() async {
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.book));
    expect(Get.currentRoute, PatientPortalRoutes.book);
  }

  /// Chooses a clinician from the picker sheet.
  Future<void> chooseDoctor(String name) async {
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.bookDoctor);
    await tester.pumpUntilFound(find.text(name));
    await tester.tap(find.text(name).last);
    await settle();
  }

  /// Taps one offered slot, by the value the request will carry — `09:30` and
  /// never the site's rendering of it, which changes with a setting.
  Future<void> chooseSlot(String time) async {
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.bookTime);
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.bookSlot(time)));
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.bookSlot(time));
    await settle();
  }

  /// A slot the clinic has already given away is not on the sheet.
  ///
  /// The assertion the availability read exists for: the grid is generated
  /// from the site's working hours, so a screen that never subtracted the
  /// bookings would offer every slot and look perfectly correct until two
  /// people arrived for the same one.
  Future<void> seeSlotNotOffered(String time) async {
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.bookTime);
    await settle();
    expect(
      find.byKey(PatientPortalKeys.bookSlot(time)),
      findsNothing,
      reason: '$time is already booked and was still offered',
    );
  }

  Future<void> closeSlots() async {
    await tester.tapAt(const Offset(10, 10));
    await settle();
  }

  Future<void> enterReason(String text) async {
    await tester.enterTextByKey(PatientPortalKeys.bookReason, text);
  }

  /// What is in the reason box, whoever put it there.
  void seeReason(String text) {
    expect(
      find.descendant(
        of: find.byKey(PatientPortalKeys.bookReason),
        matching: find.text(text),
      ),
      findsOneWidget,
      reason: 'expected the reason field to hold "$text"',
    );
  }

  Future<void> submitBooking() async {
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.bookSubmit);
    await settle();
  }

  /// The booking screen refused, and said why on the screen rather than in a
  /// toast that takes the reason away with it after three seconds.
  Future<void> seeBookingError(String phrase) async {
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.bookError));
    expect(
      find.descendant(
        of: find.byKey(PatientPortalKeys.bookError),
        matching: find.textContaining(phrase),
      ),
      findsOneWidget,
    );
  }

  // ── Getting in ────────────────────────────────────────────────────────────

  /// From the sign-in screen, the way somebody holding a card would.
  Future<void> openClaimFromSignIn() async {
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.claimFromSignIn);
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.claim));
    await settle();
  }

  Future<void> assertOnClaim() async {
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.claim));
    expect(Get.currentRoute, PatientPortalRoutes.claim);
  }

  /// Fills the card and submits.
  ///
  /// Deliberately asserts nothing about where it landed — the claim route
  /// answers the same for a card that matches and one that does not, so the
  /// two endings belong to the caller.
  Future<void> enterCard({required String mrn}) async {
    await tester.enterTextByKey(PatientPortalKeys.claimMrn, mrn);
    await pickCardDate();
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.claimSubmit);
    await settle();
  }

  /// Sets the date of birth through the calendar the field opens.
  ///
  /// The field is deliberately not a quick-pick sheet — "Today" and "In a
  /// week" are answers to a due date — so this drives the Material calendar's
  /// OK button. It lands on whatever day the picker opens at, which is enough:
  /// the fixture decides whether the pair matched, and the flow that cares
  /// overrides it.
  Future<void> pickCardDate() async {
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.claimDateOfBirth);
    await tester.pumpUntilFound(find.text('OK'));
    await tester.tap(find.text('OK'));
    await settle();
  }

  Future<void> assertOnActivate() async {
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.activate));
    expect(Get.currentRoute, PatientPortalRoutes.activate);
  }

  Future<void> setPassword({
    required String password,
    String? confirm,
    String? email,
  }) async {
    await tester.enterTextByKey(PatientPortalKeys.activatePassword, password);
    await tester.enterTextByKey(
      PatientPortalKeys.activateConfirm,
      confirm ?? password,
    );
    if (email != null) {
      await tester.enterTextByKey(PatientPortalKeys.activateEmail, email);
    }
    await tester.tapKeyWithoutKeyboard(PatientPortalKeys.activateSubmit);
    await settle();
  }

  /// "The app said no, and it said it without saying anything about the
  /// record."
  ///
  /// The second half is the assertion that matters and it is the reason this
  /// lives in a robot rather than in a flow. The claim route answers
  /// identically whether or not the MRN exists, so **the app does not know**;
  /// copy that reads as "no such record" would be a guess, and a guess that is
  /// right often enough is the oracle the server spent a design decision
  /// closing.
  Future<void> seeRefusedWithoutLeaking() async {
    await tester.pumpUntilFound(find.byKey(PatientPortalKeys.activateError));
    for (final leak in const [
      'not found',
      'No record',
      'no such',
      'does not exist',
      'already claimed',
      'wrong date',
      'incorrect',
    ]) {
      expect(
        find.textContaining(leak),
        findsNothing,
        reason: 'the refusal said "$leak", which tells somebody probing this '
            'route whether the record exists',
      );
    }
    // And it says where to go instead, which is the only thing that actually
    // resolves this for the patient.
    expect(find.textContaining('reception'), findsWidgets);
  }

  /// The password rule is written on the screen, not discovered by failing.
  void seePasswordRule() =>
      expect(find.textContaining('At least 8 characters'), findsWidgets);

  Future<void> seeFieldError(String message) async {
    await tester.pumpUntilFound(find.text(message));
  }

  // ── Leaving ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await tester.tapKey(PatientPortalKeys.signOut);
    await tester.pumpUntilFound(find.byKey(LoginKeys.screen));
    await settle();
  }

  /// Opens a portal route directly, the way a deep link or a stale shortcut
  /// does.
  ///
  /// Never awaited: `Get.toNamed` completes when the route is *popped*.
  Future<void> openRoute(String name) async {
    unawaited(Get.toNamed<void>(name) ?? Future<void>.value());
    await settle();
  }
}
