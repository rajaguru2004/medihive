import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../data/models/queue_item.dart';
import '../../../data/services/queue_service.dart';

enum QueueLoadState { idle, loading, success, error }

class QueueController extends GetxController {
  final _queueService = Get.find<QueueService>();

  // ─── Observables ───────────────────────────────────────────────────────────
  final _loadState = QueueLoadState.idle.obs;
  final _errorMessage = ''.obs;

  final liveQueueItems = <QueueItem>[].obs;
  final historyQueueItems = <QueueItem>[].obs;

  // Selected filters
  final selectedServiceArea = 'All Areas'.obs;
  final selectedPriority = 'All Priorities'.obs;
  final activeTab = 'Live Queue'.obs; // 'Live Queue' or 'History'

  // ─── Getters ────────────────────────────────────────────────────────────────
  QueueLoadState get loadState => _loadState.value;
  String get errorMessage => _errorMessage.value;
  bool get isLoading => _loadState.value == QueueLoadState.loading;
  bool get hasError => _loadState.value == QueueLoadState.error;

  // Stats computed from full (unfiltered) lists
  int get waitingCount =>
      liveQueueItems.where((x) => x.status.toLowerCase() == 'waiting').length;
  int get calledCount =>
      liveQueueItems.where((x) => x.status.toLowerCase() == 'called').length;
  int get inServiceCount => liveQueueItems
      .where((x) => x.status.toLowerCase() == 'in_service')
      .length;
  int get completedCount => historyQueueItems
      .where((x) => x.status.toLowerCase() == 'completed')
      .length;

  // Filtered lists for rendering
  List<QueueItem> get displayedQueueItems {
    final list =
        activeTab.value == 'Live Queue' ? liveQueueItems : historyQueueItems;
    return list.where((item) {
      // 1. Service Area filter
      if (selectedServiceArea.value != 'All Areas') {
        final areaVal = _mapServiceArea(selectedServiceArea.value);
        if (item.serviceArea.toLowerCase() != areaVal.toLowerCase()) {
          return false;
        }
      }
      // 2. Priority filter
      if (selectedPriority.value != 'All Priorities') {
        if (item.priority.toLowerCase() !=
            selectedPriority.value.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetchQueueData();
  }

  // ─── API Actions ────────────────────────────────────────────────────────────
  Future<void> fetchQueueData() async {
    _loadState.value = QueueLoadState.loading;
    _errorMessage.value = '';

    try {
      final results = await Future.wait([
        _queueService.fetchQueueItems(statuses: 'waiting,called,in_service'),
        _queueService.fetchQueueItems(statuses: 'completed,cancelled'),
      ]);

      final liveRes = results[0];
      final historyRes = results[1];

      if (liveRes.data != null && liveRes.data['success'] == true) {
        final List<dynamic> list = liveRes.data['data']['data'] ?? [];
        liveQueueItems.assignAll(
            list.map((e) => QueueItem.fromJson(e as Map<String, dynamic>)));
      }

      if (historyRes.data != null && historyRes.data['success'] == true) {
        final List<dynamic> list = historyRes.data['data']['data'] ?? [];
        historyQueueItems.assignAll(
            list.map((e) => QueueItem.fromJson(e as Map<String, dynamic>)));
      }

      _loadState.value = QueueLoadState.success;
    } on DioException catch (e) {
      _loadState.value = QueueLoadState.error;
      _errorMessage.value = e.message ?? 'Network error. Please try again.';
      if (kDebugMode) {
        debugPrint('[QueueController] DioException: ${e.message}');
      }
    } catch (e) {
      _loadState.value = QueueLoadState.error;
      _errorMessage.value = 'Failed to load queue. Please try again.';
      if (kDebugMode) {
        debugPrint('[QueueController] Error: $e');
      }
    }
  }

  /// Refreshes data cleanly
  Future<void> onRefresh() async {
    await fetchQueueData();
  }

  /// Change active tab: Live Queue / History
  void setActiveTab(String tabName) {
    activeTab.value = tabName;
  }

  /// Change active service area filter
  void setServiceAreaFilter(String area) {
    selectedServiceArea.value = area;
  }

  /// Change active priority filter
  void setPriorityFilter(String priority) {
    selectedPriority.value = priority;
  }

  /// Call Next: Find the first patient in 'waiting' status, sorted by priority (Urgent > Normal > Low > Routine)
  /// and joinedQueueAt (FIFO), and mark them as 'called'
  Future<void> callNextPatient() async {
    final waitingList = liveQueueItems
        .where((x) => x.status.toLowerCase() == 'waiting')
        .toList();
    if (waitingList.isEmpty) {
      Get.snackbar(
        'Call Next',
        'No patients waiting in queue.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Sort by priority weight, then by joinedQueueAt
    waitingList.sort((a, b) {
      final pA = _getPriorityWeight(a.priority);
      final pB = _getPriorityWeight(b.priority);
      if (pA != pB) {
        return pB.compareTo(pA); // Descending (higher weight first)
      }
      return a.joinedQueueAt
          .compareTo(b.joinedQueueAt); // Ascending (older first)
    });

    final nextPatient = waitingList.first;
    await updateStatus(nextPatient.id, 'called',
        patientName: nextPatient.patient.fullName);
  }

  /// Updates status of a patient in queue
  Future<void> updateStatus(String id, String status,
      {required String patientName}) async {
    try {
      final res = await _queueService.updateQueueStatus(id, status);
      if (res.statusCode == 200 ||
          res.statusCode == 204 ||
          (res.data is Map && res.data['success'] == true)) {
        final displayStatus = status.replaceAll('_', ' ');
        Get.snackbar(
          'Queue Update',
          '$patientName is now marked as $displayStatus.',
          snackPosition: SnackPosition.BOTTOM,
        );
        await fetchQueueData();
      } else {
        final errorMsg = (res.data is Map) ? res.data['message'] : null;
        Get.snackbar(
          'Queue Update Failed',
          errorMsg ?? 'Could not update patient status.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint('[QueueController] error updating status: $e');
      String msg = 'An unexpected error occurred.';
      if (e is DioException) {
        msg = e.response?.data?['message'] as String? ?? e.message ?? msg;
      }
      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Removes patient completely from queue
  Future<void> removeFromQueue(String id, {required String patientName}) async {
    try {
      final res = await _queueService.deleteQueueItem(id);
      if (res.statusCode == 200 ||
          res.statusCode == 204 ||
          (res.data is Map && res.data['success'] == true)) {
        Get.snackbar(
          'Queue Update',
          '$patientName has been removed from queue.',
          snackPosition: SnackPosition.BOTTOM,
        );
        await fetchQueueData();
      } else {
        final errorMsg = (res.data is Map) ? res.data['message'] : null;
        Get.snackbar(
          'Queue Update Failed',
          errorMsg ?? 'Could not remove patient.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint('[QueueController] error removing from queue: $e');
      String msg = 'An unexpected error occurred.';
      if (e is DioException) {
        msg = e.response?.data?['message'] as String? ?? e.message ?? msg;
      }
      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Call patient action
  Future<void> callPatient(String id, String patientName) async {
    await updateStatus(id, 'called', patientName: patientName);
  }

  /// Start service action
  Future<void> startService(String id, String patientName) async {
    await updateStatus(id, 'in_service', patientName: patientName);
  }

  /// Mark patient as no-show
  Future<void> markNoShow(String id, String patientName) async {
    await updateStatus(id, 'no_show', patientName: patientName);
  }

  /// Mark service as complete
  Future<void> markComplete(String id, String patientName) async {
    await updateStatus(id, 'completed', patientName: patientName);
  }

  /// Cancel queue item
  Future<void> cancelQueueItem(String id, String patientName) async {
    await updateStatus(id, 'cancelled', patientName: patientName);
  }

  /// Delete queue item
  Future<void> deleteQueueItem(String id, String patientName) async {
    await removeFromQueue(id, patientName: patientName);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  int _getPriorityWeight(String p) {
    switch (p.toLowerCase()) {
      case 'urgent':
        return 4;
      case 'normal':
        return 3;
      case 'low':
        return 2;
      case 'routine':
        return 1;
      default:
        return 0;
    }
  }

  String _mapServiceArea(String display) {
    switch (display) {
      case 'OPD':
        return 'opd';
      case 'Emergency':
        return 'emergency';
      case 'MCH':
        return 'mch';
      case 'Psychiatric':
        return 'psychiatric';
      case 'Laboratory':
        return 'laboratory';
      case 'Pharmacy':
        return 'pharmacy';
      case 'Radiology':
        return 'radiology';
      case 'Pediatric':
        return 'pediatric';
      default:
        return display.toLowerCase();
    }
  }
}
