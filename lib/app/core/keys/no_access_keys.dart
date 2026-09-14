import 'package:flutter/widgets.dart';

/// Widget keys for the screen a route guard lands on.
///
/// Keyed because a test asserting "a receptionist cannot open the ward board"
/// has to be able to tell a refusal from a crash, and both are a screen that
/// is not the ward board.
abstract final class NoAccessKeys {
  static const Key screen = Key('no_access_screen');
  static const Key module = Key('no_access_module');
  static const Key home = Key('no_access_home');
}
