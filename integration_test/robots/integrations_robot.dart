import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/integrations_keys.dart';
import 'package:medihive/app/core/keys/no_access_keys.dart';
import 'package:medihive/app/modules/integrations/controllers/integrations_controller.dart';
import 'package:medihive/app/modules/integrations/integrations_routes.dart';
import 'package:medihive/app/modules/integrations/views/integrations_rows.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The instrument link: the device board, the results queue, the import, and
/// the form behind one device.
///
/// One robot for two screens because `IntegrationsKeys` is one file for two,
/// and for the same reason — they are two views of one device, and an analyser
/// named on the board has to be the same analyser on the form that edits it.
final class IntegrationsRobot extends Robot {
  IntegrationsRobot(super.harness);

  /// Spans screens, so no single route identifies it. [assertOnHub] and
  /// [assertOnMachineForm] check the one they are about.
  @override
  String? get route => null;

  @override
  Key get anchor => IntegrationsKeys.screen;

  // ── Getting there ─────────────────────────────────────────────────────────

  /// Puts this module's own pages at the front of the route table.
  ///
  /// `Routes.INTEGRATIONS` still points at the placeholder `AppPages`
  /// registers, and `ParseRouteTree._findRoute` takes the **first** pattern
  /// that matches — so until `...IntegrationsPages.pages` is spliced into
  /// `AppPages.routes`, `/integrations` opens that placeholder and this flow
  /// would assert against a screen nobody wrote.
  ///
  /// Inserted rather than swapped in, so the splice changes nothing here: the
  /// same pages, still matched first. Registering the module's real `GetPage`s
  /// is also what keeps `AuthMiddleware` in the path — a flow that pushed the
  /// view directly would never reach the guard it is partly about.
  ///
  /// Called on every visit, and the repeats are harmless: `GetPage` is an
  /// immutable descriptor, the route tree is a `static final` that already
  /// accumulates one copy of the app's own table per boot, and `_findRoute`
  /// takes the first match either way.
  static void installPages() {
    Get.routeTree.routes.insertAll(0, IntegrationsPages.pages);
  }

  /// Opens the hub as its own route.
  ///
  /// `Get.toNamed` is fired and **not awaited**: its future completes when the
  /// route is *popped*, so awaiting it here waits for something this flow has
  /// not done yet and never returns.
  Future<void> openHub() async {
    installPages();
    unawaited(
      Get.toNamed<void>(IntegrationsRoutes.hub) ?? Future<void>.value(),
    );
    await tester.pumpUntilRouteSettled();
  }

  Future<void> assertOnHub() async {
    await tester.pumpUntilFound(find.byKey(IntegrationsKeys.screen));
    expect(Get.currentRoute, IntegrationsRoutes.hub);
    seeNoErrorBanner();
  }

  // ── The segments ──────────────────────────────────────────────────────────

  Future<void> showDevices() => _show(IntegrationsSegment.devices);

  Future<void> showQueue() => _show(IntegrationsSegment.queue);

  Future<void> showUpload() => _show(IntegrationsSegment.upload);

  Future<void> _show(IntegrationsSegment segment) async {
    await tester.tapKeyWithoutKeyboard(
      IntegrationsKeys.segment(segment.name),
    );
    await settle();
  }

  // ── The device board ──────────────────────────────────────────────────────

  void seeDevice(String id) => expect(
        find.byKey(IntegrationsKeys.device(id)),
        findsOneWidget,
        reason: 'expected device $id on the board',
      );

  void seeNoDevice(String id) =>
      expect(find.byKey(IntegrationsKeys.device(id)), findsNothing);

  /// How many devices the board is showing.
  ///
  /// By widget type, not by key prefix: `integrations_device_` also opens
  /// `integrations_device_add`, `integrations_device_list` and every
  /// `integrations_device_state_…`, so a prefix count would report rows on a
  /// board that has none.
  int get deviceCount => find.byType(DeviceRow).evaluate().length;

  /// The word on one device's pill — the half of the state that survives a
  /// black-and-white printout and a reader who cannot resolve a tint.
  String deviceStateWord(String id) => _devicePill(id).label ?? '';

  /// The tint on one device's pill.
  Color? deviceStateColour(String id) => _devicePill(id).color;

  StatusPill _devicePill(String id) {
    final finder = find.byKey(IntegrationsKeys.deviceState(id));
    expect(finder, findsOneWidget, reason: 'no state pill for device $id');
    return tester.widget<StatusPill>(finder);
  }

  /// "Nothing on this board is painted in the colour that means a patient is in
  /// trouble."
  ///
  /// The rule the whole module is held to. A disconnected analyser is amber; a
  /// red one costs a clinician's scan of a ward board its meaning.
  void seeNoRedOnTheBoard() {
    final pills = tester.widgetList<StatusPill>(
      find.descendant(
        of: find.byKey(IntegrationsKeys.deviceList),
        matching: find.byType(StatusPill),
      ),
    );
    expect(pills, isNotEmpty, reason: 'the board drew no state at all');
    for (final pill in pills) {
      expect(
        pill.color,
        isNot(AppColors.error),
        reason: 'a device state was painted in the app’s error red',
      );
      expect(
        pill.color,
        isNot(AppColors.acuityCritical),
        reason: 'a device state was painted in the acuity red',
      );
    }
  }

  /// "The board put the device that needs attention above the one that does
  /// not."
  ///
  /// The order is this screen's own: the route sorts by registration date, and
  /// a board worked in that order buries the analyser that stopped talking this
  /// morning under six that are fine.
  void seeDeviceAbove(String upper, String lower) {
    final above = tester.getTopLeft(find.byKey(IntegrationsKeys.device(upper)));
    final below = tester.getTopLeft(find.byKey(IntegrationsKeys.device(lower)));
    expect(
      above.dy,
      lessThan(below.dy),
      reason: '$upper should be listed above $lower',
    );
  }

  Future<void> filterDevices(String status) async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.deviceFilter(status));
    await settle();
  }

  void seeDeviceEmptyState() =>
      expect(find.byKey(IntegrationsKeys.deviceEmpty), findsOneWidget);

  /// "This account is offered the one write this board has."
  void seeAddDeviceAction() => expect(
        find.byKey(IntegrationsKeys.deviceAdd),
        findsOneWidget,
        reason: 'this role should be able to register a device',
      );

  void seeNoAddDeviceAction() => expect(
        find.byKey(IntegrationsKeys.deviceAdd),
        findsNothing,
        reason: 'a control this account cannot use must be absent, not '
            'disabled',
      );

  Future<void> tapAddDevice() async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.deviceAdd);
    await tester.pumpUntilFound(find.byKey(IntegrationsKeys.machineForm));
    await settle();
  }

  Future<void> openDevice(String id) async {
    await tester.tapKey(IntegrationsKeys.device(id));
    await tester.pumpUntilFound(find.byKey(IntegrationsKeys.machineForm));
    await settle();
  }

  // ── The results queue ─────────────────────────────────────────────────────

  void seeQueueRow(String id) => expect(
        find.byKey(IntegrationsKeys.queueRow(id)),
        findsOneWidget,
        reason: 'expected result $id on the queue',
      );

  int get queueRowCount => find.byType(QueueRow).evaluate().length;

  /// What one queue row says arrived — the analytes, in the analyser's words.
  String queueRowTitle(String id) => _queueRow(id).title;

  /// Who the result is for, the machine that sent it, and when — the line that
  /// has to say "Unmatched" rather than go blank.
  String queueRowSubtitle(String id) => _queueRow(id).subtitle ?? '';

  BentoRow _queueRow(String id) {
    final finder = find.descendant(
      of: find.byKey(IntegrationsKeys.queueRow(id)),
      matching: find.byType(BentoRow),
    );
    expect(finder, findsOneWidget, reason: 'no queue row $id on screen');
    return tester.widget<BentoRow>(finder);
  }

  Future<void> filterQueue(String status) async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.queueFilter(status));
    await settle();
  }

  void seeQueueEmptyState() =>
      expect(find.byKey(IntegrationsKeys.queueEmpty), findsOneWidget);

  // ── The import ────────────────────────────────────────────────────────────

  /// Chooses a file through the injected [FileSource].
  ///
  /// This build's source is a stub that answers with a real CSV, so the whole
  /// multipart path runs today — see `lib/app/data/services/file_source.dart`.
  Future<void> chooseFile() async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.uploadPick);
    await tester.pumpUntilFound(find.byKey(IntegrationsKeys.uploadChosen));
    await settle();
  }

  void seeChosenFile({String? named}) {
    expect(
      find.byKey(IntegrationsKeys.uploadChosen),
      findsOneWidget,
      reason: 'expected the chosen file to still be on screen',
    );
    if (named != null) {
      expect(
        find.descendant(
          of: find.byKey(IntegrationsKeys.uploadChosen),
          matching: find.text(named),
        ),
        findsOneWidget,
      );
    }
  }

  void seeNoChosenFile() =>
      expect(find.byKey(IntegrationsKeys.uploadChosen), findsNothing);

  /// Attributes the file to one registered device, by the name on its row.
  Future<void> chooseSendingDevice(String name) async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.uploadDevice);
    await settle();
    await pickFromSheet(name);
  }

  Future<void> sendFile() async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.uploadSend);
    await settle();
  }

  void seeUploadError({String? containing}) {
    expect(
      find.byKey(IntegrationsKeys.uploadError),
      findsOneWidget,
      reason: 'a refused import must say so inline, where the retry is',
    );
    if (containing != null) {
      expect(
        find.descendant(
          of: find.byKey(IntegrationsKeys.uploadError),
          matching: find.textContaining(containing),
        ),
        findsWidgets,
      );
    }
  }

  void seeNoUploadError() =>
      expect(find.byKey(IntegrationsKeys.uploadError), findsNothing);

  void seeUploadSummary() => expect(
        find.byKey(IntegrationsKeys.uploadSummary),
        findsOneWidget,
        reason: 'an import that landed must say what became of every row',
      );

  /// "Importing is not offered to this account at all."
  void seeImportLocked() => expect(
        find.byKey(IntegrationsKeys.uploadLocked),
        findsOneWidget,
        reason: 'an account without the create grant is shown why, not a '
            'button that 403s',
      );

  void seeNoImportControls() =>
      expect(find.byKey(IntegrationsKeys.uploadPick), findsNothing);

  // ── One device ────────────────────────────────────────────────────────────

  Future<void> assertOnMachineForm() async {
    await tester.pumpUntilFound(find.byKey(IntegrationsKeys.machineForm));
    expect(Get.currentRoute, IntegrationsRoutes.machineEdit);
  }

  Future<void> enterDeviceName(String name) =>
      tester.enterTextByKey(IntegrationsKeys.machineName, name);

  Future<void> enterSerial(String serial) =>
      tester.enterTextByKey(IntegrationsKeys.machineSerial, serial);

  Future<void> enterHost(String host) =>
      tester.enterTextByKey(IntegrationsKeys.machineHost, host);

  Future<void> enterPort(String port) =>
      tester.enterTextByKey(IntegrationsKeys.machinePort, port);

  /// Picks the device's kind from the picker sheet, by the words on its row.
  Future<void> chooseKind(String label) async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.machineType);
    await settle();
    await pickFromSheet(label);
  }

  Future<void> chooseLink(String label) async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.machineConnection);
    await settle();
    await pickFromSheet(label);
  }

  Future<void> saveDevice() async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.machineSave);
    await settle();
  }

  /// The card that shows the kind and the link as facts rather than as fields.
  /// On screen only for a device that already exists.
  void seeFixedLinkFacts() => expect(
        find.byKey(IntegrationsKeys.machineFixed),
        findsOneWidget,
        reason: 'a registered device must be told its kind and link cannot '
            'change, not offered pickers the server refuses',
      );

  void seeNoFixedLinkFacts() =>
      expect(find.byKey(IntegrationsKeys.machineFixed), findsNothing);

  /// The address fields, which only the transports that have an address get.
  void seeAddressFields() =>
      expect(find.byKey(IntegrationsKeys.machineHost), findsOneWidget);

  void seeNoAddressFields() =>
      expect(find.byKey(IntegrationsKeys.machineHost), findsNothing);

  void seeDeleteAction() => expect(
        find.byKey(IntegrationsKeys.machineDelete),
        findsOneWidget,
        reason: 'this role should be able to remove a device',
      );

  void seeNoDeleteAction() =>
      expect(find.byKey(IntegrationsKeys.machineDelete), findsNothing);

  /// Opens the confirm and reads it, without agreeing to it.
  Future<void> tapRemoveDevice() async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.machineDelete);
    await tester.pumpUntilFound(
      find.byKey(IntegrationsKeys.machineDeleteConfirm),
    );
  }

  /// "The confirm named what stops working, rather than asking if I am sure."
  void seeConfirmSays(String text) => expect(
        find.textContaining(text),
        findsWidgets,
        reason: 'the confirm should say "$text"',
      );

  Future<void> confirmRemoveDevice() async {
    await tester.tapKeyWithoutKeyboard(IntegrationsKeys.machineDeleteConfirm);
    await tester.pumpUntilGone(
      find.byKey(IntegrationsKeys.machineDeleteConfirm),
    );
    await settle();
  }

  Future<void> cancelRemoveDevice() async {
    Get.back<void>();
    await tester.pumpUntilGone(
      find.byKey(IntegrationsKeys.machineDeleteConfirm),
    );
  }

  /// "The form refused, and said how many fields it refused over."
  void seeFieldErrorSummary() => expect(
        find.byType(FieldErrorSummary),
        findsOneWidget,
        reason: 'a refused save must say so above the button that refused',
      );

  void seeFormError({String? containing}) {
    expect(find.byKey(IntegrationsKeys.machineFormError), findsOneWidget);
    if (containing != null) {
      expect(find.textContaining(containing), findsWidgets);
    }
  }

  // ── Refusal ───────────────────────────────────────────────────────────────

  /// "This account got a locked state rather than a board."
  ///
  /// Either of the app's two locked states counts, and the flow should not have
  /// to know which: the route guard turns an ungranted module into the shared
  /// no-access screen, and a grant withdrawn mid-session lands on the hub's own
  /// panel instead. What must be true in both is that no device is on screen.
  Future<void> assertNoAccess() async {
    await tester.pumpUntil(
      () =>
          find.byKey(NoAccessKeys.screen).evaluate().isNotEmpty ||
          find.byKey(IntegrationsKeys.locked).evaluate().isNotEmpty,
      reason: 'expected a locked state; the route is ${Get.currentRoute}',
    );
    expect(
      deviceCount,
      0,
      reason: 'a refused account must not be shown a single device',
    );
    seeNoErrorBanner();
  }

  /// The guard sent them to the shared refusal rather than to the hub.
  void seeGuardRefusal() {
    expect(find.byKey(NoAccessKeys.screen), findsOneWidget);
    expect(Get.currentRoute, Routes.NO_ACCESS);
  }
}
