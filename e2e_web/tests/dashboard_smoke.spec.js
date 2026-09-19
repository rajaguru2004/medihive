// @ts-check
const { test, expect } = require('@playwright/test');
const { enableSemantics, semanticsLabels, signIn } = require('../semantics');

/**
 * Sign in for real, cross-origin, and land on the dashboard.
 *
 * This is the test that decides whether Playwright is worth anything here.
 * It goes through `POST /api/auth/login` against the running backend, waits
 * for `/api/auth/me` and the access map, then asserts on a screen whose
 * contents came from the server. Nothing is stubbed and nothing is proxied:
 * the page is served from :8088 and the API is :3000, so every call is a
 * genuine cross-origin request that has to survive a CORS preflight.
 *
 * That preflight is the point. `DioClient` sends `ngrok-skip-browser-warning`
 * on every request, which the backend's allowlist used to omit — Chromium
 * blocked the call before sending it. The assertions below fail loudly if
 * that regresses.
 *
 * Requires the backend on :3000 with the seeded demo accounts.
 */
test('signing in as the seeded doctor reaches the dashboard, cross-origin', async ({ page, baseURL }) => {
  const blocked = [];
  page.on('requestfailed', (r) => {
    // A CORS preflight rejection lands here as net::ERR_FAILED, with no
    // response ever reaching the page. This is the exact signature of the
    // bug this test guards.
    blocked.push(`${r.url()} :: ${(r.failure() || {}).errorText}`);
  });

  await page.goto('/');
  await enableSemantics(page);

  // Armed before the click, not read after it: the response is in flight
  // while the button is still animating, so sampling a log afterwards races
  // the network and reports an empty list for a request that did happen.
  const loginResponse = page.waitForResponse(
    (r) => r.url().includes('/api/auth/login') && r.request().method() === 'POST',
    { timeout: 45_000 },
  );

  await signIn(page, 'doctor@hms.local', 'Doctor@HMS2024!');

  // ── The request really was cross-origin, and really succeeded ────────
  const response = await loginResponse;
  expect(response.status(), await response.text()).toBe(200);
  // If this ever equals the page's own origin, the API is being proxied and
  // no preflight happened — which would make the assertion above worthless.
  expect(
    new URL(response.url()).origin,
    'API was same-origin: the preflight was never exercised, so this test no longer proves the CORS fix',
  ).not.toBe(new URL(String(baseURL)).origin);
  expect(blocked, `requests the browser refused to send: ${blocked.join(' | ')}`).toEqual([]);

  // ── The shell's destinations ─────────────────────────────────────────
  // These are `NavigationDestination` labels, so they arrive as semantics
  // buttons — a renamed or removed tab fails here.
  for (const tab of ['Today', 'Queue', 'Clinic', 'Patients']) {
    await expect(page.getByRole('button', { name: tab, exact: true })).toBeVisible({ timeout: 30_000 });
  }

  const labels = await semanticsLabels(page);
  const joined = labels.join(' | ');

  // Server data reached the UI: the account chip is built from /api/auth/me,
  // so this string does not exist anywhere in the Dart source.
  expect(joined, `semantics tree: ${joined}`).toMatch(/Dr\.\s+\w+/);

  // A dashboard section that only renders once the role's access map loaded.
  expect(labels).toContain('Quick actions');

  // And no sign-in error banner — a failed login would put "Invalid
  // credentials" or "Can't reach the server" here instead.
  expect(joined).not.toMatch(/Invalid credentials|reach the server/);
});
