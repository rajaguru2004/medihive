# MediHive — Task Tracker

The running record of the design-system port: what was done, what is left, and
why each decision went the way it did. One row per unit of work. A row moves to
**Done** only when `flutter analyze` is clean for it.

**Branch:** `feat/design-system-port` · **Reference:** `idurar-erp-crm/nex_hive_app`

Legend: ✅ done · 🔄 in progress · ⬜ not started · ⛔ blocked / declined

---

## Phase 0 — Groundwork

| # | Task | Status | Notes |
|---|---|---|---|
| 0.1 | Read reference project end to end | ✅ | 218 files. Kit, test contract, `.agents/RULES.md` |
| 0.2 | Audit MediHive incumbent | ✅ | 95 files, 21.5k lines. Apple-system palette, `google_fonts` runtime fetch, 1,981-line home god-view, zero tests |
| 0.3 | Branch off `main` | ✅ | `feat/design-system-port`; `main` untouched |
| 0.4 | Bundle 10 font faces + OFL licences | ✅ | `assets/fonts/`. Kills the `google_fonts` runtime fetch |
| 0.5 | `pubspec.yaml` rewrite | ✅ | −`google_fonts` −`pretty_dio_logger` −`shimmer`; +`flutter_secure_storage` +`shared_preferences` +`integration_test` |
| 0.6 | `analysis_options.yaml` hardened | ✅ | `avoid_print`, `require_trailing_commas`, `prefer_const_*`, unused-import as error |
| 0.7 | `dart_test.yaml` tags | ✅ | `live`, `golden` |

## Phase 1 — Design system

| # | Task | Status | Notes |
|---|---|---|---|
| 1.1 | Port bento kit verbatim | ✅ | `app_bento{,_data,_forms,_adaptive,_crud,_toast}`, `app_surfaces`, `app_async_widgets` |
| 1.2 | Drop CRM-only kit layers | ✅ | `app_bento_documents` (invoice/quote), `_map`, `_permissions` not ported |
| 1.3 | `app_colors.dart` → "Chart & Vitals" | ✅ | Teal brand, acuity ramp, bed states. Two rules: teal is never an acuity; red means one thing |
| 1.4 | `brand_palette.dart` clinical presets | ✅ | `clinicalTeal` (default), `clinicalBlue`, `forest`, `plum`. Contrast-derived ink/fill kept |
| 1.5 | `DocStatus` → `CaseStatus` | ✅ | Triage words + P1–P5/ADM/OBS/DIS/TRF/REV codes, `priorityOf` sort, `isLocked` |
| 1.6 | `app_text_styles.dart` + clinical figures | ✅ | `vital()` and `unit()` added beside `money()` |
| 1.7 | Translate kit vocabulary | ✅ | invoice/quote/customer/tenant/amber → clinical equivalents in every doc comment |
| 1.8 | `site_settings.dart` | ✅ | Brand, font, triage scale, wait-breach, currency, date format |
| 1.9 | `theme_service.dart` | ✅ | Resolve-once-at-boot, adopt-on-change, no network for fonts |
| 1.10 | `theme.dart` barrel | ✅ | Single import; individual-file import is a smell |
| 1.11 | `app_bento_clinical.dart` | ✅ | AcuityPill, AcuityLegend, VitalFigure/Tile/Grid, WaitChip, QueueTicketRow, BedState/Tile/Grid, WardCapacityBar, PatientIdentityBand |
| 1.12 | Remove superseded token files | ✅ | `app_decorations.dart`, `app_spacing.dart` deleted — kit carries `BentoSpace`/`BentoRadius` |

## Phase 2 — Architecture

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Core helpers ported | ✅ | `app_log`, `window_class`, `app_clock`, `live_obx`, `paged_list_controller`, `nav_icons`, `unsaved_changes` |
| 2.2 | Data utils ported | ✅ | `api_envelope`, `error_handler`, `load_state`, `formatters` |
| 2.3 | `DioClient` + interceptors | ✅ | Envelope reads `data` (with `result` fallback); auth + logging interceptors wired |
| 2.4 | Move `network/`→`data/network`, `services/`→`data/services`, `models/`→`data/models` | ✅ | Matches reference layout; imports rewritten at correct depth |
| 2.5 | Repositories layer | ✅ | `CrudRepository<T>` over `DioClient`; writes announce on `DataBus` |
| 2.6 | `SessionManager` teardown contract | ✅ | Idempotent `endSession()`, scoped controller registry |
| 2.7 | `main.dart` rewrite | ✅ | Theme + brand restored before `runApp`; no `Obx` around `GetMaterialApp`; text scale clamped 0.85–1.3 |
| 2.8 | Widget-key registry | ✅ | 14 module files under `core/keys/`, exported from `app_keys.dart` |
| 2.9 | `tool/check_keys.dart` ratchet | ✅ | Baseline 4 unkeyed; per-module anchors added for grouped key files |

## Phase 3 — Screens

One screen = one module. The home god-view is split; every view moves onto the
kit. 22 screens.

| # | Screen | Status | Notes |
|---|---|---|---|
| 3.1 | Splash | ✅ | |
| 3.2 | Login | ✅ | |
| 3.3 | Home shell | ✅ | Split from 1,981-line god-view; `IndexedStack` + table-driven destinations |
| 3.4 | Dashboard | ✅ | Census, occupancy, queue load |
| 3.5 | Queue | ✅ | Acuity-sorted, wait-breach flag |
| 3.6 | Add to queue | ✅ | |
| 3.7 | Appointments | ✅ | |
| 3.8 | Consultations | ✅ | |
| 3.9 | Pre-triage | ✅ | |
| 3.10 | Pre-triage details | ✅ | |
| 3.11 | New screening step 1 | ✅ | |
| 3.12 | New screening step 2 | ✅ | |
| 3.13 | Edit screening | ✅ | |
| 3.14 | Inpatient overview | ✅ | |
| 3.15 | Inpatient wards | ✅ | |
| 3.16 | Inpatient beds grid | ✅ | Bed-state map, not a list |
| 3.17 | Inpatient admissions | ✅ | |
| 3.18 | Admit patient | ✅ | |
| 3.19 | Discharge patient | ✅ | |
| 3.20 | Add ward | ✅ | |
| 3.21 | Add bed | ✅ | |
| 3.22 | Placeholders (pharmacy, lab, radiology, billing, staff, integrations) | ✅ | Each names the module and says where the work happens today |

## Phase 4 — Test contract

| # | Task | Status | Notes |
|---|---|---|---|
| 4.1 | `integration_test/support/` harness | ✅ | `app_harness` boots the real app; `pump` (no `pumpAndSettle`); fake secure storage |
| 4.2 | Fake API adapter + fixtures | ✅ | Adapter sits below the interceptor chain; one coherent `World`; unstubbed call fails the test |
| 4.3 | Robots | 🔄 | Base `Robot` ported; per-screen robots follow the first flow test that needs them |
| 4.4 | Flow tests | ⬜ | Not written — the screenshot suite is the verification tier delivered |
| 4.5 | Screenshot driver | ✅ | `test_driver/screenshot_driver.dart` → `.review/` |
| 4.6 | Screenshot test | ✅ | 20 screens × 2 themes |

## Phase 5 — Verification

| # | Task | Status | Notes |
|---|---|---|---|
| 5.1 | `flutter analyze` clean | ✅ | Zero issues across lib/, integration_test/ and test_driver/ |
| 5.2 | Screenshot round 1 on Pixel 6 Pro | ✅ | 8/8 tests, 40 captures. Surfaced 6 defects |
| 5.3 | Fix defects found | ✅ | Truncated BP, red CTA, false red on empty data, ellipsised labels, empty capacity bar, fixture incoherence |
| 5.4 | Screenshot round 2 | ✅ | 8/8 tests, 40 captures, defects confirmed fixed |

## Phase 6 — Documentation

| # | Task | Status | Notes |
|---|---|---|---|
| 6.1 | `.agents/RULES.md` | ✅ | Opens with three clinical safety rules that outrank the rest |
| 6.2 | `DESIGN.md` | ✅ | Chart & Vitals: the world, the colour rules, the kit, the voice |
| 6.3 | `PRODUCT.md` | ✅ | Who holds the device, the scene, the envelope, the constraints |
| 6.4 | `README.md` | ✅ | Run it, test it, how the fake server works |

---

## Decisions

**Clinical world, not a port of Ink & Honey.** The reference's amber-on-paper
identity is built for a CRM. A ward board needs red to mean exactly one thing
and needs the brand never to appear as a patient state, so MediHive gets its
own palette built with the same machinery. Confirmed with the user before any
colour was written.

**Every screen, not the core flows.** Confirmed with the user. The home
god-view splitting is the largest single piece.

**`app_bento_documents` / `_map` / `_permissions` not ported.** Invoice line
editors, a Places-backed map picker, and an RBAC matrix have no caller in a
hospital operations app. Porting them would add 2,352 lines nobody imports and
three dependencies nobody needs.

**Red is reserved.** `acuityCritical` and `error` are the only reds. A missed
appointment (`DNA`) is amber — an administrative problem, not a deteriorating
patient. This is the single rule most likely to be broken by a later change.

## Phase 7 — Review and hardening

| # | Task | Status | Notes |
|---|---|---|---|
| 7.1 | Unit tests for pure logic | ✅ | 116 tests across 7 files: BrandPalette, CaseStatus, VitalRange, BedState, MoneyFormat, Formatters, ApiEnvelope |
| 7.2 | Craft review of all 45 module files | ✅ | Zero contract violations; 10 craft defects found |
| 7.3 | Make form validation work | ✅ | `BentoInput`/`BentoPicker` take a `validator:` and wrap a `FormField`; 14 validators wired |
| 7.4 | Layout and contrast fixes | ✅ | `bottomClearance`, `Opacity` over text, 4 tap targets, 2 missing retries, 1 stale index |

## What the screenshots caught

Sixteen defects, none of which `flutter analyze` or a unit test can see. Listed
because the pattern is the point: almost all of them are a **stored value or a
stored length reaching a screen unchanged**.

| Defect | Class |
|---|---|
| `168/96` rendered as `16…` | A vital truncated — the worst failure mode in the kit |
| `Checked_in`, `Registered_as_patient`, `icu` | Stored values printed raw |
| `BOOKED TOD…`, `LABS PENDI…`, `ADMITTED TO…` ×5 | Label past the grid's 12-character ceiling |
| `MRN MRN-10422` | The band's label repeating the value's prefix |
| `— · Male` | A placeholder dash joined into an identity line |
| `Acute Medical · be…` | Two facts joined into one half-width row |
| A red "Open queue" button | Red as an affordance colour |
| A red "Emergency" visit-type pill | A category routed through the acuity ramp |
| Every wait chip reading `0m` | Fixtures on wall-clock against a frozen `AppClock` |
| Zeros under an error banner | No data rendered as a department with no patients |
| `Beds free 0` in red with no data | A false alarm from an unloaded board |
| A gap where the capacity bar goes | Zero total rendered as nothing rather than as empty |
| Four quick actions, one unreadable | Too many tiles for the label lengths at 411dp |
| Yusuf Adeyemi in two beds at once | Fixture incoherence |
| A ward round where only some rows tap | An invisible condition on an identical-looking row |
| The observations step opening under the keyboard | `autofocus` on a form meant to be read first |

## Bugs this port found

**The splash screen hung forever.** `SplashView` draws a wordmark and never
reads `controller`, so `Get.lazyPut` never constructed `SplashController`, its
`onReady` never fired, and the app sat on the splash screen indefinitely — on a
device as well as in a test. The screenshot suite failed every single test on
it within a minute of first running. Fixed with an eager `Get.put` and a
comment saying why this one screen has to be eager.

**Wait times were a stale snapshot.** The queue board rendered the server's
`waitTime` field, which is computed when the row is serialised. A board left
open for ten minutes showed ten-minute-old waits and never flagged a breach
that happened while somebody was looking at it. Now computed from
`joinedQueueAt` against `AppClock.now()`.

**Tokens lived in a static field.** `TokenManager` held the bearer token in
process memory, so every cold start signed the clinician out. Now
`flutter_secure_storage`, restored before the first route resolves.

**The triage sort tied P2 and P3.** `CaseStatus.priorityOf` derived its rank
from the *colour*, and P2 and P3 are deliberately the same amber — so they
returned the same integer and the queue silently fell through to arrival
order. A 10-minute-target P2 could be seated behind a 60-minute-target P3
purely on who walked in first, which is exactly the failure the method exists
to prevent. Found by a unit test; bands are now spaced off the colour ladder
with a within-band offset, and the colour vocabulary is unchanged.

**An unrecorded temperature painted red.** Four of the five `VitalRange`
checks guard `<= 0`, because this backend stores an unobserved numeric vital
as zero. `temperature` guarded only null, so `0.0` fell into the hypothermia
branch and returned `acuityCritical` — a red that is not a deteriorating
patient, which breaks the first clinical rule. Reachable from a half-typed
triage form.

**Form validation never ran.** `BentoInput` is a `TextField`, not a
`TextFormField`, and nothing in `lib/` was a `FormField`. So every
`formKey.currentState?.validate()` in the app returned true unconditionally
and fourteen written validators were dead code: sign-in fired with empty
fields, a discharge saved with no reason, and the ward form reached
`int.parse('')`.

**Every pushed screen reserved height for a tab bar it does not have.**
`BentoScreen.bottomClearance` defaults to the reference app's *floating* tab
bar. This shell uses a real `bottomNavigationBar`, so the Scaffold already
reserves the height — every pushed screen carried ~96 dp of dead space, and
the three tab views had the flag inverted on top of that.

**`Opacity` over live text is a contrast bug.** Two screens muted a whole row
with `Opacity`, which composites the text colour toward the ground: a
6.5:1 subtitle became 2.8:1. Muting is a token change, not an alpha change.

## Open items

- `.claude/settings.json` permission allowlist — declined by the user; not
  added.
- **The dashboard's bed denominator is `occupied + available`**, because
  `DashboardStats` carries no total. That under-counts by the reserved and
  blocked beds, so the board says "26 of 37" where the ward screen says 40. The
  ward screen is right; the dashboard is honest about the two numbers it has.
  Fix properly by adding `totalBeds` to the dashboard payload.
- **`DashboardData.fromJson` reads `json['data']`** — the model knows about the
  envelope, which is why a caller cannot pass it the unwrapped payload. Every
  other model in the app takes the object. Worth aligning.
