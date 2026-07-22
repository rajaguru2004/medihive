import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/app_dio_client.dart';
import '../network/endpoints.dart';

class PreTriageService extends GetxService {
  static PreTriageService get to => Get.find();
  final _dio = AppDioClient.instance;

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
      Endpoints.preTriage,
      queryParameters: query,
    );
  }

  /// Fetch a single pre-triage screening by ID
  Future<Response> fetchScreeningById(String id) {
    return _dio.get(Endpoints.preTriageById(id));
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
      Endpoints.preTriage,
      data: {
        'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (phone != null) 'phone': phone,
        'chiefComplaint': chiefComplaint,
        if (briefHistory != null) 'briefHistory': briefHistory,
        if (temperature != null) 'temperature': temperature,
        if (pulse != null) 'pulseRate': pulse,
        if (bpSystolic != null) 'bloodPressureSystolic': bpSystolic,
        if (bpDiastolic != null) 'bloodPressureDiastolic': bpDiastolic,
        if (routedTo != null) 'routedTo': routedTo,
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
      Endpoints.preTriageById(id),
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
        if (status != null) 'status': status,
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
    return _dio.delete(Endpoints.preTriageById(id));
  }
}
