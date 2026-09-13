import 'package:get/get.dart' hide Response;

import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../services/data_bus.dart';
import '../utils/api_envelope.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the shared CRUD repository
///
/// Every resource in this backend answers the same five routes with the same
/// envelope, so unwrapping them belongs in one place rather than in each of the
/// dozen controllers that would otherwise repeat it — along with the two
/// details that are easy to get wrong and impossible to notice: an empty
/// collection can arrive as 202/203 with `success: false`, and pagination
/// hangs off a sibling key rather than living inside the payload.
///
/// Subclass to add a resource's own routes:
///
/// ```dart
/// class AdmissionRepository extends CrudRepository<Admission> {
///   AdmissionRepository() : super(Endpoints.admissions, Admission.fromJson, 'admissions');
///   Future<Admission> discharge(String id, {required String summary}) async { … }
/// }
/// ```
/// ─────────────────────────────────────────────────────────────────────────────
class CrudRepository<T> {
  const CrudRepository(this.routes, this.fromJson, this.entity);

  final Crud routes;
  final T Function(Map<String, dynamic> json) fromJson;

  /// What this resource is called on the [DataBus]. A screen watching
  /// `'queue'` reloads when anything writes a queue entry.
  final String entity;

  DioClient get client => Get.find<DioClient>();

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// One page of the collection.
  Future<PagedResult<T>> list([PagedQuery query = const PagedQuery()]) async {
    final response = await client.get(
      routes.list,
      queryParameters: query.toQueryParameters(),
    );
    final envelope = ApiEnvelope.of(response).orThrow();
    return PagedResult<T>(
      items: envelope.listOf(fromJson),
      // A 203 carries no pagination block, so an empty collection reports one
      // empty page rather than a null nobody checked for.
      pagination: envelope.pagination ?? Pagination.none,
    );
  }

  /// The whole collection, unpaginated.
  ///
  /// For lookups a picker fills itself from — wards, clinicians, bed types.
  /// Never for a screen's main list: a busy department's queue has no upper
  /// bound and neither does this route.
  Future<List<T>> listAll({Map<String, dynamic>? where}) async {
    final response = await client.get(
      routes.list,
      queryParameters: {'limit': 0, ...?where},
    );
    return ApiEnvelope.of(response).orThrow().listOf(fromJson);
  }

  Future<List<T>> search(String query, {String fields = 'name'}) async {
    final response = await client.get(
      routes.list,
      queryParameters: {'q': query, 'fields': fields},
    );
    return ApiEnvelope.of(response).orThrow().listOf(fromJson);
  }

  Future<T> read(String id) async {
    final response = await client.get(routes.byId(id));
    return fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  // ── Writes ────────────────────────────────────────────────────────────────
  //
  // Each announces itself on the DataBus. Announcing here rather than at call
  // sites is what makes a screen written next month automatically correct: it
  // subscribes to an entity, and every existing write already tells it.

  Future<T> create(Map<String, dynamic> data) async {
    final response = await client.post(routes.create, data: data);
    final created = fromJson(ApiEnvelope.of(response).orThrow().object);
    _announce();
    return created;
  }

  Future<T> update(String id, Map<String, dynamic> data) async {
    final response = await client.patch(routes.update(id), data: data);
    final updated = fromJson(ApiEnvelope.of(response).orThrow().object);
    _announce();
    return updated;
  }

  Future<void> delete(String id) async {
    final response = await client.delete(routes.delete(id));
    ApiEnvelope.of(response).orThrow();
    _announce();
  }

  /// Runs a named action on one record — discharge, transfer, advance — and
  /// announces it like any other write.
  Future<T> action(String path, {Map<String, dynamic>? data}) async {
    final response = await client.post(path, data: data ?? const {});
    final result = fromJson(ApiEnvelope.of(response).orThrow().object);
    _announce();
    return result;
  }

  void _announce() {
    if (Get.isRegistered<DataBus>()) DataBus.to.changedRecord(entity);
  }
}
