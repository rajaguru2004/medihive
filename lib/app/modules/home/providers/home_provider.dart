// lib/app/modules/home/providers/home_provider.dart

import 'package:dio/dio.dart';
import 'package:medihive/app/network/app_dio_client.dart';

class HomeProvider {
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
