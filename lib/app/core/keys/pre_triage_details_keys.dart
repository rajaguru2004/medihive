import 'package:flutter/widgets.dart';

import 'pre_triage_keys.dart';

/// The pre_triage_details module's anchor.
///
/// The keys themselves live in [PreTriageKeys]: this module is one view of a
/// thing that several screens show, and a parallel set of keys is how two
/// views of one object drift until a test passes against a screen the user
/// never sees.
abstract final class PreTriageDetailsKeys {
  /// one screening.
  static const Key screen = PreTriageKeys.detail;
}
