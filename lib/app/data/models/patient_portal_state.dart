/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — a patient's own view of themselves
///
/// `GET /api/patient-auth/me` is the only route in this API that answers with
/// a patient record to the patient it belongs to. Every other patient route is
/// staff-facing and keyed by an id the caller supplies; this one discards any
/// id it is given and reads the `patientId` on the bearer token, so there is
/// no way to ask it about somebody else.
///
/// That is why the portal reads its identity here rather than from
/// `/api/patients/:id`: a portal account holds **no** `patients` module at all
/// (`AccessMap` shows every flag false), so the obvious route is a 403 and the
/// obvious workaround — asking the register for one row — is the thing the
/// server is deliberately refusing.
///
/// The two halves are separate because they answer different questions. The
/// [PortalPatient] is the hospital's record of a person; the [PortalAccount]
/// is whether that record has a login yet. A record can exist without an
/// account for years, which is the whole reason the claim flow exists.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../utils/formatters.dart';
import 'json.dart';

/// The record as its own patient sees it.
///
/// Deliberately narrower than `Patient`: this is the projection the server
/// sends a patient about themselves, and widening it here would invite a
/// screen to read a field the route does not send and render a blank where a
/// clinician would read a fact.
class PortalPatient {
  const PortalPatient({
    this.id = '',
    this.mrn = '',
    this.firstName = '',
    this.middleName,
    this.lastName = '',
    this.dateOfBirth,
    this.gender = '',
    this.bloodGroup,
    this.phonePrimary,
    this.email,
  });

  final String id;

  /// The number printed on their card. The one thing a patient can read out at
  /// a desk, so it is on screen rather than only in a request.
  final String mrn;

  final String firstName;
  final String? middleName;
  final String lastName;

  /// Null when the route did not send one — never today's date. See
  /// `PatientRef.dateOfBirth`: a missing date that defaults to now makes every
  /// unknown patient a neonate.
  final DateTime? dateOfBirth;

  final String gender;
  final String? bloodGroup;
  final String? phonePrimary;
  final String? email;

  static const PortalPatient empty = PortalPatient();

  bool get isEmpty => id.isEmpty && mrn.isEmpty;

  String get fullName =>
      [firstName, middleName ?? '', lastName].where((p) => p.trim().isNotEmpty)
          .join(' ');

  /// What the greeting uses. A first name, because this screen is talking to
  /// the person rather than about them — and the MRN when the record carries
  /// no name at all, which is rarer here than on a screening but not
  /// impossible.
  String get greetingName =>
      firstName.trim().isNotEmpty ? firstName.trim() : mrn;

  String get age => Formatters.age(dateOfBirth);

  factory PortalPatient.fromJson(Map<String, dynamic> json) => PortalPatient(
        id: asString(json['id']),
        mrn: asString(json['mrn']),
        firstName: asString(json['firstName']),
        middleName: asStringOrNull(json['middleName']),
        lastName: asString(json['lastName']),
        dateOfBirth: asDate(json['dateOfBirth']),
        gender: asString(json['gender']),
        bloodGroup: asStringOrNull(json['bloodGroup']),
        phonePrimary: asStringOrNull(json['phonePrimary']),
        email: asStringOrNull(json['email']),
      );
}

/// Whether this record has a portal login, and which one.
class PortalAccount {
  const PortalAccount({
    this.isLinked = false,
    this.userId,
    this.email,
    this.activatedAt,
  });

  /// True once a `User` row is attached to the record.
  final bool isLinked;

  final String? userId;

  /// The address this account signs in with. Sign-in is by email, so a linked
  /// account with no email is one nobody can reach — which is why the
  /// activation screen offers to take one.
  final String? email;

  /// When the claim was spent. Null on a record linked by a member of staff
  /// rather than by the patient themselves, which is why it is not the test
  /// for "is this claimed" — [isLinked] is.
  final DateTime? activatedAt;

  static const PortalAccount none = PortalAccount();

  factory PortalAccount.fromJson(Map<String, dynamic> json) => PortalAccount(
        isLinked: asBool(json['isLinked']),
        userId: asStringOrNull(json['userId']),
        email: asStringOrNull(json['email']),
        activatedAt: asDate(json['activatedAt']),
      );
}

/// The whole of `GET /api/patient-auth/me`.
class PatientPortalState {
  const PatientPortalState({
    this.patient = PortalPatient.empty,
    this.portal = PortalAccount.none,
  });

  final PortalPatient patient;
  final PortalAccount portal;

  static const PatientPortalState empty = PatientPortalState();

  bool get isEmpty => patient.isEmpty;

  factory PatientPortalState.fromJson(Map<String, dynamic> json) =>
      PatientPortalState(
        patient: PortalPatient.fromJson(asMap(json['patient'])),
        portal: PortalAccount.fromJson(asMap(json['portal'])),
      );
}

/// What `POST /api/patient-auth/claim` answers with — **always**.
///
/// There is no "not found" shape of this, on purpose. An MRN that matched
/// nothing gets a token of the same length with the same lifetime, so nothing
/// the app can read tells it whether the record exists. The refusal, when
/// there is one, arrives at activation instead.
///
/// The app must not undo that. Any copy written against this response has to
/// read correctly for a patient whose MRN was right *and* for one whose MRN
/// was wrong, because the app genuinely cannot tell them apart.
class PatientClaim {
  const PatientClaim({
    required this.claimToken,
    this.expiresAt,
    this.expiresInSeconds = 0,
  });

  final String claimToken;
  final DateTime? expiresAt;

  /// Ten minutes, at the time of writing. Read from the response rather than
  /// assumed, so the screen's "this expires in X" cannot drift from what the
  /// server will actually honour.
  final int expiresInSeconds;

  bool get isEmpty => claimToken.trim().isEmpty;

  factory PatientClaim.fromJson(Map<String, dynamic> json) => PatientClaim(
        claimToken: asString(json['claimToken']),
        expiresAt: asDate(json['expiresAt']),
        expiresInSeconds: asInt(json['expiresInSeconds']),
      );
}
