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
| 2.9 | `tool/check_keys.dart` ratchet | ⬜ | Unkeyed count may only go down |

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
| 4.1 | `integration_test/support/` harness | ⬜ | `app_harness`, `pump` (no `pumpAndSettle`), `device_class` |
| 4.2 | Fake API adapter + fixtures | ⬜ | Unstubbed call fails the test with the full list |
| 4.3 | Robots | ⬜ | A flow never calls `find.*` |
| 4.4 | Flow tests | ⬜ | Registered as `void registerXFlows()`, shared headless/device |
| 4.5 | Screenshot driver | ⬜ | `test_driver/screenshot_driver.dart` → `.review/` |
| 4.6 | Screenshot test | ⬜ | Every screen, light + dark |

## Phase 5 — Verification

| # | Task | Status | Notes |
|---|---|---|---|
| 5.1 | `flutter analyze` clean | ⬜ | Zero issues is the baseline |
| 5.2 | Screenshot round 1 on Pixel 6 Pro | ⬜ | `emulator-5554`, light + dark |
| 5.3 | Fix defects found | ⬜ | One batch |
| 5.4 | Screenshot round 2 | ⬜ | Confirm; then stop |

## Phase 6 — Documentation

| # | Task | Status | Notes |
|---|---|---|---|
| 6.1 | `.agents/RULES.md` | ⬜ | The contract for anyone writing code here |
| 6.2 | `DESIGN.md` | ⬜ | What the app is made of, and why |
| 6.3 | `PRODUCT.md` | ⬜ | Who it is for, what the backend does |
| 6.4 | `README.md` | ⬜ | Run it, test it, layout |

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

## Open items

- `.claude/settings.json` permission allowlist — declined by the user; not added.
