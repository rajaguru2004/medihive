import 'package:flutter/widgets.dart';

/// Widget keys for one booking's detail.
abstract final class AppointmentDetailKeys {
  static const screen = Key('appointment_detail_screen');
  static const error = Key('appointment_detail_error');
  static const missing = Key('appointment_detail_missing');

  /// The band of facts, and the ladder of states under it.
  static const facts = Key('appointment_detail_facts');
  static const timeline = Key('appointment_detail_timeline');

  /// The banner shown instead of actions on a booking that is finished with,
  /// and the one shown when this account may not change it.
  static const closedNotice = Key('appointment_detail_closed');
  static const noAccess = Key('appointment_detail_no_access');

  /// One step along the ladder. Keyed by the status it writes — `confirmed`,
  /// `checked_in`, `in_progress`, `completed`, `no_show` — so a flow naming the
  /// button and a flow asserting the payload use the same word.
  static Key action(String status) => Key('appointment_detail_action_$status');

  static const reschedule = Key('appointment_detail_reschedule');
  static const rescheduleDate = Key('appointment_detail_reschedule_date');
  static const rescheduleTime = Key('appointment_detail_reschedule_time');
  static const rescheduleSave = Key('appointment_detail_reschedule_save');

  static Key rescheduleSlot(String time) =>
      Key('appointment_detail_reschedule_slot_$time');

  static const cancel = Key('appointment_detail_cancel');
  static const cancelReason = Key('appointment_detail_cancel_reason');
  static const cancelSave = Key('appointment_detail_cancel_save');
  static const cancelConfirm = Key('appointment_detail_cancel_confirm');

  static const delete = Key('appointment_detail_delete');
  static const deleteConfirm = Key('appointment_detail_delete_confirm');

  static const edit = Key('appointment_detail_edit');
}
