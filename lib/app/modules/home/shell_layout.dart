import 'package:flutter/widgets.dart';

import '../../data/models/access_map.dart';

/// Where a destination sits in the navigation, and in what company.
///
/// The groups mirror the web console's sidebar, because the two are one product
/// and somebody who learned the console should not have to relearn where things
/// are. Overview is deliberately outside a group: it is the shell's home, not a
/// member of a category.
enum ShellGroup {
  overview,
  clinical,
  diagnostics,
  records,
  operations,
  administration;

  String get label => switch (this) {
        ShellGroup.overview => 'Overview',
        ShellGroup.clinical => 'Clinical',
        ShellGroup.diagnostics => 'Diagnostics',
        ShellGroup.records => 'Records',
        ShellGroup.operations => 'Operations',
        ShellGroup.administration => 'Administration',
      };
}

/// One destination the shell can offer.
///
/// [module] and [verb] are what decide whether this account ever sees it. A
/// destination with a null [module] is unconditional — only Today and More are.
class ShellDestination {
  const ShellDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.body,
    required this.group,
    this.title,
    this.module,
    this.verb = AccessVerb.read,
    this.rank = 50,
    this.register,
  });

  /// The route this tab is also reachable at, so a deep link can open it
  /// directly. Also the tab's key suffix.
  final String route;

  /// What the tab bar says. Kept short: five destinations at 411 dp with the
  /// system text size at 1.3 leaves very little room, and a wrapped tab label
  /// is a tab nobody can read at a glance.
  final String label;

  final IconData icon;
  final IconData activeIcon;

  /// The shell's title while this tab is active. Defaults to [label].
  final String? title;

  final ShellGroup group;

  /// The access-map module this destination belongs to, or null when it is
  /// always available.
  final String? module;

  /// What this account must be able to do in [module] for the destination to
  /// appear. Read, for everything that is a place rather than an action.
  final AccessVerb verb;

  /// Lower wins a bottom-bar slot. Hand-assigned rather than derived from the
  /// list order: the order here is the reading order of the More hub, which is
  /// grouped by category, while the bar wants the busiest screens first.
  final int rank;

  /// Built once, lazily, and kept alive by the shell's `IndexedStack`.
  final Widget Function() body;

  /// Registers this destination's controller.
  ///
  /// Called only for destinations that actually become tabs. A nurse must never
  /// construct a `BillingController`: it would fetch on `onReady` and take a
  /// 403 for a screen she was never shown.
  final void Function()? register;

  bool isVisibleTo(AccessMap access) =>
      module == null || access.can(module!, verb);

  /// True when this account can change something here, not just look at it.
  ///
  /// Used only for ordering: a screen somebody works in earns a bottom-bar slot
  /// over one they merely consult.
  bool isWritableBy(AccessMap access) =>
      module != null &&
      (access.can(module!, AccessVerb.create) ||
          access.can(module!, AccessVerb.update));
}

/// What the shell shows this account.
class ShellLayout {
  const ShellLayout({required this.tabs, required this.more});

  /// The bottom bar's destinations, in order, excluding More.
  final List<ShellDestination> tabs;

  /// Everything else this account can reach, grouped for the More hub.
  final List<ShellDestination> more;

  bool get hasMore => more.isNotEmpty;

  /// Everything this account can reach, bar first then the rest.
  ///
  /// What a rail shows. A rail has no horizontal limit, so hiding destinations
  /// behind a hub there would be inventing the phone's constraint on hardware
  /// that does not share it.
  List<ShellDestination> get everything => [...tabs, ...more];

  /// The destinations grouped in the console's own order, for the More hub and
  /// for the tablet rail.
  Map<ShellGroup, List<ShellDestination>> get moreByGroup {
    final grouped = <ShellGroup, List<ShellDestination>>{};
    for (final destination in more) {
      grouped.putIfAbsent(destination.group, () => []).add(destination);
    }
    return grouped;
  }

  /// How many destinations the bottom bar carries, More included.
  ///
  /// Five is Material's ceiling and this shell uses it, which is what makes
  /// every label's length a constraint rather than a preference: at 411 dp each
  /// slot is about 82 dp, and at the 1.3 text scale a ward tablet is usually
  /// left at, anything past roughly eight characters truncates. That is why the
  /// destination labels are Clinic and Wards rather than Appointments and
  /// Inpatient.
  ///
  /// One of the five is always More once anything is left over — it is the only
  /// route to whatever did not fit, so it cannot be the thing that does not
  /// fit.
  static const int barSlots = 5;

  /// Resolves the navigation for one account.
  ///
  /// Derived from the server's access map, never from the role name. Roles are
  /// customisable in this product — a hospital can define TRIAGE_NURSE with
  /// patient-creation rights — so a shell that switches on `role == 'NURSE'` is
  /// a shell that breaks the first time somebody uses that feature.
  ///
  /// [modulesEnabled] hides a module the site has switched **explicitly off**.
  /// An absent key means on: the backend's own default has `inpatient: false`,
  /// and treating a missing key as off would hide the ward board from every
  /// site that never opened the settings screen.
  static ShellLayout resolve({
    required AccessMap access,
    required List<ShellDestination> destinations,
    Map<String, dynamic> modulesEnabled = const {},
  }) {
    bool siteEnabled(ShellDestination d) {
      final module = d.module;
      if (module == null) return true;
      final flag = modulesEnabled[module];
      return flag is! bool || flag;
    }

    final available = destinations
        .where((d) => d.isVisibleTo(access) && siteEnabled(d))
        .toList();

    // Today is the shell's home and always leads, whatever else is available.
    final home = available.where((d) => d.module == null).toList();
    final rest = available.where((d) => d.module != null).toList()
      ..sort((a, b) {
        // A screen this account works in outranks one they only read, then
        // rank breaks the tie. A pharmacist's Pharmacy tab should not lose its
        // slot to a Patients tab they can only look at.
        final aWrites = a.isWritableBy(access);
        final bWrites = b.isWritableBy(access);
        if (aWrites != bWrites) return aWrites ? -1 : 1;
        return a.rank.compareTo(b.rank);
      });

    // One slot is always spent on More, so the bar holds barSlots - 1 real
    // destinations alongside Today — unless everything fits, in which case
    // there is nothing for More to hold and the bar can use its slot.
    final promotable = barSlots - home.length;
    final fitsEntirely = rest.length <= promotable;
    final take = fitsEntirely ? rest.length : promotable - 1;

    return ShellLayout(
      tabs: [...home, ...rest.take(take)],
      more: rest.skip(take).toList(),
    );
  }
}
