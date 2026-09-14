import 'package:flutter/widgets.dart';

import 'radiology_keys.dart';

/// The radiology_catalog module's anchor.
///
/// The keys themselves live in [RadiologyKeys]: this module is one view of a
/// thing several screens show, and a parallel set of keys is how two views of
/// one study drift until a test passes against a screen the user never sees.
abstract final class RadiologyCatalogKeys {
  /// the exam catalogue.
  static const Key screen = RadiologyKeys.catalog;
}
