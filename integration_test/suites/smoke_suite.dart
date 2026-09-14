import 'package:integration_test/integration_test.dart';

import '../flows/auth/login_flow_test.dart';
import '../flows/billing/billing_flow_test.dart';
import '../flows/clinical/appointment_flow_test.dart';
import '../flows/clinical/consultation_flow_test.dart';
import '../flows/home/shell_flow_test.dart';
import '../flows/inpatient/beds_flow_test.dart';
import '../flows/laboratory/laboratory_flow_test.dart';
import '../flows/patients/patients_flow_test.dart';
import '../flows/pharmacy/pharmacy_flow_test.dart';
import '../flows/pre_triage/screening_flow_test.dart';
import '../flows/queue/queue_flow_test.dart';
import '../flows/radiology/radiology_flow_test.dart';

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
}
