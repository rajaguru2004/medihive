import 'package:get/get.dart' hide Response;

import '../models/dashboard_model.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../utils/api_envelope.dart';

/// The dashboard's two reads.
///
/// Both are scoped to the signed-in user's own hospital **by the server**, from
/// the organisation id inside their token. This used to send a hard-coded one:
/// correct on exactly one machine, ignored for every ordinary account, and for
/// a super admin a request for somebody else's hospital.
class HomeService extends GetxService {
  static HomeService get to => Get.find<HomeService>();

  /// The one client. Constructing a bare `Dio()` here would skip the
  /// bearer header, the 401 teardown and the logger — see
  /// `.agents/RULES.md` §3.
  DioClient get _dio => Get.find<DioClient>();

  Future<DashboardData> fetchDashboard() async {
    final response = await _dio.get(Endpoints.dashboard);
    return DashboardData.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  Future<OrganizationData> fetchOrganization() async {
    final response = await _dio.get(Endpoints.organization);
    return OrganizationData.fromJson(ApiEnvelope.of(response).orThrow().object);
  }
}
