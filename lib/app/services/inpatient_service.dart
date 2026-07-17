import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../network/app_dio_client.dart';

class InpatientService extends GetxService {
  static InpatientService get to => Get.find();
  final _dio = AppDioClient.instance;

  /// GET /api/inpatient/stats
  Future<Response> fetchStats() {
    return _dio.get('/api/inpatient/stats');
  }

  /// GET /api/inpatient/wards
  Future<Response> fetchWards() {
    return _dio.get('/api/inpatient/wards');
  }

  /// GET /api/inpatient/admissions?status=all
  Future<Response> fetchAdmissions() {
    return _dio.get(
      '/api/inpatient/admissions',
      queryParameters: {'status': 'all'},
    );
  }

  /// GET /api/users/staff?role=DOCTOR
  Future<Response> fetchDoctors() {
    return _dio.get('/api/users/staff', queryParameters: {'role': 'DOCTOR'});
  }

  /// GET /api/patients
  Future<Response> fetchPatients({required String query, int limit = 50}) {
    return _dio.get(
      '/api/patients',
      queryParameters: {'search': query, 'limit': limit},
    );
  }

  /// GET /api/inpatient/beds?wardId=xxx&status=all
  Future<Response> fetchBeds({required String wardId, String status = 'all'}) {
    return _dio.get(
      '/api/inpatient/beds',
      queryParameters: {'wardId': wardId, 'status': status},
    );
  }

  /// PATCH /api/inpatient/wards/:id
  Future<Response> updateWardStatus(String id, bool isActive) {
    return _dio.patch('/api/inpatient/wards/$id', data: {'isActive': isActive});
  }

  /// PATCH /api/inpatient/beds/:id
  Future<Response> updateBedStatus(String id, String status) {
    return _dio.patch('/api/inpatient/beds/$id', data: {'status': status});
  }

  /// POST /api/inpatient/admissions
  Future<Response> admitPatient({
    required String patientId,
    required String bedId,
    required String admissionType,
    required String admissionReason,
    required String admittingDoctorId,
    required String attendingDoctorId,
  }) {
    return _dio.post(
      '/api/inpatient/admissions',
      data: {
        'patientId': patientId,
        'bedId': bedId,
        'admissionType': admissionType,
        'admissionReason': admissionReason,
        'admittingDoctorId': admittingDoctorId,
        'attendingDoctorId': attendingDoctorId,
      },
    );
  }
}
