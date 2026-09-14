import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../../fixtures/world_roles.dart';
import '../../support/app_harness.dart';
import '../../support/pump.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerRouteFlows();
}

/// Every registered screen, opened once, as the account that can open them all.
///
/// A flow per module proves the module works. This proves the *table* works —
/// that no route in it lands on Flutter's red error screen, which is what an
/// exception thrown during `build` looks like to somebody holding the phone.
/// It is the cheapest possible test and it catches the two failures that are
/// invisible to a module flow: a screen nobody wrote a flow for, and a screen
/// whose binding is missing so `Get.find` throws before anything renders.
///
/// The ids below are the world's own, so a detail route opens on a record that
/// exists. A route whose id is wrong still passes this test — it renders "not
/// found", which is a screen — so this is a floor, not a substitute.
const Map<String, String> _idsForPattern = {
  '/appointments/:id': 'a-1',
  '/consultations/:id': 'c-1',
  '/laboratory/orders/:id': 'lab-order-1',
  '/radiology/orders/:id': 'rad-1',
  '/pharmacy/prescriptions/:id': 'rx-1',
  '/pharmacy/prescriptions/:id/dispense': 'rx-1',
  '/billing/invoices/:id': 'inv-1',
  '/billing/invoices/:id/pay': 'inv-4',
};

/// Routes this test does not drive, and why.
const Set<String> _skipped = {
  '/splash', // Re-runs the bootstrap and replaces the whole app.
  '/login', // Guarded away from a signed-in account by design.
  '/home', // Where every run already starts.
  '/not-found',
};

void registerRouteFlows() {
  group('every screen', () {
    for (final page in AppPages.routes) {
      final name = page.name;
      if (_skipped.contains(name)) continue;

      final path = name.contains(':')
          ? _idsForPattern[name] == null
              ? null
              : name.replaceFirst(RegExp(r':\w+'), _idsForPattern[name]!)
          : name;

      if (path == null) continue;

      testWidgets('$name opens without throwing', (tester) async {
        final harness = await AppHarness.bootSignedIn(
          tester,
          role: WorldRole.superAdmin,
        );

        // Never awaited: `Get.toNamed` completes when the route is *popped*.
        unawaited(Get.toNamed<void>(path, arguments: _argumentsFor(name)));
        await tester.pumpUntilRouteSettled();

        // `takeException` is how a test sees the red screen: the error goes to
        // `FlutterError.onError`, the frame still renders, and nothing else in
        // the run would notice. One assertion rather than also looking for an
        // `ErrorWidget`, because a flow may not call `find.*` — and the two
        // say the same thing anyway.
        expect(
          tester.takeException(),
          isNull,
          reason: '$name threw while building',
        );

        await harness.tester.pumpUntilViewportStable();
      });
    }
  });
}

/// What a screen opened cold expects to be handed.
///
/// Most detail screens take their record's id in the path. A handful predate
/// that and read `Get.arguments` instead — the patient hub, because a `:id`
/// there would swallow `search` and `edit`, and the two catalogue forms,
/// because an entry being created has no id to put in a path.
Object? _argumentsFor(String route) => switch (route) {
      '/patients/record' => {'id': 'p-2'},
      '/patients/edit' => null,
      '/pre-triage/details' => {'id': 's-1'},
      _ => null,
    };
