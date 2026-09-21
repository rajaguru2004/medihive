// @ts-check
const { test, expect } = require('@playwright/test');
const { enableSemantics, semanticsLabels } = require('../semantics');

/**
 * The one thing worth proving: that a browser driver can see and operate the
 * real first screen of this app, not just the canvas it is painted on.
 *
 * Every assertion below is on a widget the sign-in screen actually builds
 * (`lib/app/modules/login/views/login_view.dart`). If that screen changed —
 * a field renamed, the button relabelled, the toggle removed — these fail.
 */
test.describe('MediHive web — sign-in screen', () => {
  test('boots to sign-in and the form is drivable through the semantics tree', async ({ page }) => {
    const consoleErrors = [];
    page.on('pageerror', (e) => consoleErrors.push(String(e)));

    await page.goto('/');
    await enableSemantics(page);

    // ── The screen is the one we think it is ────────────────────────────
    // Wordmark + tagline are plain Text widgets; they reach the DOM as spans
    // inside <flt-semantics>.
    await expect(page.locator('flt-semantics-host').getByText('MediHive', { exact: true })).toBeVisible();
    await expect(
      page.locator('flt-semantics-host').getByText('Hospital operations', { exact: true }),
    ).toBeVisible();

    // ── The two fields are real <input>s with the app's own labels ───────
    const email = page.getByLabel('Work email');
    const password = page.getByLabel('Password', { exact: true });
    await expect(email).toBeVisible();
    await expect(password).toBeVisible();
    // The password field is obscured because LoginController starts hidden.
    await expect(password).toHaveAttribute('type', 'password');

    // ── The single affordance ───────────────────────────────────────────
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible();
    // The patient route out of this screen.
    await expect(page.getByRole('button', { name: 'Use my hospital card' })).toBeVisible();

    // ── Typing actually reaches the Flutter text model ───────────────────
    // Not a DOM-only echo: Flutter owns the value and writes it back, so a
    // field that never received the keystrokes would come back empty.
    await email.click();
    await email.fill('nurse@example.org');
    await expect(email).toHaveValue('nurse@example.org');

    // ── A tap changes Flutter-side state, and the tree re-renders ────────
    // `Show password` ↔ `Hide password` is driven by an Rx bool in
    // LoginController. If the click did not reach the widget, the label
    // would not flip and the input would stay type=password.
    const toggle = page.getByRole('button', { name: 'Show password' });
    await expect(toggle).toBeVisible();
    await toggle.click();
    await expect(page.getByRole('button', { name: 'Hide password' })).toBeVisible({ timeout: 15_000 });
    await expect(page.getByLabel('Password', { exact: true })).toHaveAttribute('type', 'text');

    // A blank canvas that silently threw would still satisfy a title check;
    // it would not satisfy the above, but fail loudly on engine errors too.
    expect(consoleErrors, `page errors: ${consoleErrors.join(' | ')}`).toEqual([]);
  });

  test('negative control: the semantics tree does not contain a label this app never renders', async ({ page }) => {
    // Guards the suite against the failure mode where the assertions above
    // pass for a reason unrelated to the app (empty tree, stale page, a
    // matcher that matches anything). If this ever passes vacuously, the
    // dump below shows what the tree really held.
    await page.goto('/');
    await enableSemantics(page);
    // Anchor first: the tree exists from the splash screen onward, and
    // reading it before the sign-in screen paints samples an empty app.
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible();
    const labels = await semanticsLabels(page);
    expect(labels.length, `semantics tree was empty: ${JSON.stringify(labels)}`).toBeGreaterThan(5);
    expect(labels).toContain('Sign in');
    expect(labels).not.toContain('Patient discharge summary');
  });
});
