import 'package:integration_test/integration_test.dart';

import '../flows/auth/login_flow_test.dart';
import '../flows/billing/billing_flow_test.dart';
import '../flows/case_review/case_review_flow_test.dart';
import '../flows/case_taking/case_taking_flow_test.dart';
import '../flows/clinical/appointment_flow_test.dart';
import '../flows/clinical/consultation_flow_test.dart';
import '../flows/dashboard/shift_flow_test.dart';
import '../flows/home/shell_flow_test.dart';
import '../flows/inpatient/beds_flow_test.dart';
import '../flows/integrations/integrations_flow_test.dart';
import '../flows/laboratory/laboratory_flow_test.dart';
import '../flows/patient_documents/patient_documents_flow_test.dart';
import '../flows/patient_portal/patient_portal_flow_test.dart';
import '../flows/patients/patients_flow_test.dart';
import '../flows/pharmacy/pharmacy_flow_test.dart';
import '../flows/pre_triage/screening_flow_test.dart';
import '../flows/queue/queue_flow_test.dart';
import '../flows/radiology/radiology_flow_test.dart';
import '../flows/routes/every_route_builds_test.dart';
import '../flows/settings/settings_flow_test.dart';
import '../flows/staff/staff_flow_test.dart';

/// Every behavioural flow, in one run.
///
/// ```sh
/// flutter test integration_test/suites/smoke_suite.dart -d emulator-5554
/// ```
///
/// Each flow file registers rather than runs — `registerXFlows()` declares its
/// groups, and its own `main()` is a one-liner that calls it. So a single file
/// is still runnable on its own while a change to the set is one import and one
/// line here, not a hand-maintained copy of every `testWidgets` in the tree.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // First: every screen in the table, opened once. A module flow proves a
  // module works; this proves nothing in the table lands on the red screen,
  // which is what an exception during `build` looks like to somebody holding
  // the phone.
  registerRouteFlows();
  registerAuthFlows();
  registerShellFlows();
  registerQueueFlows();
  registerInpatientFlows();
  registerPreTriageFlows();
  registerPatientsFlows();
  registerAppointmentFlows();
  registerConsultationFlows();
  registerLaboratoryFlows();
  registerRadiologyFlows();
  registerPharmacyFlows();
  registerBillingFlows();
  registerStaffFlows();
  registerSettingsFlows();
  registerIntegrationsFlows();
  registerShiftFlows();

  // Last, and the only two whose account is not a member of staff: a patient
  // reading their own record, and then that same patient answering questions
  // about themselves. They boot a role the flows above never use, so this is
  // also the run that proves the landing decision has two answers.
  //
  // The portal goes first because it walks the entry sequence that ends at the
  // interview — language, consent, and then the first question.
  registerPatientPortalFlows();
  registerCaseTakingFlows();

  // Then the two the interview hands over to: the papers the patient brought
  // with them, and the case they read back before it is sent. After the
  // interview because that is the order a patient meets them in, and because
  // both boot the same portal account.
  registerPatientDocumentsFlows();
  registerCaseReviewFlows();
}
