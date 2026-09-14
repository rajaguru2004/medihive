import 'package:flutter/widgets.dart';

/// Widget keys for the instrument link: the hub's three segments and the device
/// form.
///
/// One file for two screens because they are two views of one device — an
/// analyser named on the board must be the same analyser on the form that edits
/// it. A parallel set per module is how two views of one record drift until a
/// test passes against a screen nobody sees.
///
/// `machine_form_keys.dart` is the anchor that module directory needs; every
/// name it carries is one of these.
abstract final class IntegrationsKeys {
  // ── The hub ───────────────────────────────────────────────────────────────
  static const screen = Key('integrations_screen');
  static const segmented = Key('integrations_segmented');
  static const error = Key('integrations_error');

  /// The hub with nothing on it because this account may not read
  /// integrations. Its own key, because "no devices" and "not your module" are
  /// different answers and a test must not accept one for the other.
  static const locked = Key('integrations_locked');

  static Key segment(String name) => Key('integrations_segment_$name');

  // ── Devices ───────────────────────────────────────────────────────────────
  static const deviceList = Key('integrations_device_list');
  static const deviceEmpty = Key('integrations_device_empty');
  static const deviceFilters = Key('integrations_device_filters');

  /// Register a device. The pushed header carries it, and so does the body when
  /// this screen is a shell tab — never both at once, or a test cannot say
  /// which of the two it tapped.
  static const deviceAdd = Key('integrations_device_add');

  static Key device(String id) => Key('integrations_device_$id');

  /// The pill on one device's row. Keyed per device so a flow can read the
  /// word as well as see the tint.
  static Key deviceState(String id) => Key('integrations_device_state_$id');

  static Key deviceFilter(String status) =>
      Key('integrations_device_filter_$status');

  // ── Results queue ─────────────────────────────────────────────────────────
  static const queueList = Key('integrations_queue_list');
  static const queueEmpty = Key('integrations_queue_empty');
  static const queueFilters = Key('integrations_queue_filters');

  static Key queueRow(String id) => Key('integrations_queue_row_$id');

  static Key queueFilter(String status) =>
      Key('integrations_queue_filter_$status');

  // ── Upload ────────────────────────────────────────────────────────────────
  static const uploadCard = Key('integrations_upload_card');
  static const uploadPick = Key('integrations_upload_pick');
  static const uploadChosen = Key('integrations_upload_chosen');
  static const uploadClear = Key('integrations_upload_clear');
  static const uploadDevice = Key('integrations_upload_device');
  static const uploadSend = Key('integrations_upload_send');
  static const uploadProgress = Key('integrations_upload_progress');

  /// The failure, inline and persistent. Never a toast: the chosen file is
  /// still on screen and the retry is attached to this.
  static const uploadError = Key('integrations_upload_error');

  static const uploadSummary = Key('integrations_upload_summary');

  /// Shown instead of the picker when this account may not import results.
  static const uploadLocked = Key('integrations_upload_locked');

  // ── Device form ───────────────────────────────────────────────────────────
  static const machineForm = Key('machine_form_screen');
  static const machineName = Key('machine_form_name');
  static const machineType = Key('machine_form_type');
  static const machineConnection = Key('machine_form_connection');
  static const machineManufacturer = Key('machine_form_manufacturer');
  static const machineModel = Key('machine_form_model');
  static const machineSerial = Key('machine_form_serial');
  static const machineDepartment = Key('machine_form_department');
  static const machineHost = Key('machine_form_host');
  static const machinePort = Key('machine_form_port');
  static const machineActive = Key('machine_form_active');
  static const machineSave = Key('machine_form_save');
  static const machineFormError = Key('machine_form_error');

  /// Only on an edit. Absent — not disabled — for an account that may not
  /// remove a device.
  static const machineDelete = Key('machine_form_delete');
  static const machineDeleteConfirm = Key('machine_form_delete_confirm');

  /// The pair a device cannot change after it is registered. Shown as facts
  /// rather than as fields, because `UpdateMachineDto` declares neither and a
  /// picker that 400s is worse than a sentence saying why.
  static const machineFixed = Key('machine_form_fixed');
}
