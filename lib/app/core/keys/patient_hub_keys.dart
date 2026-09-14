import 'package:flutter/widgets.dart';

/// Widget keys for the patient hub.
///
/// Every tab gets three of them — the tab control, the body it selects, and
/// the locked panel it shows when this account may not read that module —
/// because the whole point of the hub is that those states are **per tab**,
/// and a flow that cannot name one tab's refusal cannot prove the other six
/// still work.
abstract final class PatientHubKeys {
  static const screen = Key('patient_hub_screen');
  static const band = Key('patient_hub_band');
  static const tabs = Key('patient_hub_tabs');
  static const error = Key('patient_hub_error');
  static const quickActions = Key('patient_hub_quick_actions');

  /// The allergy warning on the summary. Words, not only a colour.
  static const allergyNotice = Key('patient_hub_allergy_notice');

  /// The out-of-range warning above the vitals grid, in words.
  static const vitalsNotice = Key('patient_hub_vitals_notice');

  /// The critical-result warning above the results list, in words.
  static const criticalNotice = Key('patient_hub_critical_notice');

  static Key tab(String name) => Key('patient_hub_tab_$name');
  static Key body(String name) => Key('patient_hub_body_$name');
  static Key noAccess(String name) => Key('patient_hub_no_access_$name');
  static Key tabError(String name) => Key('patient_hub_error_$name');
  static Key tabEmpty(String name) => Key('patient_hub_empty_$name');
  static Key row(String name, String id) => Key('patient_hub_${name}_$id');

  /// A gated quick action, by the verb it performs.
  static Key action(String name) => Key('patient_hub_action_$name');
}
