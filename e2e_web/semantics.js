/**
 * Turning a CanvasKit canvas into something a browser driver can address.
 *
 * Flutter web paints into a WebGL canvas: no widget has a DOM node. The one
 * exception is the semantics tree, which Flutter mirrors into real elements
 * under `<flt-semantics-host>` — but only once something asks for it. What
 * asks for it is a 1x1 off-screen `<flt-semantics-placeholder role="button"
 * aria-label="Enable accessibility">`, which a screen reader would focus and
 * activate. Nothing else in the page will turn it on, so every test does.
 *
 * After activation the placeholder removes itself and `<flt-semantics-host>`
 * fills with `<flt-semantics>` elements carrying roles, aria-labels and, for
 * text fields, real `<input>`s. That subtree is the only surface these tests
 * can see or click.
 */

const SEMANTICS_HOST = 'flt-semantics-host flt-semantics';

/** Waits for the engine to boot, then switches the semantics tree on. */
async function enableSemantics(page) {
  // The placeholder is emitted by the engine's bootstrap, not by index.html,
  // so its presence is also the signal that the engine is alive.
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60_000 });

  // A real click would land on the glass pane; the placeholder is 1x1 at
  // (-1,-1) and deliberately out of reach. Dispatching the click is what a
  // screen reader's activation does.
  await page.evaluate(() => {
    /** @type {HTMLElement | null} */
    const el = document.querySelector('flt-semantics-placeholder');
    if (!el) throw new Error('semantics placeholder vanished before activation');
    el.click();
  });

  // Semantics nodes appear on the next frame Flutter builds, not synchronously.
  await page.waitForSelector(SEMANTICS_HOST, { state: 'attached', timeout: 60_000 });

  // ...and the first frame they appear on is usually the splash, which has
  // two nodes and no content. Anything that reads the whole tree rather than
  // waiting on a named element would sample that and see an "empty" app.
  // Waiting for the node count to stop changing is what makes a tree-wide
  // read meaningful; tests that assert on a specific label should still
  // anchor on that label with `expect().toBeVisible()`, which retries.
  await settleSemantics(page);
}

/** Waits until the semantics tree stops growing — i.e. a screen finished. */
async function settleSemantics(page, { minNodes = 4, timeout = 45_000 } = {}) {
  const started = Date.now();
  let previous = -1;
  let stableFor = 0;
  while (Date.now() - started < timeout) {
    const count = await page.evaluate(
      () => document.querySelectorAll('flt-semantics-host flt-semantics').length,
    );
    stableFor = count === previous ? stableFor + 1 : 0;
    previous = count;
    if (count >= minNodes && stableFor >= 2) return count;
    await page.waitForTimeout(250);
  }
  throw new Error(`semantics tree never settled (last count ${previous}, wanted >= ${minNodes})`);
}

/**
 * Every label the semantics tree currently exposes. Used by assertions and,
 * when something fails, printed so the failure says what the tree *did* hold.
 */
async function semanticsLabels(page) {
  return page.evaluate(() => {
    const out = [];
    document.querySelectorAll('flt-semantics-host flt-semantics, flt-semantics-host input, flt-semantics-host form').forEach((el) => {
      const aria = el.getAttribute('aria-label');
      if (aria) out.push(aria);
      // Leaf text nodes carry plain text (buttons) or a <span> (labels).
      const own = Array.from(el.childNodes)
        .filter((n) => n.nodeType === Node.TEXT_NODE)
        .map((n) => (n.textContent || '').trim())
        .filter(Boolean);
      out.push(...own);
      el.querySelectorAll(':scope > span').forEach((s) => {
        const t = (s.textContent || '').trim();
        if (t) out.push(t);
      });
    });
    return Array.from(new Set(out));
  });
}

/**
 * Signs in through the real form.
 *
 * Two details are not optional. The field must be clicked before it is
 * filled: Flutter keeps one live `<input>` for the *focused* field and the
 * semantics `<input>` is only wired to the text model once it has focus, so
 * a bare `fill()` on an unfocused field is silently dropped. And `fill()`
 * rather than `pressSequentially()`: synthesised keystrokes go through the
 * engine's key handling and were observed to lose a character
 * (`Doctor@HMS2024!` arriving 14 long instead of 15).
 */
async function signIn(page, email, password) {
  const emailField = page.getByLabel('Work email');
  await emailField.click();
  await emailField.fill(email);
  const passwordField = page.getByLabel('Password', { exact: true });
  await passwordField.click();
  await passwordField.fill(password);

  // Guard against the silent-drop failure above: if the model did not take
  // the text, say so here rather than as a confusing "Invalid credentials".
  if ((await emailField.inputValue()) !== email) {
    throw new Error('email field did not receive the text (Flutter text model out of sync)');
  }

  await page.getByRole('button', { name: 'Sign in' }).click();
}

module.exports = { enableSemantics, settleSemantics, semanticsLabels, signIn, SEMANTICS_HOST };
