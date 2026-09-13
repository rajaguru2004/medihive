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
`--dart-define` (the default is `10.0.2.2:8000`, which is the host machine
from an Android emulator):

```sh
flutter pub get
flutter run \
  --dart-define=MEDIHIVE_API=http://10.0.2.2:8000/ \
  --dart-define=MEDIHIVE_FILES=http://10.0.2.2:8000/
```

Sign-in is one step: work email and password. Accounts are issued by an
administrator in the web console — there is no self-registration and no
password reset in this app, because neither is something this app can do.

---

## The test suite

Three tiers. The first needs no device.

```sh
flutter analyze                      # must be clean — the baseline is zero

# every flow against a fake server, on a real device
flutter test integration_test/

# screenshots for a design pass, written to .review/
flutter drive \
  --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/screenshots/review_screenshots_test.dart \
  -d <device>
```

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
