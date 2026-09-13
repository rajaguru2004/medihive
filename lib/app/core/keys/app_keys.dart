/// Barrel for every module's widget keys.
///
/// Keys live in `lib/`, not in the test tree, because the widgets reference
/// them — they are production API, the same way a route name is.
///
/// They exist because `find.text` is ambiguous by construction in an app like
/// this one: "Queue" is a nav destination, a screen title and a section
/// header; "Save" appears on every form; a patient's name appears on the row
/// and again on the detail it opens. Every interactive widget a test drives
/// gets a key from here.
///
/// One file per module under `lib/app/modules/`, named `<module>_keys.dart`.
/// `tool/check_keys.dart` enforces both halves of that convention.
library;

export 'add_to_queue_keys.dart';
export 'admit_patient_keys.dart';
export 'appointments_keys.dart';
export 'consultations_keys.dart';
export 'discharge_patient_keys.dart';
export 'edit_screening_keys.dart';
export 'home_keys.dart';
export 'inpatient_keys.dart';
export 'login_keys.dart';
export 'placeholder_keys.dart';
export 'pre_triage_keys.dart';
export 'queue_keys.dart';
export 'screening_keys.dart';
export 'splash_keys.dart';
