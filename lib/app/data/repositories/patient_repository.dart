import '../models/admission_model.dart';
import '../models/appointment_model.dart';
import '../models/consultation_model.dart';
import '../models/invoice.dart';
import '../models/lab_order.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../models/queue_item.dart';
import '../models/radiology_order.dart';
import '../network/endpoints.dart';
import '../utils/api_envelope.dart';
import 'crud_repository.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the patient register, and everything hanging off one patient
///
/// The five CRUD routes come from [CrudRepository]; `Endpoints.patients`
/// already carries `updateVerb: put`, which is the one this resource answers
/// to and the one an edit written against PATCH 404s on.
///
/// The rest of this file is the **hub**: eight sibling collections, each read
/// through the module that owns it. They are gathered here rather than on the
/// hub's controller because every one of them has a parameter vocabulary that
/// has to be checked against a DTO, and a controller is the wrong place to
/// keep that knowledge.
///
/// Every query below sends only keys its route's DTO declares. Validation runs
/// `whitelist` with `forbidNonWhitelisted`, so an invented parameter is a 400
/// for the whole request rather than a key the server ignores — and a 400 on a
/// hub tab looks exactly like a broken screen.
///
/// Two of the eight cannot filter by patient at all, and both are filtered
/// here instead. Each is commented where it happens.
/// ─────────────────────────────────────────────────────────────────────────────
class PatientRepository extends CrudRepository<Patient> {
  const PatientRepository()
      : super(Endpoints.patients, Patient.fromJson, 'patients');

  /// How many rows one hub tab asks for.
  ///
  /// A single page, deliberately: the hub is a summary of a record, not a
  /// browsable archive, and a clinician who needs the ninetieth invoice goes
  /// to Billing. `MAX_LIMIT` on this server is 100, and a `limit` above it is
  /// rejected rather than clamped.
  static const int _hubPage = 50;

  /// The sub-collections `OptionalPaginationDto` governs — radiology orders,
  /// prescriptions, invoices, admissions.
  ///
  /// That DTO declares **`page`, `limit` and `search` and nothing else**: no
  /// `orderBy`, no `orderDir`. Sending an order — which `PagedQuery` does by
  /// default — is a 400 on four of the eight tabs, so these go through
  /// [_rows] with an explicit map rather than through `PagedQuery`.
  static const Map<String, dynamic> _hubPageParams = {
    'page': 1,
    'limit': _hubPage,
  };

  /// One sibling collection, as a list of models.
  ///
  /// Reads through `ApiEnvelope`, which flattens the two shapes these routes
  /// answer with — a bare array without `page`, `{data, meta}` with it — so a
  /// caller never has to know which it asked for. A 403 leaves here as
  /// `ApiForbiddenException`, which is what lets one tab show a locked panel
  /// while the other six carry on.
  Future<List<T>> _rows<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson, {
    Map<String, dynamic> params = const {},
  }) async {
    final response = await client.get<dynamic>(path, queryParameters: params);
    return ApiEnvelope.of(response).orThrow().listOf(fromJson);
  }

  // ── Visits ────────────────────────────────────────────────────────────────

  /// `AppointmentQueryDto` declares `patientId` beside the pagination base.
  Future<List<AppointmentModel>> appointmentsFor(String patientId) => _rows(
        Endpoints.appointments.list,
        AppointmentModel.fromJson,
        params: {'patientId': patientId, 'page': 1, 'limit': _hubPage},
      );

  /// `ConsultationQueryDto` declares `patientId` beside the pagination base.
  Future<List<ConsultationModel>> consultationsFor(String patientId) => _rows(
        Endpoints.consultations.list,
        ConsultationModel.fromJson,
        params: {'patientId': patientId, 'page': 1, 'limit': _hubPage},
      );

  /// The handful of most recent consultations, for the observations on them.
  ///
  /// Separate from [consultationsFor] so the Vitals tab owns its own request
  /// and its own load state: a consultations route that is slow or refused
  /// then greys out Vitals alone rather than the whole hub.
  Future<List<ConsultationModel>> recentConsultationsFor(
    String patientId, {
    int limit = 5,
  }) =>
      _rows(
        Endpoints.consultations.list,
        ConsultationModel.fromJson,
        params: {'patientId': patientId, 'page': 1, 'limit': limit},
      );

  // ── Orders and results ────────────────────────────────────────────────────

  /// Lab orders, each with its results and their reference ranges already
  /// populated by the server.
  ///
  /// That is why there is no `labResultsFor`: `GET /api/laboratory/results`
  /// takes **only** `orderId`, so results per patient can only be reached
  /// through the orders — and the orders route already includes them, so
  /// asking again would be one request per order for data already in hand.
  Future<List<LabOrder>> labOrdersFor(String patientId) => _rows(
        Endpoints.labOrders.list,
        LabOrder.fromJson,
        params: {'patientId': patientId, 'page': 1, 'limit': _hubPage},
      );

  Future<List<RadiologyOrder>> radiologyOrdersFor(String patientId) => _rows(
        Endpoints.radiologyOrders.list,
        RadiologyOrder.fromJson,
        params: {'patientId': patientId, ..._hubPageParams},
      );

  // ── Pharmacy and billing ──────────────────────────────────────────────────

  Future<List<Prescription>> prescriptionsFor(String patientId) => _rows(
        Endpoints.prescriptions.list,
        Prescription.fromJson,
        params: {'patientId': patientId, ..._hubPageParams},
      );

  Future<List<Invoice>> invoicesFor(String patientId) => _rows(
        Endpoints.invoices.list,
        Invoice.fromJson,
        params: {'patientId': patientId, ..._hubPageParams},
      );

  // ── Where the patient is right now ────────────────────────────────────────

  /// The live queue entries this patient holds.
  ///
  /// **Filtered here, not by the server.** `QueueQueryDto` declares
  /// `serviceArea`, `status`, `page`, `limit`, `orderBy` and `orderDir` — and
  /// no `patientId`. With `forbidNonWhitelisted` on, `?patientId=` is a 400,
  /// not an ignored key, so the board is fetched and narrowed in the client.
  /// Only the three live statuses are asked for, which keeps that page small.
  Future<List<QueueItem>> queueEntriesFor(String patientId) async {
    final rows = await _rows(
      Endpoints.queue.list,
      QueueItem.fromJson,
      params: const {'status': 'waiting,called,in_service', 'limit': 100},
    );
    return rows.where((row) => row.patientId == patientId).toList();
  }

  /// The admissions this patient has, newest first.
  ///
  /// **Filtered here, not by the server.** `AdmissionListQueryDto` declares
  /// only `status` — `'all'` meaning no filter — so there is no way to ask for
  /// one patient's admissions. Everything is fetched and narrowed in the
  /// client; the hub needs only the current one, which is the first row left
  /// after the sort below.
  Future<List<AdmissionModel>> admissionsFor(String patientId) async {
    final rows = await _rows(
      Endpoints.admissions.list,
      AdmissionModel.fromJson,
      params: const {'status': 'all', ..._hubPageParams},
    );
    final mine = rows.where((row) => row.patientId == patientId).toList()
      ..sort((a, b) => b.admissionDate.compareTo(a.admissionDate));
    return mine;
  }
}

/// The one instance every patient controller reads through.
///
/// A repository here is stateless — it resolves `DioClient` per call — so one
/// shared const value is cheaper than a registration and cannot be missing
/// from a binding somebody forgot to write.
const PatientRepository patientRepository = PatientRepository();
