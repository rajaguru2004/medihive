import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/dio_client.dart';
import '../network/endpoints.dart';

class QueueService extends GetxService {
  /// The one client. Constructing a bare `Dio()` here would skip the
  /// bearer header, the 401 teardown and the logger — see
  /// `.agents/RULES.md` §3.
  DioClient get _dio => Get.find<DioClient>();

  /// Fetches patients for dropdown lookup with optional search query
  Future<Response> fetchPatients({required String query, int limit = 50}) {
    return _dio.get(
      Endpoints.patients.list,
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
      Endpoints.queue.list,
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
      Endpoints.queue.list,
      queryParameters: {
        'status': statuses,
        'limit': limit,
      },
    );
  }

  /// Updates queue status (e.g. called, cancelled, completed)
  Future<Response> updateQueueStatus(String id, String status) {
    return _dio.patch(
      Endpoints.queue.byId(id),
      data: {
        'status': status,
      },
    );
  }

  /// Removes an item completely from the queue (DELETE)
  Future<Response> deleteQueueItem(String id) {
    return _dio.delete(
      Endpoints.queue.byId(id),
    );
  }
}
