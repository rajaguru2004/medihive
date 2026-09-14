/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the two writes a patient makes before they have an account
///
/// Both routes are public and both are throttled, so they are the only writes
/// in this app that leave without a bearer token. `main.ts` still runs
/// `whitelist` with `forbidNonWhitelisted` over them, so one key their DTO
/// does not declare is a 400 for the whole request — and a 400 here is a
/// patient standing at a desk unable to get into their own record.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'draft_json.dart';

/// The two things printed on a patient card.
///
/// DTO: `hms_v2/src/modules/patient-auth/dto/claim-patient-record.dto.ts`.
///
/// Both are required by the server, and both are required here for the reason
/// the DTO gives: an MRN on its own is a sequential number on a piece of paper
/// anybody could be holding, and the date of birth is what makes the pair
/// evidence that the card is yours.
class PatientClaimDraft {
  const PatientClaimDraft({required this.mrn, required this.dateOfBirth});

  /// As printed. Not upper-cased or stripped of its hyphens on the way out:
  /// the server matches the column exactly, so "helpfully" normalising an MRN
  /// is how a correct card stops working.
  final String mrn;

  /// The day on the card. A calendar day, never an instant — [isoDay] does not
  /// convert to UTC first, because 1990-05-17 in a UTC+ zone becomes the 16th
  /// if it does, and then the pair never matches.
  final DateTime dateOfBirth;

  Map<String, dynamic> toCreateJson() => draftBody({
        'mrn': mrn,
        'dateOfBirth': isoDay(dateOfBirth),
      });
}

/// The claim, spent: a password, and an address to sign in with.
///
/// DTO: `hms_v2/src/modules/patient-auth/dto/activate-patient-account.dto.ts`.
class PatientActivationDraft {
  const PatientActivationDraft({
    required this.claimToken,
    required this.password,
    this.email,
  });

  /// From `POST /patient-auth/claim`, and good for ten minutes. Single use.
  final String claimToken;

  /// 8 to 72 characters. The ceiling is the server's and it is not arbitrary:
  /// bcrypt hashes the first 72 bytes and silently ignores the rest, so a
  /// longer password is not the password the patient thinks they set.
  final String password;

  /// Optional **only** because the record may already carry one.
  ///
  /// Sign-in is `POST /auth/login`, which looks an account up by email, so an
  /// activation that ends with no email anywhere is an account nobody can
  /// reach. The server answers `PATIENT_PORTAL_EMAIL_REQUIRED` when the record
  /// has none and none was sent; the screen asks for it then.
  ///
  /// Never lower-cased on the way out. `findByEmail` matches exactly, so
  /// normalising the case here would create an account that cannot sign in.
  final String? email;

  Map<String, dynamic> toCreateJson() => draftBody({
        'claimToken': claimToken,
        'password': password,
        'email': email,
      });
}
