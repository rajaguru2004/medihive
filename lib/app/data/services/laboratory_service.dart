import 'package:get/get.dart' hide Response;

import '../models/json.dart';
import '../models/lab_order.dart';
import '../models/lab_result.dart';
import '../models/lab_test.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../repositories/crud_repository.dart';
import '../utils/api_envelope.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the laboratory's three collections
///
/// A catalogue of what can be ordered, the orders themselves, and the results
/// against them. Each is a plain [CrudRepository]; this file exists to hold the
/// two things that are not one — the stats figure, and the fact that this
/// backend has no `GET /laboratory/orders/:id`.
///
/// Deliberately **not** a `GetxService`. There is no state here to hold — the
/// repositories read their client from the container at call time — and a
/// service registered in one binding and found in another is a lookup that
/// throws the first time somebody deep-links past the screen that registered
/// it.
/// ─────────────────────────────────────────────────────────────────────────────
class LaboratoryService {
  const LaboratoryService();

  LabOrderRepository get orders => const LabOrderRepository();
  LabTestRepository get tests => const LabTestRepository();
  LabResultRepository get results => const LabResultRepository();

  /// The six figures on the worklist header.
  Future<LabStats> stats() async {
    final response = await Get.find<DioClient>().get(Endpoints.labStats);
    return LabStats.fromJson(ApiEnvelope.of(response).orThrow().object);
  }
}

/// Lab orders. Paged, and the only laboratory route that is.
class LabOrderRepository extends CrudRepository<LabOrder> {
  const LabOrderRepository()
      : super(Endpoints.labOrders, LabOrder.fromJson, entityName);

  /// What a write to an order announces itself as on the `DataBus`.
  static const String entityName = 'lab-orders';

  /// Reads one order back, through the list it came from.
  ///
  /// There is no `GET /laboratory/orders/:id` on this backend — the route
  /// table stops at `PATCH /orders/:id` — so a detail screen that asked for
  /// one would 404 on a path that looks right. [orderNumber] narrows it to a
  /// single match when the caller already has one; without it this reads the
  /// first page and matches on id, which is what a cold deep link gets.
  ///
  /// Null when the order is not in reach, rather than an exception: the caller
  /// has a screen to put that on, and "not found" is not a fault.
  Future<LabOrder?> find(String id, {String? orderNumber}) async {
    final page = await list(
      PagedQuery(
        limit: (orderNumber ?? '').isEmpty ? 100 : 20,
        search: orderNumber,
      ),
    );
    return page.items.firstWhereOrNull((order) => order.id == id);
  }
}

/// The catalogue. A bare array with no `meta`, and no `search` parameter — the
/// route reads only `category`.
class LabTestRepository extends CrudRepository<LabTest> {
  const LabTestRepository()
      : super(Endpoints.labTests, LabTest.fromJson, entityName);

  static const String entityName = 'lab-tests';
}

/// Results, always read against one order.
class LabResultRepository extends CrudRepository<LabResult> {
  const LabResultRepository()
      : super(Endpoints.labResults, LabResult.fromJson, entityName);

  static const String entityName = 'lab-results';

  /// Every result entered against [orderId], newest state first.
  Future<List<LabResult>> forOrder(String orderId) async {
    final page = await list(
      PagedQuery(limit: 100, params: {'orderId': orderId}),
    );
    return page.items;
  }
}

/// The laboratory's own figures, from `GET /api/laboratory/stats`.
class LabStats {
  const LabStats({
    this.pending = 0,
    this.sampleCollected = 0,
    this.inProgress = 0,
    this.completedToday = 0,
    this.criticalResults = 0,
    this.totalTests = 0,
  });

  /// Ordered, requested, no tube yet.
  final int pending;

  final int sampleCollected;
  final int inProgress;
  final int completedToday;

  /// Critical **and unverified** — the server counts only results nobody has
  /// signed off yet, which is why this figure is a queue and not a total.
  final int criticalResults;

  /// Active entries in the catalogue, not tests run.
  final int totalTests;

  static const LabStats empty = LabStats();

  factory LabStats.fromJson(Map<String, dynamic> json) => LabStats(
        pending: asInt(json['pending']),
        sampleCollected: asInt(json['sampleCollected']),
        inProgress: asInt(json['inProgress']),
        completedToday: asInt(json['completedToday']),
        criticalResults: asInt(json['criticalResults']),
        totalTests: asInt(json['totalTests']),
      );
}
