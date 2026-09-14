import 'package:flutter/widgets.dart';

import 'staff_keys.dart';

/// The staff directory module's anchor.
///
/// The keys themselves live in [StaffKeys]: this screen is one view of a
/// person several screens show, and a parallel set of keys is how two views of
/// one record drift until a test passes against a screen the user never sees.
abstract final class UsersKeys {
  static const Key screen = StaffKeys.screen;
}
