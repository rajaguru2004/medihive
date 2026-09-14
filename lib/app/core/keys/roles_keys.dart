import 'package:flutter/widgets.dart';

/// Widget keys for the roles list.
///
/// The editor a card opens is keyed from [StaffKeys]: it shares its people with
/// the staff directory and the record, and one namespace across the four
/// screens is what stops two views of one role drifting apart.
abstract final class RolesKeys {
  static const Key screen = Key('roles_screen');
  static const Key list = Key('roles_list');
  static const Key add = Key('roles_add');
  static const Key empty = Key('roles_empty');
  static const Key noAccess = Key('roles_no_access');

  static Key card(String id) => Key('roles_card_$id');

  // The permission editor's own keys live in `staff_keys.dart`, beside the
  // staff directory and the record that share its people. They were declared
  // here first, as placeholders, and two namespaces for one screen is how a
  // test ends up passing against a control nobody renders.
}
