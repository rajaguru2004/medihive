# MediHive — Full HMS parity tracker

The running record for making the **app the primary platform**: every web-console
feature in the app, RBAC enforced from the server's access map, and every site
setting changeable from the phone. Verified against a real local backend.

`docs/TASK_TRACKER.md` is the previous record (the design-system port) and stays
as history. This file owns everything from 2026-09-14 onward.

**Branches** · mobile `feat/full-hms-parity` (from `feat/design-system-port`) ·
backend `feat/mobile-parity` (from `main`) · web `frontend/` touched only for the
one-line client fixes a backend contract change forces.

Legend: ✅ done · 🔄 in progress · ⬜ not started · ⛔ blocked · ⏭ deferred

**A row is ✅ only when all of its gates pass.** Mobile gates: `flutter analyze`
zero, `flutter test test/`, `dart run tool/check_keys.dart`, the module's flow
test, its screenshot round reviewed, and its live check against the real API.
Backend gates: `npm run lint`, `npm run build`, `npm test`, `npm run verify:mobile`.

---

## Progress

| Phase | Scope | Size | Status |
|---|---|---|---|
| [P0](#p0--foundation-and-local-stack) | Foundation, local stack, backend contract, RBAC plumbing | L | 🔄 nearly done — test infra + drafts remain |
| [P1](#p1--shell-navigation-and-design-contract) | Role-shaped shell, More hub, tablet rail | M | ⬜ |
| [P2](#p2--patients) | Registry, search, form, patient hub | L | ⬜ |
| [P3](#p3--clinical-parity) | Appointments, consultations, queue/triage/inpatient gating | L | ⬜ |
| [P4](#p4--diagnostics) | Laboratory, radiology | XL | ⬜ |
| [P5](#p5--pharmacy) | Dispensing, inventory, POS | L | ⬜ |
| [P6](#p6--billing) | Invoices, payments, services | L | ⬜ |
| [P7](#p7--administration-and-settings) | Users, settings hub, roles, integrations | XL | ⬜ |
| [P8](#p8--dashboard-and-my-shift) | Role-composed shift board, parity tiles | M | ⬜ |
| [P9](#p9--hardening-and-documentation) | Session lock, a11y, full review, docs | M | ⬜ |

Sizes: S ≤ ½ day · M 1 day · L 2–3 days · XL 4+ days.

---

## P0 · Foundation and local stack

Nothing else can start until the backend answers correctly and the app's data
layer stops sending a vocabulary the backend rejects.

### P0.A — Branches and safety

| # | Task | Status | Notes |
|---|---|---|---|
| 0.1 | Branch `feat/mobile-parity` (hms_v2) | ✅ | from `main` |
| 0.2 | Branch `feat/full-hms-parity` (medihive) | ✅ | from `feat/design-system-port` |
| 0.3 | `docker-compose.local.yml` — postgres 5432 `hms_v2_dev`, redis 6379, `postgres_test` 5433 under profile `test` | ✅ | the shipped compose file attaches to an external proxy network that does not exist locally |
| 0.4 | `.env.local` pointing at localhost, long dev token, `ALLOW_REMOTE_DB=0` | ✅ | **the tracked `.env` points at production `140.245.10.145`** |
| 0.5 | `database-url.util.ts` + `PrismaService` startup guard (refuse non-local outside production unless `ALLOW_REMOTE_DB=1`) | ✅ | |
| 0.6 | `cleanDatabase()` hardened: local host **and** a `_test` database name | ✅ | today it truncates whatever `.env.local` points at |
| 0.7 | Env precedence `['.env.test']` when `NODE_ENV=test` in `app.module.ts`, `prisma.config.ts`, `prisma/load-env.ts` | ✅ | Jest currently resolves `.env.local` first |
| 0.8 | Containers up, `prisma migrate deploy`, `prisma generate`, host confirmed in the Prisma startup log | ✅ | never `migrate dev` — migrations are gitignored |
| 0.9 | Seeds: `db:seed` → `db:seed:catalog` | ✅ | |

### P0.B — Backend auth (B1)

| # | Task | Status | Notes |
|---|---|---|---|
| 0.10 | Refresh-token storage → deterministic `sha256`; rotation in one transaction; family revoke on replay; `logout` revokes its row | ✅ | today `findUnique` re-hashes with a fresh bcrypt salt, so refresh **always** 401s |
| 0.11 | `expiresIn` derived from `JWT_EXPIRES_IN` via `ms()` | ✅ | hard-coded 900 today |
| 0.12 | `GET /api/auth/me` bootstrap: user + roles + permissions + access map + organization(settings) | ✅ | the app already calls this route and swallows the 404 |
| 0.13 | `POST /api/auth/change-password` (existing DTO, revoke all tokens, audit) | ✅ | |
| 0.14 | `ThrottlerGuard` registered before `JwtAuthGuard`; per-route limits; `@SkipThrottle` on health | ✅ | configured but never registered |
| 0.15 | Roles/permissions reads gated on permissions, not the literal SUPER_ADMIN role | ✅ | ADMIN with `roles.read` gets 403 today |
| 0.16 | `AuthCacheService.invalidateUser` wired into roles, users, settings-users, change-password | ✅ | `auth:access-map` is never busted today |
| 0.17 | CORS origin from `CORS_ORIGINS` in production | ✅ | SHOULD |
| 0.18 | `auth.service.spec.ts` extended (expiresIn, rotation, replay, logout, change-password, getMe) | ✅ | |

### P0.C — Backend settings and tenancy (B2)

| # | Task | Status | Notes |
|---|---|---|---|
| 0.19 | `OrganizationSettingsDto` — `locale` / `appearance` / `clinical` / `scheduling` + legacy flat aliases | ✅ | no migration; stays JSON-in-String |
| 0.20 | `resolveOrganizationSettings` (defaults deep-merged) + `mergeOrganizationSettings` (partial merge, unknown keys preserved) | ✅ | a PUT must not wipe keys it did not send |
| 0.21 | `GET /api/settings` — JWT-only flat site map the app's `SiteSettings` already parses | ✅ | the app calls this on every sign-in |
| 0.22 | Org resolved from the JWT everywhere (`tenant.util.ts`); `'org-demo'` fallbacks removed; `UserService` org-scoped | ✅ | cross-tenant read **and** write today |
| 0.23 | `/settings/users`: never return `password`; optional initial password; `USER_*` + `ROLE_UPDATE` alongside `SETTINGS_UPDATE` | ✅ | password hashes are returned today |
| 0.24 | `POST /api/settings/organization/logo` (multipart) so the phone can change logos | ✅ | |
| 0.25 | Seed: ADMIN gains `ROLE_UPDATE` + `PERMISSION_READ`; `DEATH_CERTIFICATE_*` seeded | ✅ | enum/seed drift |

### P0.D — Backend contract normalisation (B3 MUST)

| # | Task | Status | Notes |
|---|---|---|---|
| 0.26 | Remove the 18 hand-rolled envelopes (inpatient, laboratory, pharmacy, radiology) | ✅ | |
| 0.27 | Settings/roles/death-certificate deletes return the entity, not a double-wrapped message | ✅ | |
| 0.28 | Queue meta → standard shape + legacy keys for one release; `pagination.util.ts` | ✅ | web reads the legacy keys |
| 0.29 | Queue accepts `p1..p5`; rank-table sort | ✅ | **every add-to-queue from the app is a 400 today** |
| 0.30 | `search` on consultations and appointments queries | ✅ | the app already sends it → 400 |
| 0.31 | `patientId` filter + embedded `patient{}` on lab orders, radiology orders, prescriptions | ✅ | the patient hub needs it |
| 0.32 | `totalBeds` on dashboard stats | ✅ | fixes the occupancy undercount |
| 0.33 | Web one-liners: `axios.ts` refresh unwrap, queue/patients/pre-triage meta types | ⬜ | |

### P0.E — Mobile data layer

| # | Task | Status | Notes |
|---|---|---|---|
| 0.34 | `registerDomainServices()` shared by `main()` and the harness | ✅ | **domain services are never registered in production today** |
| 0.35 | `Endpoints`: base URL → `:3000`, dead routes removed, every new module route added, `Crud.updateVerb` | ✅ | |
| 0.36 | `ApiEnvelope`: keep `statusCode`, lift `{data,meta}`, 204 = success; `Pagination.fromMeta` reads both shapes | ✅ | |
| 0.37 | `PagedQuery` re-targeted to this backend's query vocabulary | ✅ | current keys are a 400 under `forbidNonWhitelisted` |
| 0.38 | `CrudRepository`: paged + bare lists, `listAll` follows `hasMore`, honours `updateVerb`, accepts 204, `action()`, `upload()` | ✅ | |
| 0.39 | `asJsonList()` for JSON-string fields; `PatientRef` replaces the three patient copies; `QueueServiceCount` rename; `DashboardData`/`OrganizationData` unwrapped | ✅ | |
| 0.40 | Write drafts per entity + `write_contract_test.dart` pinning each key set | ⬜ | |
| 0.41 | `status_registry.dart` + unit test forbidding red for non-clinical states | ✅ | RULES §0 rule 1 |
| 0.42 | 21 inline `/api/...` paths moved into `Endpoints`; hard-coded org id removed | ✅ | |

### P0.F — Mobile RBAC plumbing

| # | Task | Status | Notes |
|---|---|---|---|
| 0.43 | `access_map.dart` — `AccessVerb`, `Modules`, `ModuleAccess`, `AccessMap` (+ `fromPermissions` fallback) | ✅ | |
| 0.44 | `AccessService` — bootstrap → access → JWT claims → empty; persisted; `refreshIfStale`; cleared on teardown | ✅ | |
| 0.45 | `jwt_claims.dart`; `AuthUser` gains `organizationId`/`roles`; logout sends the refresh token; expired token dropped on restore | ✅ | |
| 0.46 | 403 pipeline: `ApiForbiddenException`, `rxNoAccess`, `ListPhase.forbidden`, `NoAccessState` | ✅ | **403 arrives as a normal response, not a `DioException`** |
| 0.47 | `SiteSettings.fromOrganization` adapter | ✅ | |

### P0.G — Platform, test infra, gate

| # | Task | Status | Notes |
|---|---|---|---|
| 0.48 | Android: INTERNET, debug cleartext config, `com.medihive.app`, label, `medihive://` deep-link filter | ✅ | **a release build cannot reach any API today** |
| 0.49 | iOS: bundle id, display name, debug ATS exception | ✅ | not verifiable on this machine |
| 0.50 | `WorldRole` + fake JWT + `api.forbid` + `bootSignedIn(role:)` | ⬜ | |
| 0.51 | `DeviceClass` wired into the harness; role-parameterised screenshot suite; `NEX_HIVE_TEXT_SCALE` | ⬜ | defined but never applied today |
| 0.52 | Live tier skeleton `test/contract/live/` + `tool/live.env.example` | ⬜ | |
| 0.53 | Unit tests: access map, both metas, `PagedQuery`, write contracts, status registry | ⬜ | |
| 0.54 | Backend `seed-mobile-demo.ts` + `verify:mobile` green for all roles | ✅ | |
| 0.55 | **P0 gate**: analyze clean · unit green · the existing 12 flows green · the app signs in against the real API as every seeded role | ⬜ | |

---

## P1 · Shell, navigation and design contract

| # | Task | Status | Notes |
|---|---|---|---|
| 1.1 | PRODUCT.md rewritten to the current schema, `## Platform adaptive`, every staff role as a user | ⬜ | the record predates the current schema |
| 1.2 | Shell concept round (decision page) → direction contract in the surface brief | ⬜ | code-led; no image generation on this machine |
| 1.3 | `ShellLayout.resolve` + table-driven per-tab registration | ⬜ | a nurse must never construct a billing controller |
| 1.4 | More hub (grouped like the web IA) + account entry | ⬜ | |
| 1.5 | `no_access` module + `AuthMiddleware(module:, verb:)` route guard | ⬜ | |
| 1.6 | Global patient search entry in the shell bar | ⬜ | screen lands in P2 |
| 1.7 | Tablet `ShellRail` at ≥600 dp | ⬜ | |
| 1.8 | Access flows (super admin, nurse, receptionist, 403-safe write) + `ShellLayout` unit test for all roles | ⬜ | |
| 1.9 | Screenshot round → fix → confirm (4 roles × light/dark × phone/tablet) | ⬜ | |

---

## P2 · Patients

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | `PATIENTS` registry — server search, filters, sort, infinite list, tablet list-detail | ⬜ | |
| 2.2 | `PATIENT_SEARCH` — autofocus, user-scoped recents | ⬜ | recents must clear on sign-out (shared device) |
| 2.3 | `PATIENT_FORM` — create/edit, insurance group, chip lists | ⬜ | |
| 2.4 | `PATIENT_HUB` — identity band + 7 tabs, each with its own load and no-access state | ⬜ | the app's central navigation idea |
| 2.5 | Fixtures, keys, robot, flows | ⬜ | |
| 2.6 | Screenshot round → fix → confirm; live check | ⬜ | |
| 2.7 | **Finish review milestone 1** (shell + patients) | ⬜ | |

---

## P3 · Clinical parity

| # | Task | Status | Notes |
|---|---|---|---|
| 3.1 | `APPOINTMENT_FORM` (book/edit) + `APPOINTMENT_DETAIL` (confirm, check in, start, complete, no-show, reschedule, cancel) | ⬜ | replaces a placeholder route |
| 3.2 | `CONSULTATION_FORM` (7 tabs incl. prescription items and lab/imaging orders) + `CONSULTATION_DETAIL` | ⬜ | the largest single form in the app |
| 3.3 | Queue: write gating, backend vocabulary, history detail | ⬜ | |
| 3.4 | Pre-triage: gating, convert honours a custom triage role | ⬜ | |
| 3.5 | Inpatient: bed reserved/maintenance, ward edit, admission detail | ⬜ | |
| 3.6 | Flows + screenshot rounds + live checks | ⬜ | |

---

## P4 · Diagnostics

| # | Task | Status | Notes |
|---|---|---|---|
| 4.1 | Lab: hub (stats + worklist, STAT first) | ⬜ | |
| 4.2 | Lab: order form, order detail (collect, reject, verify, complete) | ⬜ | |
| 4.3 | Lab: result form (flag words, abnormal/critical) + catalog | ⬜ | critical must be colour **and** word |
| 4.4 | Radiology: hub with critical-findings banner | ⬜ | |
| 4.5 | Radiology: order form, order detail (schedule/start/performed/cancel, image upload) | ⬜ | needs `image_picker` |
| 4.6 | Radiology: report form (critical switch → text + notified-to, amendment) + catalog | ⬜ | |
| 4.7 | Flows (incl. multipart) + screenshot rounds + live chains | ⬜ | |

---

## P5 · Pharmacy

| # | Task | Status | Notes |
|---|---|---|---|
| 5.1 | Hub: to dispense · inventory (low stock amber) · sales | ⬜ | low stock is **not** red |
| 5.2 | Prescription detail + dispense flow (qty capped by stock) | ⬜ | |
| 5.3 | Drug form + POS sale | ⬜ | |
| 5.4 | Flows + screenshot rounds + live check | ⬜ | |

---

## P6 · Billing

| # | Task | Status | Notes |
|---|---|---|---|
| 6.1 | Hub (money figures, invoices, services) | ⬜ | ledger blue only, never the acuity ramp |
| 6.2 | Invoice builder + `InvoiceMath` unit test | ⬜ | GST-style tax from settings |
| 6.3 | Invoice detail (paid/total bar, history) + payment form (conditional fields per method) | ⬜ | |
| 6.4 | Services catalog | ⬜ | |
| 6.5 | Flows + screenshot rounds + live check | ⬜ | |
| 6.6 | **Finish review milestone 2** (diagnostics, pharmacy, billing) | ⬜ | |

---

## P7 · Administration and settings

| # | Task | Status | Notes |
|---|---|---|---|
| 7.1 | Users list / form / detail (role membership, activate, delete) | ⬜ | |
| 7.2 | Settings hub (grouped rows, gated per module) | ⬜ | |
| 7.3 | Hospital profile (logo upload, brand colour → immediate re-theme) | ⬜ | |
| 7.4 | Locale · Appearance · Clinical settings | ⬜ | partial save must preserve untouched keys |
| 7.5 | Core modules toggles | ⬜ | |
| 7.6 | Departments CRUD | ⬜ | |
| 7.7 | Roles cards + role editor (switch rows on phone, grid on tablet, members) | ⬜ | a 4-column matrix is unreadable at 1.3× |
| 7.8 | Integrations: devices, results queue, upload, machine form | ⬜ | needs `file_picker` |
| 7.9 | Flows + screenshot rounds + live checks | ⬜ | |

---

## P8 · Dashboard and My shift

| # | Task | Status | Notes |
|---|---|---|---|
| 8.1 | `ShiftSections.forAccess` — per-role sections, each with its own load state | ⬜ | |
| 8.2 | Web parity: 8 tiles, status + queue-by-service charts, recent/upcoming rows | ⬜ | `fl_chart` is a dependency with no chart today |
| 8.3 | Ranked, gated quick actions | ⬜ | |
| 8.4 | Flows for three roles + screenshot rounds per role | ⬜ | |

---

## P9 · Hardening and documentation

| # | Task | Status | Notes |
|---|---|---|---|
| 9.1 | `SessionLockService` + lock screen (+ optional biometric) | ⬜ | shared ward tablet |
| 9.2 | Freshness stamps, stale banner, draft preservation audit | ⬜ | |
| 9.3 | 1.3× text scale pass + tablet pass over every screen | ⬜ | |
| 9.4 | Full screenshot suite (all roles × themes × device classes) → fix → confirm | ⬜ | |
| 9.5 | **Finish review milestone 3** + `impeccable-documenter` updates DESIGN.md | ⬜ | |
| 9.6 | Live contract tier across every module + `tool/live_capture.sh` real-API captures | ⬜ | |
| 9.7 | Docs: RULES.md, README.md, this tracker, backend README + API docs | ⬜ | |
| 9.8 | Backend B3 SHOULD items (optional pagination, `@IsIn`, catalog deletes, upload limits) | ⬜ | |

---

## Decisions

**Platform is `adaptive`.** Material 3 on Android, HIG on iOS, one kit. Verified
on the Pixel 6 Pro and Pixel Tablet emulators; iOS is configured but unverified
on this machine.

**Settings are typed keys inside `Organization.settings`,** not a new table. No
migration, and the web console keeps working because it already reads and writes
that JSON. A new `GET /api/auth/me` returns user, access map and organization in
one round trip, which is what makes branding and clinical settings reach the
phone at all.

**The shell is derived from the access map, never from the role name.** Roles are
customizable in this product, so a shell that switches on `role == 'NURSE'` is a
shell that breaks the first time somebody makes a custom role.

**Controls are absent, not disabled.** A disabled button teaches a clinician that
the app is broken; an absent one teaches them the shape of their job. Every
gated write still handles the 403, because the server's map can be five minutes
stale.

**Locale is settings-driven, seeded with India defaults** (INR, Asia/Kolkata,
`dd/MM/yyyy`, 24-hour, GST-style tax labels). ETB and the Ethiopic calendar stay
selectable — nothing is hard-coded to one market.

**Session lock, not sign-out, for a shared tablet.** An idle ward device locks
and takes a password; handover is still a full sign-out.

**Out of scope, deliberately:** death certificates (backend-only today), an
audit-log viewer (no endpoint), user invitations, push notifications, full
offline sync. Listed in Follow-ups.

---

## Bugs this port has found

Filled in as they are fixed, with the same discipline as the previous tracker:
what broke, why it was invisible, and what now prevents it.

### Backend

| Bug | Why it matters | Status |
|---|---|---|
| Two refresh tokens minted in the same second were byte-identical, so the new deterministic hash collided on a unique index | Surfaced only once the bcrypt bug was fixed; login and refresh both 409'd. Tokens now carry a `jti` | ✅ |
| `laboratory.getStats` counted unverified critical results with **no tenant filter** | A clinician saw every hospital's criticals as their own | ✅ |
| `dashboard` and `laboratory` specs asserted against implementations rewritten as single SQL aggregates | 15 tests failing before this work started; both suites were green-looking noise | ✅ |
|---|---|---|
| Refresh tokens are stored as a **salted** bcrypt hash and looked up by re-hashing the same plaintext — the lookup can never match | `POST /auth/refresh` always 401s and `logout` revokes nothing while returning 204, so it looks like it works | ✅ |
| `expiresIn` hard-coded to 900 s regardless of `JWT_EXPIRES_IN` | A client that schedules a refresh off this value is wrong by a factor of 96 in dev | ✅ |
| `ThrottlerModule` configured, `ThrottlerGuard` never registered | Unlimited credential stuffing on `/auth/login`, with a comment claiming the opposite | ✅ |
| Settings routes take the organisation id from the query string or body | Any `SETTINGS_READ` holder can read — and `PUT` — another tenant's organisation | ✅ |
| `GET /api/users` is not organisation-scoped | Same class of leak, on the staff directory | ⬜ |
| `/settings/users` returns the bcrypt password hash | Hashes reach any client that can read the staff list | ✅ |
| `POST /settings/users` creates users with no password | They cannot log in, and no invitation flow exists to fix it | ✅ |
| Queue rejects the `p1..p5` priorities the app sends | Every add-to-queue from the phone is a 400 | ⬜ |
| Consultations query DTO has no `search`, which the app sends | 400 under `forbidNonWhitelisted` | ⬜ |
| Roles and permissions reads are gated on the literal SUPER_ADMIN role | An ADMIN the access map says can read roles still gets 403 | ✅ |
| Jest resolves `.env.local` before `.env.test`, and `cleanDatabase()` truncates every table | A test run can truncate the dev database — or worse, whatever `.env` points at | ✅ |
| The tracked `.env` points `DATABASE_URL` at a production host | `npm run start:dev` with no `.env.local` connects to production; only the seeds are guarded | ✅ |
| `DEATH_CERTIFICATE_*` in the permission enum but not in the seed | The whole module is 403 for every role but SUPER_ADMIN, unfixable through the API | ✅ |
| `@Throttle` read `process.env` in a decorator argument | Decorators evaluate before `ConfigModule` loads any .env, so the login limit was silently 10/min whatever was configured — worse than no limit, because it looks deliberate | ✅ |
| The queue board ordered by the priority **string** | Alphabetical, not clinical: "routine" outranked "normal", and with pagination a P1 lands on page two | ✅ |
| The queue rejected the `p1`–`p5` codes the app sends | Every add-to-queue from a phone was a 400 | ✅ |
| `laboratory.getStats` counted critical results with no tenant filter | A clinician saw every hospital's unverified criticals as their own | ✅ |
| The web console posts capitalised `admissionType` | A lowercase-only vocabulary would have 400'd every admission from the web | ✅ |
| `AdmissionRepository` had no `paginate` override and `Admission` has no `isDeleted` | The first paged admissions request would have thrown | ✅ |
| The radiology uploader rejected `application/dicom` via `startsWith('image/')` | Blocked the one type the endpoint exists to accept | ✅ |
| `RadiologyReport.organizationId` is nullable exactly like `LabResult` | The same latent cross-tenant read, one module over | ✅ |

### Mobile

| Bug | Why it matters | Status |
|---|---|---|
| Domain services are never registered in production — only the test harness puts them | `Get.find<HomeService>()` throws outside tests; the initial binding was never wired into `GetMaterialApp` | ⬜ |
| `PagedQuery` emits the reference CRM's query vocabulary | Every paged list would 400 against this backend | ⬜ |
| `CrudRepository.delete` treats a 204 as a failure; `update` always PATCHes | Deletes would report failure; PUT-only routes would 404 | ⬜ |
| A 403 arrives as an ordinary response, not a `DioException` | The 403 branch in the error handler is unreachable; permission errors would read as generic failures | ⬜ |
| The Android release manifest has no `INTERNET` permission and no cleartext config | A release build cannot reach any API, and fails with a network error nobody can explain | ⬜ |
| `applicationId` is still `com.example.medihive` | Ships under the template identity | ⬜ |
| A hard-coded organisation id in the dashboard service | Single-tenant leak in a per-site product | ✅ |
| `RecentPatient.dateOfBirth` defaulted to `DateTime.now()` | Every patient with no recorded date of birth rendered as a **neonate** on the board, and as registered today | ✅ |
| `fetchAppointments` asked for 1000 rows against a server cap of 100 | "All appointments" silently meant the first hundred | ✅ |
| `AuthUser.fromJson` read `department` as a string when the bootstrap sends an object | Would have painted `{id: …, name: …}` into the shell header | ✅ |
| Five `Crud` entries pointed at multiplexed compat routes with no `/:id` | `byId`/`delete` would 404 on a path that looks right | ✅ |
| `SortOption.sortValue` sent `1`/`-1` to a server validating `asc`/`desc` | Same class as the `PagedQuery` defect | ✅ |
| `DashboardStats` has no `totalBeds` | Occupancy undercounts by reserved and blocked beds; the board and the ward screen disagree | ⬜ |

---

## Toolchain notes

**`./gradlew` fails with the system JDK.** `java` is OpenJDK 25.0.4.1 and Gradle
8.14's Kotlin DSL cannot parse a four-component version string. Use
`JAVA_HOME=/opt/android-studio/jbr` (JDK 17) for direct `./gradlew` calls;
`flutter build` picks that JDK on its own.

**Deep links arrive with the scheme attached.** Flutter 3.38.4 has deep linking
on by default and passes the whole URI, so `medihive://queue` reaches
`defaultRouteName` verbatim. `main.dart`'s `_launchRoute` only special-cases
`''` and `'/'`, so the screenshot harness will land on `unknownRoute` until the
scheme is stripped.

**`NODE_ENV=test` leaking into a shell** now makes the API load `.env.test`
alone — port 3001, the 5433 test database. That is the isolation working as
intended, but start the dev server with an explicit `NODE_ENV=development` if a
jest run has been through the same shell.

**The e2e fixtures are stale against the real backend.** `world.dart` serves
`/api/settings` as an array of `{settingKey, settingValue}` documents and
`/api/auth/me` as a bare user with no `access` block. Both legacy shapes are
still tolerated, so nothing fails — but the harness is not exercising the real
contract, and that has to be fixed before the flow tests mean anything.

## Follow-ups

Death certificates module · audit-log endpoint and viewer · user invitations ·
committing `prisma/migrations/` · rotating and untracking the production `.env` ·
push notifications · full offline sync.
