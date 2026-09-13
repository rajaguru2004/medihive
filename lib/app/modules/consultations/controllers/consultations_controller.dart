import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../../data/models/consultation_model.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/queue_item.dart';
import '../../../data/services/consultation_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// Consultations: the record of what happened in a room.
///
/// Paginated, because unlike a queue or a ward board this list only grows —
/// a department a year old has thousands of them, and a screen that fetches
/// all of them is a screen that stops opening.
class ConsultationsController extends GetxController with LoadStateMixin {
  static ConsultationsController get to => Get.find<ConsultationsController>();

  final _service = ConsultationService.to;

  final consultations = <ConsultationModel>[].obs;
  final waiting = <QueueItem>[].obs;
  final doctors = <DoctorModel>[].obs;

  final query = ''.obs;
  final onDate = Rxn<DateTime>();
  final doctor = Rxn<DoctorModel>();

  final isLoadingMore = false.obs;
  final hasMore = true.obs;

  final scrollController = ScrollController();

  /// Counts by visit type, from the server rather than from the page on
  /// screen — a count derived from ten loaded rows is a count that changes
  /// every time somebody scrolls.
  final totals = <String, int>{}.obs;

  static const _pageSize = 10;
  int _page = 1;
  Timer? _searchDebounce;

  int get totalVisits => totals['total'] ?? 0;
  int get outpatientCount => totals['outpatient'] ?? 0;
  int get emergencyCount => totals['emergency'] ?? 0;
  int get followUpCount => totals['followup'] ?? 0;

  bool get isFiltered =>
      query.value.trim().isNotEmpty || onDate.value != null || doctor.value != null;

  @override
  void onReady() {
    super.onReady();
    scrollController.addListener(_onScroll);
    load();
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick('consultations'), (_) {
        if (!isLoading) load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          _page = 1;
          hasMore.value = true;

          final results = await Future.wait([
            _fetchPage(1),
            _service.getWaitingQueue(),
            _service.getDoctors(),
          ]);

          consultations.assignAll(results[0] as List<ConsultationModel>);

          waiting.assignAll(
            envelopeRows((results[1] as dynamic).data)
                .map(QueueItem.fromJson)
                .toList(),
          );
          doctors.assignAll(
            envelopeRows((results[2] as dynamic).data)
                .map(DoctorModel.fromJson)
                .toList(),
          );

          // Statistics last and unguarded: they are a nicety, and a failure
          // here must not blank a list that loaded perfectly well.
          try {
            totals.assignAll(await _service.getStatistics());
          } catch (_) {
            totals.clear();
          }
        },
        fallback: "Couldn't load consultations.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || isLoading) return;
    isLoadingMore.value = true;
    try {
      final next = await _fetchPage(_page + 1);
      if (next.isEmpty) {
        hasMore.value = false;
      } else {
        _page++;
        consultations.addAll(next);
        // A short page is the last page. Waiting for an empty one costs an
        // extra round trip at the bottom of every list.
        if (next.length < _pageSize) hasMore.value = false;
      }
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't load more consultations."),
        tone: ToastTone.failure,
      );
    } finally {
      isLoadingMore.value = false;
    }
  }

  void search(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      query.value = text;
      load(silent: true);
    });
  }

  void filterByDate(DateTime? date) {
    onDate.value = date;
    load(silent: true);
  }

  void filterByDoctor(DoctorModel? value) {
    doctor.value = value;
    load(silent: true);
  }

  void clearFilters() {
    query.value = '';
    onDate.value = null;
    doctor.value = null;
    load(silent: true);
  }

  Future<List<ConsultationModel>> _fetchPage(int page) async {
    final date = onDate.value;
    final response = await _service.getConsultations(
      page: page,
      limit: _pageSize,
      search: query.value.trim().isEmpty ? null : query.value.trim(),
      // ISO date only — the API filters on the calendar day, and sending a
      // timestamp matches nothing.
      date: date == null
          ? null
          : '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}',
      doctorId: doctor.value?.id,
    );
    return envelopeRows(response.data)
        .map(ConsultationModel.fromJson)
        .toList();
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    // 400 px of runway, so the next page is usually there by the time the
    // reader reaches the bottom rather than after it.
    if (position.pixels >= position.maxScrollExtent - 400) loadMore();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }
}
