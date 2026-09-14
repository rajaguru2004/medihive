import 'package:flutter/widgets.dart';

import 'laboratory_keys.dart';

/// The lab catalog module's anchor.
///
/// The keys themselves live in [LaboratoryKeys]: this screen is one view of a
/// workflow several screens show, and a parallel set of keys is how two views
/// of one object drift until a test passes against a screen the user never
/// sees.
abstract final class LabCatalogKeys {
  static const Key screen = LaboratoryKeys.catalogScreen;
}
