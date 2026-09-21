import 'package:flutter/widgets.dart';

/// Widget keys for the patient portal — the dashboard a patient lands on and
/// the four screens that get them there.
///
/// One file for five screens, the way `ScreeningKeys` is one file for three:
/// they are one task. Claim hands a token to Activate, Activate signs the
/// patient in, and Language and Consent are the two answers the interview
/// needs before it can start. A flow that walks the entry has no business
/// holding five key sets to do it.
abstract final class PatientPortalKeys {
  // ── The dashboard ─────────────────────────────────────────────────────────

  static const Key dashboard = Key('patient_dashboard_screen');
  static const Key greeting = Key('patient_dashboard_greeting');
  static const Key dashboardError = Key('patient_dashboard_error');
  static const Key signOut = Key('patient_dashboard_sign_out');

  /// The primary action on the screen, and the reason the screen exists.
  static const Key startCaseTaking = Key('patient_dashboard_start_case');

  static const Key appointments = Key('patient_dashboard_appointments');
  static const Key appointmentsEmpty = Key(
    'patient_dashboard_appointments_empty',
  );

  /// The way to the booking screen, from the appointments section.
  ///
  /// One key for one action, wherever the section is showing it from: the
  /// control sits on the empty card when nothing is booked and above the list
  /// when something is, and a flow should not have to know which of those a
  /// world it did not write is in.
  static const Key bookAppointment = Key('patient_dashboard_book');
  static const Key record = Key('patient_dashboard_record');
  static const Key documents = Key('patient_dashboard_documents');

  static Key appointment(String id) => Key('patient_dashboard_appointment_$id');

  // ── Claim ─────────────────────────────────────────────────────────────────

  /// The way in, on the sign-in screen.
  ///
  /// Keyed here rather than in `login_keys.dart` because it belongs to this
  /// feature: it is the portal's only entry point for somebody who has never
  /// signed in, and without it the claim screen is reachable by deep link
  /// alone.
  static const Key claimFromSignIn = Key('patient_claim_from_sign_in');

  static const Key claim = Key('patient_claim_screen');
  static const Key claimMrn = Key('patient_claim_mrn');
  static const Key claimDateOfBirth = Key('patient_claim_dob');
  static const Key claimSubmit = Key('patient_claim_submit');

  /// Where the screen says the pair was not accepted.
  ///
  /// Keyed rather than matched on words because of what the copy is not
  /// allowed to say: the server answers identically whether or not the MRN
  /// exists, so this message must never read as "no such record". A test that
  /// matched on text would be the thing that let that copy change.
  static const Key claimError = Key('patient_claim_error');

  // ── Activate ──────────────────────────────────────────────────────────────

  static const Key activate = Key('patient_activate_screen');
  static const Key activatePassword = Key('patient_activate_password');
  static const Key activateConfirm = Key('patient_activate_confirm');
  static const Key activateEmail = Key('patient_activate_email');
  static const Key activateReveal = Key('patient_activate_reveal');
  static const Key activateSubmit = Key('patient_activate_submit');
  static const Key activateError = Key('patient_activate_error');

  /// The banner on a screen opened without a claim token — by a deep link, or
  /// by coming back to it after the ten minutes ran out.
  static const Key activateNoClaim = Key('patient_activate_no_claim');

  // ── Language ──────────────────────────────────────────────────────────────

  static const Key language = Key('patient_language_screen');
  static const Key languageContinue = Key('patient_language_continue');

  /// The scrolling list of languages.
  ///
  /// Keyed because twelve rows do not fit on a phone and a flow that wants the
  /// last of them has to scroll something. `tester.scrollToKey` needs a
  /// scrollable it can name, and "the only `Scrollable` on screen" stops being
  /// true the first time this screen grows a second one.
  static const Key languageList = Key('patient_language_list');

  /// One language, by its code — `en`, `ta`, `or`. A key per option rather than
  /// per index, so a language arriving or leaving the list moves no existing
  /// assertion.
  static Key languageOption(String code) => Key('patient_language_$code');

  /// Where the screen says the language just chosen cannot be answered out
  /// loud — Odia, today.
  ///
  /// Keyed rather than matched on words, and it is the assertion this screen
  /// most needs: the honest thing and the convenient thing point opposite ways
  /// here. A picker that quietly offered Odia and let the patient discover in
  /// the interview that the microphone was missing would look *better* than
  /// this one and would be the defect. A key is what holds the sentence on the
  /// screen while the wording is still being argued about.
  static const Key languageVoiceNotice = Key('patient_language_voice_notice');

  // ── Consent ───────────────────────────────────────────────────────────────

  static const Key consent = Key('patient_consent_screen');

  /// The four things the patient is being told, before they are asked
  /// anything. Keyed as a group: the assertion worth making is that they are
  /// on screen *above* the question, not which order they are in.
  static const Key consentPoints = Key('patient_consent_points');

  static const Key consentAgree = Key('patient_consent_agree');
  static const Key consentDecline = Key('patient_consent_decline');

  // ── Booking ───────────────────────────────────────────────────────────────

  static const Key book = Key('patient_book_screen');
  static const Key bookDoctor = Key('patient_book_doctor');
  static const Key bookDate = Key('patient_book_date');
  static const Key bookTime = Key('patient_book_time');
  static const Key bookReason = Key('patient_book_reason');
  static const Key bookSubmit = Key('patient_book_submit');
  static const Key bookError = Key('patient_book_error');

  /// One offered slot, by the exact string the request will carry — `09:30`,
  /// never the site's 12-hour rendering of it. What a patient taps and what
  /// the server stores are then the same value, and a site switching its
  /// clock format moves no assertion.
  static Key bookSlot(String time) => Key('patient_book_slot_$time');

  /// Where the screen says this clinician's day has nothing left on it.
  ///
  /// Keyed because it is the state the feature is most likely to get wrong: a
  /// full day and a day the availability call failed on look identical to
  /// somebody reading the screen, and only one of them means "choose another
  /// day".
  static const Key bookNoSlots = Key('patient_book_no_slots');

  // ── The hand-off to the interview ─────────────────────────────────────────
  //
  // Nothing here. The two keys that used to sit in this block belonged to a
  // placeholder screen that said "the questions are coming"; the interview has
  // since been built, so the consent screen now hands over to a real one and
  // the keys for it live in `case_taking_keys.dart`.
}
