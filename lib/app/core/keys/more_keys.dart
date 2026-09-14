import 'package:flutter/widgets.dart';

/// Widget keys for the More hub.
///
/// Rows are keyed by **route**, not by label: the label is display copy that
/// changes with the wording, the route is the thing the tap actually does.
abstract final class MoreKeys {
  static const Key screen = Key('more_screen');
  static const Key account = Key('more_account');
  static const Key signOut = Key('more_sign_out');
  static const Key appearance = Key('more_appearance');
  static const Key accessNotice = Key('more_access_notice');

  static Key group(String group) => Key('more_group_$group');
  static Key item(String route) => Key('more_item_$route');
}
