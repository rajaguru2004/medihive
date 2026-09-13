import 'package:flutter/widgets.dart';

import 'inpatient_keys.dart';

/// The inpatient_add_ward module's anchor.
///
/// The keys themselves live in [InpatientKeys]: this module is one view of a
/// thing that several screens show, and a parallel set of keys is how two
/// views of one object drift until a test passes against a screen the user
/// never sees.
abstract final class InpatientAddWardKeys {
  /// the ward form.
  static const Key screen = InpatientKeys.wardForm;
}
