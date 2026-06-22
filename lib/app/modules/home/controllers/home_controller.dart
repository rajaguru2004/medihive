// lib/app/modules/home/controllers/home_controller.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:medihive/app/modules/home/models/dashboard_model.dart';
import 'package:medihive/app/modules/home/providers/home_provider.dart';

enum LoadState { idle, loading, success, error }

class HomeController extends GetxController {
  final _provider = HomeProvider();

  // ── Observable State ───────────────────────────────────────────────────────
  final _loadState = LoadState.idle.obs;
  final _dashboardData = Rxn<DashboardData>();
  final _orgData = Rxn<OrganizationData>();
  final _errorMessage = ''.obs;
  final _selectedNavIndex = 0.obs;
  final _showAllPatients = false.obs;

  // ── Getters ────────────────────────────────────────────────────────────────
  LoadState get loadState => _loadState.value;
  DashboardData? get dashboardData => _dashboardData.value;
  OrganizationData? get orgData => _orgData.value;
  String get errorMessage => _errorMessage.value;
  int get selectedNavIndex => _selectedNavIndex.value;
  bool get showAllPatients => _showAllPatients.value;

  bool get isLoading => _loadState.value == LoadState.loading;
  bool get hasError => _loadState.value == LoadState.error;
  bool get hasData => _loadState.value == LoadState.success;

  DashboardStats get stats =>
      _dashboardData.value?.stats ??
      const DashboardStats(
        totalPatients: 0,
        todayAppointments: 0,
        pendingLabOrders: 0,
        pendingPrescriptions: 0,
        todayRevenue: 0,
        occupiedBeds: 0,
        availableBeds: 0,
        queueWaiting: 0,
        criticalAlerts: 0,
      );

  List<RecentPatient> get recentPatients {
    final patients = _dashboardData.value?.recentPatients ?? [];
    if (_showAllPatients.value) return patients;
    return patients.take(5).toList();
  }

  List<UpcomingAppointment> get upcomingAppointments =>
      _dashboardData.value?.upcomingAppointments ?? [];

  AppointmentStatuses get appointmentStatuses =>
      _dashboardData.value?.appointmentStatuses ?? const AppointmentStatuses();

  List<QueueService> get queueByService =>
      _dashboardData.value?.queueByService ?? [];

  String get orgName => _orgData.value?.name ?? 'MediHive';
  String? get orgLogoUrl => _orgData.value?.logoUrl;

  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> fetchAll() async {
    _loadState.value = LoadState.loading;
    _errorMessage.value = '';

    try {
      final results = await Future.wait([
        _provider.fetchDashboard(),
        _provider.fetchOrganization(),
      ]);

      final dashRes = results[0];
      final orgRes = results[1];

      if (dashRes.data != null) {
        _dashboardData.value =
            DashboardData.fromJson(dashRes.data as Map<String, dynamic>);
      }
      if (orgRes.data != null) {
        _orgData.value =
            OrganizationData.fromJson(orgRes.data as Map<String, dynamic>);
      }

      _loadState.value = LoadState.success;
    } on DioException catch (e) {
      _loadState.value = LoadState.error;
      _errorMessage.value = e.message ?? 'Network error. Please try again.';
      if (kDebugMode) {
        debugPrint('[HomeController] DioException: ${e.message}');
      }
    } catch (e) {
      _loadState.value = LoadState.error;
      _errorMessage.value = 'Something went wrong. Please try again.';
      if (kDebugMode) {
        debugPrint('[HomeController] Error: $e');
      }
    }
  }

  Future<void> onRefresh() async {
    await fetchAll();
  }

  void setNavIndex(int index) => _selectedNavIndex.value = index;

  void toggleShowAllPatients() =>
      _showAllPatients.value = !_showAllPatients.value;

  void onQuickAction(String action) {
    // Navigation stubs — connect to routes when modules are ready
    switch (action) {
      case 'add_patient':
        Get.snackbar('Add Patient', 'Coming soon', snackPosition: SnackPosition.BOTTOM);
        break;
      case 'book_appointment':
        Get.snackbar('Book Appointment', 'Coming soon', snackPosition: SnackPosition.BOTTOM);
        break;
      case 'admit_patient':
        Get.snackbar('Admit Patient', 'Coming soon', snackPosition: SnackPosition.BOTTOM);
        break;
      case 'create_prescription':
        Get.snackbar('Create Prescription', 'Coming soon', snackPosition: SnackPosition.BOTTOM);
        break;
      case 'lab_orders':
        Get.snackbar('Lab Orders', 'Coming soon', snackPosition: SnackPosition.BOTTOM);
        break;
      case 'billing':
        Get.snackbar('Billing', 'Coming soon', snackPosition: SnackPosition.BOTTOM);
        break;
    }
  }
}
