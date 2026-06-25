// lib/app/modules/queue/providers/queue_provider.dart

import 'package:dio/dio.dart';
import 'package:medihive/app/network/app_dio_client.dart';

class QueueProvider {
  final _dio = AppDioClient.instance;

  /// Fetches queue items with optional filters
  Future<Response> fetchQueue({
    String status = 'waiting,called,in_service',
    String? serviceArea,
    String? priority,
    int limit = 100,
    int page = 1,
  }) {
    final params = <String, dynamic>{
      'status': status,
      'limit': limit,
      'page': page,
    };
    if (serviceArea != null && serviceArea.isNotEmpty) {
      params['serviceArea'] = serviceArea;
    }
    if (priority != null && priority.isNotEmpty) {
      params['priority'] = priority;
    }
    return _dio.get('/api/queue', queryParameters: params);
  }

  /// Fetches history (completed) queue items
  Future<Response> fetchHistory({
    String? serviceArea,
    int limit = 100,
    int page = 1,
  }) {
    final params = <String, dynamic>{
      'status': 'completed',
      'limit': limit,
      'page': page,
    };
    if (serviceArea != null && serviceArea.isNotEmpty) {
      params['serviceArea'] = serviceArea;
    }
    return _dio.get('/api/queue', queryParameters: params);
  }

  /// Updates a queue item's status (PATCH)
  Future<Response> updateQueueStatus(String id, String status) =>
      _dio.patch(
        '/api/queue/$id',
        data: {'status': status},
      );

  /// Deletes a queue item
  Future<Response> deleteQueue(String id) => _dio.delete('/api/queue/$id');

  /// Creates a new queue entry
  Future<Response> createQueue(Map<String, dynamic> body) =>
      _dio.post('/api/queue', data: body);

  /// Fetches patients for the dropdown
  Future<Response> fetchPatients({int limit = 200}) => _dio.get(
        '/api/patients',
        queryParameters: {'limit': limit, 'page': 1},
      );
}
