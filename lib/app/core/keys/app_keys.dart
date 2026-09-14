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
export 'appointment_detail_keys.dart';
export 'appointment_form_keys.dart';
export 'appointments_keys.dart';
export 'billing_invoice_detail_keys.dart';
export 'billing_invoice_form_keys.dart';
export 'billing_keys.dart';
export 'billing_payment_form_keys.dart';
export 'billing_service_form_keys.dart';
export 'billing_services_keys.dart';
export 'case_review_keys.dart';
export 'case_taking_keys.dart';
export 'consultation_detail_keys.dart';
export 'consultation_form_keys.dart';
export 'consultations_keys.dart';
export 'dashboard_keys.dart';
export 'discharge_patient_keys.dart';
export 'edit_screening_keys.dart';
export 'home_keys.dart';
export 'inpatient_add_bed_keys.dart';
export 'inpatient_add_ward_keys.dart';
export 'inpatient_admissions_keys.dart';
export 'inpatient_beds_grid_keys.dart';
export 'inpatient_keys.dart';
export 'inpatient_overview_keys.dart';
export 'inpatient_wards_keys.dart';
export 'integrations_keys.dart';
export 'lab_catalog_keys.dart';
export 'lab_order_detail_keys.dart';
export 'lab_order_form_keys.dart';
export 'lab_result_form_keys.dart';
export 'lab_test_form_keys.dart';
export 'laboratory_keys.dart';
export 'login_keys.dart';
export 'machine_form_keys.dart';
export 'more_keys.dart';
export 'new_screening_step1_keys.dart';
export 'new_screening_step2_keys.dart';
export 'no_access_keys.dart';
export 'patient_documents_keys.dart';
export 'patient_form_keys.dart';
export 'patient_hub_keys.dart';
export 'patient_portal_keys.dart';
export 'patient_search_keys.dart';
export 'patients_keys.dart';
export 'pharmacy_keys.dart';
export 'placeholder_keys.dart';
export 'placeholders_keys.dart';
export 'pre_triage_details_keys.dart';
export 'pre_triage_keys.dart';
export 'queue_keys.dart';
export 'radiology_catalog_keys.dart';
export 'radiology_exam_form_keys.dart';
export 'radiology_keys.dart';
export 'radiology_order_detail_keys.dart';
export 'radiology_order_form_keys.dart';
export 'radiology_report_form_keys.dart';
export 'role_editor_keys.dart';
export 'roles_keys.dart';
export 'screening_keys.dart';
export 'session_lock_keys.dart';
export 'settings_departments_keys.dart';
export 'settings_keys.dart';
export 'settings_locale_keys.dart';
export 'settings_modules_keys.dart';
export 'settings_profile_keys.dart';
export 'shift_keys.dart';
export 'splash_keys.dart';
export 'staff_keys.dart';
export 'user_detail_keys.dart';
export 'user_form_keys.dart';
export 'users_keys.dart';
