import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../fakes/fake_api.dart';
import '../../robots/dashboard_robot.dart';
import '../../robots/home_robot.dart';
import '../../robots/login_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerAuthFlows();
}

/// Signing in, and the two ways it can fail.
///
/// The refusal and the validation are not the same test and must not be
/// allowed to collapse into one: one proves the app can show what the server
/// said, the other proves it never asked.
void registerAuthFlows() {
  group('sign in', () {
    testWidgets('good credentials land on the shell', (tester) async {
      final harness = await AppHarness.bootSignedOut(tester);
      final login = LoginRobot(harness);
      final home = HomeRobot(harness);
      final dashboard = DashboardRobot(harness);

      await login.assertVisible();
      await login.signIn(
        email: 'a.okonkwo@example.org',
        password: 'correct-horse',
      );

      await home.assertVisible();
      await dashboard.assertOnBoard();
      home.seeSite('St Aidan’s General');

      final request = harness.api.requireCall('POST', '/api/auth/login');
      expect(request.jsonBody['email'], 'a.okonkwo@example.org');
      expect(
        request.isAuthenticated,
        isFalse,
        reason: 'sign-in goes out unauthenticated, so a 401 from it reads as '
            '"wrong password" rather than tearing down a session that does '
            'not exist yet',
      );
    });

    testWidgets('a refused sign-in says so and stays on the form',
        (tester) async {
      final harness = await AppHarness.bootSignedOut(
        tester,
        // One endpoint of the world, re-registered. Later registrations win.
        overrides: (api) => api.on(
          'POST',
          '/api/auth/login',
          (_) => FakeResponse.unauthorized('Wrong email or password.'),
        ),
      );
      final login = LoginRobot(harness);

      await login.assertVisible();
      await login.signIn(
        email: 'a.okonkwo@example.org',
        password: 'not-the-password',
      );

      await login.seeSignInRefused(containing: 'Wrong email or password.');
      // Still here. A 401 on sign-in must not be mistaken for an expired
      // session and bounced through SessionManager.
      await login.assertVisible();
      login.seeNavigatorIntact();
    });

    testWidgets('empty fields are refused without asking the server',
        (tester) async {
      final harness = await AppHarness.bootSignedOut(tester);
      final login = LoginRobot(harness);

      await login.assertVisible();
      final before = harness.api.calls.length;

      await login.submit();

      await login.seeEmptyFieldErrors();
      login.seeNoSignInRefused();
      await login.assertVisible();

      harness.api.requireNoCall('POST', '/api/auth/login');
      expect(
        harness.api.calls.length,
        before,
        reason: 'a form that cannot validate is a form that posts empty '
            'credentials — the whole point of the validators is that the '
            'request never leaves',
      );
    });
  });
}
