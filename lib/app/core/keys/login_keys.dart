import 'package:flutter/widgets.dart';

/// Widget keys for the sign-in screen.
abstract final class LoginKeys {
  static const screen = Key('login_screen');
  static const emailField = Key('login_email_field');
  static const passwordField = Key('login_password_field');
  static const passwordToggle = Key('login_password_toggle');
  static const submit = Key('login_submit');
  static const error = Key('login_error');

  /// The banner that says why the last session ended. Keyed separately from
  /// [error] because "your session expired" and "wrong password" are different
  /// things and a test that cannot tell them apart is a test that passes on
  /// the wrong one.
  static const sessionNotice = Key('login_session_notice');

  /// The one-tap seeded sign-ins. Debug builds only — see `demo_accounts.dart`.
  static const demoPanel = Key('login_demo_panel');

  static Key demoAccount(String email) => Key('login_demo_$email');
}
