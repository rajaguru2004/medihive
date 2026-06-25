// lib/app/modules/appointments/controllers/appointments_controller.dart

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../models/appointment_model.dart';
import '../providers/appointments_provider.dart';

enum AppointmentsLoadState { idle, loading, success, error }

/// Tab index for the view switcher
enum AppointmentViewTab { calendar, list, todaySchedule }

class AppointmentsController extends GetxController {
  final _provider = AppointmentsProvider();

  // ── State ─────────────────────────────────────────────────────────────────
  AppointmentsLoadState _loadState = AppointmentsLoadState.idle;
  String _errorMessage = '';

  /// Raw list from the API (all pages fetched in one call for simplicity)
  List<AppointmentModel> _allAppointments = [];

  /// Currently selected view tab
  AppointmentViewTab _selectedTab = AppointmentViewTab.calendar;

  /// Currently focused calendar date (defaults to today)
  DateTime _focusedDate = DateTime.now();

  /// Selected date in the calendar (for showing day appointments)
  DateTime? _selectedDate;

  /// Selected date for the ListView search filters
  DateTime _listFilterDate = DateTime.now();

  /// List of appointments loaded for the ListView
  List<AppointmentModel> _listViewAppointments = [];

  /// Loading state for the ListView specific date fetch
  bool _isListLoading = false;

  /// Search / filter state for List view
  String _searchQuery = '';
  String _filterStatus = ''; // empty = all
  String _filterDoctorId = '';

  // ── Getters ───────────────────────────────────────────────────────────────
  AppointmentsLoadState get loadState => _loadState;
  bool get isLoading => _loadState == AppointmentsLoadState.loading;
  bool get hasError => _loadState == AppointmentsLoadState.error;
  bool get hasData => _loadState == AppointmentsLoadState.success;
  String get errorMessage => _errorMessage;

  AppointmentViewTab get selectedTab => _selectedTab;
  DateTime get focusedDate => _focusedDate;
  DateTime? get selectedDate => _selectedDate;
  String get searchQuery => _searchQuery;
  String get filterStatus => _filterStatus;
  DateTime get listFilterDate => _listFilterDate;
  List<AppointmentModel> get listViewAppointments => _listViewAppointments;
  bool get isListLoading => _isListLoading;
  String get filterDoctorId => _filterDoctorId;

  /// Summary counts derived from the full list
  AppointmentSummary get summary =>
      AppointmentSummary.fromList(_allAppointments);

  /// All appointments sorted by date+time
  List<AppointmentModel> get allAppointments => List.unmodifiable(_allAppointments);

  /// Appointments for a specific date (used by calendar bottom sheet)
  List<AppointmentModel> appointmentsForDate(DateTime date) =>
      _allAppointments
          .where((a) =>
              a.appointmentDate.year == date.year &&
              a.appointmentDate.month == date.month &&
              a.appointmentDate.day == date.day)
          .toList()
        ..sort(_compareByTime);

  /// Whether a given date has any appointments (for calendar dot indicators)
  bool hasAppointmentsOnDate(DateTime date) =>
      _allAppointments.any((a) =>
          a.appointmentDate.year == date.year &&
          a.appointmentDate.month == date.month &&
          a.appointmentDate.day == date.day);

  /// Filtered list for the List View
  List<AppointmentModel> get filteredAppointments {
    var list = _listViewAppointments.toList();
    if (_filterStatus.isNotEmpty) {
      list = list.where((a) => a.status == _filterStatus).toList();
    }
    if (_filterDoctorId.isNotEmpty) {
      list = list.where((a) => a.doctorId == _filterDoctorId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) {
        return a.patient.fullName.toLowerCase().contains(q) ||
            a.patient.mrn.toLowerCase().contains(q) ||
            a.doctor.fullName.toLowerCase().contains(q) ||
            (a.chiefComplaint?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    list.sort(_compareByTime);
    return list;
  }

  /// Today's appointments split into active vs completed
  List<AppointmentModel> get todayActiveAppointments => _allAppointments
      .where((a) => a.isToday && a.isActive)
      .toList()
    ..sort(_compareByTime);

  List<AppointmentModel> get todayCompletedAppointments => _allAppointments
      .where((a) => a.isToday && a.isCompleted)
      .toList()
    ..sort(_compareByTime);

  /// Unique doctor list for filter dropdown
  List<AppointmentDoctor> get doctors {
    final seen = <String>{};
    return _allAppointments
        .where((a) => seen.add(a.doctorId))
        .map((a) => a.doctor)
        .toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _selectedDate = DateTime.now();
    fetchAppointments();
    fetchListViewAppointments();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────
  Future<void> fetchAppointments() async {
    _loadState = AppointmentsLoadState.loading;
    _errorMessage = '';
    update();

    try {
      final response = await _provider.fetchAppointments(limit: 100);
      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final parsed = AppointmentsResponse.fromJson(body);
        _allAppointments = parsed.data;
        _loadState = AppointmentsLoadState.success;
      } else {
        _loadState = AppointmentsLoadState.error;
        _errorMessage = body['message'] as String? ?? 'Unknown error';
      }
    } on DioException catch (e) {
      _loadState = AppointmentsLoadState.error;
      _errorMessage = e.message ?? 'Network error. Please try again.';
      if (kDebugMode) debugPrint('[AppointmentsController] DioException: $e');
    } catch (e) {
      _loadState = AppointmentsLoadState.error;
      _errorMessage = 'Something went wrong. Please try again.';
      if (kDebugMode) debugPrint('[AppointmentsController] Error: $e');
    }

    update();
  }

  Future<void> onRefresh() async {
    await Future.wait([
      fetchAppointments(),
      fetchListViewAppointments(),
    ]);
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void setTab(AppointmentViewTab tab) {
    _selectedTab = tab;
    update();
  }

  void setFocusedDate(DateTime date) {
    _focusedDate = date;
    update();
  }

  void setSelectedDate(DateTime? date) {
    _selectedDate = date;
    update();
  }

  // ── Search & Filter ───────────────────────────────────────────────────────
  void setSearchQuery(String q) {
    _searchQuery = q;
    update();
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    update();
  }

  void setFilterDoctor(String doctorId) {
    _filterDoctorId = doctorId;
    update();
  }

  void setListFilterDate(DateTime date) {
    _listFilterDate = date;
    fetchListViewAppointments();
  }

  Future<void> fetchListViewAppointments() async {
    _isListLoading = true;
    _listViewAppointments = [];
    update();

    try {
      final dateStr = "${_listFilterDate.year}-${_listFilterDate.month.toString().padLeft(2, '0')}-${_listFilterDate.day.toString().padLeft(2, '0')}";
      final response = await _provider.fetchAppointments(date: dateStr, limit: 100);
      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final parsed = AppointmentsResponse.fromJson(body);
        _listViewAppointments = parsed.data;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AppointmentsController] fetchListViewAppointments error: $e');
    } finally {
      _isListLoading = false;
      update();
    }
  }

  void clearFilters() {
    _searchQuery = '';
    _filterStatus = '';
    _filterDoctorId = '';
    update();
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> updateStatus(AppointmentModel appt, String newStatus) async {
    try {
      await _provider.updateAppointmentStatus(appt.id, newStatus);
      final updated = AppointmentModel(
        id: appt.id,
        organizationId: appt.organizationId,
        patientId: appt.patientId,
        doctorId: appt.doctorId,
        appointmentDate: appt.appointmentDate,
        appointmentTime: appt.appointmentTime,
        durationMinutes: appt.durationMinutes,
        appointmentType: appt.appointmentType,
        departmentId: appt.departmentId,
        status: newStatus,
        chiefComplaint: appt.chiefComplaint,
        notes: appt.notes,
        reminderSent: appt.reminderSent,
        createdAt: appt.createdAt,
        updatedAt: DateTime.now(),
        patient: appt.patient,
        doctor: appt.doctor,
      );

      final idx = _allAppointments.indexWhere((a) => a.id == appt.id);
      if (idx != -1) {
        _allAppointments[idx] = updated;
      }

      final listIdx = _listViewAppointments.indexWhere((a) => a.id == appt.id);
      if (listIdx != -1) {
        _listViewAppointments[listIdx] = updated;
      }

      update();
      Get.snackbar(
        '✓ Success',
        'Status updated to ${_formatStatus(newStatus)}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update status',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> sendReminder(AppointmentModel appt) async {
    try {
      await _provider.sendReminder(appt.id);
      final updated = AppointmentModel(
        id: appt.id,
        organizationId: appt.organizationId,
        patientId: appt.patientId,
        doctorId: appt.doctorId,
        appointmentDate: appt.appointmentDate,
        appointmentTime: appt.appointmentTime,
        durationMinutes: appt.durationMinutes,
        appointmentType: appt.appointmentType,
        departmentId: appt.departmentId,
        status: appt.status,
        chiefComplaint: appt.chiefComplaint,
        notes: appt.notes,
        reminderSent: true,
        createdAt: appt.createdAt,
        updatedAt: DateTime.now(),
        patient: appt.patient,
        doctor: appt.doctor,
      );

      final idx = _allAppointments.indexWhere((a) => a.id == appt.id);
      if (idx != -1) {
        _allAppointments[idx] = updated;
      }

      final listIdx = _listViewAppointments.indexWhere((a) => a.id == appt.id);
      if (listIdx != -1) {
        _listViewAppointments[listIdx] = updated;
      }

      update();
      Get.snackbar(
        '✓ Success',
        'Reminder sent successfully',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send reminder',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void showActionMenu(AppointmentModel appt) {
    // This is triggered from the view — handled via bottom sheet in the view layer
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  int _compareByTime(AppointmentModel a, AppointmentModel b) {
    final dateCompare = a.appointmentDate.compareTo(b.appointmentDate);
    if (dateCompare != 0) return dateCompare;
    return a.appointmentTime.compareTo(b.appointmentTime);
  }

  String _formatStatus(String status) => status
      .split('_')
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
