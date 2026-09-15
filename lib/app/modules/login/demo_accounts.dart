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
  /// Compiled out of release builds. See the class comment.
  static const bool enabled = kDebugMode;

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
