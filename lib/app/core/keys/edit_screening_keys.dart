import 'screening_keys.dart';

/// The edit-screening module's anchor.
///
/// The fields themselves live in [ScreeningKeys]: the edit screen is the same
/// form as step two, and giving it a parallel set of field keys is how the two
/// drift until a test passes against a form the user never sees.
abstract final class EditScreeningKeys {
  static const screen = ScreeningKeys.edit;
  static const save = ScreeningKeys.editSave;
}
