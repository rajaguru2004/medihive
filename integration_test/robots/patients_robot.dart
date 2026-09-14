import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/modules/patient_hub/controllers/patient_hub_controller.dart';
import 'package:medihive/app/modules/patients/patient_routes.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The patient register.
final class PatientsRobot extends Robot {
  PatientsRobot(super.harness);

  @override
  String? get route => PatientRoutes.registry;

  @override
  Key get anchor => PatientsKeys.screen;

  static const _rowPrefix = 'patients_row_';

  /// How long the search field waits before it asks the server. One frame
  /// past it, so a flow never races the debounce it is meant to be testing.
  static const _debounce = Duration(milliseconds: 400);

  /// Pushes the register.
  ///
  /// Not awaited: `Get.toNamed` completes when the route is **popped**, so
  /// awaiting it here waits forever.
  Future<void> open() async {
    unawaited(
      Get.toNamed<void>(PatientRoutes.registry) ?? Future<void>.value(),
    );
    await tester.pumpUntilRouteSettled(expectRoute: PatientRoutes.registry);
  }

  Future<void> assertOnRegister() async {
    await assertVisible();
    seeNoErrorBanner();
  }

  /// Types into the search field and waits out its debounce.
  Future<void> search(String term) async {
    await tester.enterTextByKey(PatientsKeys.search, term);
    await tester.pump(_debounce);
    await settle();
  }

  Future<void> showStatus(String status) async {
    await tester.tapKey(PatientsKeys.statusFilter(status));
    await settle();
  }

  Future<void> sortBy(String field, {required bool descending}) async {
    await tester.tapKey(PatientsKeys.sortButton);
    await tester.pumpUntilRouteSettled();
    await tester.tapKey(
      PatientsKeys.sortOption(field, descending: descending),
    );
    await settle();
  }

  /// Drags the register to its end, which is what asks for the next page.
  ///
  /// `dragFrom` a point in the left gutter rather than `drag` on the list:
  /// `InfiniteList` is a sliver and has no `RenderBox` to take a centre from,
  /// and a drag started in the middle of the rows can land on a row's own
  /// `InkWell` instead of on the scroll view.
  Future<void> scrollToEnd() async {
    for (var i = 0; i < 6; i++) {
      await tester.dragFrom(const Offset(12, 420), const Offset(0, -320));
      await tester.pump(const Duration(milliseconds: 32));
    }
    await settle();
  }

  /// The rows on screen, top to bottom.
  List<String> rowIds() {
    final rows = <({double top, String id})>[
      for (final element in _rowElements)
        (
          top: (element.renderObject! as RenderBox)
              .localToGlobal(Offset.zero)
              .dy,
          id: _idOf(element.widget.key!),
        ),
    ]..sort((a, b) => a.top.compareTo(b.top));
    return [for (final row in rows) row.id];
  }

  Future<void> openPatient(String id) async {
    await tester.tapKey(PatientsKeys.row(id));
    await tester.pumpUntilRouteSettled();
  }

  /// "This account may register somebody."
  ///
  /// The control is **absent** rather than disabled for an account without
  /// `patients.create`, so this is a presence assertion and its opposite is a
  /// real absence rather than a greyed-out button.
  void seeRegisterAction() => expect(
        find.byKey(PatientsKeys.registerButton),
        findsOneWidget,
        reason: 'this account can create patients, so Register must be here',
      );

  void seeNoRegisterAction() => expect(
        find.byKey(PatientsKeys.registerButton),
        findsNothing,
        reason: 'this account cannot create patients, so Register must be '
            'absent — not disabled',
      );

  void seeEmptyState() =>
      expect(find.byKey(PatientsKeys.empty), findsOneWidget);

  Iterable<Element> get _rowElements => find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(_rowPrefix),
        description: 'a keyed patient row',
      )
      .evaluate();

  String _idOf(Key key) =>
      (key as ValueKey<String>).value.substring(_rowPrefix.length);
}

/// The patient hub.
final class PatientHubRobot extends Robot {
  PatientHubRobot(super.harness);

  /// Deliberately null.
  ///
  /// The hub is two things: a pushed screen at [PatientRoutes.hub], and the
  /// detail pane of the register on a tablet — where the current route is
  /// still `/patients`. The route is therefore not evidence of which one is on
  /// screen; the anchor is.
  @override
  String? get route => null;

  @override
  Key get anchor => PatientHubKeys.screen;

  Future<void> open(String patientId) async {
    unawaited(
      Get.toNamed<void>(
            PatientRoutes.hub,
            arguments: {'id': patientId},
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilRouteSettled(expectRoute: PatientRoutes.hub);
  }

  Future<void> assertOnHub() async {
    await tester.pumpUntilFound(find.byKey(PatientHubKeys.band));
    seeNoErrorBanner();
  }

  Future<void> openTab(PatientHubTab tab) async {
    // The strip scrolls sideways and the last tabs are past the right edge on
    // a phone, where they are not built at all — so this has to drag the strip
    // before it can tap anything on it.
    await tester.scrollToKeyInStrip(
      find.byKey(PatientHubKeys.tabs),
      PatientHubKeys.tab(tab.name),
    );
    await tester.tapKey(PatientHubKeys.tab(tab.name));
    await settle();
  }

  /// "This tab has its content on screen."
  Future<void> seeTabLoaded(PatientHubTab tab) async {
    final key = PatientHubKeys.body(tab.name);
    await tester.scrollToKey(key);
    expect(
      find.byKey(key),
      findsOneWidget,
      reason: '${tab.name} should have loaded its own content',
    );
  }

  /// "This tab, and only this tab, is locked."
  Future<void> seeTabNoAccess(PatientHubTab tab) async {
    final key = PatientHubKeys.noAccess(tab.name);
    await tester.scrollToKey(key);
    expect(
      find.byKey(key),
      findsOneWidget,
      reason: '${tab.name} was refused, so it must show the locked state',
    );
    expect(
      find.byKey(PatientHubKeys.body(tab.name)),
      findsNothing,
      reason: 'a refused tab must not also render its content',
    );
  }

  Future<void> seeTabEmpty(PatientHubTab tab) async {
    final key = PatientHubKeys.tabEmpty(tab.name);
    await tester.scrollToKey(key);
    expect(find.byKey(key), findsOneWidget);
  }

  /// The identity band is on screen and the record behind it arrived.
  void seeBand() => expect(find.byKey(PatientHubKeys.band), findsOneWidget);

  /// The allergy warning, which is words as well as a tint.
  void seeAllergyNotice() => expect(
        find.byKey(PatientHubKeys.allergyNotice),
        findsOneWidget,
        reason: 'a patient with allergies must say so on the summary',
      );

  Future<void> seeVitalsNotice() async {
    await tester.scrollToKey(PatientHubKeys.vitalsNotice);
    expect(
      find.byKey(PatientHubKeys.vitalsNotice),
      findsOneWidget,
      reason: 'an out-of-range observation must be flagged in words, not only '
          'by the colour of the figure',
    );
  }

  Future<void> seeCriticalNotice() async {
    await tester.scrollToKey(PatientHubKeys.criticalNotice);
    expect(
      find.byKey(PatientHubKeys.criticalNotice),
      findsOneWidget,
      reason: 'an unverified critical result must say "Critical" in words',
    );
  }

  void seeQuickAction(String name) =>
      expect(find.byKey(PatientHubKeys.action(name)), findsOneWidget);

  void seeNoQuickAction(String name) =>
      expect(find.byKey(PatientHubKeys.action(name)), findsNothing);
}

/// The global lookup.
final class PatientSearchRobot extends Robot {
  PatientSearchRobot(super.harness);

  @override
  String? get route => PatientRoutes.search;

  @override
  Key get anchor => PatientSearchKeys.screen;

  static const _debounce = Duration(milliseconds: 400);

  Future<void> open() async {
    unawaited(
      Get.toNamed<void>(PatientRoutes.search) ?? Future<void>.value(),
    );
    await tester.pumpUntilRouteSettled(expectRoute: PatientRoutes.search);
  }

  Future<void> search(String term) async {
    await tester.enterTextByKey(PatientSearchKeys.field, term);
    await tester.pump(_debounce);
    await settle();
  }

  Future<void> openResult(String id) async {
    await tester.tapKey(PatientSearchKeys.result(id));
    await tester.pumpUntilRouteSettled();
  }

  void seeRecent(String id) =>
      expect(find.byKey(PatientSearchKeys.recent(id)), findsOneWidget);

  void seeNoRecents() =>
      expect(find.byKey(PatientSearchKeys.recents), findsNothing);

  void seePrompt() =>
      expect(find.byKey(PatientSearchKeys.prompt), findsOneWidget);
}

/// Registering and editing.
final class PatientFormRobot extends Robot {
  PatientFormRobot(super.harness);

  @override
  String? get route => PatientRoutes.form;

  @override
  Key get anchor => PatientFormKeys.screen;

  Future<void> openForRegistration() async {
    unawaited(Get.toNamed<void>(PatientRoutes.form) ?? Future<void>.value());
    await tester.pumpUntilRouteSettled(expectRoute: PatientRoutes.form);
  }

  Future<void> openForEdit(String patientId) async {
    unawaited(
      Get.toNamed<void>(
            PatientRoutes.form,
            arguments: {'id': patientId},
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilRouteSettled(expectRoute: PatientRoutes.form);
  }

  Future<void> typeName({required String first, required String last}) async {
    await tester.enterTextByKey(PatientFormKeys.firstName, first);
    await tester.enterTextByKey(PatientFormKeys.lastName, last);
  }

  Future<void> chooseSex(String value) async {
    await tester.tapKeyWithoutKeyboard(PatientFormKeys.sex(value));
    await tester.pump(const Duration(milliseconds: 32));
  }

  Future<void> addAllergy(String value) async {
    await tester.enterTextByKey(PatientFormKeys.allergyField, value);
    await tester.tapKeyWithoutKeyboard(PatientFormKeys.allergyAdd);
    await tester.pump(const Duration(milliseconds: 32));
  }

  void seeAllergyChip(String value) => expect(
        find.byKey(PatientFormKeys.chip('allergy', value)),
        findsOneWidget,
      );

  Future<void> save() async {
    await tester.tapKeyWithoutKeyboard(PatientFormKeys.save);
    await settle();
  }

  /// The save was refused, and the line above the button says how many fields
  /// need attention.
  ///
  /// Asserted on `FieldErrorSummary` itself rather than on its words: the
  /// sentence is singular for one field and plural for more, and a test that
  /// matched the text would be asserting the grammar.
  void seeSaveRefused() => expect(
        find.byType(FieldErrorSummary),
        findsOneWidget,
        reason: 'a refused save must say how many fields are wrong, because '
            'the fields themselves are several screens up',
      );
}
