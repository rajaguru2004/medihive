import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../support/pump.dart';
import 'robot.dart';

/// Sign in.
final class LoginRobot extends Robot {
  LoginRobot(super.harness);

  @override
  String? get route => Routes.LOGIN;

  @override
  Key get anchor => LoginKeys.screen;

  /// Fills both fields and submits.
  ///
  /// Deliberately asserts nothing about where it landed. The two answers — the
  /// shell, or a banner still on this screen — belong to two different robots,
  /// and a helper that assumed the happy one could not be used to test the
  /// other.
  Future<void> signIn({required String email, required String password}) async {
    await tester.enterTextByKey(LoginKeys.emailField, email);
    await tester.enterTextByKey(LoginKeys.passwordField, password);
    await submit();
  }

  /// Presses Sign in with whatever the fields currently hold.
  ///
  /// The keyboard comes down first: it is up from the password field, it covers
  /// the lower half of a phone, and the button is underneath it.
  Future<void> submit() async {
    await tester.tapKeyWithoutKeyboard(LoginKeys.submit);
    await settle();
  }

  /// The banner that says the server refused these credentials.
  ///
  /// Keyed rather than matched on words: "wrong password" and "your session
  /// expired" are different things, they render in the same place, and a test
  /// that cannot tell them apart is a test that passes on the wrong one.
  Future<void> seeSignInRefused({String? containing}) async {
    await tester.pumpUntilFound(find.byKey(LoginKeys.error));
    if (containing != null) {
      expect(
        find.descendant(
          of: find.byKey(LoginKeys.error),
          matching: find.textContaining(containing),
        ),
        findsOneWidget,
        reason: 'expected the refusal to say "$containing"',
      );
    }
  }

  void seeNoSignInRefused() =>
      expect(find.byKey(LoginKeys.error), findsNothing);

  /// The per-field messages the `Form` puts up when it refuses to submit.
  Future<void> seeEmptyFieldErrors() async {
    await tester.pumpUntilFound(find.text(_emailRequired));
    expect(
      find.text(_passwordRequired),
      findsOneWidget,
      reason: 'the password field said nothing about being empty',
    );
  }

  // The validators' own words, from LoginController.
  static const _emailRequired = 'Enter your work email';
  static const _passwordRequired = 'Enter your password';
}
