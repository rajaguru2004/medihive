import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/dio_client.dart';
import '../network/endpoints.dart';

class InpatientService extends GetxService {
  static InpatientService get to => Get.find();
  /// The one client. Constructing a bare `Dio()` here would skip the
  /// bearer header, the 401 teardown and the logger — see
  /// `.agents/RULES.md` §3.
  DioClient get _dio => Get.find<DioClient>();

  /// GET /api/inpatient/stats
  Future<Response> fetchStats() {
    return _dio.get(Endpoints.inpatientStats);
  }

  /// GET /api/inpatient/wards
  Future<Response> fetchWards() {
    return _dio.get(Endpoints.wards.list);
  }

  /// GET /api/inpatient/admissions?status=all
  Future<Response> fetchAdmissions() {
    return _dio.get(
      Endpoints.admissions.list,
      queryParameters: {'status': 'all'},
    );
  }

  /// GET /api/users/staff?role=DOCTOR
  Future<Response> fetchDoctors() {
    return _dio.get(Endpoints.staff, queryParameters: {'role': 'DOCTOR'});
  }

  /// GET /api/patients
  Future<Response> fetchPatients({required String query, int limit = 50}) {
    return _dio.get(
      Endpoints.patients.list,
      queryParameters: {'search': query, 'limit': limit},
    );
  }

  /// GET /api/inpatient/beds?wardId=xxx&status=all
  Future<Response> fetchBeds({required String wardId, String status = 'all'}) {
    return _dio.get(
      Endpoints.beds.list,
      queryParameters: {'wardId': wardId, 'status': status},
    );
  }

  /// PATCH /api/inpatient/wards/:id
  Future<Response> updateWardStatus(String id, bool isActive) {
    return _dio.patch(Endpoints.wards.update(id), data: {'isActive': isActive});
  }

  /// PATCH /api/inpatient/beds/:id
  Future<Response> updateBedStatus(String id, String status) {
    return _dio.patch(Endpoints.beds.update(id), data: {'status': status});
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
      Endpoints.admissions.create,
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

  /// PATCH /api/inpatient/admissions/:id
  Future<Response> dischargePatient({
    required String admissionId,
    required String dischargeReason,
    required String dischargeSummary,
    required String dischargeDoctorId,
    DateTime? followUpDate,
    String? followUpNotes,
  }) {
    return _dio.patch(
      Endpoints.admissions.update(admissionId),
      data: {
        'status': 'discharged',
        'dischargeReason': dischargeReason,
        'dischargeSummary': dischargeSummary,
        'dischargeDoctorId': dischargeDoctorId,
        if (followUpDate != null)
          'followUpDate': followUpDate.toUtc().toIso8601String(),
        if (followUpNotes != null && followUpNotes.isNotEmpty)
          'followUpNotes': followUpNotes,
      },
    );
  }

  /// POST /api/inpatient/wards
  Future<Response> createWard({
    required String name,
    required String code,
    required String type,
    required int capacity,
  }) {
    return _dio.post(
      Endpoints.wards.create,
      data: {
        'name': name,
        'code': code,
        'type': type,
        'capacity': capacity,
      },
    );
  }

  /// PATCH /api/inpatient/wards/:id
  Future<Response> updateWard({
    required String id,
    required String name,
    required String code,
    required String type,
    required int capacity,
  }) {
    return _dio.patch(
      Endpoints.wards.update(id),
      data: {
        'name': name,
        'code': code,
        'type': type,
        'capacity': capacity,
      },
    );
  }

  /// POST /api/inpatient/beds
  Future<Response> createBed({
    required String wardId,
    required String bedNumber,
    required String type,
    required String status,
  }) {
    return _dio.post(
      Endpoints.beds.create,
      data: {
        'wardId': wardId,
        'bedNumber': bedNumber,
        'type': type,
        'status': status,
      },
    );
  }
}
