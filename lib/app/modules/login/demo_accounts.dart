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
/// The password is the one `prisma/seed.ts` gives every demo user. If the seed
/// changes it, this stops working — which is the right failure, because the
/// alternative is a login screen that quietly offers credentials nobody can
/// use.
@immutable
class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.label,
    required this.shows,
  });

  final String email;

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

  /// Every demo user in `prisma/seed.ts` shares this.
  static const String password = 'Demo@HMS2024!';

  /// The patient first: this build's new work is the patient's side, and it is
  /// what a demo is most likely to be about.
  static const List<DemoAccount> all = [
    DemoAccount(
      email: 'patient@hms.local',
      label: 'Patient',
      shows: 'The portal — case taking, documents, the case read back',
    ),
    DemoAccount(
      email: 'doctor@hms.local',
      label: 'Doctor',
      shows: 'Clinic list, consultations, the case a patient submitted',
    ),
    DemoAccount(
      email: 'nurse@hms.local',
      label: 'Nurse',
      shows: 'The queue board, pre-triage, observations',
    ),
    DemoAccount(
      email: 'receptionist@hms.local',
      label: 'Receptionist',
      shows: 'Booking and check-in, and no clinical controls at all',
    ),
    DemoAccount(
      email: 'admin@hms.local',
      label: 'Administrator',
      shows: 'Settings, staff, roles — every module switched on',
    ),
    DemoAccount(
      email: 'pharmacist@hms.local',
      label: 'Pharmacist',
      shows: 'Dispensing and stock',
    ),
    DemoAccount(
      email: 'radiologist@hms.local',
      label: 'Radiologist',
      shows: 'Imaging worklist and reporting',
    ),
    DemoAccount(
      email: 'billing@hms.local',
      label: 'Billing',
      shows: 'Invoices and payments',
    ),
  ];
}
