import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/billing_services_keys.dart';
import '../../../data/models/billing_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../billing/billing_routes.dart';
import '../controllers/billing_services_controller.dart';

/// The price list.
///
/// A lookup list rather than a module with a detail screen: there is nothing to
/// say about a consultation fee that does not fit on its row, so
/// [SimpleCrudScaffold] is the shape — rows, a search, and one primary action.
class BillingServicesView extends GetView<BillingServicesController> {
  const BillingServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read the controller at the root of the build, or the `lazyPut` never
    // happens and `onReady` never fetches.
    final catalogue = controller;

    return Obx(() {
      final rows = catalogue.rows;

      return SimpleCrudScaffold(
        screenKey: BillingServicesKeys.screen,
        title: 'Service catalogue',
        subtitle: 'What this site charges for',
        itemCount: rows.length,
        phase: catalogue.phase,
        error: catalogue.rxLoadError.value,
        onRetry: catalogue.load,
        onRefresh: catalogue.reload,
        onSearch: catalogue.search,
        searchKey: BillingServicesKeys.search,
        searchHint: 'Name, code, category or department',
        empty: EmptyState(
          key: BillingServicesKeys.empty,
          icon: Icons.sell_outlined,
          title: catalogue.query.value.trim().isEmpty
              ? 'Nothing in the catalogue'
              : 'Nothing matches that',
          message: catalogue.query.value.trim().isEmpty
              ? 'A service is a thing this site charges for — a consultation, '
                  'a procedure, a night on a ward.'
              : 'Try a shorter search.',
          actionLabel: catalogue.canCreate ? 'Add a service' : null,
          onAction: catalogue.canCreate ? () => _open(null) : null,
          actionKey: BillingServicesKeys.add,
        ),
        // Absent, not disabled, for an account that may not add one.
        addLabel: catalogue.canCreate ? 'Add a service' : null,
        onAdd: catalogue.canCreate ? () => _open(null) : null,
        addKey: BillingServicesKeys.add,
        itemBuilder: (context, index) {
          final service = rows[index];
          return LookupRow(
            key: BillingServicesKeys.service(service.id),
            title: service.serviceName,
            subtitle: _subtitle(service),
            value: catalogue.money(service.unitPrice),
            enabled: service.isActive,
            onTap: catalogue.canUpdate ? () => _open(service) : null,
          );
        },
      );
    });
  }

  String? _subtitle(BillingService service) {
    final parts = <String>[
      if ((service.serviceCode ?? '').trim().isNotEmpty) service.serviceCode!,
      if ((service.serviceCategory ?? '').trim().isNotEmpty)
        Formatters.label(service.serviceCategory),
      if ((service.department ?? '').trim().isNotEmpty)
        Formatters.label(service.department),
      if (service.isTaxable) 'Tax ${_percent(service.taxPercentage)}%',
      if (!service.isCoveredByInsurance) 'Not covered',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// `18`, not `18.0` — a rate with a trailing zero on it reads as a
  /// measurement rather than a percentage.
  static String _percent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  /// Null adds a new entry; a service edits that one.
  void _open(BillingService? service) => Get.toNamed<void>(
        BillingRoutes.serviceEdit,
        arguments: service == null ? null : {'service': service},
      );
}
