import 'package:get/get.dart' hide Response;

import '../models/case_intake.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../utils/api_envelope.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the clinician's side of the patient's intake
///
/// Not a [CrudRepository], and the missing half is the point: there is a list
/// and a read here and **no create, no update and no delete**. A doctor and a
/// nurse hold `CASE_TAKING_READ` and nothing else, deliberately — an intake a
/// clinician can rewrite stops being evidence of what the patient said. A
/// `CrudRepository` would offer three methods whose every call is a 403, and
/// a screen written against one of them would eventually get built.
///
/// Distinct from [CaseReviewRepository], which is the *patient* reading their
/// own case: those routes read the patient id off the bearer token and refuse
/// a staff caller outright. These take an explicit `patientId` and are scoped
/// by organisation on the server.
/// ─────────────────────────────────────────────────────────────────────────────
class CaseIntakeRepository {
  const CaseIntakeRepository();

  DioClient get _client => Get.find<DioClient>();

  /// The intakes one patient has sent in, newest first.
  ///
  /// `patientId` is not optional in any sense that matters here. The route
  /// answers the whole site's intakes without it, which is a different screen
  /// — a ward worklist — and handing this method an empty string would fetch
  /// it by accident onto a chart.
  Future<List<IntakeSummary>> forPatient(String patientId, {int limit = 20}) async {
    if (patientId.isEmpty) return const [];

    final response = await _client.get(
      Endpoints.caseSubmissions,
      queryParameters: {'patientId': patientId, 'page': 1, 'limit': limit},
    );
    return ApiEnvelope.of(response).orThrow().listOf(IntakeSummary.fromJson);
  }

  /// One intake, whole: the sections, what was not asked, and the safety rules
  /// that fired.
  ///
  /// The server answers from the document as it was stored rather than
  /// re-rendering the session, so this is what the patient sent and not what
  /// their record says today.
  Future<CaseIntake> read(String submissionId) async {
    final response = await _client.get(
      Endpoints.caseSubmission(submissionId),
    );
    return CaseIntake.fromJson(ApiEnvelope.of(response).orThrow().object);
  }
}

/// The single instance screens reach for, like the other read-only
/// repositories in this layer.
const CaseIntakeRepository caseIntakeRepository = CaseIntakeRepository();
