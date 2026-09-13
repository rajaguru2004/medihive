import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/app_dio_client.dart';

class AppointmentService extends GetxService {
  final _dio = AppDioClient.instance;

  Future<Response> fetchAppointments({
    int page = 1,
    int limit = 1000, // Make limit large to fetch all appointments
  }) =>
      _dio.get(
        '/api/appointments',
        queryParameters: {'page': page, 'limit': limit},
      );

  Future<Response> updateAppointmentStatus(
    String id,
    String status, {
    Map<String, dynamic>? additionalData,
  }) {
    final payload = {
      'status': status,
      if (additionalData != null) ...additionalData,
    };
    return _dio.patch(
      '/api/appointments/$id',
      data: payload,
    );
  }

  Future<Response> sendReminder(String id) => _dio.patch(
        '/api/appointments/$id',
        data: {'reminderSent': true},
      );

  Future<Response> rescheduleAppointment(
    String id,
    DateTime date,
    String time,
  ) =>
      _dio.patch(
        '/api/appointments/$id',
        data: {
          'appointmentDate': date.toIso8601String(),
          'appointmentTime': time,
        },
      );

  Future<Response> fetchDoctors() => _dio.get(
        '/api/users/staff',
        queryParameters: {'role': 'DOCTOR'},
      );
}
