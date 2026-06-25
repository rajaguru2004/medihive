// lib/app/modules/appointments/controllers/appointment_create_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../models/appointment_create_model.dart';
import '../providers/appointments_provider.dart';
import 'appointments_controller.dart';

class AppointmentCreateController extends GetxController {
  final _provider = AppointmentsProvider();

  // ── Form key ───────────────────────────────────────────────────────────────
  final formKey = GlobalKey<FormState>();

  // ── Loading states ─────────────────────────────────────────────────────────
  bool _patientsLoading = false;
  bool _doctorsLoading = false;
  bool _submitting = false;

  bool get patientsLoading => _patientsLoading;
  bool get doctorsLoading => _doctorsLoading;
  bool get submitting => _submitting;
  bool get isDropdownsLoading => _patientsLoading || _doctorsLoading;

  // ── Data ───────────────────────────────────────────────────────────────────
  List<PatientListItem> _patients = [];
  List<DoctorListItem> _doctors = [];

  List<PatientListItem> get patients => _patients;
  List<DoctorListItem> get doctors => _doctors;

  List<PatientListItem> get filteredPatients {
    final query = patientSearchCtrl.text.trim().toLowerCase();
    final list = _patients.where((p) {
      if (query.isEmpty) return true;
      return p.fullName.toLowerCase().contains(query);
    }).toList();
    if (_selectedPatient != null && !list.contains(_selectedPatient)) {
      list.insert(0, _selectedPatient!);
    }
    return list;
  }

  // ── Selected values ────────────────────────────────────────────────────────
  PatientListItem? _selectedPatient;
  DoctorListItem? _selectedDoctor;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime; // "HH:mm" 24h
  int _durationMinutes = 30;
  String _appointmentType = 'new_patient';
  String _priority = 'normal'; // UI-only; API doesn't have this field

  PatientListItem? get selectedPatient => _selectedPatient;
  DoctorListItem? get selectedDoctor => _selectedDoctor;
  DateTime get selectedDate => _selectedDate;
  String? get selectedTime => _selectedTime;
  int get durationMinutes => _durationMinutes;
  String get appointmentType => _appointmentType;
  String get priority => _priority;

  // ── Text controllers ───────────────────────────────────────────────────────
  final chiefComplaintCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final patientSearchCtrl = TextEditingController();

  // ── Time slots ─────────────────────────────────────────────────────────────
  /// Generates slots 08:00–16:45 every 15 min (24-hour "HH:mm" values).
  static List<String> get timeSlots {
    final slots = <String>[];
    for (var h = 8; h <= 16; h++) {
      for (var m = 0; m < 60; m += 15) {
        if (h == 16 && m > 45) break;
        slots.add(
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
        );
      }
    }
    return slots;
  }

  /// Formats a 24h "HH:mm" string into "hh:mm AM/PM".
  static String formatTimeSlot(String slot) {
    final parts = slot.split(':');
    final h = int.parse(parts[0]);
    final m = parts[1];
    final period = h < 12 ? 'AM' : 'PM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:$m $period';
  }

  // ── Appointment type options ───────────────────────────────────────────────
  static const appointmentTypes = [
    _Option('new_patient', 'New Patient'),
    _Option('follow_up', 'Follow-up'),
    _Option('emergency', 'Emergency'),
  ];

  static const durationOptions = [
    _IntOption(30, '00:30'),
    _IntOption(45, '00:45'),
    _IntOption(60, '01:00'),
  ];

  static const priorityOptions = [
    _Option('normal', 'Normal'),
    _Option('urgent', 'Urgent'),
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    patientSearchCtrl.addListener(() {
      update();
    });
    _loadDropdowns();
  }

  @override
  void onClose() {
    chiefComplaintCtrl.dispose();
    notesCtrl.dispose();
    patientSearchCtrl.dispose();
    super.onClose();
  }

  // ── Load data ──────────────────────────────────────────────────────────────
  Future<void> _loadDropdowns() async {
    await Future.wait([_loadPatients(), _loadDoctors()]);
  }

  Future<void> _loadPatients() async {
    _patientsLoading = true;
    update();
    try {
      final res = await _provider.fetchPatients();
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final outer = body['data'];
        List<dynamic> list;
        if (outer is Map) {
          list = (outer['data'] as List<dynamic>?) ?? [];
        } else if (outer is List) {
          list = outer;
        } else {
          list = [];
        }
        _patients = list
            .map((e) => PatientListItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[CreateCtrl] fetchPatients DioEx: $e');
    } catch (e) {
      if (kDebugMode) debugPrint('[CreateCtrl] fetchPatients err: $e');
    } finally {
      _patientsLoading = false;
      update();
    }
  }

  Future<void> _loadDoctors() async {
    _doctorsLoading = true;
    update();
    try {
      final res = await _provider.fetchDoctors();
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final outer = body['data'];
        List<dynamic> list;
        if (outer is Map) {
          list = (outer['data'] as List<dynamic>?) ?? [];
        } else if (outer is List) {
          list = outer;
        } else {
          list = [];
        }
        _doctors = list
            .map((e) => DoctorListItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[CreateCtrl] fetchDoctors DioEx: $e');
    } catch (e) {
      if (kDebugMode) debugPrint('[CreateCtrl] fetchDoctors err: $e');
    } finally {
      _doctorsLoading = false;
      update();
    }
  }

  // ── Setters ────────────────────────────────────────────────────────────────
  void setPatient(PatientListItem? p) {
    _selectedPatient = p;
    update();
  }

  void setDoctor(DoctorListItem? d) {
    _selectedDoctor = d;
    update();
  }

  void setDate(DateTime date) {
    _selectedDate = date;
    update();
  }

  void setTime(String? t) {
    _selectedTime = t;
    update();
  }

  void setDuration(int? minutes) {
    if (minutes != null) _durationMinutes = minutes;
    update();
  }

  void setAppointmentType(String? type) {
    if (type != null) _appointmentType = type;
    update();
  }

  void setPriority(String? p) {
    if (p != null) _priority = p;
    update();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    // Extra runtime guards (already validated by form but defensive)
    if (_selectedPatient == null) {
      _showError('Please select a patient.');
      return;
    }
    if (_selectedDoctor == null) {
      _showError('Please select a doctor.');
      return;
    }
    if (_selectedTime == null) {
      _showError('Please select an appointment time.');
      return;
    }

    _submitting = true;
    update();

    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final body = CreateAppointmentRequest(
        patientId: _selectedPatient!.id,
        doctorId: _selectedDoctor!.id,
        appointmentDate: dateStr,
        appointmentTime: _selectedTime!,
        durationMinutes: _durationMinutes,
        appointmentType: _appointmentType,
        chiefComplaint: chiefComplaintCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
      ).toJson();

      final res = await _provider.createAppointment(body);
      final resBody = res.data as Map<String, dynamic>;

      if (resBody['success'] == true) {
        // Refresh parent list if controller is in memory
        if (Get.isRegistered<AppointmentsController>()) {
          Get.find<AppointmentsController>().onRefresh();
        }
        Get.back();
        Get.snackbar(
          '✓ Appointment Created',
          'Appointment scheduled successfully.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF30D158),
          colorText: const Color(0xFFFFFFFF),
        );
      } else {
        _showError(resBody['message'] as String? ?? 'Failed to create appointment.');
      }
    } on DioException catch (e) {
      _showError(e.message ?? 'Network error. Please try again.');
      if (kDebugMode) debugPrint('[CreateCtrl] submit DioEx: $e');
    } catch (e) {
      _showError('Something went wrong. Please try again.');
      if (kDebugMode) debugPrint('[CreateCtrl] submit err: $e');
    } finally {
      _submitting = false;
      update();
    }
  }

  void _showError(String msg) {
    Get.snackbar(
      'Error',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFF453A),
      colorText: const Color(0xFFFFFFFF),
      duration: const Duration(seconds: 4),
    );
  }
}

// ── Private option helpers ─────────────────────────────────────────────────────

class _Option {
  final String value;
  final String label;
  const _Option(this.value, this.label);
}

class _IntOption {
  final int value;
  final String label;
  const _IntOption(this.value, this.label);
}
