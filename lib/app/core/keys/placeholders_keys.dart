import 'package:flutter/widgets.dart';

import 'placeholder_keys.dart';

/// The placeholders module's anchor.
///
/// [PlaceholderKeys] builds a key per module, because one view serves seven
/// routes. This is the module-level anchor the key ratchet looks for; the
/// generic route is `/pharmacy`, which is the one a shell walk lands on.
abstract final class PlaceholdersKeys {
  static final Key screen = PlaceholderKeys.screen('pharmacy');
}
