import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../network/app_dio_client.dart';

class HomeService extends GetxService {
  final _dio = AppDioClient.instance;

  static const _orgId = 'cmqckgpi400005kijus0qqbhn';

  Future<Response> fetchDashboard() => _dio.get(
        '/api/dashboard',
      );

  Future<Response> fetchOrganization() => _dio.get(
        '/api/settings/organization',
        queryParameters: {'id': _orgId},
      );
}
