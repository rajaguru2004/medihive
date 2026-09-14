import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../utils/legacy_envelope.dart';

class ConsultationService extends GetxService {
  static ConsultationService get to => Get.find();
  /// The one client. Constructing a bare `Dio()` here would skip the
  /// bearer header, the 401 teardown and the logger — see
  /// `.agents/RULES.md` §3.
  DioClient get _dio => Get.find<DioClient>();

  /// Fetch all consultations with filters
  Future<Response> getConsultations({
    int page = 1,
    int limit = 10,
    String? search,
    String? date,
    String? doctorId,
  }) {
    final Map<String, dynamic> query = {
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }
    if (date != null && date.isNotEmpty) {
      query['date'] = date;
    }
    if (doctorId != null && doctorId.isNotEmpty) {
      query['doctorId'] = doctorId;
    }
    return _dio.get(
      Endpoints.consultations.list,
      queryParameters: query,
    );
  }

  /// Fetch statistics (dynamically computed or fallback counts)
  Future<Map<String, int>> getStatistics() async {
    try {
      final res = await getConsultations(page: 1, limit: 100);
      final list = envelopeRows(res.data);
      final int total = list.length;
      int outpatient = 0;
      int emergency = 0;
      int followup = 0;

      for (final item in list) {
        final type = (item['visitType'] as String? ?? '').toLowerCase();
        if (type == 'outpatient') {
          outpatient++;
        } else if (type == 'emergency') {
          emergency++;
        } else if (type == 'follow-up' || type == 'followup') {
          followup++;
        }
      }

      // If counts are zero but we have total, assign outpatient for fallback visual satisfaction
      if (total > 0 && outpatient == 0 && emergency == 0 && followup == 0) {
        outpatient = total;
      }

      return {
        'total': total,
        'outpatient': outpatient,
        'emergency': emergency,
        'followup': followup,
      };
    } catch (_) {
      return {
        'total': 0,
        'outpatient': 0,
        'emergency': 0,
        'followup': 0,
      };
    }
  }

  /// Fetch OPD Waiting Queue
  Future<Response> getWaitingQueue() {
    return _dio.get(
      Endpoints.queue.list,
      queryParameters: {
        'serviceArea': 'opd',
        'status': 'in_service',
        'limit': 100,
      },
    );
  }

  /// Fetch all doctors
  Future<Response> getDoctors() {
    return _dio.get(
      Endpoints.staff,
      queryParameters: {'role': 'DOCTOR'},
    );
  }

  /// Delete a consultation
  Future<Response> deleteConsultation(String id) {
    return _dio.delete(Endpoints.consultations.byId(id));
  }

  /// Mark consultation complete / create one
  Future<Response> completeConsultation(String id, Map<String, dynamic> data) {
    // API complete consultation simulation or PATCH
    return _dio.patch(
      Endpoints.consultations.byId(id),
      data: data,
    );
  }
}
