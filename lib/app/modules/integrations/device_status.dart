import 'package:flutter/material.dart';

import '../../data/models/machine_integration.dart';
import '../../data/models/results_queue_item.dart';
import '../../data/repositories/integrations_repository.dart';
import '../../data/utils/formatters.dart';
import '../../theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the instrument link's own vocabulary
///
/// `CaseStatus` resolves clinical states, and neither of the two vocabularies
/// here is one. A machine is a piece of equipment and a queued result is a
/// message in transit; routed through the acuity ramp both land wrong, and
/// `manual_review` and `lab_analyzer` are not spelled the way that table spells
/// anything, so every row would resolve to the grey fallback and the whole
/// board would become one colour.
///
/// So the three link states, the five queue states and the two enums a device
/// is described by are mapped here, once, and every integrations screen reads
/// them from here. Each carries **colour and rank and word**, never colour
/// alone.
///
/// The rule this file exists to hold: **no red.** Not one state below is
/// `AppColors.error` or `AppColors.acuityCritical`, because red in this app
/// means a deteriorating patient or a fault in the app itself. An analyser that
/// has not phoned home is neither — it is a job for whoever looks after the
/// lab, the same way an unpaid invoice and an empty shelf are. A red row here
/// costs a clinician's scan of a ward board its meaning on a screen that has no
/// patients on it at all.
/// ─────────────────────────────────────────────────────────────────────────────

/// What one device's link looks like and what it is called.
///
/// A value rather than three parallel `switch`es, so a row cannot show the
/// amber of "not connected" beside the word "Connected" — the two come out of
/// the same resolution or not at all.
@immutable
class DeviceLink {
  const DeviceLink._({
    required this.label,
    required this.color,
    required this.icon,
    required this.rank,
    required this.needsAttention,
  });

  /// The word on the pill. Never the stored spelling: an underscore on a pill
  /// has leaked a database convention onto a ward screen.
  final String label;

  final Color color;
  final IconData icon;

  /// Lowest first, and derived from the **state**, not from the colour.
  /// Deriving rank from colour ties any two states that share one, which is how
  /// the triage sort silently fell back to arrival order.
  final int rank;

  /// Whether somebody has to do something about this device.
  final bool needsAttention;

  /// The link as this device actually stands.
  ///
  /// A device switched off is reported as switched off whatever its last
  /// connection state was: "not connected" about a machine somebody
  /// deliberately took out of service is an alarm about a decision.
  static DeviceLink of(MachineIntegration machine) =>
      machine.isActive ? ofStatus(machine.connectionStatus) : switchedOff;

  static DeviceLink ofStatus(String? status) =>
      switch ((status ?? '').trim().toLowerCase()) {
        MachineLink.connected => const DeviceLink._(
            label: 'Connected',
            color: AppColors.acuityStable,
            icon: Icons.link_rounded,
            rank: 3,
            needsAttention: false,
          ),
        // Amber, not red. A machine that is switched on and not talking is a
        // job for the lab's morning, not an emergency.
        MachineLink.disconnected => const DeviceLink._(
            label: 'Not connected',
            color: AppColors.warning,
            icon: Icons.link_off_rounded,
            rank: 1,
            needsAttention: true,
          ),
        // The top of this ladder, and still not red. `acuityUrgent` is the
        // app's "attend to this before the others", which is exactly what a
        // machine reporting a fault is asking for.
        MachineLink.error => const DeviceLink._(
            label: 'Reporting a fault',
            color: AppColors.acuityUrgent,
            icon: Icons.report_problem_outlined,
            rank: 0,
            needsAttention: true,
          ),
        // A state this build has not been taught. Neutral and named, rather
        // than painted with a meaning nobody chose.
        _ => DeviceLink._(
            label: Formatters.label(status),
            color: AppColors.acuityRoutine,
            icon: Icons.help_outline_rounded,
            rank: 2,
            needsAttention: false,
          ),
      };

  /// Taken out of service on purpose.
  static const DeviceLink switchedOff = DeviceLink._(
    label: 'Switched off',
    color: AppColors.acuityDischarged,
    icon: Icons.power_settings_new_rounded,
    rank: 4,
    needsAttention: false,
  );

  /// What the filter row offers, worst first — which is the order somebody
  /// looking after the lab reads them in.
  static const List<String> filterOptions = [
    MachineLink.error,
    MachineLink.disconnected,
    MachineLink.connected,
  ];
}

/// What a queued result's state looks like and what it is called.
///
/// Nothing here is red either. A sample the analyser could not put a name to is
/// an unmatched message, not a patient in trouble — and the whole reason this
/// queue exists is that the app must show one rather than drop it.
abstract final class QueueState {
  static String _key(String? status) => (status ?? '').trim().toLowerCase();

  static Color colorOf(String? status) => switch (_key(status)) {
        ResultsQueueStatus.pending => AppColors.acuityRoutine,
        ResultsQueueStatus.matched => AppColors.acuityStandard,
        ResultsQueueStatus.imported => AppColors.acuityStable,
        // Violet, the app's "waiting on a person", not amber — amber is
        // `warning` and a second opinion is not a warning.
        ResultsQueueStatus.manualReview => AppColors.acuityReview,
        ResultsQueueStatus.failed => AppColors.warning,
        _ => AppColors.acuityRoutine,
      };

  static String labelOf(String? status) => switch (_key(status)) {
        ResultsQueueStatus.pending => 'Waiting',
        ResultsQueueStatus.matched => 'Matched',
        ResultsQueueStatus.imported => 'Imported',
        ResultsQueueStatus.manualReview => 'Needs a person',
        // "Failed" is what the column says and the wrong word for a reader: the
        // import did not fail, the identifier on the sample matched nobody.
        ResultsQueueStatus.failed => 'No patient matched',
        _ => Formatters.label(status),
      };

  static IconData iconOf(String? status) => switch (_key(status)) {
        ResultsQueueStatus.pending => Icons.schedule_rounded,
        ResultsQueueStatus.matched => Icons.person_search_outlined,
        ResultsQueueStatus.imported => Icons.check_circle_rounded,
        ResultsQueueStatus.manualReview => Icons.rule_folder_outlined,
        ResultsQueueStatus.failed => Icons.person_off_outlined,
        _ => Icons.circle_outlined,
      };
}

/// `lab_analyzer` → `Lab analyzer`, and the icon that goes with it.
///
/// A kind is a **category**, not a state, so it gets one neutral tint wherever
/// it is shown and the word carries it. Routed through the acuity ramp,
/// `radiology_equipment` would be painted with an urgency it does not have.
abstract final class DeviceKind {
  static String labelOf(String? type) => switch (
      (type ?? '').trim().toLowerCase()) {
        MachineType.labAnalyzer => 'Lab analyser',
        MachineType.radiologyEquipment => 'Imaging equipment',
        MachineType.vitalSignsMonitor => 'Vitals monitor',
        _ => Formatters.label(type),
      };

  static IconData iconOf(String? type) => switch (
      (type ?? '').trim().toLowerCase()) {
        MachineType.labAnalyzer => Icons.biotech_outlined,
        MachineType.radiologyEquipment => Icons.monitor_heart_outlined,
        MachineType.vitalSignsMonitor => Icons.favorite_outline_rounded,
        _ => Icons.memory_outlined,
      };
}

/// `rest_api` → `REST API`. The three acronyms are set the way the people who
/// wire these machines up say them; anything else goes through `Formatters`.
String connectionLabel(String? type) => switch (
    (type ?? '').trim().toLowerCase()) {
      MachineConnection.hl7 => 'HL7',
      MachineConnection.astm => 'ASTM',
      MachineConnection.restApi => 'REST API',
      MachineConnection.fileUpload => 'File upload',
      MachineConnection.serial => 'Serial',
      _ => Formatters.label(type),
    };

/// What the result is for, in the words a technician would use.
///
/// The queue matches a **patient**, not an order — the analyser identifies a
/// sample by whatever the bench typed onto the tube, and this backend resolves
/// that to a patient or to nothing. So an unmatched row says so in a word
/// rather than showing a blank, which reads as a rendering fault.
String queueSubject(ResultsQueueItem row) =>
    row.isMatched ? row.subjectLabel : 'Unmatched';
