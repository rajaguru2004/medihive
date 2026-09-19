// Static file server for the built Flutter web bundle (build/web).
// Minimal on purpose: Playwright's `webServer` starts it, nothing else uses it.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', 'build', 'web');
const LIB = path.resolve(__dirname, '..', 'lib');
const PORT = Number(process.env.PORT || 8088);

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain; charset=utf-8',
};

// ── The bundle is an artifact, and a stale one tests yesterday's app ──────
//
// Nothing rebuilds `build/web` automatically. A run against a bundle older
// than the Dart source is not a weaker test, it is a misleading one: it can
// pass for code that no longer exists. So refuse to serve rather than lie.
function assertBundleFresh() {
  const bundle = path.join(ROOT, 'main.dart.js');
  if (!fs.existsSync(bundle)) {
    die(
      `No bundle at ${bundle}.\n\n` +
        'Build it first, from the medihive directory:\n' +
        `  ${BUILD_CMD}\n`,
    );
  }
  const builtAt = fs.statSync(bundle).mtimeMs;

  let newest = { at: 0, file: null };
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith('.dart')) {
        const at = fs.statSync(full).mtimeMs;
        if (at > newest.at) newest = { at, file: full };
      }
    }
  };
  if (fs.existsSync(LIB)) walk(LIB);

  if (newest.at > builtAt) {
    die(
      'build/web is STALE — the tests would assert against a previous ' +
        'version of the app.\n\n' +
        `  bundle built : ${new Date(builtAt).toISOString()}\n` +
        `  newer source : ${new Date(newest.at).toISOString()}  ${path.relative(
          path.resolve(__dirname, '..'),
          newest.file,
        )}\n\n` +
        'Rebuild, from the medihive directory:\n' +
        `  ${BUILD_CMD}\n\n` +
        'Set MEDIHIVE_ALLOW_STALE=1 to serve it anyway.',
    );
  }
}

const BUILD_CMD =
  'flutter build web \\\n' +
  `    --dart-define=MEDIHIVE_API=${process.env.MEDIHIVE_API_TARGET || 'http://127.0.0.1:3000/'} \\\n` +
  `    --dart-define=MEDIHIVE_FILES=${process.env.MEDIHIVE_API_TARGET || 'http://127.0.0.1:3000/'}`;

function die(message) {
  console.error(`\n[e2e_web] ${message}\n`);
  process.exit(1);
}

// ── Optional /api proxy, off by default ───────────────────────────────────
//
// History, because the reason matters if this ever comes back. `DioClient`
// sends `ngrok-skip-browser-warning` on every request. The backend's CORS
// allowlist used to be `Content-Type, Authorization, x-correlation-id`, so
// the preflight for a cross-origin call refused that header and Chromium
// blocked the request before sending it — net::ERR_FAILED, which the app
// surfaced as "Can't reach the server". Proxying the API onto this origin
// removed the preflight entirely and was the only way to test a signed-in
// screen from a browser.
//
// That is fixed: `hms_v2/src/main.ts` now lists the header in
// `app.enableCors({ allowedHeaders })`, and the app reaches :3000 directly
// as a genuine cross-origin client, preflight and all. That is the honest
// configuration and it is the default — the proxy would hide exactly the
// class of bug it was invented to dodge.
//
// Left available for the case where it is the subject rather than the
// obstacle: reproducing a CORS regression, or pointing the suite at a
// backend that cannot be reached cross-origin.
//
//   PROXY_API=1 node serve.js
//   # and build the bundle against THIS origin instead:
//   #   --dart-define=MEDIHIVE_API=http://127.0.0.1:8088/
const PROXY_API = process.env.PROXY_API === '1';
const API_TARGET = process.env.MEDIHIVE_API_TARGET || 'http://127.0.0.1:3000';

function proxy(req, res) {
  const target = new URL(req.url, API_TARGET);
  const headers = { ...req.headers, host: target.host };
  const upstream = http.request(
    {
      hostname: target.hostname,
      port: target.port || 80,
      path: target.pathname + target.search,
      method: req.method,
      headers,
    },
    (up) => {
      res.writeHead(up.statusCode || 502, up.headers);
      up.pipe(res);
    },
  );
  upstream.on('error', (e) => {
    res.writeHead(502, { 'Content-Type': 'text/plain' }).end('proxy error: ' + e.message);
  });
  req.pipe(upstream);
}

if (process.env.MEDIHIVE_ALLOW_STALE !== '1') assertBundleFresh();

http
  .createServer((req, res) => {
    if (PROXY_API && req.url && (req.url.startsWith('/api') || req.url.startsWith('/uploads'))) {
      return proxy(req, res);
    }
    const url = decodeURIComponent((req.url || '/').split('?')[0]);
    const rel = url === '/' ? 'index.html' : url.replace(/^\/+/, '');
    let file = path.join(ROOT, rel);
    if (!file.startsWith(ROOT)) {
      res.writeHead(403).end('forbidden');
      return;
    }
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      // Single-page app: unknown paths fall back to the shell so GetX routes work.
      file = path.join(ROOT, 'index.html');
    }
    res.writeHead(200, {
      'Content-Type': TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    fs.createReadStream(file).pipe(res);
  })
  .listen(PORT, () =>
    console.log(
      `serving ${ROOT} on http://127.0.0.1:${PORT}` +
        (PROXY_API ? `  (/api proxied to ${API_TARGET})` : '  (no /api proxy — app talks to the API cross-origin)'),
    ),
  );
