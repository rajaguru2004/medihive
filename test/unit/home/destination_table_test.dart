import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/access_map.dart';
import 'package:medihive/app/modules/home/bindings/home_binding.dart';

/// Guards the destination table itself.
///
/// Not the resolver — that has its own spec — but the list every screen is
/// reached through, where a missing field is a crash somebody only sees when
/// they sign in as the right role.
void main() {
  final destinations = HomeBinding.allDestinations();

  test('every destination names a module the server actually grants', () {
    // A key with a typo is not an error: `AccessMap.of` returns "no access"
    // for anything it does not recognise, so the destination silently vanishes
    // for every account. `preTriage` instead of `pre-triage` is the one that
    // hides in plain sight.
    for (final destination in destinations) {
      final module = destination.module;
      if (module == null) continue;
      expect(
        Modules.all,
        contains(module),
        reason: '${destination.label} is keyed on "$module", which is not a '
            'module the access map carries',
      );
    }
  });

  test('routes and ranks are unique', () {
    // Two destinations sharing a route makes `selectRoute` ambiguous; two
    // sharing a rank makes the bar's membership depend on list order, which is
    // the hub's reading order and not a priority.
    final routes = destinations.map((d) => d.route).toList();
    final ranks = destinations.map((d) => d.rank).toList();
    expect(routes.toSet().length, routes.length, reason: 'duplicate route');
    expect(ranks.toSet().length, ranks.length, reason: 'duplicate rank');
  });

  test('labels fit a five-slot bar', () {
    // At 411 dp each slot is about 82 dp, and at the 1.3 text scale a ward
    // tablet is usually left at, anything much past eight characters truncates
    // or wraps to two lines.
    for (final destination in destinations) {
      expect(
        destination.label.length,
        lessThanOrEqualTo(8),
        reason: '"${destination.label}" is too long for a bar slot',
      );
    }
  });

  test('exactly one destination is unconditional', () {
    // Today. Everything else answers to the access map, and a second
    // permission-free destination would be one nobody could ever hide.
    final unconditional = destinations.where((d) => d.module == null);
    expect(unconditional.length, 1);
    expect(unconditional.single.label, 'Today');
  });

  test('every destination can survive being promoted to a tab', () {
    // The bug this exists for: a destination whose view is a `GetView` but
    // whose `register` is null builds fine as a More row (it is pushed, and
    // its route binding runs) and **throws** the moment the access map
    // promotes it to a bar tab, because `LazyIndexedStack` builds it inside
    // the shell where no binding has run.
    //
    // The rule is therefore: a destination either registers a controller, or
    // its body is a widget that needs none. Since this test cannot inspect a
    // closure's widget type, it asserts the conservative half — every
    // destination that names a real module registers — and lists the
    // stateless exceptions explicitly so adding one is a deliberate act.
    const stateless = {
      '/patients',
      '/pharmacy',
      '/laboratory',
      '/radiology',
      '/billing',
      '/staff',
      '/integrations',
    };

    for (final destination in destinations) {
      if (stateless.contains(destination.route)) continue;
      expect(
        destination.register,
        isNotNull,
        reason: '${destination.label} (${destination.route}) has no controller '
            'registration, so it crashes when it becomes a bar tab',
      );
    }
  });

  test('the stateless exception list has not gone stale', () {
    // Every route named above must still exist in the table. A renamed route
    // would otherwise silently drop out of the check above and take its
    // registration requirement with it.
    const stateless = {
      '/patients',
      '/pharmacy',
      '/laboratory',
      '/radiology',
      '/billing',
      '/staff',
      '/integrations',
    };
    final routes = destinations.map((d) => d.route).toSet();
    for (final route in stateless) {
      expect(routes, contains(route), reason: '$route is no longer a destination');
    }
  });
}
