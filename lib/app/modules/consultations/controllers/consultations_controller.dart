import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;

import '../../../data/models/consultation_model.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/queue_item.dart';
import '../../../data/services/consultation_service.dart';
import '../../../theme/theme.dart';

class ConsultationsController extends GetxController {
  final _service = ConsultationService.to;

  // State Variables
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isLoadingQueue = false.obs;
  
  final RxList<ConsultationModel> consultations = <ConsultationModel>[].obs;
  final RxList<QueueItem> waitingQueue = <QueueItem>[].obs;
  final RxList<DoctorModel> doctors = <DoctorModel>[].obs;

  // Stats Counters
  final RxInt totalVisits = 0.obs;
  final RxInt outpatientCount = 0.obs;
  final RxInt emergencyCount = 0.obs;
  final RxInt followUpCount = 0.obs;

  // Filter States
  final searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final Rxn<DateTime> selectedDate = Rxn<DateTime>();
  final Rxn<DoctorModel> selectedDoctor = Rxn<DoctorModel>();

  // Pagination & Scrolling
  final ScrollController scrollController = ScrollController();
  int _currentPage = 1;
  final int _limit = 10;
  final RxBool hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    loadAllData();
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    searchController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      loadMoreConsultations();
    }
  }

  // Load all initial data
  Future<void> loadAllData() async {
    isLoading.value = true;
    _currentPage = 1;
    hasMore.value = true;
    consultations.clear();
    
    await Future.wait([
      fetchConsultations(isRefresh: true),
      fetchWaitingQueue(),
      fetchDoctorsList(),
      fetchStats(),
    ]);
    
    isLoading.value = false;
  }

  // Fetch paginated consultations
  Future<void> fetchConsultations({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      hasMore.value = true;
    }

    try {
      final formattedDate = selectedDate.value != null
          ? "${selectedDate.value!.year}-${selectedDate.value!.month.toString().padLeft(2, '0')}-${selectedDate.value!.day.toString().padLeft(2, '0')}"
          : null;

      final response = await _service.getConsultations(
        page: _currentPage,
        limit: _limit,
        search: searchQuery.value.isEmpty ? null : searchQuery.value,
        date: formattedDate,
        doctorId: selectedDoctor.value?.id,
      );

      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> dataList = response.data['data']?['data'] ?? [];
        final List<ConsultationModel> parsedList = dataList
            .map((json) => ConsultationModel.fromJson(json as Map<String, dynamic>))
            .toList();

        final meta = response.data['data']?['meta'] ?? {};
        final totalPages = meta['totalPages'] as int? ?? 1;

        if (isRefresh) {
          consultations.assignAll(parsedList);
        } else {
          consultations.addAll(parsedList);
        }

        hasMore.value = _currentPage < totalPages;
        if (hasMore.value) {
          _currentPage++;
        }
      }
    } on dio.DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data?['message'] ?? 'Failed to load consultations',
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        colorText: AppColors.error,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Load next page
  Future<void> loadMoreConsultations() async {
    if (isLoadingMore.value || !hasMore.value) return;

    isLoadingMore.value = true;
    await fetchConsultations(isRefresh: false);
    isLoadingMore.value = false;
  }

  // Fetch statistics counts
  Future<void> fetchStats() async {
    final stats = await _service.getStatistics();
    totalVisits.value = stats['total'] ?? 0;
    outpatientCount.value = stats['outpatient'] ?? 0;
    emergencyCount.value = stats['emergency'] ?? 0;
    followUpCount.value = stats['followup'] ?? 0;
  }

  // Fetch Waiting Queue
  Future<void> fetchWaitingQueue() async {
    isLoadingQueue.value = true;
    try {
      final response = await _service.getWaitingQueue();
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> dataList = response.data['data']?['data'] ?? [];
        waitingQueue.assignAll(
          dataList.map((json) => QueueItem.fromJson(json as Map<String, dynamic>)).toList(),
        );
      }
    } catch (_) {
      waitingQueue.clear();
    } finally {
      isLoadingQueue.value = false;
    }
  }

  // Fetch doctors list for filter dropdown
  Future<void> fetchDoctorsList() async {
    try {
      final response = await _service.getDoctors();
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> dataList = response.data['data'] ?? [];
        doctors.assignAll(
          dataList.map((json) => DoctorModel.fromJson(json as Map<String, dynamic>)).toList(),
        );
      }
    } catch (_) {
      doctors.clear();
    }
  }

  // Filters trigger refresh
  void updateSearch(String query) {
    searchQuery.value = query;
    fetchConsultations(isRefresh: true);
  }

  void selectDate(DateTime? date) {
    selectedDate.value = date;
    fetchConsultations(isRefresh: true);
  }

  void selectDoctor(DoctorModel? doctor) {
    selectedDoctor.value = doctor;
    fetchConsultations(isRefresh: true);
  }

  void clearFilters() {
    searchController.clear();
    searchQuery.value = '';
    selectedDate.value = null;
    selectedDoctor.value = null;
    fetchConsultations(isRefresh: true);
  }

  // Delete Consultation Record
  Future<void> deleteConsultationRecord(String id) async {
    try {
      final response = await _service.deleteConsultation(id);
      if (response.data != null && response.data['success'] == true) {
        Get.snackbar(
          'Success',
          'Consultation record deleted successfully',
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          colorText: AppColors.success,
          snackPosition: SnackPosition.BOTTOM,
        );
        loadAllData();
      }
    } on dio.DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data?['message'] ?? 'Failed to delete record',
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        colorText: AppColors.error,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Mock complete consultation
  Future<void> completeConsultationRecord(String id) async {
    try {
      final response = await _service.completeConsultation(id, {'status': 'completed'});
      if (response.data != null && response.data['success'] == true) {
        Get.snackbar(
          'Success',
          'Consultation completed successfully',
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          colorText: AppColors.success,
          snackPosition: SnackPosition.BOTTOM,
        );
        loadAllData();
      }
    } on dio.DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data?['message'] ?? 'Failed to complete consultation',
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        colorText: AppColors.error,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
