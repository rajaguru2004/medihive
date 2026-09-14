import 'package:flutter/widgets.dart';

/// Widget keys for the service catalogue — `/billing/services`.
abstract final class BillingServicesKeys {
  static const Key screen = Key('billing_services_screen');
  static const Key search = Key('billing_services_search');

  static Key service(String id) => Key('billing_service_$id');

  static const Key empty = Key('billing_services_empty');
  static const Key add = Key('billing_services_add');
}
