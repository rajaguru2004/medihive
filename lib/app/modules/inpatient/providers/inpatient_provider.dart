// lib/app/modules/inpatient/providers/inpatient_provider.dart

import 'package:dio/dio.dart';
import 'package:medihive/app/network/app_dio_client.dart';

class InpatientProvider {
  final _dio = AppDioClient.instance;

  Future<Response> fetchStats() => _dio.get('/api/inpatient/stats');

  Future<Response> fetchWards() => _dio.get('/api/inpatient/wards');

  Future<Response> fetchAdmissions({String status = 'all'}) =>
      _dio.get('/api/inpatient/admissions', queryParameters: {'status': status});

  Future<Response> fetchPatients() => _dio.get('/api/patients');

  Future<Response> fetchDoctors() =>
      _dio.get('/api/users/staff', queryParameters: {'role': 'DOCTOR'});

  Future<Response> deactivateWard(String wardId) =>
      _dio.patch('/api/inpatient/wards/$wardId', data: {'isActive': false});

  Future<Response> createWard(Map<String, dynamic> payload) =>
      _dio.post('/api/inpatient/wards', data: payload);

  Future<Response> updateWard(String wardId, Map<String, dynamic> payload) =>
      _dio.patch('/api/inpatient/wards/$wardId', data: payload);

  Future<Response> admitPatient(Map<String, dynamic> payload) =>
      _dio.post('/api/inpatient/admissions', data: payload);

  Future<Response> createBed(Map<String, dynamic> payload) =>
      _dio.post('/api/inpatient/beds', data: payload);

  Future<Response> updateBed(String bedId, Map<String, dynamic> payload) =>
      _dio.patch('/api/inpatient/beds/$bedId', data: payload);
}
