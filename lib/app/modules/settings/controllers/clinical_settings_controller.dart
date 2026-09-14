import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../data/models/drafts/drafts.dart';
import '../../../data/services/settings_service.dart';
import 'settings_form_controller.dart';

/// The settings that change how a clinical screen behaves.
///
/// Every one of these has a visible consequence on a board somebody is reading,
/// which is why they are worded on the screen as what they do rather than as
/// what they are called in the database.
class ClinicalSettingsController extends SettingsFormController {
  static ClinicalSettingsController get to =>
      Get.find<ClinicalSettingsController>();

  /// The triage vocabularies the backend accepts.
  static const triageScales = ['p1-p5', 'esi', 'mts', 'colour'];

  static String triageScaleLabel(String id) => switch (id) {
        'p1-p5' => 'P1 to P5',
        'esi' => 'ESI (1 to 5)',
        'mts' => 'Manchester (colours)',
        'colour' => 'Colour only',
        _ => id,
      };

  /// Text controllers, because the kit's `QuantityField` is a text field with
  /// two buttons — the keyboard has to stay reachable for somebody entering
  /// 45 rather than pressing step nine times.
  final waitBreach = TextEditingController();
  final sessionLock = TextEditingController();

  final _waitBreach = 30.obs;
  final _triageScale = 'p1-p5'.obs;
  final _showNames = true.obs;
  final _sessionLock = 5.obs;

  int get waitBreachMinutes => _waitBreach.value;
  String get triageScale => _triageScale.value;
  bool get showPatientNames => _showNames.value;
  int get sessionLockMinutes => _sessionLock.value;

  late int _initialWait;
  late String _initialScale;
  late bool _initialShowNames;
  late int _initialLock;

  @override
  void onInit() {
    super.onInit();
    final s = SettingsService.to.settings;
    _initialWait = s.waitBreachMinutes;
    _initialScale = s.triageScale;
    _initialShowNames = s.showPatientNames;
    _initialLock = s.sessionLockMinutes;
    _waitBreach.value = _initialWait;
    _triageScale.value = _initialScale;
    _showNames.value = _initialShowNames;
    _sessionLock.value = _initialLock;

    waitBreach.text = '$_initialWait';
    sessionLock.text = '$_initialLock';
    waitBreach.addListener(
      () => _waitBreach.value = _minutes(waitBreach.text, 720),
    );
    sessionLock.addListener(
      () => _sessionLock.value = _minutes(sessionLock.text, 60),
    );
  }

  /// Parses a typed value into a usable number of minutes.
  ///
  /// An empty field reads as zero rather than as "unchanged": zero is a real
  /// setting on both of these — never flag a wait, never lock — and treating a
  /// cleared field as no-change would make it impossible to turn either off by
  /// deleting the number.
  int _minutes(String raw, int max) {
    final value = int.tryParse(raw.trim());
    if (value == null) return 0;
    return value.clamp(0, max);
  }

  @override
  void onClose() {
    waitBreach.dispose();
    sessionLock.dispose();
    super.onClose();
  }

  void setTriageScale(String id) => _triageScale.value = id;
  void setShowNames(bool value) => _showNames.value = value;

  @override
  bool get isDirty =>
      _waitBreach.value != _initialWait ||
      _triageScale.value != _initialScale ||
      _showNames.value != _initialShowNames ||
      _sessionLock.value != _initialLock;

  @override
  OrganizationSettingsDraft buildDraft() => OrganizationSettingsDraft(
        waitBreachMinutes: _waitBreach.value,
        triageScale: _triageScale.value,
        showPatientNames: _showNames.value,
        sessionLockMinutes: _sessionLock.value,
      );

  @override
  void onSaved() {
    _initialWait = _waitBreach.value;
    _initialScale = _triageScale.value;
    _initialShowNames = _showNames.value;
    _initialLock = _sessionLock.value;
  }

  /// What the wait-breach field is doing, in words.
  ///
  /// Zero is a setting, not a blank, and the screen has to say so — otherwise
  /// it reads as a field somebody forgot to fill in.
  String get waitBreachHelper => _waitBreach.value == 0
      ? 'Waits are never flagged.'
      : 'A patient waiting longer than this is flagged on the board.';

  String get sessionLockHelper => _sessionLock.value == 0
      ? 'The device never locks on its own.'
      : 'The session stays; the screen goes behind a password. Signing out is '
          'still a separate action.';
}
