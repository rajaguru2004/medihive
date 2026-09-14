import 'package:flutter/widgets.dart';

import 'radiology_keys.dart';

/// The radiology_exam_form module's anchor.
///
/// The keys themselves live in [RadiologyKeys]: this module is one view of a
/// thing several screens show, and a parallel set of keys is how two views of
/// one study drift until a test passes against a screen the user never sees.
abstract final class RadiologyExamFormKeys {
  /// one catalogue entry.
  static const Key screen = RadiologyKeys.examForm;
}
