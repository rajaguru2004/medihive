/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Write drafts
///
/// One immutable draft per write the app can make. Each emits **only** the
/// keys its backend DTO accepts, because the API runs `whitelist +
/// forbidNonWhitelisted` and an extra key is a 400 rather than a shrug.
///
/// `test/unit/data/write_contract_test.dart` holds the allowed key set for
/// every one of them, copied from the DTO file named in each class's comment.
/// That test is the point of this directory: it turns a field that drifted
/// from a 400 on a ward into a red unit test on a laptop.
/// ─────────────────────────────────────────────────────────────────────────────
library;

export 'admin_drafts.dart';
export 'appointment_draft.dart';
export 'billing_drafts.dart';
export 'consultation_draft.dart';
export 'draft_json.dart';
export 'inpatient_drafts.dart';
export 'lab_drafts.dart';
export 'patient_draft.dart';
export 'patient_portal_drafts.dart';
export 'pharmacy_drafts.dart';
export 'queue_draft.dart';
export 'radiology_drafts.dart';
export 'screening_draft.dart';
