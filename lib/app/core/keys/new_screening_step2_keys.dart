import 'package:flutter/widgets.dart';

import 'screening_keys.dart';

/// The new_screening_step2 module's anchor.
///
/// The keys themselves live in [ScreeningKeys]: this module is one view of a
/// thing that several screens show, and a parallel set of keys is how two
/// views of one object drift until a test passes against a screen the user
/// never sees.
abstract final class NewScreeningStep2Keys {
  /// screening step two.
  static const Key screen = ScreeningKeys.step2;
}
