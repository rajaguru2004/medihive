import 'package:flutter/widgets.dart';

import 'inpatient_keys.dart';

/// The inpatient_admissions module's anchor.
///
/// The keys themselves live in [InpatientKeys]: this module is one view of a
/// thing that several screens show, and a parallel set of keys is how two
/// views of one object drift until a test passes against a screen the user
/// never sees.
abstract final class InpatientAdmissionsKeys {
  /// the admissions register.
  static const Key screen = InpatientKeys.admissions;
}
