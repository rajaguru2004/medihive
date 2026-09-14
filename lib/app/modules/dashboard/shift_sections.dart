import 'package:flutter/widgets.dart';

import '../../data/models/access_map.dart';

/// One band on the shift board.
///
/// Not a widget: a description of what this account should be looking at, so
/// the board can be composed from access rather than from a role name. A
/// hospital can define its own roles, and a dashboard that switches on
/// `role == 'NURSE'` is a dashboard that ignores them.
class ShiftSection {
  const ShiftSection({
    required this.id,
    required this.title,
    required this.emptyMessage,
    required this.module,
    required this.route,
    this.icon,
    this.verb = AccessVerb.read,
    this.rank = 50,
    this.needsWrite = false,
  });

  final String id;

  /// What this band is, phrased as the question it answers. "Waiting and
  /// breached", not "Queue" — the tab is already called Queue, and repeating it
  /// tells somebody nothing they did not already know.
  final String title;

  /// What it says when there is nothing in it. An empty band is information:
  /// "Nobody is waiting" is a good shift, and a blank space is a bug.
  final String emptyMessage;

  final String module;
  final AccessVerb verb;

  /// Where tapping the band's header goes.
  final String route;

  final IconData? icon;

  /// Lower comes first. What a role looks at first is not the same as what the
  /// navigation puts first: a doctor's board opens on their own clinic, not on
  /// the queue, even though Queue outranks Clinic in the bar.
  final int rank;

  /// True when merely reading the module is not enough to make the band useful.
  ///
  /// A band offering work somebody cannot do is the dashboard version of a
  /// dead-end shortcut.
  final bool needsWrite;
}

/// Which bands an account gets, and in what order.
abstract final class ShiftSections {
  /// The full catalogue. Order here is the fallback ordering; `rank` is what
  /// actually sorts.
  static List<ShiftSection> catalogue({
    required String queueRoute,
    required String clinicRoute,
    required String wardsRoute,
    required String triageRoute,
    required String labRoute,
    required String imagingRoute,
    required String pharmacyRoute,
    required String billingRoute,
  }) =>
      [
        ShiftSection(
          id: 'waiting',
          title: 'Waiting now',
          emptyMessage: 'Nobody is waiting.',
          module: Modules.queue,
          route: queueRoute,
          rank: 10,
        ),
        ShiftSection(
          id: 'clinic',
          title: 'Still to be seen',
          emptyMessage: 'Everybody booked today has been seen.',
          module: Modules.appointments,
          route: clinicRoute,
          rank: 20,
        ),
        ShiftSection(
          id: 'screenings',
          title: 'Screenings to route',
          emptyMessage: 'Every screening has been routed.',
          module: Modules.preTriage,
          route: triageRoute,
          rank: 15,
          needsWrite: true,
        ),
        ShiftSection(
          id: 'ward',
          title: 'On the ward',
          emptyMessage: 'No live admissions.',
          module: Modules.inpatient,
          route: wardsRoute,
          rank: 25,
        ),
        ShiftSection(
          id: 'lab',
          title: 'Samples and results',
          emptyMessage: 'No lab work outstanding.',
          module: Modules.laboratory,
          route: labRoute,
          rank: 30,
          needsWrite: true,
        ),
        ShiftSection(
          id: 'imaging',
          title: 'Imaging to report',
          emptyMessage: 'No imaging outstanding.',
          module: Modules.radiology,
          route: imagingRoute,
          rank: 35,
          needsWrite: true,
        ),
        ShiftSection(
          id: 'dispense',
          title: 'To dispense',
          emptyMessage: 'No prescriptions waiting.',
          module: Modules.pharmacy,
          route: pharmacyRoute,
          rank: 40,
          needsWrite: true,
        ),
        ShiftSection(
          id: 'unpaid',
          title: 'Unpaid and overdue',
          emptyMessage: 'Nothing outstanding.',
          module: Modules.billing,
          route: billingRoute,
          rank: 45,
        ),
      ];

  /// The bands this account should see, most urgent first.
  ///
  /// Capped at four. A board somebody scans between patients has to answer
  /// "what needs me" in one look; a fifth band is a band nobody reaches, and a
  /// scroll is not a look.
  static List<ShiftSection> forAccess(
    AccessMap access,
    List<ShiftSection> catalogue, {
    int limit = 4,
  }) {
    final visible = catalogue.where((section) {
      if (!access.can(section.module, section.verb)) return false;
      if (!section.needsWrite) return true;
      return access.can(section.module, AccessVerb.create) ||
          access.can(section.module, AccessVerb.update);
    }).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return visible.take(limit).toList();
  }
}
