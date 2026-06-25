// lib/app/modules/appointments/providers/appointments_provider.dart

import 'package:dio/dio.dart';
import 'package:medihive/app/network/app_dio_client.dart';

class AppointmentsProvider {
  final _dio = AppDioClient.instance;

  /// Fetches all appointments. Passes optional filters.
  Future<Response> fetchAppointments({
    int page = 1,
    int limit = 100, // fetch all for calendar/list
    String? status,
    String? date,
  }) {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (date != null && date.isNotEmpty) params['date'] = date;

    return _dio.get(
      '/api/appointments',
      queryParameters: params,
    );
  }

  /// Updates an appointment's status (using PUT per backend spec)
  Future<Response> updateAppointmentStatus(String id, String status) =>
      _dio.put(
        '/api/appointments/$id',
        data: {'status': status},
      );

  /// Sends a reminder for an appointment
  Future<Response> sendReminder(String id) =>
      _dio.put(
        '/api/appointments/$id',
        data: {'reminderSent': true},
      );

  /// Creates a new appointment (POST /api/appointments)
  Future<Response> createAppointment(Map<String, dynamic> body) =>
      _dio.post(
        '/api/appointments',
        data: body,
      );

  /// Fetches all patients for the dropdown
  Future<Response> fetchPatients({int limit = 200}) =>
      _dio.get(
        '/api/patients',
        queryParameters: {'limit': limit, 'page': 1},
      );

  /// Fetches doctors list — users with role DOCTOR
  Future<Response> fetchDoctors() =>
      _dio.get(
        '/api/users/staff',
        queryParameters: {'role': 'DOCTOR'},
      );
}
