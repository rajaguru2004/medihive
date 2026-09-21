// @ts-check
const { defineConfig, devices } = require('@playwright/test');

/**
 * Playwright against the *built* Flutter web bundle.
 *
 * `serve.js` serves `../build/web`, and A REBUILD IS MANDATORY BEFORE EVERY
 * RUN — the bundle is an artifact and nothing regenerates it, so a stale one
 * lets the suite pass for code that no longer exists. serve.js refuses to
 * start when `build/web` is older than the newest file in `lib/`, but that
 * check is a backstop, not a substitute:
 *
 *   flutter build web \
 *     --dart-define=MEDIHIVE_API=http://127.0.0.1:3000/ \
 *     --dart-define=MEDIHIVE_FILES=http://127.0.0.1:3000/
 *
 * The app reaches the backend cross-origin, CORS preflight and all — which
 * `dashboard_smoke.spec.js` asserts on purpose. serve.js can proxy /api onto
 * this origin instead (PROXY_API=1), but does not by default; the note there
 * explains when that was needed.
 *
 * Flutter web renders through CanvasKit, so there is no DOM for the widgets.
 * Everything here goes through the accessibility/semantics tree, which only
 * exists after the hidden "Enable accessibility" placeholder is activated —
 * see `semantics.js`.
 */
module.exports = defineConfig({
  testDir: './tests',
  // CanvasKit has to download and the engine has to boot before anything is
  // assertable, so the per-test budget is generous by web standards.
  timeout: 120_000,
  expect: { timeout: 30_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list']],
  use: {
    baseURL: 'http://127.0.0.1:8088',
    viewport: { width: 1280, height: 900 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'node serve.js',
    url: 'http://127.0.0.1:8088/index.html',
    reuseExistingServer: true,
    timeout: 30_000,
  },
});
