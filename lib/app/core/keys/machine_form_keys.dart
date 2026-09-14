import 'package:flutter/widgets.dart';

import 'integrations_keys.dart';

/// The device form's anchor.
///
/// Thin on purpose. The form is a second view of a device the integrations hub
/// already lists, so its keys live in `integrations_keys.dart` beside the rows
/// they edit — two parallel sets is how a board and the form behind it drift
/// until a test passes against a screen nobody sees. This file exists because
/// `tool/check_keys.dart` asks every module directory for one, and a flow that
/// only ever reaches the form should not have to know which module's file to
/// import.
abstract final class MachineFormKeys {
  /// The `Scaffold` anchor `Robot.assertVisible` looks for.
  static const Key screen = IntegrationsKeys.machineForm;

  static const Key save = IntegrationsKeys.machineSave;
  static const Key delete = IntegrationsKeys.machineDelete;
}
