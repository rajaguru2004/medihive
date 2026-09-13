import 'package:integration_test/integration_test_driver.dart';

/// The plain driver for `integration_test/suites/*`.
///
/// Run: `flutter drive --driver=test_driver/integration_test.dart \
///        --target=integration_test/suites/smoke_suite.dart`
Future<void> main() => integrationDriver();
