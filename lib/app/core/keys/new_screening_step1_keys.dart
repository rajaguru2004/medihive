import 'package:flutter/widgets.dart';

import 'screening_keys.dart';

/// The new_screening_step1 module's anchor.
///
/// The keys themselves live in [ScreeningKeys]: this module is one view of a
/// thing that several screens show, and a parallel set of keys is how two
/// views of one object drift until a test passes against a screen the user
/// never sees.
abstract final class NewScreeningStep1Keys {
  /// screening step one.
  static const Key screen = ScreeningKeys.step1;
}
