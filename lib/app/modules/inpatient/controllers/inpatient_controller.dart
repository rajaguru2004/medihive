// lib/app/modules/inpatient/controllers/inpatient_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import 'package:medihive/app/theme/theme.dart';
import '../models/inpatient_models.dart';
import '../providers/inpatient_provider.dart';

enum InpatientLoadState { idle, loading, success, error }

enum InpatientTab { overview, wards, bedsGrid, admissions }

class InpatientController extends GetxController {
  final _provider = InpatientProvider();

  // ── Load States ──────────────────────────────────────────────────────────
  InpatientLoadState _loadState = InpatientLoadState.idle;
  String _errorMessage = '';
  bool _isRefreshing = false;

  // ── Data ─────────────────────────────────────────────────────────────────
  InpatientStats _stats = InpatientStats.empty();
  List<WardModel> _wards = [];
  List<AdmissionModel> _admissions = [];
  List<PatientModel> _patients = [];
  List<DoctorModel> _doctors = [];

  // ── Tab State ─────────────────────────────────────────────────────────────
  InpatientTab _selectedTab = InpatientTab.overview;

  // ── Beds Grid Filters ─────────────────────────────────────────────────────
  String _selectedWardId = '';
  String _selectedBedStatus = 'all'; // all / available / occupied / maintenance

  // ── Admission List Search/Filter (Overview + Admissions tabs) ───────────
  String _admissionSearch = '';
  String _admissionFilter = 'active'; // active / discharged / all

  // ── Admit Form ────────────────────────────────────────────────────────────
  PatientModel? _admitSelectedPatient;
  WardModel? _admitSelectedWard;
  BedModel? _admitSelectedBed;
  String _admitType = 'Routine Admission';
  DoctorModel? _admittingDoctor;
  DoctorModel? _attendingDoctor;
  String _admissionReason = '';
  String _patientSearchQuery = '';

  // ── Getters ───────────────────────────────────────────────────────────────
  InpatientLoadState get loadState => _loadState;
  bool get isLoading => _loadState == InpatientLoadState.loading;
  bool get hasError => _loadState == InpatientLoadState.error;
  bool get isRefreshing => _isRefreshing;
  String get errorMessage => _errorMessage;

  InpatientStats get stats => _stats;
  List<WardModel> get wards => List.unmodifiable(_wards);
  List<WardModel> get activeWards => _wards.where((w) => w.isActive).toList();
  List<AdmissionModel> get admissions => List.unmodifiable(_admissions);
  List<AdmissionModel> get activeAdmissions =>
      _admissions.where((a) => a.isActive).toList();

  String get admissionSearch => _admissionSearch;
  String get admissionFilter => _admissionFilter;

  /// Filtered list used by Overview & Admissions tabs
  List<AdmissionModel> get filteredAdmissions {
    List<AdmissionModel> list;
    switch (_admissionFilter) {
      case 'active':
        list = _admissions.where((a) => a.isActive).toList();
        break;
      case 'discharged':
        list = _admissions.where((a) => a.isDischarged).toList();
        break;
      default:
        list = List.of(_admissions);
    }
    if (_admissionSearch.trim().isNotEmpty) {
      final q = _admissionSearch.toLowerCase();
      list = list.where((a) {
        return a.patient.fullName.toLowerCase().contains(q) ||
            a.patient.mrn.toLowerCase().contains(q) ||
            a.wardAndBed.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }
  List<PatientModel> get patients => List.unmodifiable(_patients);
  List<DoctorModel> get doctors => List.unmodifiable(_doctors);

  InpatientTab get selectedTab => _selectedTab;

  String get selectedWardId => _selectedWardId;
  String get selectedBedStatus => _selectedBedStatus;

  PatientModel? get admitSelectedPatient => _admitSelectedPatient;
  WardModel? get admitSelectedWard => _admitSelectedWard;
  BedModel? get admitSelectedBed => _admitSelectedBed;
  String get admitType => _admitType;
  DoctorModel? get admittingDoctor => _admittingDoctor;
  DoctorModel? get attendingDoctor => _attendingDoctor;
  String get admissionReason => _admissionReason;
  String get patientSearchQuery => _patientSearchQuery;

  List<PatientModel> get filteredPatients {
    if (_patientSearchQuery.isEmpty) return _patients;
    final q = _patientSearchQuery.toLowerCase();
    return _patients
        .where((p) =>
            p.fullName.toLowerCase().contains(q) ||
            p.mrn.toLowerCase().contains(q))
        .toList();
  }

  /// Beds for the currently selected ward + status filter
  List<BedModel> get filteredBeds {
    if (_selectedWardId.isEmpty) return [];
    final ward = _wards.firstWhereOrNull((w) => w.id == _selectedWardId);
    if (ward == null) return [];
    var beds = ward.beds;
    if (_selectedBedStatus != 'all') {
      beds = beds.where((b) => b.status == _selectedBedStatus).toList();
    }
    return beds;
  }

  WardModel? get selectedWardModel =>
      _wards.firstWhereOrNull((w) => w.id == _selectedWardId);

  List<BedModel> get availableBedsForAdmitWard =>
      _admitSelectedWard?.availableBedsList ?? [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────
  Future<void> fetchAll({bool silent = false}) async {
    if (!silent) {
      _loadState = InpatientLoadState.loading;
      _errorMessage = '';
      update();
    }

    try {
      final results = await Future.wait([
        _provider.fetchStats(),
        _provider.fetchWards(),
        _provider.fetchAdmissions(),
        _provider.fetchPatients(),
        _provider.fetchDoctors(),
      ]);

      // Stats
      final statsBody = results[0].data as Map<String, dynamic>;
      if (statsBody['success'] == true) {
        _stats = InpatientStats.fromJson(
            statsBody['data'] as Map<String, dynamic>);
      }

      // Wards
      final wardsBody = results[1].data as Map<String, dynamic>;
      if (wardsBody['success'] == true) {
        _wards = (wardsBody['data'] as List<dynamic>)
            .map((w) => WardModel.fromJson(w as Map<String, dynamic>))
            .toList();
        // Default select first active ward
        if (_selectedWardId.isEmpty && activeWards.isNotEmpty) {
          _selectedWardId = activeWards.first.id;
        }
      }

      // Admissions
      final admBody = results[2].data as Map<String, dynamic>;
      if (admBody['success'] == true) {
        _admissions = (admBody['data'] as List<dynamic>)
            .map((a) => AdmissionModel.fromJson(a as Map<String, dynamic>))
            .toList();
      }

      // Patients
      final patientsBody = results[3].data as Map<String, dynamic>;
      if (patientsBody['success'] == true) {
        final dataField = patientsBody['data'];
        List<dynamic> rawList;
        if (dataField is Map) {
          rawList = dataField['data'] as List<dynamic>? ?? [];
        } else {
          rawList = dataField as List<dynamic>? ?? [];
        }
        // Deduplicate by fullName
        final seen = <String>{};
        _patients = rawList
            .map((p) => PatientModel.fromJson(p as Map<String, dynamic>))
            .where((p) => seen.add(p.fullName.toLowerCase()))
            .toList();
      }

      // Doctors
      final docBody = results[4].data as Map<String, dynamic>;
      if (docBody['success'] == true) {
        _doctors = (docBody['data'] as List<dynamic>)
            .map((d) => DoctorModel.fromJson(d as Map<String, dynamic>))
            .toList();
      }

      _loadState = InpatientLoadState.success;
    } on DioException catch (e) {
      _loadState = InpatientLoadState.error;
      _errorMessage = e.message ?? 'Network error. Try again.';
      if (kDebugMode) debugPrint('[InpatientController] DioException: $e');
    } catch (e) {
      _loadState = InpatientLoadState.error;
      _errorMessage = 'Something went wrong. Try again.';
      if (kDebugMode) debugPrint('[InpatientController] Error: $e');
    }

    update();
  }

  Future<void> onRefresh() async {
    _isRefreshing = true;
    update();
    await fetchAll(silent: true);
    _isRefreshing = false;
    update();
  }

  // ── Tab ───────────────────────────────────────────────────────────────────
  void setTab(InpatientTab tab) {
    _selectedTab = tab;
    update();
  }

  // ── Wards ─────────────────────────────────────────────────────────────────
  void deactivateWard(String wardId) async {
    try {
      await _provider.deactivateWard(wardId);
      _wards.removeWhere((w) => w.id == wardId);
      // Update stats locally
      // Recompute selected ward
      if (_selectedWardId == wardId) {
        _selectedWardId = activeWards.isNotEmpty ? activeWards.first.id : '';
      }
      update();
      Get.snackbar(
        'Ward Deactivated',
        'Ward has been removed successfully.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      // Optimistic: remove locally even if API fails (as per spec)
      _wards.removeWhere((w) => w.id == wardId);
      if (_selectedWardId == wardId) {
        _selectedWardId = activeWards.isNotEmpty ? activeWards.first.id : '';
      }
      update();
      if (kDebugMode) debugPrint('[InpatientController] deactivateWard: $e');
    }
  }

  Future<void> createWard({
    required String name,
    required String code,
    required String type,
    required int capacity,
  }) async {
    try {
      final res = await _provider.createWard({
        'name': name,
        'code': code,
        'type': type,
        'capacity': capacity,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final newWard = WardModel.fromJson(
            body['data'] as Map<String, dynamic>);
        _wards.insert(0, newWard);
        update();
        Get.back();
        Get.snackbar(
          '✓ Ward Created',
          '"${newWard.name}" added successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.secondary.withValues(alpha: 0.92),
          colorText: AppColors.lightSurface,
          icon: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.lightSurface),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );
        onRefresh();
      }
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[InpatientController] createWard: $e');
      Get.snackbar(
        'Error',
        e.message ?? 'Failed to create ward.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.92),
        colorText: AppColors.lightSurface,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[InpatientController] createWard: $e');
    }
  }

  Future<void> updateWard({
    required String wardId,
    required String name,
    required String code,
    required String type,
    required int capacity,
  }) async {
    try {
      final res = await _provider.updateWard(wardId, {
        'name': name,
        'code': code,
        'type': type,
        'capacity': capacity,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final updated = WardModel.fromJson(
            body['data'] as Map<String, dynamic>);
        final idx = _wards.indexWhere((w) => w.id == wardId);
        if (idx != -1) _wards[idx] = updated;
        update();
        Get.back();
        Get.snackbar(
          '✓ Ward Updated',
          '"${updated.name}" saved successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.secondary.withValues(alpha: 0.92),
          colorText: AppColors.lightSurface,
          icon: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.lightSurface),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );
        onRefresh();
      }
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[InpatientController] updateWard: $e');
      Get.snackbar(
        'Error',
        e.message ?? 'Failed to update ward.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.92),
        colorText: AppColors.lightSurface,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[InpatientController] updateWard: $e');
    }
  }

  // ── Beds Grid ─────────────────────────────────────────────────────────────
  void setSelectedWard(String wardId) {
    _selectedWardId = wardId;
    _selectedBedStatus = 'all';
    update();
  }

  void setSelectedBedStatus(String status) {
    _selectedBedStatus = status;
    update();
  }

  // ── Admission Search/Filter ───────────────────────────────────────────────
  void setAdmissionSearch(String q) {
    _admissionSearch = q;
    update();
  }

  void setAdmissionFilter(String f) {
    _admissionFilter = f;
    update();
  }

  // ── Admit Form ────────────────────────────────────────────────────────────
  void setPatientSearchQuery(String q) {
    _patientSearchQuery = q;
    update();
  }

  void setAdmitPatient(PatientModel? p) {
    _admitSelectedPatient = p;
    _patientSearchQuery = '';
    update();
  }

  void setAdmitWard(WardModel? w) {
    _admitSelectedWard = w;
    _admitSelectedBed = null;
    update();
  }

  void setAdmitBed(BedModel? b) {
    _admitSelectedBed = b;
    update();
  }

  void setAdmitType(String t) {
    _admitType = t;
    update();
  }

  void setAdmittingDoctor(DoctorModel? d) {
    _admittingDoctor = d;
    update();
  }

  void setAttendingDoctor(DoctorModel? d) {
    _attendingDoctor = d;
    update();
  }

  void setAdmissionReason(String r) {
    _admissionReason = r;
    update();
  }

  void resetAdmitForm() {
    _admitSelectedPatient = null;
    _admitSelectedWard = null;
    _admitSelectedBed = null;
    _admitType = 'Routine Admission';
    _admittingDoctor = null;
    _attendingDoctor = null;
    _admissionReason = '';
    _patientSearchQuery = '';
    update();
  }

  bool get canSubmitAdmit =>
      _admitSelectedPatient != null &&
      _admitSelectedWard != null &&
      _admitSelectedBed != null &&
      _admissionReason.trim().isNotEmpty;

  // Validation helper — returns null if valid, error string if not
  String? validateAdmitForm() {
    if (_admitSelectedPatient == null) return 'Please select a patient.';
    if (_admitSelectedWard == null) return 'Please select a ward.';
    if (_admitSelectedBed == null) return 'Please assign a bed.';
    if (_admittingDoctor == null) return 'Please select an admitting doctor.';
    if (_attendingDoctor == null) return 'Please select an attending doctor.';
    if (_admissionReason.trim().isEmpty) {
      return 'Please enter the admission reason.';
    }
    return null;
  }

  Future<void> submitAdmitPatient() async {
    final error = validateAdmitForm();
    if (error != null) {
      Get.snackbar(
        'Incomplete Form',
        error,
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error.withValues(alpha: 0.92),
        colorText: AppColors.lightSurface,
        icon: const Icon(Icons.error_outline_rounded,
            color: AppColors.lightSurface),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
      return;
    }

    try {
      final payload = {
        'patientId': _admitSelectedPatient!.id,
        'bedId': _admitSelectedBed!.id,
        'admissionType': _admitType == 'Routine Admission'
            ? 'routine'
            : _admitType.toLowerCase().replaceAll(' ', '_'),
        'admissionReason': _admissionReason,
        'admittingDoctorId': _admittingDoctor?.id,
        'attendingDoctorId': _attendingDoctor?.id,
      };

      final res = await _provider.admitPatient(payload);
      final body = res.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final newAdmission = AdmissionModel.fromJson(
            body['data'] as Map<String, dynamic>);
        
        // Add to local list immediately
        _admissions.insert(0, newAdmission);

        // Update bed status in the UI model immediately
        _updateBedStatusLocally(
          newAdmission.bedId,
          'occupied',
          patientId: newAdmission.patientId,
          isNewAdmission: true,
        );

        // Show success snackbar and navigate back
        Get.back();
        Get.snackbar(
          '✓ Admission Recorded',
          '${newAdmission.patient.fullName} admitted to ${newAdmission.bed.ward?.name ?? _admitSelectedWard!.name} – ${newAdmission.bed.bedNumber}.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.secondary.withValues(alpha: 0.92),
          colorText: AppColors.lightSurface,
          icon: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.lightSurface),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );

        resetAdmitForm();
        update();
        // Silently sync from backend
        onRefresh();
      } else {
        Get.snackbar(
          'Error',
          body['message'] ?? 'Failed to admit patient.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error.withValues(alpha: 0.92),
          colorText: AppColors.lightSurface,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[InpatientController] submitAdmitPatient DioException: $e');
      }
      Get.snackbar(
        'Error',
        e.message ?? 'Network error. Failed to admit patient.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.92),
        colorText: AppColors.lightSurface,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InpatientController] submitAdmitPatient Error: $e');
      }
      Get.snackbar(
        'Error',
        'Something went wrong. Try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.92),
        colorText: AppColors.lightSurface,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
    }
  }

  Future<void> createBed({
    required String wardId,
    required String bedNumber,
    required String type,
  }) async {
    try {
      final res = await _provider.createBed({
        'wardId': wardId,
        'bedNumber': bedNumber,
        'type': type,
        'status': 'available',
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        Get.back();
        Get.snackbar(
          '✓ Bed Created',
          'Bed "$bedNumber" added successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.secondary.withValues(alpha: 0.92),
          colorText: AppColors.lightSurface,
          icon: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.lightSurface),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppDecorations.radiusMD,
        );
        onRefresh();
      }
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[InpatientController] createBed: $e');
      Get.snackbar(
        'Error',
        e.message ?? 'Failed to create bed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.92),
        colorText: AppColors.lightSurface,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[InpatientController] createBed: $e');
    }
  }

  void _updateBedStatusLocally(String bedId, String status, {String? patientId, bool isNewAdmission = false}) {
    for (var i = 0; i < _wards.length; i++) {
      final ward = _wards[i];
      final bedIndex = ward.beds.indexWhere((b) => b.id == bedId);
      if (bedIndex != -1) {
        final oldBed = ward.beds[bedIndex];
        final newBed = BedModel(
          id: oldBed.id,
          wardId: oldBed.wardId,
          bedNumber: oldBed.bedNumber,
          type: oldBed.type,
          status: status,
          currentPatientId: (status == 'available' || status == 'maintenance')
              ? null
              : (patientId ?? oldBed.currentPatientId),
        );

        final updatedBeds = List<BedModel>.from(ward.beds);
        updatedBeds[bedIndex] = newBed;

        final occupiedCount = updatedBeds.where((b) => b.status == 'occupied').length;
        final availableCount = updatedBeds.where((b) => b.status == 'available').length;
        final occupancyRate = ward.capacity > 0
            ? (occupiedCount / ward.capacity) * 100
            : 0;

        final updatedWard = WardModel(
          id: ward.id,
          name: ward.name,
          code: ward.code,
          type: ward.type,
          capacity: ward.capacity,
          isActive: ward.isActive,
          beds: updatedBeds,
          occupiedBeds: occupiedCount,
          availableBeds: availableCount,
          occupancyRate: occupancyRate,
        );

        _wards[i] = updatedWard;
        break;
      }
    }

    // Also update global statistics
    int totalOccupied = 0;
    int totalAvailable = 0;
    int totalBeds = 0;
    for (var w in _wards) {
      totalOccupied += w.occupiedBeds;
      totalAvailable += w.availableBeds;
      totalBeds += w.capacity;
    }
    final newOccupancyRate = totalBeds > 0
        ? (totalOccupied / totalBeds) * 100
        : 0;

    _stats = InpatientStats(
      totalBeds: totalBeds,
      occupiedBeds: totalOccupied,
      availableBeds: totalAvailable,
      todayAdmissions: _stats.todayAdmissions + (isNewAdmission ? 1 : 0),
      todayDischarges: _stats.todayDischarges,
      occupancyRate: newOccupancyRate,
    );
  }

  Future<void> updateBedStatus(String bedId, String status) async {
    // 1. Immediate local state update for instant UI response
    _updateBedStatusLocally(bedId, status);
    update();

    // 2. Call background API to update server
    try {
      await _provider.updateBed(bedId, {'status': status});
      onRefresh();
    } catch (e) {
      if (kDebugMode) debugPrint('[InpatientController] updateBedStatus: $e');
    }
  }
}
