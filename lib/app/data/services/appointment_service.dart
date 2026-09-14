import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/dio_client.dart';
import '../network/endpoints.dart';

class AppointmentService extends GetxService {
  /// The one client. Constructing a bare `Dio()` here would skip the
  /// bearer header, the 401 teardown and the logger — see
  /// `.agents/RULES.md` §3.
  DioClient get _dio => Get.find<DioClient>();

  /// One page of the clinic list.
  ///
  /// The server caps `limit` at 100 whatever is asked for, so the old 1000 was
  /// not "all appointments" — it was the first hundred, with the other pages
  /// silently missing from the board.
  Future<Response> fetchAppointments({int page = 1, int limit = 100}) =>
      _dio.get(
        Endpoints.appointments.list,
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
      Endpoints.appointments.update(id),
      data: payload,
    );
  }

  Future<Response> sendReminder(String id) => _dio.patch(
        Endpoints.appointments.update(id),
        data: {'reminderSent': true},
      );

  Future<Response> rescheduleAppointment(
    String id,
    DateTime date,
    String time,
  ) =>
      _dio.patch(
        Endpoints.appointments.update(id),
        data: {
          'appointmentDate': date.toIso8601String(),
          'appointmentTime': time,
        },
      );

  Future<Response> fetchDoctors() => _dio.get(
        Endpoints.staff,
        queryParameters: {'role': 'DOCTOR'},
      );
}
