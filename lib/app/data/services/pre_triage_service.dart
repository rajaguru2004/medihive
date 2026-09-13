import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/dio_client.dart';
import '../network/endpoints.dart';

class PreTriageService extends GetxService {
  static PreTriageService get to => Get.find();
  /// The one client. Constructing a bare `Dio()` here would skip the
  /// bearer header, the 401 teardown and the logger — see
  /// `.agents/RULES.md` §3.
  DioClient get _dio => Get.find<DioClient>();

  /// Fetch all pre-triage screenings with optional pagination and queries
  Future<Response> fetchScreenings({
    int page = 1,
    int limit = 100,
    String? search,
    String? status,
  }) {
    final Map<String, dynamic> query = {
      'page': page,
      'limit': limit,
      'orderBy': 'screenedAt',
      'orderDir': 'desc',
    };
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }
    return _dio.get(
      Endpoints.preTriage.list,
      queryParameters: query,
    );
  }

  /// Fetch a single pre-triage screening by ID
  Future<Response> fetchScreeningById(String id) {
    return _dio.get(Endpoints.preTriage.byId(id));
  }

  /// Create a new pre-triage screening
  Future<Response> createScreening({
    required String firstName,
    String? lastName,
    int? age,
    String? gender,
    String? phone,
    required String chiefComplaint,
    String? briefHistory,
    double? temperature,
    int? pulse,
    int? bpSystolic,
    int? bpDiastolic,
    String? routedTo,
  }) {
    return _dio.post(
      Endpoints.preTriage.list,
      data: {
        'firstName': firstName,
        'lastName': ?lastName,
        'age': ?age,
        'gender': ?gender,
        'phone': ?phone,
        'chiefComplaint': chiefComplaint,
        'briefHistory': ?briefHistory,
        'temperature': ?temperature,
        'pulseRate': ?pulse,
        'bloodPressureSystolic': ?bpSystolic,
        'bloodPressureDiastolic': ?bpDiastolic,
        'routedTo': ?routedTo,
      },
    );
  }

  /// Edit/Update an existing pre-triage screening
  Future<Response> updateScreening(
    String id, {
    required String firstName,
    String? lastName,
    int? age,
    String? gender,
    String? phone,
    required String chiefComplaint,
    String? briefHistory,
    double? temperature,
    int? pulse,
    int? bpSystolic,
    int? bpDiastolic,
    String? routedTo,
    String? status,
  }) {
    return _dio.patch(
      Endpoints.preTriage.byId(id),
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'gender': gender,
        'phone': phone,
        'chiefComplaint': chiefComplaint,
        'briefHistory': briefHistory,
        'temperature': temperature,
        'pulseRate': pulse,
        'bloodPressureSystolic': bpSystolic,
        'bloodPressureDiastolic': bpDiastolic,
        'routedTo': routedTo,
        'status': ?status,
      },
    );
  }

  /// Convert a screening to registered patient status
  Future<Response> convertToPatient(String id) {
    return _dio.post(
      Endpoints.convertPreTriage(id),
    );
  }

  /// Delete a pre-triage screening
  Future<Response> deleteScreening(String id) {
    return _dio.delete(Endpoints.preTriage.byId(id));
  }
}
