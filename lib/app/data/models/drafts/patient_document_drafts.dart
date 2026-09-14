/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the one write a document upload makes besides the file
///
/// `main.ts` runs `whitelist` with `forbidNonWhitelisted`, and that applies to
/// a **multipart** body too: an undeclared text part is a 400 for the whole
/// request, file and all. So the non-file half of the upload goes through a
/// draft like every other write in this app, and
/// `test/unit/data/write_contract_test.dart` pins its key set against the DTO.
///
/// `patientId` is declared by the DTO and is deliberately not sent. It is there
/// for a receptionist scanning a referral letter on somebody's behalf; a
/// patient uploading their own document has their id on the bearer token, and
/// `PatientSelfGuard` prefers the token over the body for a patient caller
/// whatever the body says. Sending it from the portal would be the app naming
/// a record it has no business naming.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'draft_json.dart';

/// The text parts of `POST /api/patient-documents`.
///
/// DTO: `hms_v2/src/modules/patient-documents/dto/upload-patient-document.dto.ts`
/// (`UploadPatientDocumentDto`).
class PatientDocumentUploadDraft {
  const PatientDocumentUploadDraft({this.sessionId});

  /// Attaches the document to an interview in progress, so the questions can
  /// stop asking what the document already answers.
  ///
  /// Null when the patient is adding a document from their dashboard rather
  /// than mid-interview, and dropped rather than sent empty: the server checks
  /// that the session belongs to this patient and answers a blank one with
  /// "That case-taking session could not be found."
  final String? sessionId;

  Map<String, dynamic> toCreateJson() => draftBody({'sessionId': sessionId});

  /// The multipart form fields, as strings.
  ///
  /// Everything in a multipart body arrives as text no matter what it was on
  /// the client, so this is the shape the server will actually see — spelled
  /// out here rather than left to `FormData.fromMap` to coerce.
  Map<String, String> toFormFields() => {
        for (final entry in toCreateJson().entries)
          entry.key: '${entry.value}',
      };
}
