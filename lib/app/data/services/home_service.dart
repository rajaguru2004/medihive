import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../network/dio_client.dart';

class HomeService extends GetxService {
  /// The one client. Constructing a bare `Dio()` here would skip the
  /// bearer header, the 401 teardown and the logger — see
  /// `.agents/RULES.md` §3.
  DioClient get _dio => Get.find<DioClient>();

  static const _orgId = 'cmqckgpi400005kijus0qqbhn';

  Future<Response> fetchDashboard() => _dio.get(
        '/api/dashboard',
      );

  Future<Response> fetchOrganization() => _dio.get(
        '/api/settings/organization',
        queryParameters: {'id': _orgId},
      );
}
