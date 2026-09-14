import 'package:flutter/widgets.dart';

/// Widget keys for a catalogue entry — `/billing/services/edit`.
abstract final class BillingServiceFormKeys {
  static const Key screen = Key('billing_service_form_screen');
  static const Key form = Key('billing_service_form');

  static const Key name = Key('billing_service_name');
  static const Key code = Key('billing_service_code');
  static const Key category = Key('billing_service_category');
  static const Key department = Key('billing_service_department');
  static const Key unitPrice = Key('billing_service_price');

  static const Key taxable = Key('billing_service_taxable');
  static const Key taxPercentage = Key('billing_service_tax_percent');

  static const Key insured = Key('billing_service_insured');
  static const Key copayPercentage = Key('billing_service_copay');

  static const Key active = Key('billing_service_active');

  static const Key errors = Key('billing_service_errors');
  static const Key save = Key('billing_service_save');
}
