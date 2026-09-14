import 'package:flutter/widgets.dart';

/// Widget keys for one consultation's record.
abstract final class ConsultationDetailKeys {
  static const screen = Key('consultation_detail_screen');
  static const error = Key('consultation_detail_error');
  static const missing = Key('consultation_detail_missing');

  static const vitals = Key('consultation_detail_vitals');

  /// The sentence over the vitals grid. The form warns in words as the reading
  /// is typed; this is the same warning on the record that opens afterwards,
  /// keyed so a flow can prove the two screens agree.
  static const vitalsFlag = Key('consultation_detail_vitals_flag');

  static const notes = Key('consultation_detail_notes');
  static const diagnosis = Key('consultation_detail_diagnosis');
  static const prescription = Key('consultation_detail_prescription');
  static const labOrders = Key('consultation_detail_lab_orders');
  static const radiologyOrders = Key('consultation_detail_radiology_orders');

  static const edit = Key('consultation_detail_edit');
  static const delete = Key('consultation_detail_delete');
  static const deleteConfirm = Key('consultation_detail_delete_confirm');
  static const orderLab = Key('consultation_detail_order_lab');
  static const orderImaging = Key('consultation_detail_order_imaging');
  static const newInvoice = Key('consultation_detail_new_invoice');

  /// Shown instead of the actions when this account may only read.
  static const noActions = Key('consultation_detail_no_actions');
}
