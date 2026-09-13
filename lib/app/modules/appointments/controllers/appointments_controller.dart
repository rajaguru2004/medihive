import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/services/appointment_service.dart';
import '../../../theme/theme.dart';

class AppointmentsController extends GetxController {
  final _service = Get.find<AppointmentService>();

  // ─── Controller State ──────────────────────────────────────────────────────
  List<AppointmentModel> allAppointments = [];
  List<AppointmentModel> filteredAppointments = [];
  List<AppointmentDoctor> doctors = [];

  bool isLoading = false;
  String errorMessage = '';

  // Active View Tab (0: Calendar View, 1: List View, 2: Today's Schedule)
  int activeViewTab = 0;

  // Filter States
  String searchQuery = '';
  DateTime? selectedFilterDate;
  String selectedStatusFilter = 'All Statuses';
  String selectedDoctorFilter = 'All Doctors';

  // Calendar States
  DateTime calendarSelectedDate = DateTime.now();
  List<AppointmentModel> calendarAppointmentsForDate = [];

  // ─── Getters ───────────────────────────────────────────────────────────────
  int get todayTotalCount => _getTodayCountForStatus(null);
  int get todayConfirmedCount => _getTodayCountForStatus('confirmed');
  int get todayCheckedInCount => _getTodayCountForStatus('checked_in');
  int get todayInProgressCount => _getTodayCountForStatus('in_progress');
  int get todayCompletedCount => _getTodayCountForStatus('completed');
  int get todayCancelledCount => _getTodayCountForStatus('cancelled');
  int get todayNoShowCount => _getTodayCountForStatus('no_show');
  int get todayScheduledCount => _getTodayCountForStatus('scheduled');

  List<AppointmentModel> get todayCurrentAndUpcoming =>
      allAppointments.where((a) {
        final now = DateTime.now();
        final isToday = _isSameDay(a.appointmentDate, now);
        if (!isToday) return false;
        final status = a.status.toLowerCase();
        return status == 'scheduled' ||
            status == 'confirmed' ||
            status == 'checked_in' ||
            status == 'in_progress';
      }).toList();

  List<AppointmentModel> get todayCompletedAndOthers =>
      allAppointments.where((a) {
        final now = DateTime.now();
        final isToday = _isSameDay(a.appointmentDate, now);
        if (!isToday) return false;
        final status = a.status.toLowerCase();
        return status == 'completed' ||
            status == 'cancelled' ||
            status == 'no_show';
      }).toList();

  @override
  void onInit() {
    super.onInit();
    refreshData();
  }

  // ─── Fetching Data ─────────────────────────────────────────────────────────
  Future<void> refreshData() async {
    isLoading = true;
    errorMessage = '';
    update();

    try {
      await Future.wait([
        fetchAppointmentsInternal(),
        fetchDoctorsInternal(),
      ]);
      applyFilters();
      // Initialize calendar list with selected date
      calendarAppointmentsForDate = allAppointments
          .where((a) => _isSameDay(a.appointmentDate, calendarSelectedDate))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppointmentsController] Refresh error: $e');
      }
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<void> fetchAppointments() async {
    isLoading = true;
    update();
    try {
      await fetchAppointmentsInternal();
      applyFilters();
      calendarAppointmentsForDate = allAppointments
          .where((a) => _isSameDay(a.appointmentDate, calendarSelectedDate))
          .toList();
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<void> fetchAppointmentsInternal() async {
    try {
      final res = await _service.fetchAppointments();
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> list = res.data['data']['data'] ?? [];
        allAppointments = list
            .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Sort chronologically by date then time
        allAppointments.sort((a, b) {
          final dateCompare = a.appointmentDate.compareTo(b.appointmentDate);
          if (dateCompare != 0) return dateCompare;
          return a.appointmentTime.compareTo(b.appointmentTime);
        });
      }
    } on DioException catch (e) {
      errorMessage = e.message ?? 'Network error. Please try again.';
      rethrow;
    } catch (e) {
      errorMessage = 'Failed to load appointments';
      rethrow;
    }
  }

  Future<void> fetchDoctorsInternal() async {
    try {
      final res = await _service.fetchDoctors();
      if (res.data != null && res.data['success'] == true) {
        final List<dynamic> list = res.data['data'] ?? [];
        doctors = list
            .map((e) => AppointmentDoctor.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppointmentsController] Error fetching doctors: $e');
      }
    }
  }

  // ─── Filter Logic ──────────────────────────────────────────────────────────
  void applyFilters() {
    filteredAppointments = allAppointments.where((a) {
      // 1. Search Query
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final patientName = a.patient.fullName.toLowerCase();
        final patientMrn = a.patient.mrn.toLowerCase();
        final docName = a.doctor.fullName.toLowerCase();
        final complaint = a.chiefComplaint.toLowerCase();
        if (!patientName.contains(q) &&
            !patientMrn.contains(q) &&
            !docName.contains(q) &&
            !complaint.contains(q)) {
          return false;
        }
      }

      // 2. Date Filter
      if (selectedFilterDate != null) {
        if (!_isSameDay(a.appointmentDate, selectedFilterDate!)) {
          return false;
        }
      }

      // 3. Status Filter
      if (selectedStatusFilter != 'All Statuses') {
        if (a.status.toLowerCase() != selectedStatusFilter.toLowerCase()) {
          return false;
        }
      }

      // 4. Doctor Filter
      if (selectedDoctorFilter != 'All Doctors') {
        if (a.doctorId != selectedDoctorFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    applyFilters();
    update();
  }

  void setFilterDate(DateTime? date) {
    selectedFilterDate = date;
    applyFilters();
    update();
  }

  void setStatusFilter(String status) {
    selectedStatusFilter = status;
    applyFilters();
    update();
  }

  void setDoctorFilter(String docId) {
    selectedDoctorFilter = docId;
    applyFilters();
    update();
  }

  void resetFilters() {
    searchQuery = '';
    selectedFilterDate = null;
    selectedStatusFilter = 'All Statuses';
    selectedDoctorFilter = 'All Doctors';
    applyFilters();
    update();
  }

  // ─── Calendar / Switcher Actions ──────────────────────────────────────────
  void setActiveTab(int index) {
    activeViewTab = index;
    update();
  }

  void setCalendarSelectedDate(DateTime date) {
    calendarSelectedDate = date;
    calendarAppointmentsForDate = allAppointments
        .where((a) => _isSameDay(a.appointmentDate, date))
        .toList();
    update();
  }

  // ─── API Mutator Actions ───────────────────────────────────────────────────
  Future<void> updateStatus(String id, String status,
      {Map<String, dynamic>? additionalData}) async {
    isLoading = true;
    update();
    try {
      await _service.updateAppointmentStatus(id, status,
          additionalData: additionalData);
      Get.snackbar(
        'Success',
        'Appointment status updated to ${status.replaceAll('_', ' ')}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
        colorText: AppColors.primary,
      );
      await fetchAppointmentsInternal();
      applyFilters();
      calendarAppointmentsForDate = allAppointments
          .where((a) => _isSameDay(a.appointmentDate, calendarSelectedDate))
          .toList();
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data['message'] ?? 'Failed to update appointment status',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.15),
        colorText: AppColors.error,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Something went wrong',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.15),
        colorText: AppColors.error,
      );
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<void> sendReminder(String id) async {
    isLoading = true;
    update();
    try {
      await _service.sendReminder(id);
      Get.snackbar(
        'Reminder Sent',
        'Appointment reminder sent successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
        colorText: AppColors.primary,
      );
      await fetchAppointmentsInternal();
      applyFilters();
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data['message'] ?? 'Failed to send reminder',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.15),
        colorText: AppColors.error,
      );
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<void> reschedule(String id, DateTime date, String time) async {
    isLoading = true;
    update();
    try {
      await _service.rescheduleAppointment(id, date, time);
      Get.snackbar(
        'Rescheduled',
        'Appointment rescheduled successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
        colorText: AppColors.primary,
      );
      await fetchAppointmentsInternal();
      applyFilters();
      calendarAppointmentsForDate = allAppointments
          .where((a) => _isSameDay(a.appointmentDate, calendarSelectedDate))
          .toList();
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data['message'] ?? 'Failed to reschedule',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.15),
        colorText: AppColors.error,
      );
    } finally {
      isLoading = false;
      update();
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  int _getTodayCountForStatus(String? status) {
    final now = DateTime.now();
    return allAppointments.where((a) {
      final isSame = _isSameDay(a.appointmentDate, now);
      if (!isSame) return false;
      if (status == null) return true;
      return a.status.toLowerCase() == status.toLowerCase();
    }).length;
  }
}
