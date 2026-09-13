import 'package:flutter/widgets.dart';

/// Widget keys for the modules that are routed but not yet built —
/// pharmacy, laboratory, radiology, billing, staff, integrations.
///
/// They are keyed like any other screen because they are reachable: a deep
/// link or a nav entry lands on one, and a test that walks the shell has to be
/// able to say "this is the pharmacy placeholder, not a crash".
abstract final class PlaceholderKeys {
  static Key screen(String module) => Key('placeholder_${module}_screen');
  static Key action(String module) => Key('placeholder_${module}_action');
}
