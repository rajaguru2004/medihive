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
  static const Key appointmentsEmpty = Key('patient_dashboard_appointments_empty');
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
  static const Key languageMore = Key('patient_language_more_coming');
  static const Key languageContinue = Key('patient_language_continue');

  /// One language, by its code — `en`. A key per option rather than per index,
  /// so the list can grow in P10 without moving any existing assertion.
  static Key languageOption(String code) => Key('patient_language_$code');

  // ── Consent ───────────────────────────────────────────────────────────────

  static const Key consent = Key('patient_consent_screen');

  /// The four things the patient is being told, before they are asked
  /// anything. Keyed as a group: the assertion worth making is that they are
  /// on screen *above* the question, not which order they are in.
  static const Key consentPoints = Key('patient_consent_points');

  static const Key consentAgree = Key('patient_consent_agree');
  static const Key consentDecline = Key('patient_consent_decline');

  // ── The hand-off to the interview ─────────────────────────────────────────
  //
  // Both keys belong to a screen the case-taking phase replaces. They are
  // here rather than in the flow tree because a flow may not call `find.*`,
  // and the entry sequence has to be walkable end to end today.

  static const Key casePending = Key('patient_case_pending_screen');
  static const Key casePendingBack = Key('patient_case_pending_back');
}
