---
name: medihive_codebase_rules
description: >
  Authoritative rules for all agents/AI working on the MediHive hospital
  operations app. Covers: the centralized design system, Dio networking,
  logging, runtime theming, GetX architecture, screen separation, clinical
  safety rules, and the test contract. Read this before touching any file in
  the project.
---

# MediHive — Agent Codebase Rules

> **MANDATORY**: Read this file completely before writing any code.
> All rules below are non-negotiable project standards.

---

## 0. The clinical rules

Three rules outrank everything else in this document. They are about patient
safety, not about taste, and a change that breaks one is a defect however good
it looks.

1. **Red means one thing.** `AppColors.acuityCritical` and `AppColors.error`
   are the only reds in this app. Not a chart series, not a decorative accent,
   not a "delete" affordance that is not actually destructive. A clinician
   scans a ward board for red; every red that is not a deteriorating patient
   costs that scan its meaning. A missed appointment is **amber**.

2. **Teal is the brand, never an acuity.** Status lives in its own ramp
   (`acuityCritical` … `acuityDischarged`) with no teal in it. A teal "stable"
   pill beside a teal primary button makes the brand unreadable as an
   affordance.

3. **A clinical state is colour *and* rank *and* word.** `AcuityPill` carries
   its P-code as a glyph; `BedState` carries an icon; `StatusPill` carries its
   label. A pill that is only a colour is unreadable to eight percent of men,
   to every screenshot, and to anyone reading a ward screen across a corridor.

A fourth: **a category is not a state.** `CaseStatus` resolves clinical
states — a triage level, an admission state, an appointment state. A *visit
type*, a ward type, a bed type and a service area are categories, and routing
one through the ramp paints it with a meaning it does not have: `emergency` as
a visit type means "came through the ED", and the ramp reads it as "immediate".
Give a category one neutral tint and let the word carry it.

A fifth, narrower: **`VitalRange` is the only place that decides whether an
observation is normal.** Three screens each judging for themselves is three
screens that eventually disagree, and a clinician who has learned to trust the
colour is one the third screen misleads.

---

## 0.1 Access, in the app

The server owns authorisation; the app's job is never to offer a clinician a
door that is going to be shut in their face.

1. **Navigation is derived from the access map, never from the role name.**
   `GET /api/auth/me` returns `access.modules`, and `ShellLayout.resolve` reads
   it. Roles are customisable in this product — a hospital can define
   `TRIAGE_NURSE` with patient-creation rights — so a shell that switches on
   `role == 'NURSE'` breaks the first time somebody uses that feature.

2. **Controls are absent, not disabled.** A greyed button is a question the
   person holding the tablet cannot answer; an absent one teaches them the
   shape of their job. `AccessService.to.can(module, verb)` decides.

3. **Every gated write still handles a 403.** The server caches its access map
   for five minutes, so the map in hand can be older than the role it
   describes. A 403 on a write is a toast and an `AccessService.load()`, never
   the end of the session.

4. **A module the site switched off takes its figures with it.** A tab that
   disappears while the board underneath still counts occupied beds is a
   switch that only half worked. `modulesEnabled` with an **absent key means
   on** — the backend's own default has `inpatient: false`, and reading a
   missing key as off would hide the ward board from every site that never
   opened the settings screen.

5. **A 403 arrives as an ordinary response**, not a `DioException`:
   `DioClient.validateStatus` passes everything below 500 except 401. Detect it
   by status inside `ApiEnvelope`; `orThrow()` raises `ApiForbiddenException`
   and `runGuarded` turns that into `rxNoAccess`.

---

## 0.2 Writing to this backend

`main.ts` runs `whitelist` **and** `forbidNonWhitelisted`, so **one key the DTO
does not declare is a 400 for the whole request**.

- Writes go through a `XxxDraft` in `lib/app/data/models/drafts/`, whose
  `toCreateJson()`/`toUpdateJson()` emit only the keys that DTO accepts.
  **Never spread a model's `toJson()` into a write.**
- `test/unit/data/write_contract_test.dart` pins each key set, so drift fails
  in the unit tier rather than as a 400 on a ward.
- Several routes bind individual `@Query('x')` parameters rather than a DTO;
  those ignore extras rather than refusing them. `CrudRepository.listUnpaged`
  exists for the collections that page nothing — asking them for `page` and
  `orderBy` is noise at best.
- `PUT /api/settings/organization` is a **partial deep merge**. Send only what
  changed, or you stamp defaults over keys another screen owns.

---

## 1. Project Stack

| Layer | Package |
|---|---|
| State / DI / Nav | `get` (GetX) |
| HTTP client | `dio`, behind a single `DioClient` |
| Debug logging | `LoggingInterceptor` (HTTP) + `AppLog` (everything else) |
| Secure storage | `flutter_secure_storage` (token + cached user) |
| Snapshot storage | `shared_preferences` (brand + face, restored pre-first-frame) |
| Fonts | Ten bundled faces — **no runtime font fetch** |
| Architecture | GetX MVC — one module per screen under `lib/app/modules/<name>/` |

Backend: the MediHive Express API. Envelope is `{success, data, message}` —
**`data`**, with `result` accepted as a legacy fallback in `ApiEnvelope`.
Auth is one call (`POST /api/auth/login` → bearer token).

---

## 2. The Design System

**Barrel import** — always the single barrel, never an individual file:

```dart
import 'package:medihive/app/theme/theme.dart';
```

### 2.1 Colour (`AppColors`, `BrandPalette`)

| Token | Use |
|---|---|
| `colorScheme.primary` | The brand as a **fill** — CTAs, the active tab |
| `colorScheme.onPrimaryContainer` | The brand as **words and icons** |
| `brandInkColor(context)` / `brandFillColor(context)` | The same two, by context |
| `AppColors.acuityCritical/Urgent/Standard/Routine/Stable/Discharged` | Clinical state |
| `AppColors.bedVacant/Occupied/Reserved/Blocked` | Bed state |
| `AppColors.success/warning/error/info` | Semantic feedback |
| `AppColors.accent` | Ledger blue — billing, never a clinical state |

**Rules:**
- ❌ NEVER hardcode `Color(0xFF…)` in a widget. Use a token.
- ❌ NEVER use `Colors.red` / `.green` / `.blue`.
- ❌ NEVER use `AppColors.primary` for a status, a chart series, or a chip
  that is not the primary action.
- ❌ NEVER use the brand as text by reading `colorScheme.primary` — that is
  the fill. `#0E7C7B` passes on paper (4.63:1) and fails on slate (3.79:1) —
  and which way round a brand fails is not predictable from looking at it.
  Read `brandInkColor(context)`.
- ✅ **A ramp or semantic colour used as text goes through
  `semanticInk(context, colour)`.** The ramp is chosen for a light ground;
  `#0070C0` on a dark card is 2.7:1. Fills and legend dots keep the raw
  colour — they are seen, not read.

### 2.2 Typography (`AppTextStyles`, `AppFonts`)

One eleven-step scale, light and dark variants of each:

```
largeTitle 34 → title1 28 → title2 22 → title3 20 → headline 17
→ body 17 → callout 16 → subheadline 15 → footnote 13
→ caption1 12 → caption2 11
```

**Rules:**
- ❌ NEVER write `TextStyle(fontSize: …)` inline.
- ❌ NEVER set `fontFamily` by hand — the site chooses the face, and
  `ThemeService` applies it.
- ❌ NEVER `copyWith(fontWeight: …)` onto a style. Ask the factory for the
  weight instead. Every style carries the face's `wght` axis beside its
  weight; a `copyWith` moves one and not the other, so the text claims bold
  and draws regular. Montserrat's default instance is **Thin**.
- ✅ **Any figure that lines up in a column or ticks uses tabular numerals** —
  `AppTextStyles.vital(...)`, `.money(...)`, `AppFonts.numeric(...)` or
  `numeralStyle(context, ...)`.
- ✅ A vital is `AppTextStyles.vital` and its unit is `AppTextStyles.unit`.
  Never bold **and** coloured: that reads as two alarms.

### 2.3 `AppTheme`

`AppTheme.build(brightness, brand:)` is the only place component theming
happens.

| Constant | Value | Use for |
|---|---|---|
| `AppTheme.radiusSmall` | 10 | Chips, tags |
| `AppTheme.radiusMedium` | 16 | Inputs, buttons |
| `AppTheme.radiusLarge` | 24 | Cards, modals |
| `AppTheme.minTapTarget` | 48 | Every interactive control |

- ❌ NEVER build an ad-hoc `ThemeData` or wrap a subtree in `Theme(data: …)`.
- ❌ NEVER hardcode `BorderRadius.circular(12)` — use `AppTheme.radius*` or
  `BentoRadius.*`.
- ❌ NEVER override `style:` on a button to restate what the theme says.

### 2.4 Runtime theming (`AppThemeController`, `ThemeService`)

- **`AppThemeController`** owns light / dark / system. Persisted, restored
  before `runApp`.
- **`ThemeService`** owns *what the two modes are made of* — the site's brand
  and face. Resolved once at boot, rebuilt only when the three branding keys
  change.

- ❌ NEVER call `Get.changeTheme()` or `Get.changeThemeMode()` directly.
- ❌ NEVER rebuild a `ThemeData` in a widget or a controller.
- ❌ NEVER wrap `GetMaterialApp` in an `Obx` — it rebuilds the navigator on
  every sign-in and races `Get.offAllNamed`.
- ✅ New branding reaches the app through `SettingsService.adopt`, once.

### 2.5 The bento kit

`DESIGN.md` is the contract; `app_bento*.dart` is its executable form. **A
screen that hand-rolls a border, a lift, a status pill or a row that already
lives in the kit is a defect, not a variation.**

```
Screen shell  → BentoScreen(slivers:), BentoSection, BentoGround
Cards         → BentoCard, BentoRow, FactRow, InsetSurface, Hairline
Figures       → VitalFigure, VitalTile, VitalsGrid, MoneyFigure, RatioBar, UsedBar
Clinical      → AcuityPill, AcuityLegend, WaitChip, QueueTicketRow,
                BedState/BedTile/BedGrid, WardCapacityBar,
                PatientIdentityBand, VitalInput, VitalRange
Status        → StatusPill, StatusMark, CountBadge, CaseStatus
States        → EmptyState, ErrorRetryBanner, NoticeBanner, BentoSkeleton
Actions       → PrimaryBar, SecondaryBar, ActionCard, QuickActionTile
Navigation    → DetailHeader, SectionHeader, FilterChips, CircleIconButton
Forms         → FormCard, BentoField, BentoInput, BentoPicker, BentoSegmented
Sheets        → SheetShell, SheetRow, ConfirmDialog
```

- ❌ Do NOT use Flutter's `Card`. Use `BentoCard`.
- ❌ Do NOT set `Scaffold(backgroundColor:)`. Use `BentoGround`.
- ❌ **Do NOT add a `BackdropFilter`.** There are none in this app. A blur
  reads back and re-blurs everything under it on every frame the content
  moves; on a ward tablet running a list that refreshes every thirty seconds
  that is a cost paid continuously for decoration. The bento material gets its
  glass from a translucent top-lit fill instead.
- ❌ Do NOT use `CrossAxisAlignment.stretch` on a `Row` inside a sliver — it
  is laid out at infinite height and asserts. Use `IntrinsicHeight`.
- ❌ Do NOT use `Get.snackbar`. Use `showBentoToast`.
- ✅ Any `Text` that can hold site data (a patient name, a ward name) is
  `maxLines` + `TextOverflow.ellipsis`, or `Flexible`.
- ✅ Honour `motionDuration(context)` — it respects Reduce Motion, which the
  e2e harness turns on.
- ✅ A screen inside the shell passes `bottomClearance: false` to
  `BentoScreen`: the `Scaffold` has already reserved the tab bar's height.

---

## 3. Networking

### 3.1 `DioClient`

One instance, registered in `main()`:

```dart
final client = Get.find<DioClient>();
final response = await client.get(Endpoints.queue.list);
final envelope = ApiEnvelope.of(response).orThrow();
final rows = envelope.listOf(QueueItem.fromJson);
```

- ❌ NEVER construct a bare `Dio()` — it skips the bearer header, the 401
  teardown and the logger.
- ❌ NEVER add an interceptor outside `DioClient._attachInterceptors()`.
- ❌ NEVER write a path inline. Add it to `Endpoints`.
- ✅ Unauthenticated calls pass `AuthInterceptor.unauthenticated`, so a 401
  reads as "wrong password" rather than tearing down a session.
- ✅ Services that still hand back a raw `Response` unwrap through
  `data/utils/legacy_envelope.dart` — never by reaching into
  `res.data['data']['data']` at a call site.

### 3.2 Logging

| File | Covers |
|---|---|
| `data/network/interceptors/logging_interceptor.dart` | Every request / response / error |
| `core/app_log.dart` | Everything else, tagged and levelled |

Both are debug-only and both go quiet when `AppLog.enabled` is false (which
the e2e harness sets).

```dart
AppLog.info('SettingsService', 'brand → ${brand.name}');
AppLog.error('QueueController', 'queue load failed', e, stack);
```

- ❌ NEVER `print()`. NEVER `debugPrint()` outside the two files above. A
  `print` in a release build is an unredacted log line on a device that holds
  patient data.
- ❌ NEVER log a token, a password, or **any patient identifier** — a name, an
  MRN, a date of birth. The interceptor redacts `Authorization`, `password`
  and `token`; it does not know what a patient is, so this one is on you.
- ✅ Pass the `catch (e, stack)` pair to `AppLog.error`.

### 3.3 Errors

- ❌ NEVER show a raw exception to a user.
- ❌ NEVER report a load failure only through a toast — it disappears in three
  seconds and takes the retry with it, leaving an empty list that looks like
  "there is nobody waiting".
- ✅ Every fetching controller mixes in `LoadStateMixin` and uses
  `runGuarded`, which drives `ErrorRetryBanner`.

---

## 4. GetX Architecture

### 4.1 Module structure

```
lib/app/modules/<module_name>/
├── bindings/<module_name>_binding.dart
├── controllers/<module_name>_controller.dart
└── views/<module_name>_view.dart
```

### 4.2 Controllers

- ✅ Extend `GetxController`; add `LoadStateMixin` when it fetches.
- ✅ Keep them thin: state and calls, no widgets.
- ✅ Fetch in `onReady()`, never `onInit()` — the first widget to touch
  `controller` constructs it, and a write during that build marks the building
  `Obx` dirty.
- ❌ NEVER call `setState()`. Use `.obs` + `Obx`.
- ❌ NEVER name a method `refresh()` — `GetxController.refresh()` exists and
  returns void, so an `onRefresh:` callback silently never awaits it. Call it
  `reload()`.
- ❌ NEVER reach into a sibling controller to refresh it. Announce on the
  `DataBus`; the screens that care listen.

### 4.3 Bindings

A controller hosted in the shell's `IndexedStack` is `Get.put(..., permanent:
true)` **and** registered with `SessionManager.registerScoped<T>()` —
otherwise the next clinician to sign in on a shared ward tablet inherits the
previous one's patient list.

### 4.4 Session teardown

Every sign-out — user-initiated or forced by a 401 — goes through
`SessionManager.endSession()`. It is idempotent.

- ❌ NEVER call `AuthService.clearSession()` directly, except on the sign-in
  screen itself.
- ✅ A reactive section whose controller is user-scoped uses **`LiveObx<T>`**,
  not `Obx`.

---

## 5. Files & Imports

- ✅ Barrel import for the theme; relative imports within `lib/app/`.
- ✅ `snake_case.dart`, `PascalCase` classes, `camelCase` members.
- ✅ Run `flutter analyze` after every change. **It must be clean** — the
  baseline is zero, and a baseline with three known warnings in it is a
  baseline nobody reads.
- ❌ NEVER commit a `// TODO: remove` or a leftover `print()`.

---

## 6. Screen Separation & Navigation

### 6.1 One screen = one module (non-negotiable)

- ❌ NEVER bundle several screens into one view behind `_buildXTab()` methods.
  The previous `HomeView` was 1,981 lines and held four screens.
- ❌ NEVER create a god controller owning state for several screens.
- ✅ Each screen: `XView extends GetView<XController>`, its own `XBinding`,
  its own `Routes.X` + `GetPage`.

### 6.2 The shell

`HomeController` owns only the active tab, the signed-in user and the sheets
the top bar opens.

- ✅ Destinations are a **table** (`HomeBinding.shellDestinations()`). Adding a
  module is one entry there plus its registration.
- ✅ Tabs live in a `LazyIndexedStack`, so switching keeps scroll position and
  does not refetch. That is why their controllers are `permanent`.
- ✅ Every tab is also a standalone `GetPage`, so a deep link can open it.

### 6.3 App bars — no duplicated top bars

- ❌ NEVER copy the shell's top bar onto a pushed sub-screen.
- ✅ A pushed screen gets a `DetailHeader`.
- ✅ The shell bar shows the **active tab's** title; the tab body must not
  repeat it.

---

## 7. The Test Contract

| Tier | Command | Covers |
|---|---|---|
| Analyze | `flutter analyze` | Must be clean |
| Flows (device) | `flutter test integration_test/` | The real app against a fake server |
| Screenshots | `flutter drive --driver=test_driver/screenshot_driver.dart --target=integration_test/screenshots/review_screenshots_test.dart` | Every screen, both themes, into `.review/` |
| Keys | `dart run tool/check_keys.dart` | Unkeyed count may only go down; no key string declared twice; no `pumpAndSettle`; no `find.*` in a flow |

Run every tier on the **Pixel 6 Pro** (`emulator-5554`). One device is the
gate; a tablet pass is a deliberate one-off, not part of the loop.

`integration_test/flows/routes/every_route_builds_test.dart` runs first in the
suite. It walks `AppPages.routes`, opens each one, and fails on any exception
or on a screen with no `Material` above it. It is the cheapest test in the
suite and it catches the two failures a module flow cannot see: a screen nobody
wrote a flow for, and a screen that renders but renders wrongly for a
structural reason.

### 7.1 Widget keys

Keys live in `lib/app/core/keys/<module>_keys.dart` — production API, because
the widgets reference them. `find.text` is ambiguous here by construction: a
patient's name appears on the row and again on the detail it opens.

### 7.2 Flow tests

- ❌ **A flow test never calls `find.*`.** Finders live in robots.
- ❌ **`pumpAndSettle` is banned.** Any widget that schedules a frame forever
  makes it hang until the twelve-minute timeout with no message. Use
  `pumpUntil`, `pumpUntilFound`, `pumpUntilRouteSettled`.
- ✅ Close what you opened: a sheet owns tickers that `flutter_test` checks for
  at the end of the test *body*, earlier than `addTearDown`.
- ✅ Every request needs a fixture. `AppHarness.dispose` fails the test on an
  unstubbed call, with the full list.
- ✅ Fixtures live in one coherent `World`. A flow that needs one endpoint
  different **overrides that one endpoint**; later registrations win — which is
  why `World.install` orders its module fixtures deliberately: the patient
  register re-registers six list routes it does not own so the hub's tabs can
  ask for one patient's rows, and every module below it reclaims its own
  worklist.
- ✅ A sliver below the fold is **not built**, so an assertion that only looks
  reports what is there as missing. Scroll first: `tester.scrollToKey`, or
  `scrollToKeyInStrip` for a row of chips that scrolls sideways.
- ✅ `enterTextByKey` drops focus, types, and checks what landed. A field is
  allowed to refuse what it was given — a dispense quantity capped at the shelf
  answers 999 with 60 — but a field that silently keeps its old text is a form
  that cannot be saved for no visible reason.

---

## 8. Quick Reference

```
Theme     → import 'package:medihive/app/theme/theme.dart'
Brand fill→ Theme.of(context).colorScheme.primary   (shapes)
Brand ink → brandInkColor(context)                  (words) — NOT primary
Acuity    → AcuityPill(code: 'P1') / CaseStatus.colorOfCode(…)   never teal
Ramp text → semanticInk(context, AppColors.acuityCritical)  fills keep raw
Vitals    → VitalTile / VitalFigure + VitalRange.temperature(…)
Beds      → BedState.resolve(status) → BedTile → BedGrid
Waiting   → WaitChip(waited:, breachMinutes:)       flags past the threshold
Text      → AppTextStyles.light*() / dark*()        pick per brightness
Radius    → AppTheme.radius* / BentoRadius.*
Theme ⚙   → AppThemeController.to.setDark()         never Get.changeTheme
HTTP      → Get.find<DioClient>() + ApiEnvelope.of(res).orThrow()
Raw svc   → envelopeRows(res.data) / envelopeOk(res.data, statusCode:)
Logs      → AppLog.info/warn/error                  never print()
Load state→ with LoadStateMixin → runGuarded(…)     drives ErrorRetryBanner
Toast     → showBentoToast(…)                       never Get.snackbar
Teardown  → SessionManager.endSession()             LiveObx for scoped views
Stale tab → DataBus.to.changedRecord('queue')       never refresh a sibling
Module    → 1 screen = 1 module (binding/controller/view/route)
AppBar    → shell = tab title + global actions; sub-screen = DetailHeader
Tests     → robots only, no find.*, no pumpAndSettle, close your sheets
Blur      → zero. There are no BackdropFilters in this app.
Red       → acuityCritical and error only. Never anything else.
Access    → AccessService.to.can(module, verb)      absent, not disabled
Shell     → ShellLayout.resolve(access, modulesEnabled)  never the role name
Writes    → XxxDraft.toCreateJson()                 never a model's toJson()
Unpaged   → CrudRepository.listUnpaged()            routes that page nothing
Obx       → must read an observable or it **throws**; branch outside it
Pushed    → `embedded: false`, or the screen has no Material and every
            label on it is drawn with a yellow underline through it
```
