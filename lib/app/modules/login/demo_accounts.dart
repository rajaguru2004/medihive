import 'package:flutter/foundation.dart';

/// The seeded accounts, offered as one tap on the sign-in screen.
///
/// **Debug builds only.** [enabled] is `kDebugMode`, so the panel and the
/// credentials below are compiled out of a release build entirely — a shipped
/// app that lists working hospital logins on its first screen is not a
/// convenience, it is the whole authentication system undone.
///
/// It is also worth being precise about what this does and does not do: it
/// **fills the form and signs in normally**. There is no bypass. The request is
/// the same `POST /api/auth/login` a typed password makes, the token comes back
/// the same way, the access map is loaded the same way, and an account the
/// server refuses is refused here too. What it removes is the typing, which on
/// a phone in front of an audience is the part that goes wrong.
///
/// The passwords come from `prisma/seed.ts`. If the seed changes one, that
/// button stops working — which is the right failure, because the alternative
/// is a login screen that quietly offers credentials nobody can use.
@immutable
class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.password,
    required this.label,
    required this.shows,
  });

  final String email;

  /// This account's own password.
  ///
  /// Not one shared constant: `prisma/seed.ts` gives the administrator, the
  /// doctor and the nurse passwords of their own (`Admin@`, `Doctor@`,
  /// `Nurse@`) and only the remaining demo users share `Demo@`. Assuming one
  /// password for all eight left three of these buttons answering 401 — which
  /// is a worse demo than no buttons.
  final String password;

  /// What a person running the demo would call this account.
  final String label;

  /// One line on why you would pick this one — shown under the label, because
  /// "Nurse" and "Receptionist" look interchangeable until you know that one
  /// of them cannot admit a patient.
  final String shows;
}

abstract final class DemoAccounts {
  /// On in debug. Off in release **unless a build explicitly asks for it**.
  ///
  /// ```sh
  /// flutter build apk --dart-define=MEDIHIVE_DEMO=true
  /// ```
  ///
  /// The opt-in exists because a release build is the one worth demonstrating —
  /// it is the fast one — and a demo that begins with somebody typing an email
  /// address on a phone in front of a room is a demo that begins badly.
  ///
  /// It defaults to `kDebugMode` rather than to `true` so that the dangerous
  /// case is the one you have to ask for: a shipped build that lists working
  /// hospital logins on its first screen has no authentication at all. Asking
  /// is a flag in a command somebody typed on purpose; forgetting is not
  /// enough.
  static const bool enabled =
      bool.fromEnvironment('MEDIHIVE_DEMO', defaultValue: kDebugMode);

  /// Lets a patient confirm a document they have marked wrong or uncertain.
  ///
  /// **This loosens a clinical rule, and it is the only flag here that does.**
  /// Normally `verify` means "what was extracted is correct", so a document
  /// with a corrected or unsure value on it is not sent at all: it stays
  /// unconfirmed and goes to a clinician. That is §18 and it is right.
  ///
  /// A demo cannot show the end of the flow that way. The extraction on a
  /// photographed prescription is rarely perfect, one "I don't know" stops the
  /// run, and the audience is left looking at the screen before the one worth
  /// showing. So this exists, and three things keep it honest:
  ///
  ///  * it follows [enabled], so a release build without `MEDIHIVE_DEMO=true`
  ///    behaves exactly as before — the dangerous case is still the one you
  ///    have to ask for;
  ///  * the notice explaining that a clinician will look at the document
  ///    **stays on screen** next to the button, rather than being swapped out
  ///    for it. What the demo shows is the real warning plus a way past it,
  ///    not a screen pretending the values were agreed with;
  ///  * nothing about the record changes. The server still marks the
  ///    corrections as the patient's words, and the document still carries
  ///    every "I don't know" into whatever reads it next.
  ///
  /// Turn it off on its own, keeping the rest of demo mode, with
  /// `--dart-define=MEDIHIVE_DEMO_CONFIRM_ANYWAY=false`.
  static const bool confirmAnyway = bool.fromEnvironment(
    'MEDIHIVE_DEMO_CONFIRM_ANYWAY',
    defaultValue: enabled,
  );

  /// The patient first: this build's new work is the patient's side, and it is
  /// what a demo is most likely to be about.
  static const List<DemoAccount> all = [
    DemoAccount(
      email: 'patient@hms.local',
      password: 'Demo@HMS2024!',
      label: 'Patient',
      shows: 'The portal — case taking, documents, the case read back',
    ),
    DemoAccount(
      email: 'doctor@hms.local',
      password: 'Doctor@HMS2024!',
      label: 'Doctor',
      shows: 'Clinic list, consultations, the case a patient submitted',
    ),
    DemoAccount(
      email: 'nurse@hms.local',
      password: 'Nurse@HMS2024!',
      label: 'Nurse',
      shows: 'The queue board, pre-triage, observations',
    ),
    DemoAccount(
      email: 'receptionist@hms.local',
      password: 'Demo@HMS2024!',
      label: 'Receptionist',
      shows: 'Booking and check-in, and no clinical controls at all',
    ),
    DemoAccount(
      email: 'admin@hms.local',
      password: 'Admin@HMS2024!',
      label: 'Administrator',
      shows: 'Settings, staff, roles — every module switched on',
    ),
    DemoAccount(
      email: 'pharmacist@hms.local',
      password: 'Demo@HMS2024!',
      label: 'Pharmacist',
      shows: 'Dispensing and stock',
    ),
    DemoAccount(
      email: 'radiologist@hms.local',
      password: 'Demo@HMS2024!',
      label: 'Radiologist',
      shows: 'Imaging worklist and reporting',
    ),
    DemoAccount(
      email: 'billing@hms.local',
      password: 'Demo@HMS2024!',
      label: 'Billing',
      shows: 'Invoices and payments',
    ),
  ];
}
