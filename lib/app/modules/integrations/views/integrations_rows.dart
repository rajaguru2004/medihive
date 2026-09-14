import 'package:flutter/material.dart';

import '../../../core/keys/integrations_keys.dart';
import '../../../data/models/json.dart';
import '../../../data/models/machine_integration.dart';
import '../../../data/models/results_queue_item.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../device_status.dart';

/// One device on the board.
///
/// Name, kind, and where the link stands — **as a word beside its tint**, never
/// as a tint alone. Colour by itself fails three readers at once: somebody
/// colour-blind, somebody reading a printed copy of this board, and somebody
/// standing far enough away to see a colour but not resolve it.
class DeviceRow extends StatelessWidget {
  const DeviceRow({super.key, required this.machine, this.onTap});

  final MachineIntegration machine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final link = DeviceLink.of(machine);

    final facts = [
      DeviceKind.labelOf(machine.machineType),
      connectionLabel(machine.connectionType),
      if (machine.address.isNotEmpty) machine.address,
      if ((machine.department ?? '').isNotEmpty)
        Formatters.label(machine.department),
    ].join(' · ');

    return BentoRow(
      title: machine.displayName,
      subtitle: facts,
      icon: DeviceKind.iconOf(machine.machineType),
      // The kind is a **category**, so it gets one neutral tint and the word
      // carries it. Tinting it by link state would give the row two colours
      // saying the same thing, and a reader no way to tell which is which.
      iconColor: AppColors.acuityRoutine,
      onTap: onTap,
      showChevron: onTap != null,
      trailing: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusPill(
              key: IntegrationsKeys.deviceState(machine.id),
              status: machine.connectionStatus,
              color: link.color,
              label: link.label,
              icon: link.icon,
              compact: true,
            ),
            const SizedBox(height: 4),
            Text(
              lastHeardFrom(machine),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: isDark
                  ? AppTextStyles.darkCaption2()
                  : AppTextStyles.lightCaption2(),
            ),
            if ((machine.queuedResults ?? 0) > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${machine.queuedResults} waiting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppFonts.text(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: semanticInk(context, AppColors.acuityStandard),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// When this machine last said anything.
///
/// A connection and a result are two different kinds of contact and the later
/// of them is what "last heard from" means — a machine that posted results an
/// hour ago is talking, whatever its last handshake says.
///
/// Named in words rather than left as `Formatters.elapsed`'s em dash: a device
/// that has never called in is a device somebody has to go and look at, and a
/// dash reads as a rendering fault.
String lastHeardFrom(MachineIntegration machine) {
  final connected = machine.lastConnectedAt;
  final received = machine.lastResultReceivedAt;
  final latest = switch ((connected, received)) {
    (null, null) => null,
    (final DateTime a, null) => a,
    (null, final DateTime b) => b,
    (final DateTime a, final DateTime b) => a.isAfter(b) ? a : b,
  };
  return latest == null ? 'Never called in' : '${Formatters.elapsed(latest)} ago';
}

/// One result waiting on the queue.
///
/// What came in, who it is for — or the word **Unmatched**, because a blank
/// there reads as a rendering fault rather than as a sample nobody could put a
/// name to — and when.
class QueueRow extends StatelessWidget {
  const QueueRow({super.key, required this.row});

  final ResultsQueueItem row;

  @override
  Widget build(BuildContext context) {
    final facts = [
      queueSubject(row),
      if (row.machineName.isNotEmpty) row.machineName,
      Formatters.elapsed(row.receivedAt),
    ].join(' · ');

    return BentoRow(
      title: analyteSummary(row),
      subtitle: facts,
      subtitleMaxLines: 2,
      trailing: StatusPill(
        status: row.status,
        color: QueueState.colorOf(row.status),
        label: QueueState.labelOf(row.status),
        icon: QueueState.iconOf(row.status),
        compact: true,
      ),
    );
  }
}

/// What actually arrived, in the analyser's own words.
///
/// The test name where the instrument sent one and its code where it did not —
/// a code is what is printed on the analyser's own report, so it is never
/// nothing. Capped at three because a haematology profile is twenty and a row
/// is one line.
String analyteSummary(ResultsQueueItem row) {
  final names = <String>[
    for (final result in row.testResults)
      asString(
        result['testName'] ?? result['name'],
        fallback: asString(result['testCode'] ?? result['code']),
      ),
  ].where((name) => name.isNotEmpty).toList();

  if (names.isEmpty) {
    return row.resultCount == 1 ? '1 result' : '${row.resultCount} results';
  }
  if (names.length <= 3) return names.join(', ');
  return '${names.take(3).join(', ')} and ${names.length - 3} more';
}
