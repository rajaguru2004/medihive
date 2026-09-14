import 'package:flutter/widgets.dart';

import 'laboratory_keys.dart';

/// The lab test form module's anchor.
///
/// The keys themselves live in [LaboratoryKeys]: this screen is one view of a
/// workflow several screens show, and a parallel set of keys is how two views
/// of one object drift until a test passes against a screen the user never
/// sees.
abstract final class LabTestFormKeys {
  static const Key screen = LaboratoryKeys.testFormScreen;
}
