# MediHive — mobile

The phone and tablet companion to the MediHive hospital operations platform.
Flutter, GetX, one Dio client, a runtime-themed design system driven by the
site's own settings.

```
com.medihive.app · "MediHive"
```

---

## Run it

The app talks to the MediHive backend. Point it at yours with a
`--dart-define` (`10.0.2.2` is the host machine as seen from an Android
emulator):

```sh
flutter pub get
flutter run -d emulator-5554 \
  --dart-define=MEDIHIVE_API=http://10.0.2.2:3000/
```

### On a physical handset

**`10.0.2.2` does not exist on a real phone.** It is the *emulator's* alias for
the host machine, and it is also `Endpoints.baseUrl`'s default — so a debug
build installed on a handset with no `--dart-define` talks to nothing. Every
call hangs until it times out, and the app reads as "the hospital is down". It
says so in the debug log on the first frame (`main()` prints the warning
whenever `Endpoints.isLoopback`), which is the line to look for before
suspecting the screen.

Either tunnel the host's port over USB:

```sh
adb reverse tcp:3000 tcp:3000
flutter run -d <device-id> \
  --dart-define=MEDIHIVE_API=http://localhost:3000/
```

…or point it at the machine's LAN address — same wifi, and the backend must be
listening on `0.0.0.0` rather than only on loopback:

```sh
flutter run -d <device-id> \
  --dart-define=MEDIHIVE_API=http://192.168.1.x:3000/
```

Android debug builds permit cleartext to these hosts; a release build does not,
and should never be pointed at one.

### Against the local backend

```sh
cd ../hms_v2
docker compose -f docker-compose.local.yml up -d postgres redis
npx prisma migrate deploy && npx prisma generate
npm run db:seed && npm run db:seed:catalog && npm run db:seed:mobile
docker exec hms_v2_redis_local redis-cli FLUSHDB   # the demo seed writes past the API's cache
npm run start:dev                                   # confirm the Prisma log says localhost:5432/hms_v2_dev
```

Seeded sign-ins: `admin@hms.local` / `Admin@HMS2024!`, `doctor@hms.local` /
`Doctor@HMS2024!`, `nurse@hms.local` / `Nurse@HMS2024!`, and the demo's own
`triage-nurse@hms.local` / `ward-clerk@hms.local` on `Demo@HMS2024!`.

`npm run verify:mobile` in `hms_v2` asserts the whole contract this app is
written against — 153 checks across ten roles, every one against a running
API.

Sign-in is one step: work email and password. Accounts are issued by an
administrator in the web console — there is no self-registration and no
password reset in this app, because neither is something this app can do.

---

## The test suite

Four tiers. The first two need no device.

```sh
flutter analyze                      # must be clean — the baseline is zero
flutter test test/                   # pure logic; no device
dart run tool/check_keys.dart        # key hygiene; the unkeyed count only goes down

# every behavioural flow against a fake server, on a real device
flutter test integration_test/suites/smoke_suite.dart -d emulator-5554

# screenshots for a design pass, written to .review/
flutter drive \
  --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/screenshots/review_screenshots_test.dart \
  -d emulator-5554

# the same sheet at the text size a ward tablet is usually left at
flutter drive ... -d emulator-5554 --dart-define=NEX_HIVE_TEXT_SCALE=1.3
```

**One device is the gate: the Pixel 6 Pro** (`emulator-5554`). A tablet run is
a deliberate one-off for the rail and the list-detail panes, not part of the
loop.

The suite opens with `flows/routes/every_route_builds_test.dart`, which walks
the whole route table and fails on any screen that throws or renders with no
`Material` above it. It is the cheapest test here and it catches what a module
flow cannot: a screen nobody wrote a flow for.

The screenshot suite captures every screen in both themes, from the same
fixtures the flow suite uses — so a screenshot is a picture of the app under
known data, not a picture of whatever the server held that morning. Files land
in `.review/` and are deliberately not committed: a screenshot is evidence of
one build, not an artefact of the repo.

### How the fake server works

`integration_test/fakes/` installs an in-memory router as Dio's
**`HttpClientAdapter`** — below the interceptor chain, not in place of the
client. The bearer header is attached for real, and a 401 returned by a fixture
produces a genuine `DioException` that `AuthInterceptor` routes into
`SessionManager`. A stubbed client could not reach that path, and it is the
most important cross-cutting behaviour in the app.

`integration_test/fixtures/world.dart` is one coherent department: the
dashboard's bed counts match the wards, the queue's length matches the
dashboard's waiting figure. A flow that needs one endpoint different
**overrides that one endpoint** rather than writing a second world.

An endpoint the app calls with no fixture fails the test, with the full list.

---

## Layout

```
lib/app/
├── core/            keys registry, AppLog, LiveObx, WindowClass, AppClock
├── data/
│   ├── models/      SiteSettings (+ MoneyFormat), AuthUser, the domain models
│   ├── network/     DioClient, Endpoints, auth + logging interceptors
│   ├── repositories/CrudRepository
│   ├── services/    Auth, Session, Settings, DataBus, the domain services
│   └── utils/       ApiEnvelope, error handler, LoadStateMixin, Formatters
├── modules/         one screen = one module (binding + controller + view)
├── routes/          app_pages + app_routes + Auth/Guest middleware
└── theme/           the design system — read DESIGN.md
```

`.agents/RULES.md` is the contract for anyone (human or agent) writing code
here. `DESIGN.md` is the contract for anything anyone draws.

---

## Before you write code

1. `.agents/RULES.md` — the non-negotiables. §0 is about patient safety.
2. `DESIGN.md` — what the app is made of, and why.
3. `PRODUCT.md` — who it is for and what the backend actually does.
4. `docs/TASK_TRACKER.md` — where this port got to.

Three rules outrank everything else, and they are in `.agents/RULES.md` §0:

- **Red means one thing** — a deteriorating patient, or an error. Nothing else.
- **Teal is the brand, never an acuity.**
- **A clinical state is colour *and* rank *and* word**, never colour alone.
