import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/app_dio_client.dart';
import '../network/endpoints.dart';

class QueueService extends GetxService {
  final _dio = AppDioClient.instance;

  /// Fetches patients for dropdown lookup with optional search query
  Future<Response> fetchPatients({required String query, int limit = 50}) {
    return _dio.get(
      Endpoints.patients,
      queryParameters: {
        'search': query,
        'limit': limit,
      },
    );
  }

  /// Registers a patient into the queue
  Future<Response> addToQueue({
    required String patientId,
    required String serviceArea,
    String? serviceType,
    required String priority,
    String? assignedRoom,
  }) {
    return _dio.post(
      Endpoints.queue,
      data: {
        'patientId': patientId,
        'serviceArea': serviceArea,
        'serviceType': serviceType,
        'priority': priority,
        'assignedRoom': assignedRoom,
      },
    );
  }

  /// Fetches queue items filtered by comma-separated status strings
  Future<Response> fetchQueueItems(
      {required String statuses, int limit = 100}) {
    return _dio.get(
      Endpoints.queue,
      queryParameters: {
        'status': statuses,
        'limit': limit,
      },
    );
  }

  /// Updates queue status (e.g. called, cancelled, completed)
  Future<Response> updateQueueStatus(String id, String status) {
    return _dio.patch(
      Endpoints.queueById(id),
      data: {
        'status': status,
      },
    );
  }

  /// Removes an item completely from the queue (DELETE)
  Future<Response> deleteQueueItem(String id) {
    return _dio.delete(
      Endpoints.queueById(id),
    );
  }
}
