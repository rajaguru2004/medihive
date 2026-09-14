import 'package:get/get.dart' hide Response;

import '../models/drafts/draft_json.dart';
import '../models/drafts/pharmacy_drafts.dart';
import '../models/drug.dart';
import '../models/json.dart';
import '../models/pharmacy_sale.dart';
import '../models/prescription.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../repositories/crud_repository.dart';
import '../utils/api_envelope.dart';
import 'data_bus.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the dispensing counter
///
/// Three collections and a figure block, behind `/api/pharmacy`. Reads are
/// written out by hand rather than routed through `CrudRepository.list`,
/// because `PagedQuery` always sends `page` — and sending `page` is what flips
/// these routes from the bare array the console indexes directly into
/// `{data, meta}`. Writes go through the repository, so every one of them
/// announces itself on the `DataBus` without a call site remembering to.
///
/// **There is no `/:id` route under any of these three.** The controller mounts
/// `drugs`, `prescriptions`, `sales` and `stats` as collections and nothing
/// else, so a detail screen is handed its record or finds it in the list —
/// `Crud.byId` here would 404 on a path that looks exactly right.
/// ─────────────────────────────────────────────────────────────────────────────
class PharmacyService {
  const PharmacyService();

  /// Not a `GetxService`, and deliberately so: it holds no state, and every
  /// screen that needs it would otherwise have to be sure somebody registered
  /// it first. `CrudRepository` resolves the one `DioClient` when it is
  /// actually called, which is the only dependency here.
  static const PharmacyService instance = PharmacyService();

  /// The server's code for a dispense the shelf cannot cover.
  ///
  /// Matched on the code rather than on the status: the service raises this
  /// through `AppException`, whose default status is 400, and the same refusal
  /// is documented as a 409. A screen keyed on the number would stop
  /// recognising it the day that default changes; the code is the contract.
  static const String insufficientStock = 'INSUFFICIENT_STOCK';

  static const _drugs = CrudRepository<Drug>(
    Endpoints.drugs,
    Drug.fromJson,
    drugsEntity,
  );
  static const _prescriptions = CrudRepository<Prescription>(
    Endpoints.prescriptions,
    Prescription.fromJson,
    prescriptionsEntity,
  );
  static const _sales = CrudRepository<PharmacySale>(
    Endpoints.pharmacySales,
    PharmacySale.fromJson,
    salesEntity,
  );

  /// What these three are called on the [DataBus].
  static const String drugsEntity = 'drugs';
  static const String prescriptionsEntity = 'prescriptions';
  static const String salesEntity = 'pharmacy-sales';

  DioClient get _client => Get.find<DioClient>();

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// `GET /api/pharmacy/stats`
  Future<PharmacyStats> stats() async {
    final response = await _client.get(Endpoints.pharmacyStats);
    return PharmacyStats.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// `GET /api/pharmacy/drugs?category=&search=`
  ///
  /// `search` matches the drug name, the generic name and the code on the
  /// server, which is why the counter's search box is not filtered in memory:
  /// a pharmacist typing a generic name would find nothing here.
  Future<List<Drug>> drugs({String? category, String? search}) async {
    final term = (search ?? '').trim();
    final response = await _client.get(
      Endpoints.drugs.list,
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (term.isNotEmpty) 'search': term,
      },
    );
    return ApiEnvelope.of(response).orThrow().listOf(Drug.fromJson);
  }

  /// `GET /api/pharmacy/prescriptions?status=&patientId=`
  Future<List<Prescription>> prescriptions({
    String? status,
    String? patientId,
  }) async {
    final response = await _client.get(
      Endpoints.prescriptions.list,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (patientId != null && patientId.isNotEmpty) 'patientId': patientId,
      },
    );
    return ApiEnvelope.of(response).orThrow().listOf(Prescription.fromJson);
  }

  /// `GET /api/pharmacy/sales?date=`
  ///
  /// The day, never an instant: the server widens whatever it is given to that
  /// calendar day's bounds, and an ISO instant sent from a zone ahead of UTC
  /// widens the wrong day.
  Future<List<PharmacySale>> sales({DateTime? date}) async {
    final response = await _client.get(
      Endpoints.pharmacySales.list,
      queryParameters: {if (date != null) 'date': isoDay(date)},
    );
    return ApiEnvelope.of(response).orThrow().listOf(PharmacySale.fromJson);
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<Drug> createDrug(DrugDraft draft) =>
      _drugs.create(draft.toCreateJson());

  Future<Drug> updateDrug(String id, DrugDraft draft) =>
      _drugs.update(id, draft.toUpdateJson());

  Future<Prescription> updatePrescription(String id, PrescriptionDraft draft) =>
      _prescriptions.update(id, draft.toUpdateJson());

  /// `POST /api/pharmacy/sales`
  ///
  /// Does three things on the server, in one transaction: writes the sale,
  /// **decrements every line's stock**, and — when `prescriptionId` came with
  /// it — moves that prescription to `fully_dispensed` and stamps who
  /// dispensed it. So a full dispense needs no PATCH afterwards; a partial one
  /// does, to correct the status the sale just set. See
  /// `DispenseController.confirm`.
  ///
  /// Refuses with [insufficientStock] when any line asks for more than the
  /// shelf holds, in a message that names the drug. Nothing is written in that
  /// case — the check runs before the transaction opens.
  Future<PharmacySale> createSale(SaleDraft draft) async {
    final sale = await _sales.create(draft.toCreateJson());
    // The repository announced the sale itself. Stock and the prescription
    // moved in the same transaction, and the screens watching those two would
    // otherwise be showing figures the server has already changed.
    if (Get.isRegistered<DataBus>()) {
      DataBus.to.changed([
        drugsEntity,
        prescriptionsEntity,
        DataBus.summary,
      ]);
    }
    return sale;
  }
}

/// The counter's headline figures — `GET /api/pharmacy/stats`.
class PharmacyStats {
  const PharmacyStats({
    this.totalDrugs = 0,
    this.lowStock = 0,
    this.outOfStock = 0,
    this.pendingPrescriptions = 0,
    this.todaySales = 0,
  });

  final int totalDrugs;

  /// Drugs at or below their reorder level, the server's count.
  ///
  /// **Amber wherever it is shown, never red.** An empty shelf is an
  /// administrative problem; red on this app means a patient is deteriorating,
  /// and every red that is not one costs that scan its meaning.
  final int lowStock;

  final int outOfStock;
  final int pendingPrescriptions;

  /// Today's takings, in the site's currency. Formatted only through
  /// `SettingsService.money` — never with a symbol written into a screen.
  final double todaySales;

  static const PharmacyStats empty = PharmacyStats();

  factory PharmacyStats.fromJson(Map<String, dynamic> json) => PharmacyStats(
        totalDrugs: asInt(json['totalDrugs']),
        lowStock: asInt(json['lowStock']),
        outOfStock: asInt(json['outOfStock']),
        pendingPrescriptions: asInt(json['pendingPrescriptions']),
        todaySales: asDouble(json['todaySales']),
      );
}
