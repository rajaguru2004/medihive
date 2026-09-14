/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what the app is allowed to say about a failed claim
///
/// This file exists because of one property of the backend that the copy must
/// not undo.
///
/// **`POST /patient-auth/claim` answers identically whether or not the MRN
/// exists.** A number that matched nothing gets a token of the same shape, the
/// same length and the same ten-minute life as one that matched. That is
/// deliberate: the route is public and cheap to call, so a response that
/// differed would let a script walk the record-number space and find out which
/// patients this hospital has.
///
/// The consequence for the app is absolute: **it does not know.** A message
/// reading "we couldn't find that record" would be a guess, and a guess that
/// is right often enough to be useful to somebody probing is the leak the
/// server just spent a design decision closing. It would also be *wrong* for
/// the commonest real case — a patient who typed the date of birth in the
/// wrong order.
///
/// So there is one sentence for every way this can fail, it names no cause,
/// and it ends with the thing that actually works: ask at the desk. A person
/// at reception can look at the card.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:dio/dio.dart';

import '../../data/utils/api_envelope.dart';
import '../../data/utils/error_handler.dart';

/// The only thing the app may say when a claim or an activation is refused.
///
/// Note what it does not contain: no "not found", no "already claimed", no
/// "wrong date of birth". Each of those is a fact about a record the caller
/// has not proved they are entitled to know about.
///
/// It also has to read correctly for the patient whose details were right and
/// who simply took too long — the token lives ten minutes — which is another
/// reason not to write a cause into it.
const String kPatientClaimRefused =
    'We could not set up your account from those details. Check the number '
    'and the date of birth on your hospital card, and if they are right, ask '
    'at reception — they can set it up for you.';

/// The error codes this pair of routes answers with.
///
/// Read to decide *which* message to show, never shown. Four of the seven
/// collapse onto [kPatientClaimRefused] on purpose: they are the ones whose
/// difference is the existence of a record.
abstract final class PatientPortalErrors {
  /// The claim token matched nothing, matched a record that has since been
  /// claimed, or was issued against an MRN that never existed. **One message
  /// for all three.**
  static const Set<String> refusals = {
    'PATIENT_PORTAL_CLAIM_INVALID',
    'PATIENT_PORTAL_CLAIM_EXPIRED',
    'PATIENT_PORTAL_CLAIM_CONSUMED',
    'PATIENT_PORTAL_CLAIM_LOCKED',
    'PATIENT_PORTAL_ALREADY_CLAIMED',
  };

  /// The record carries no email and none was sent, so the account that would
  /// be created could never sign in — sign-in is by email.
  ///
  /// This one **is** told apart from the rest, and it is safe to: it says
  /// nothing about whether the record exists, because the server only reaches
  /// this check on a claim that was already valid... which it also returns for
  /// a claim that was not, precisely so this cannot be used as an oracle.
  /// Either way the patient's next action is the same: type an address.
  static const String emailRequired = 'PATIENT_PORTAL_EMAIL_REQUIRED';
}

/// The backend's machine-readable reason, out of whatever was thrown.
///
/// Two shapes, because two transports reach here. A 403 and most 4xx arrive as
/// an ordinary response and leave `ApiEnvelope.orThrow` as an [ApiException];
/// a **401 is the exception** — `DioClient.validateStatus` lets everything
/// below 500 through *except* 401 — and an invalid claim is answered 401, so
/// it arrives as a `DioException` with the envelope still in its body.
String portalErrorCode(Object? error) {
  if (error is ApiException) return error.errorCode;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) return (data['errorCode'] ?? '').toString();
  }
  return '';
}

/// The sentence to show for a failed claim or activation.
///
/// Anything the server refused on existence grounds gets
/// [kPatientClaimRefused]; everything else — a timeout, a rate limit, a 500 —
/// gets its real message, because those are faults the patient can act on and
/// none of them says anything about a record.
String patientPortalMessage(Object? error) {
  final code = portalErrorCode(error);
  if (PatientPortalErrors.refusals.contains(code)) return kPatientClaimRefused;
  return parseErrorMessage(error, kPatientClaimRefused);
}
