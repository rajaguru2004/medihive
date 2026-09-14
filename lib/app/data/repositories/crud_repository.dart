import 'package:dio/dio.dart';
// `FormData` is declared by both packages; GetX's belongs to its own HTTP
// client, which this app does not use.
import 'package:get/get.dart' hide Response, FormData;

import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../services/data_bus.dart';
import '../utils/api_envelope.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the shared CRUD repository
///
/// Every resource in this backend answers the same five routes with the same
/// envelope, so unwrapping them belongs in one place rather than in each of the
/// dozen controllers that would otherwise repeat it — along with the details
/// that are easy to get wrong and impossible to notice:
///
///   * a list arrives either paged (`{data, meta}`) or as a bare array, and
///     `ApiEnvelope` flattens both, so this class never asks which;
///   * an update is PATCH on most resources and PUT on patients, users and the
///     settings collections — `Crud.updateVerb` decides, not this file;
///   * a delete answers **204 with no body**, which is a success and used to
///     read as a failure;
///   * an empty collection can arrive as 202/203 with `success: false`.
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
      // A bare array and a 203 both carry no meta, so an unpaged collection
      // reports one complete page rather than a null nobody checked for.
      pagination: envelope.pagination ?? Pagination.none,
    );
  }

  /// The whole collection, for a picker to fill itself from — wards,
  /// clinicians, bed types.
  ///
  /// Pages rather than asking for everything at once. `limit: 0` was how this
  /// used to say "no limit"; the DTO declares `@Min(1)`, so it was a 400 every
  /// time and the picker was always empty.
  ///
  /// Capped at five rounds. A picker with five hundred entries is already the
  /// wrong control, and an uncapped follow of `hasMore` against a busy
  /// department is a phone paging a queue that grows while it reads it.
  Future<List<T>> listAll({Map<String, dynamic>? params}) async {
    const pageSize = 100; // The server's own ceiling; asking for more is capped.
    const maxRounds = 5;

    final all = <T>[];
    for (var page = 1; page <= maxRounds; page++) {
      final result = await list(
        PagedQuery(page: page, limit: pageSize, params: params ?? const {}),
      );
      all.addAll(result.items);
      if (!result.hasMore || result.items.isEmpty) break;
    }
    return all;
  }

  /// The first page matching a search term.
  Future<List<T>> search(
    String query, {
    int limit = 20,
    Map<String, dynamic> params = const {},
  }) async {
    final result = await list(
      PagedQuery(limit: limit, search: query, params: params),
    );
    return result.items;
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

  /// Updates one record with whichever verb this resource's route answers to.
  ///
  /// Always PATCH here once, which meant every edit to a patient, a user or a
  /// department 404'd on a route that exists.
  Future<T> update(String id, Map<String, dynamic> data) async {
    final path = routes.update(id);
    final response = switch (routes.updateVerb) {
      HttpVerb.put => await client.put(path, data: data),
      _ => await client.patch(path, data: data),
    };
    final updated = fromJson(ApiEnvelope.of(response).orThrow().object);
    _announce();
    return updated;
  }

  /// Removes one record.
  ///
  /// The delete routes answer **204 with an empty body**. `ApiEnvelope` reads
  /// a 2xx with nothing in it as a success with a null payload, which is what
  /// makes this method not throw on every successful delete.
  Future<void> delete(String id) async {
    final response = await client.delete(routes.delete(id));
    ApiEnvelope.of(response).orThrow();
    _announce();
  }

  /// Runs a named action that answers **with the record** — convert, issue,
  /// discharge — and announces it like any other write.
  ///
  /// [method] because these are not all POST: assigning a role's permissions
  /// is a PUT and revoking one is a DELETE.
  ///
  /// For an action that answers 204, use [command]: a model built from an empty
  /// payload is a model whose required fields are missing, and several of them
  /// throw rather than come back blank.
  Future<T> action(
    String path, {
    Map<String, dynamic>? data,
    HttpVerb method = HttpVerb.post,
  }) async {
    final response = switch (method) {
      HttpVerb.get => await client.get(path),
      HttpVerb.put => await client.put(path, data: data),
      HttpVerb.patch => await client.patch(path, data: data),
      HttpVerb.delete => await client.delete(path, data: data),
      HttpVerb.post => await client.post(path, data: data ?? const {}),
    };
    final result = fromJson(ApiEnvelope.of(response).orThrow().object);
    _announce();
    return result;
  }

  /// Runs a named action that answers with nothing — revoking a role, saving
  /// the enabled modules.
  Future<void> command(
    String path, {
    Map<String, dynamic>? data,
    HttpVerb method = HttpVerb.post,
  }) async {
    final response = switch (method) {
      HttpVerb.get => await client.get(path),
      HttpVerb.put => await client.put(path, data: data),
      HttpVerb.patch => await client.patch(path, data: data),
      HttpVerb.delete => await client.delete(path, data: data),
      HttpVerb.post => await client.post(path, data: data ?? const {}),
    };
    ApiEnvelope.of(response).orThrow();
    _announce();
  }

  /// Posts a multipart body — a scan, a result file, a logo.
  ///
  /// [onProgress] is what a progress bar follows. A radiology upload over ward
  /// wifi takes long enough that a spinner with no figure on it reads as a
  /// hung screen, and the second tap sends the study twice.
  Future<ApiEnvelope> upload(
    String path,
    FormData form, {
    ProgressCallback? onProgress,
  }) async {
    final response = await client.post(
      path,
      data: form,
      // Dio sets the multipart boundary itself. Leaving the client's default
      // `application/json` on the request sends a body no parser can read.
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onProgress,
    );
    final envelope = ApiEnvelope.of(response).orThrow();
    _announce();
    return envelope;
  }

  void _announce() {
    if (Get.isRegistered<DataBus>()) DataBus.to.changedRecord(entity);
  }
}
