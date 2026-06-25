// lib/app/modules/queue/controllers/queue_controller.dart

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../models/queue_model.dart';
import '../providers/queue_provider.dart';

enum QueueLoadState { idle, loading, success, error }

enum QueueViewTab { live, history }

class QueueController extends GetxController {
  final _provider = QueueProvider();

  // ── State ─────────────────────────────────────────────────────────────────
  QueueLoadState _loadState = QueueLoadState.idle;
  String _errorMessage = '';

  List<QueueModel> _allItems = [];
  List<QueueModel> _historyItems = [];

  QueueViewTab _viewTab = QueueViewTab.live;
  String _selectedArea = ''; // '' = all areas
  String _selectedPriority = ''; // '' = all priorities

  bool _isHistoryLoading = false;

  // Patient dropdown for Add to Queue
  List<PatientOption> _patients = [];
  bool _isPatientsLoading = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  QueueLoadState get loadState => _loadState;
  bool get isLoading => _loadState == QueueLoadState.loading;
  bool get hasError => _loadState == QueueLoadState.error;
  bool get hasData => _loadState == QueueLoadState.success;
  String get errorMessage => _errorMessage;

  QueueViewTab get viewTab => _viewTab;
  String get selectedArea => _selectedArea;
  String get selectedPriority => _selectedPriority;
  bool get isHistoryLoading => _isHistoryLoading;

  List<PatientOption> get patients => _patients;
  bool get isPatientsLoading => _isPatientsLoading;

  /// All live items
  List<QueueModel> get allItems => List.unmodifiable(_allItems);

  /// History items
  List<QueueModel> get historyItems => List.unmodifiable(_historyItems);

  /// Filtered live items by area + priority
  List<QueueModel> get filteredItems {
    var list = _allItems.toList();
    if (_selectedArea.isNotEmpty) {
      list = list.where((q) => q.serviceArea == _selectedArea).toList();
    }
    if (_selectedPriority.isNotEmpty) {
      list = list.where((q) => q.priority == _selectedPriority).toList();
    }
    return list;
  }

  /// Filtered history by area + priority
  List<QueueModel> get filteredHistory {
    var list = _historyItems.toList();
    if (_selectedArea.isNotEmpty) {
      list = list.where((q) => q.serviceArea == _selectedArea).toList();
    }
    if (_selectedPriority.isNotEmpty) {
      list = list.where((q) => q.priority == _selectedPriority).toList();
    }
    return list;
  }

  /// Summary based on all items
  QueueSummary get summary => QueueSummary.fromList(_allItems);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchQueue();
    fetchPatients();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────
  Future<void> fetchQueue() async {
    _loadState = QueueLoadState.loading;
    _errorMessage = '';
    update();

    try {
      final response = await _provider.fetchQueue(limit: 100);
      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final parsed = QueueResponse.fromJson(body);
        _allItems = parsed.data;
        _loadState = QueueLoadState.success;
      } else {
        _loadState = QueueLoadState.error;
        _errorMessage = body['message'] as String? ?? 'Unknown error';
      }
    } on DioException catch (e) {
      _loadState = QueueLoadState.error;
      _errorMessage = e.message ?? 'Network error. Please try again.';
      if (kDebugMode) debugPrint('[QueueController] DioException: $e');
    } catch (e) {
      _loadState = QueueLoadState.error;
      _errorMessage = 'Something went wrong. Please try again.';
      if (kDebugMode) debugPrint('[QueueController] Error: $e');
    }

    update();
  }

  Future<void> fetchHistory() async {
    _isHistoryLoading = true;
    _historyItems = [];
    update();

    try {
      final response = await _provider.fetchHistory(limit: 100);
      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final parsed = QueueResponse.fromJson(body);
        _historyItems = parsed.data;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QueueController] fetchHistory error: $e');
      }
    } finally {
      _isHistoryLoading = false;
      update();
    }
  }

  Future<void> fetchPatients() async {
    _isPatientsLoading = true;
    update();
    try {
      final response = await _provider.fetchPatients();
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final outer = body['data'] as Map<String, dynamic>? ?? body;
        final dataList = outer['data'] as List<dynamic>? ?? [];
        _patients = dataList
            .map((e) => PatientOption.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[QueueController] fetchPatients error: $e');
    } finally {
      _isPatientsLoading = false;
      update();
    }
  }

  Future<void> onRefresh() async {
    await fetchQueue();
    if (_viewTab == QueueViewTab.history) {
      await fetchHistory();
    }
  }

  // ── Tab & Filter ──────────────────────────────────────────────────────────
  void setViewTab(QueueViewTab tab) {
    _viewTab = tab;
    if (tab == QueueViewTab.history && _historyItems.isEmpty) {
      fetchHistory();
    }
    update();
  }

  void setServiceArea(String area) {
    _selectedArea = area;
    update();
  }

  void setPriority(String priority) {
    _selectedPriority = priority;
    update();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Call Next — finds first waiting item and calls it
  Future<void> callNext() async {
    final waiting = _allItems.where((q) => q.status == 'waiting').toList();
    if (_selectedArea.isNotEmpty) {
      final areaWaiting =
          waiting.where((q) => q.serviceArea == _selectedArea).toList();
      if (areaWaiting.isNotEmpty) {
        await _callItem(areaWaiting.first);
        return;
      }
    }
    if (waiting.isNotEmpty) {
      await _callItem(waiting.first);
    } else {
      Get.snackbar(
        'No Patients',
        'No waiting patients in queue',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _callItem(QueueModel item) async {
    try {
      await _provider.updateQueueStatus(item.id, 'called');
      await fetchQueue();
      Get.snackbar(
        '✓ Called',
        '${item.patient.fullName} (${item.queueNumber}) has been called',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to call patient',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> callPatient(QueueModel item) async {
    await _callItem(item);
  }

  Future<void> cancelPatient(QueueModel item) async {
    try {
      await _provider.updateQueueStatus(item.id, 'cancelled');
      await fetchQueue();
      Get.snackbar(
        '✓ Cancelled',
        'Queue entry for ${item.patient.fullName} cancelled',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> startService(QueueModel item) async {
    try {
      await _provider.updateQueueStatus(item.id, 'in_service');
      await fetchQueue();
      Get.snackbar(
        '✓ Service Started',
        'Service started for ${item.patient.fullName}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to start service',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> markNoShow(QueueModel item) async {
    try {
      await _provider.updateQueueStatus(item.id, 'no_show');
      await fetchQueue();
      Get.snackbar(
        '✓ Marked No-Show',
        '${item.patient.fullName} marked as No-Show',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to mark no-show',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> markComplete(QueueModel item) async {
    try {
      await _provider.updateQueueStatus(item.id, 'completed');
      await fetchQueue();
      Get.snackbar(
        '✓ Completed',
        'Service completed for ${item.patient.fullName}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to complete service',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> removeFromQueue(QueueModel item) async {
    try {
      await _provider.deleteQueue(item.id);
      _allItems.removeWhere((q) => q.id == item.id);
      update();
      Get.snackbar(
        '✓ Removed',
        '${item.patient.fullName} removed from queue',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to remove from queue',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool> addToQueue({
    required String patientId,
    required String serviceArea,
    String? serviceType,
    required String priority,
    String? assignedRoom,
  }) async {
    try {
      final body = <String, dynamic>{
        'patientId': patientId,
        'serviceArea': serviceArea,
        'priority': priority,
      };
      if (serviceType != null && serviceType.isNotEmpty) {
        body['serviceType'] = serviceType;
      }
      if (assignedRoom != null && assignedRoom.isNotEmpty) {
        body['assignedRoom'] = assignedRoom;
      }

      await _provider.createQueue(body);
      await fetchQueue();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[QueueController] addToQueue error: $e');
      return false;
    }
  }
}
