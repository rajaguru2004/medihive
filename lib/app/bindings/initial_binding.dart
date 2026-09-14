import 'package:get/get.dart';

import '../data/services/appointment_service.dart';
import '../data/services/consultation_service.dart';
import '../data/services/home_service.dart';
import '../data/services/inpatient_service.dart';
import '../data/services/pre_triage_service.dart';
import '../data/services/queue_service.dart';

/// Registers the domain services every module reaches for with `Get.find`.
///
/// A free function rather than only a [Bindings] class, because these were
/// registered in exactly one place — `integration_test/support/app_harness.dart`
/// — and nowhere in the app. `GetMaterialApp` had no `initialBinding:` and
/// `main()` never put them, so every flow test passed and
/// `Get.find<HomeService>()` threw on a real device the moment the dashboard
/// built. The suite could not see it because the suite was the only thing
/// registering them.
///
/// Idempotent, so a caller that has already put one of these by hand — a test
/// installing a fake — keeps its own instance.
void registerDomainServices() {
  _putOnce(() => HomeService());
  _putOnce(() => QueueService());
  _putOnce(() => AppointmentService());
  _putOnce(() => InpatientService());
  _putOnce(() => PreTriageService());
  _putOnce(() => ConsultationService());
}

/// Permanent: these outlive any one route, and a service dropped when the last
/// screen using it closes is a service reconstructed on every tab switch.
void _putOnce<T extends GetxService>(T Function() create) {
  if (!Get.isRegistered<T>()) Get.put<T>(create(), permanent: true);
}

/// The `initialBinding:` form, for a `GetMaterialApp` that wants one.
class InitialBinding extends Bindings {
  @override
  void dependencies() => registerDomainServices();
}
