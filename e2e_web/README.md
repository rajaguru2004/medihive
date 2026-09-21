# e2e_web — Playwright against the Flutter web build

**Status: a working proof, deliberately kept small.** The main test tier for
this UI is `../integration_test/` (Dart, real widgets, real `WidgetTester`).
This directory is scoped to two things and should stay that way:

1. **accessibility regression cover** — these tests are literally assertions
   about the screen-reader tree, which the Dart tier does not check; and
2. **a boot / cross-origin canary** — proof the web target still compiles,
   boots, and can talk to the API from a browser.

No flows should be ported here.

## Rebuild before every run. This is not optional.

`build/web` is a build artifact and **nothing regenerates it**. Run the suite
against a stale bundle and it will happily pass for code that no longer
exists — a misleading green, which is worse than a red.

`serve.js` refuses to start when `build/web/main.dart.js` is older than the
newest `.dart` file under `../lib`, and prints which file is newer. Treat
that as a backstop, not as permission to skip the build:
`MEDIHIVE_ALLOW_STALE=1` overrides it, and there is rarely a good reason to.

```bash
# from medihive/
flutter build web \
  --dart-define=MEDIHIVE_API=http://127.0.0.1:3000/ \
  --dart-define=MEDIHIVE_FILES=http://127.0.0.1:3000/

cd e2e_web
npm install
npx playwright install chromium
npm test
```

The backend must be up on `:3000` with the seeded demo accounts, because
`dashboard_smoke.spec.js` signs in for real.

## There is no DOM

Flutter web renders through CanvasKit; widgets are pixels in a WebGL canvas.
The only DOM mirror is the accessibility/semantics tree, and it is off until
the hidden `<flt-semantics-placeholder aria-label="Enable accessibility">` is
activated. `semantics.js#enableSemantics` does that, and every test must call
it first.

What the tree gives you is good but partial: `aria-label`s, `role="button"`,
real `<input>`s for text fields, and text content for `Text` widgets. What it
does not give you is anything without semantics — decoration, layout,
spacing, colour, charts, custom paint. **You cannot assert on appearance at
all**, only on labels and roles. Widget `Key`s (`LoginKeys.emailField` and
friends) are invisible from the browser, so selectors are user-visible
strings that copy edits will break.

## Cross-origin: fixed, and now asserted

The app is served from `:8088` and calls the API on `:3000`, so every request
is genuinely cross-origin and must survive a CORS preflight.
`dashboard_smoke.spec.js` asserts that the login POST returned 200, that no
request was refused before being sent, and that the API origin was *not* the
page origin — so the test cannot silently stop proving this.

It used to fail. `DioClient` sends `ngrok-skip-browser-warning` on every
request; the backend's allowlist was `Content-Type, Authorization,
x-correlation-id`, so the preflight refused that header and Chromium blocked
the call before sending it — `net::ERR_FAILED`, which the app surfaced as
"Can't reach the server". `hms_v2/src/main.ts` now lists the header in
`app.enableCors({ allowedHeaders })` and it works.

The `/api` proxy that was built to dodge that bug is still here but **off by
default** — proxying would hide exactly the class of bug it was invented to
work around. Turn it on only when it is the subject rather than the obstacle
(reproducing a CORS regression, or pointing the suite at a backend that
cannot be reached cross-origin):

```bash
PROXY_API=1 node serve.js
# and build the bundle against THIS origin instead:
#   --dart-define=MEDIHIVE_API=http://127.0.0.1:8088/
```

## Gotchas found the hard way

- **Click a text field before `fill()`.** Flutter wires the semantics
  `<input>` to its text model only on focus; a bare `fill()` on an unfocused
  field is silently dropped, and the app then reports a validation error for
  a field you believe you filled.
- **`fill()`, not `pressSequentially()`.** Synthesised keystrokes go through
  the engine's key handling and were observed to lose a character
  (`Doctor@HMS2024!` arriving 14 chars instead of 15).
- **The tree exists before the screen does.** Semantics turn on during the
  splash, when the tree holds two nodes. Anything that reads the whole tree
  must call `settleSemantics` first (`enableSemantics` does); anything that
  asserts on a label should anchor with `expect(locator).toBeVisible()`,
  which retries.
- **Arm `waitForResponse` before the click, never sample a log after it.**
  The response is still in flight while the button animates, and the "Sign
  in" label disappears as soon as the button goes busy — so a post-hoc check
  can see an empty network log for a request that did happen.

## Layout

| file | what it is |
| --- | --- |
| `serve.js` | static server for `../build/web`, staleness guard, optional `/api` proxy |
| `semantics.js` | `enableSemantics`, `settleSemantics`, `semanticsLabels`, `signIn` |
| `tests/login_smoke.spec.js` | first screen is present and drivable; plus a negative control |
| `tests/dashboard_smoke.spec.js` | real cross-origin sign-in through the API, lands on the dashboard |
