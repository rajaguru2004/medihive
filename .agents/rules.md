# MediHive — Agent Coding Rules
> Version: 1.0 | Updated: 2026-06-22
> Apply these rules in EVERY file you generate or modify.

# MediHive — Agent Codebase Rules

> **MANDATORY**: Read this file completely before writing any code.
> All rules below are non-negotiable project standards.

## 1. Project Stack

| Layer | Package |
|---|---|
| State / DI / Nav | `get` (GetX) |
| HTTP Client | `dio` + custom `DioClient` |
| Debug Logging | `pretty_dio_logger` + custom `LoggingInterceptor` |
| Fonts | `google_fonts` (Inter) |
| Architecture | GetX MVC — modules under `lib/app/modules/<name>/` |

## 1. Theme System

### 1.1 Single Import
Always use the barrel import. Never import individual theme files directly.

```dart
// ✅ Correct
import 'package:medihive/app/theme/theme.dart';

// ❌ Wrong
import 'package:medihive/app/theme/app_colors.dart';
import 'package:medihive/app/theme/app_theme.dart';
```

### 1.2 Colors — Use `AppColors`, Never Raw Hex
```dart
// ✅
color: AppColors.primary
color: AppColors.error
color: AppColors.darkGlass

// ❌
color: Color(0xFF0A84FF)
color: Colors.blue
color: Colors.red
```

**Color token reference:**

| Token | Value | Use |
|---|---|---|
| `AppColors.primary` | `#0A84FF` (Apple blue) | CTAs, links, focus rings |
| `AppColors.secondary` | `#30D158` (mint green) | Success, vitals OK, active |
| `AppColors.tertiary` | `#BF5AF2` (lavender) | Tags, supporting actions |
| `AppColors.error` | `#FF453A` | Errors, critical alerts |
| `AppColors.warning` | `#FF9F0A` | Warnings, pending status |
| `AppColors.info` | `#64D2FF` | Info chips, highlights |
| `AppColors.lightBackground` | `#F2F2F7` | iOS grouped bg (light) |
| `AppColors.darkBackground` | `#000000` | OLED black (dark) |
| `AppColors.lightSurface` | `#FFFFFF` | Cards/sheets (light) |
| `AppColors.darkSurface` | `#1C1C1E` | Cards/sheets (dark) |
| `AppColors.lightGlass` | white @ 60% | Glass overlay (light) |
| `AppColors.darkGlass` | white @ 10% | Glass overlay (dark) |

### 1.3 Typography — Use `AppTextStyles`, Never Raw `TextStyle`
```dart
// ✅
Text('Patient Name', style: AppTextStyles.titleMedium(AppColors.lightTextPrimary))
Text('BP: 120/80', style: AppTextStyles.numeric(AppColors.primary, fontSize: 18))

// ❌
Text('Patient Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
```

**Style method signatures:**
```dart
AppTextStyles.headlineLarge(Color color)
AppTextStyles.headlineMedium(Color color)
AppTextStyles.headlineSmall(Color color)
AppTextStyles.titleLarge(Color color)
AppTextStyles.titleMedium(Color color)
AppTextStyles.titleSmall(Color color)
AppTextStyles.bodyLarge(Color color)
AppTextStyles.bodyMedium(Color color)
AppTextStyles.bodySmall(Color color)
AppTextStyles.labelLarge(Color color)
AppTextStyles.labelMedium(Color color)
AppTextStyles.labelSmall(Color color)
AppTextStyles.numeric(Color color, {double fontSize = 16})  // JetBrains Mono
```

Always resolve color from context when inside a widget:
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
Text('Hello', style: AppTextStyles.bodyLarge(textColor));
```

### 1.4 Spacing — Use `AppSpacing`, Never Raw Numbers
```dart
// ✅
padding: EdgeInsets.all(AppSpacing.lg)          // 16
gap: SizedBox(height: AppSpacing.sectionSpacing) // 32

// ❌
padding: EdgeInsets.all(16)
SizedBox(height: 32)
```

**Key tokens:** `xxs=2, xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, xxxl=32, huge=40`

### 1.5 Decorations — Glass-Effect UI

Use `AppDecorations` helpers for borders, shadows, and glass effects.

```dart
// Glass card (Apple visionOS style)
Container(
  decoration: AppDecorations.glassCard(isDark: isDark),
  child: ...
)

// Pre-built GlassCard widget (preferred)
GlassCard(
  padding: EdgeInsets.all(AppSpacing.lg),
  child: ...
)

// Frosted pill (chips, badges)
Container(
  decoration: AppDecorations.glassPill(isDark: isDark),
  child: ...
)
```

**Border radius tokens:**
```dart
AppDecorations.radiusXS  = 6
AppDecorations.radiusSM  = 10
AppDecorations.radiusMD  = 14   // inputs, cards
AppDecorations.radiusLG  = 20   // large cards (default)
AppDecorations.radiusXL  = 28   // dialogs, bottom sheets
AppDecorations.radiusFull = 999 // pills, chips
```

### 1.6 Theme Switching
```dart
// Toggle dark/light
Get.find<AppThemeController>().toggleTheme();

// Set explicitly
Get.find<AppThemeController>().setDark(true);

// Check current mode
final isDark = Get.find<AppThemeController>().isDark;
// or from context:
final isDark = Theme.of(context).brightness == Brightness.dark;
```

### 1.7 Semantic Status Badges (Pre-built)
```dart
StatusBadge(label: 'Active', type: StatusType.success)
StatusBadge(label: 'Critical', type: StatusType.error, icon: Icons.warning_rounded)
StatusBadge(label: 'Pending', type: StatusType.warning)
StatusBadge(label: 'Discharged', type: StatusType.neutral)
```

### 1.8 Do NOT
- ❌ Use `Colors.X` (e.g. `Colors.blue`, `Colors.grey`) anywhere in UI code
- ❌ Hardcode `TextStyle` font sizes or weights
- ❌ Use raw `double` literals for padding/margin/gap
- ❌ Create local `BoxDecoration` with manual border-radius numbers
- ❌ Use `withOpacity()` — use `withValues(alpha: 0.x)` instead (Flutter 3.27+)

---

## 2. Network Layer (Dio)

### 2.1 Always Use `AppDioClient.instance`
Never instantiate `Dio()` directly in services or repositories.

### 2.2 Only Use Dio Package
- ❌ Do NOT use other HTTP clients like `http`, `GetConnect`, or raw `HttpClient`.
- ✅ All API calls and networking MUST use the `dio` package via `AppDioClient.instance`.

```dart
// ✅
import 'package:medihive/app/network/app_dio_client.dart';

class PatientProvider {
  final _dio = AppDioClient.instance;

  Future<Response> getPatients() => _dio.get('/patients');
}

// ❌
final dio = Dio(); // creates unregistered instance with no interceptors
```

### 2.2 File locations
```
lib/app/network/
├── app_dio_client.dart          ← Singleton Dio + interceptor registration
└── interceptors/
    └── app_log_interceptor.dart ← Custom structured logger
```

### 2.3 What Gets Logged (Debug Only)

`AppLogInterceptor` prints to `debugPrint` (visible in Flutter DevTools + Android Studio):

```
╔══════════════════════════════════════════════
║  ➤ REQUEST
║  Method : POST
║  URL    : https://api.medihive.app/v1/patients
║  Headers:
║    Authorization: Bearer <token>
║  Body:
║    {"name":"John","age":45}
╚══════════════════════════════════════════════

╔══════════════════════════════════════════════
║  ✅ RESPONSE
║  Status : 200 OK
║  URL    : https://api.medihive.app/v1/patients
║  Data:
║    {"id":"abc123","name":"John"}
╚══════════════════════════════════════════════
```

`PrettyDioLogger` adds colorized, tree-formatted output on top of that.

Logs are **stripped in release builds** — `kDebugMode` gate is enforced.

### 2.4 Adding New Interceptors
Add to `AppDioClient._addInterceptors()` only — never elsewhere:

```dart
static void _addInterceptors(Dio dio) {
  dio.interceptors.add(const AppLogInterceptor());   // 1. always first
  if (kDebugMode) { ... PrettyDioLogger ... }        // 2. debug only
  dio.interceptors.add(AuthInterceptor());            // 3. auth token
  dio.interceptors.add(RetryInterceptor(dio));        // 4. retry logic
}
```

Order matters: interceptors execute top-to-bottom on request, bottom-to-top on response.

### 2.5 Base URL
Set `baseUrl` in `AppDioClient._create()`. Use a flavor/env constant — not hardcoded in providers.

### 2.6 Error Handling Pattern
```dart
try {
  final res = await AppDioClient.instance.get('/patients/$id');
  return PatientModel.fromJson(res.data);
} on DioException catch (e) {
  // AppLogInterceptor already logged this — just handle UX
  throw AppException.fromDio(e);
}
```

---

## 3. General Agent Rules

- Follow GetX conventions — controllers in `modules/<name>/controllers/`, providers in `modules/<name>/providers/`.
- Use `get_cli` for scaffolding: `get create page:<name>`, `get create provider:<name> on <module>`.
- Run `flutter analyze` after any generation — zero warnings/errors before committing.
- Run `get sort` after bulk file creation.
- Never use `print()` — use `debugPrint()` wrapped in `kDebugMode`.


## 3. Networking — Dio Rules

### 3.1 DioClient

**File**: `lib/app/data/network/dio_client.dart`

Single Dio instance. Registered in GetX:

```dart
// In InitialBinding or app startup:
Get.put(DioClient());

// In any provider / repository:
final _dio = Get.find<DioClient>().dio;

// OR use convenience methods:
final client = Get.find<DioClient>();
final res = await client.get('/employees');
final res = await client.post('/leave/request', data: payload);
```

**Rules:**
- ❌ NEVER create a raw `Dio()` instance directly in a provider or controller.
- ❌ NEVER add `dio.interceptors.add(...)` outside `DioClient._attachInterceptors()`.
- ✅ All HTTP calls MUST go through `DioClient`.
- ✅ To change `baseUrl` per environment, pass it to `DioClient(baseUrl: Env.apiBase)`.

### 3.2 Logging Interceptors

**Files**:
- `lib/app/data/network/interceptors/logging_interceptor.dart` — custom ANSI logger
- `pretty_dio_logger` — secondary pretty-printer (both auto-attached by `DioClient`)

Both interceptors are **debug-only** (`kDebugMode`). Zero output in release builds.

**What gets logged per request:**

```
╔ REQUEST [POST] ────────────────────────────
║ URL     : https://api.hivesphere.com/v1/leave/request
║ HEADERS : Authorization: Bearer <token>
║ BODY    : {employeeId: E123, type: casual, days: 2}
╚────────────────────────────────────────────

╔ RESPONSE [POST] [HTTP 201] ────────────────
║ URL     : https://api.hivesphere.com/v1/leave/request
║ BODY    : {status: approved, leaveId: L456}
╚────────────────────────────────────────────

╔ ERROR [GET] [HTTP 401] ─────────────────────
║ URL     : https://api.hivesphere.com/v1/employees
║ TYPE    : DioExceptionType.badResponse
║ MESSAGE : Http status error [401]
╚────────────────────────────────────────────
```

Color coding in debug console:
- 🔵 **Cyan** = outgoing request
- 🟢 **Green** = successful response (2xx/3xx)
- 🔴 **Red** = error response
- 🟡 **Yellow** = non-error but unusual status

**Rules:**
- ❌ NEVER use `print()` or `debugPrint()` directly for API logging — the interceptors handle it.
- ❌ NEVER log tokens / passwords / PII in production. If logging sensitive headers, guard with `kDebugMode`.
- ✅ Body truncated at 2000 chars automatically — do NOT manually truncate before calling API.

### 3.3 Error Handling Pattern

All API calls must be wrapped:

```dart
try {
  final response = await Get.find<DioClient>().get('/employees');
  // handle response.data
} on DioException catch (e) {
  // e.type, e.response?.statusCode, e.message already logged by interceptor
  // show user-facing error via Get.snackbar or AppSnackBar helper
  Get.snackbar('Error', e.response?.data['message'] ?? 'Something went wrong');
}
```

---

## 4. GetX Architecture Rules

### 4.1 Module Structure
- ❌ Do NOT place `models` folders inside individual module folders.
- ✅ All model classes MUST reside inside the centralized `lib/app/models/` folder.

```dart
lib/app/modules/<module_name>/
├── bindings/<module_name>_binding.dart
├── controllers/<module_name>_controller.dart
└── views/<module_name>_view.dart
```

### 4.2 Generating Modules
Always use get_cli (see `.agents/skills/get_cli/SKILL.md`):
```bash
get create page:<name>
```

### 4.3 Controller Rules
- ✅ Extend `GetxController`.
- ✅ Register `DioClient` in Binding, not in Controller constructor.
- ✅ Keep controllers thin — business logic only, no UI code.
- ❌ NEVER call `setState()` — use `.obs` + `Obx()`.

### 4.4 Dependency Registration Order (in Bindings)
```dart
@override
void dependencies() {
  Get.lazyPut<DioClient>(() => DioClient());         // network first
  Get.lazyPut<EmployeeController>(() => EmployeeController());
}
```

### 4.5 Services vs Providers (API logic)
- ❌ Do NOT use module-level providers or provider files under modules (`lib/app/modules/<name>/providers/`).
- ❌ Do NOT use provider management for API logic.
- ✅ All API calls and HTTP requests MUST reside inside centralized service files located under the `lib/app/services/` directory.
- ✅ Services must extend `GetxService` and be registered globally (e.g. in `main.dart`'s `initialBinding` using `Get.put(..., permanent: true)`).
- ✅ Controllers must fetch these services using `Get.find<ServiceName>()` instead of instantiating or finding module-specific providers.

---

## 5. File & Import Conventions

- ✅ Barrel imports: use `theme.dart` not individual theme files.
- ✅ Use relative imports within `lib/app/` — avoid `package:` imports for internal files.
- ✅ Run `flutter analyze` after every generation step.
- ✅ File names: `snake_case.dart`. Class names: `PascalCase`. Variables: `camelCase`.
- ❌ NEVER commit files with `// TODO: remove` or leftover debug `print()`.

---

## 6. Screen Separation & Navigation Architecture

> **WHY THIS EXISTS**: the app once bundled five distinct screens (Dashboard,
> Leaves, Overtime, Tasks, Calendar) into ONE 6,000-line view driven by ONE
> god `HomeController`, with the same branded top bar pasted onto every pushed
> sub-screen. That is banned. These rules keep every screen independent and
> scalable.

### 6.1 One Screen = One Module (non-negotiable)

Every distinct screen is its OWN module with its OWN controller, binding, view,
and route — see §4.1. Never put two screens in one view file or behind one
controller.

- ❌ NEVER bundle multiple screens into a single view (e.g. a giant `IndexedStack`
  whose children are `_buildXTab()` methods all reading one controller).
- ❌ NEVER create a "god controller" that owns the state + API calls for several
  screens. Each screen's controller fetches and owns only its own data.
- ✅ Each screen: `XView extends GetView<XController>`, its own `XBinding`, its own
  `Routes.X` + `GetPage`. Generate with `get create page:<name>` (§4.2).
- ✅ A screen's controller calls its own `fetchData()` in `onInit()` — data is not
  pushed in from another controller.

### 6.2 Bottom-Nav Shell Pattern

A persistent bottom nav is a **thin shell**, not a mega-screen.

- ✅ The shell (`home` module) owns ONLY cross-cutting state: active tab index,
  top-bar/profile/more-menu toggles, current user, system settings, unread count.
- ✅ Each tab is a separate module/view hosted in the shell's `IndexedStack`
  (`const DashboardView()`, `const LeavesView()`, …) — each backed by its own
  controller, registered `permanent: true` in the shell binding (IndexedStack
  builds all tabs eagerly).
- ✅ Tab controllers are also added to `app_pages.dart` as standalone `GetPage`s so
  each is independently routable.

### 6.3 App Bar Rules — no duplicated top bars

- ❌ NEVER copy the shell/home top bar (brand wordmark + search + notifications +
  settings + profile dropdown) onto a pushed sub-screen. That bar belongs to the
  shell only.
- ✅ A pushed sub-screen (detail / form / list opened via `Get.to`/`Get.toNamed`)
  gets its OWN header: a **back button** (`Get.back()`) + the screen title (+ an
  optional screen-specific action). No global action icons.
- ✅ On the shell's top-level tabs, the shell bar shows the **active tab's title**
  (contextual) on the left and the global actions on the right — the tab content
  must NOT repeat that title inside its scroll body.
- ✅ Branding (`HiveSphere` wordmark) appears only on the Home tab and Login.

### 6.4 Overlays must not dead-zone touches

A persistent shell `Stack` often layers popups (dropdowns, speed-dial menus) over
the tab content. An always-present overlay that is merely hidden will still
intercept touches and create dead zones in the content below.

- ❌ NEVER wrap an inactive/hidden overlay in `AbsorbPointer` — when hidden it
  still swallows every touch inside its bounds (this caused the right-half of
  the tab screens to stop scrolling).
- ✅ For an overlay that stays in the tree but animates open/closed (e.g.
  `AnimatedOpacity`/`AnimatedPositioned`), gate hit-testing with
  `IgnorePointer(ignoring: !isOpen)` so touches pass THROUGH when closed.
- ✅ Even better when no open/close animation is needed: conditionally build the
  overlay (`if (!isOpen) return const SizedBox.shrink();`) so it isn't in the
  tree at all — as the profile dropdown does.
- ✅ A full-screen tap-to-dismiss scrim is fine ONLY while the menu is open
  (render it conditionally), and use `behavior: HitTestBehavior.translucent`.

### 6.5 Reuse, don't copy-paste

- ✅ Extract shared pure helpers (date/time formatters, etc.) into
  `lib/app/data/utils/` and import them — never paste the same helper into
  multiple views.
- ✅ Cross-screen actions use `Get.find<TargetController>()` against the specific
  owning controller (e.g. attendance success → `Get.find<DashboardController>()
  .fetchData()`), never a shared god controller. Guard with
  `Get.isRegistered<T>()` when the target may not be alive.

---

## 7. Quick Reference Card

```
Theme   → import 'app/theme/theme.dart'
Colors  → AppColors.primary / .accent / .hr*
Text    → AppTextStyles.light*()/dark*()   (pick per brightness)
Radius  → AppTheme.radiusMedium / Large / XL
Glass   → GlassCard / GlassPill / GlassBackground
Theme ⚙ → AppThemeController.to.toggle()
HTTP    → Get.find<DioClient>().get/post/put/patch/delete
Logs    → auto by LoggingInterceptor (debug only)
Module  → get create page:<name> (do NOT generate provider files; use services instead)
Services → under 'lib/app/services/'; extends GetxService; global registration; no providers
Models  → under 'lib/app/models/'; no module-level model folders
Screens → 1 screen = 1 module (own controller/binding/view/route); no god controller
AppBar  → shell tabs = contextual title + global actions; sub-screens = back + title
Overlay → hidden overlays use IgnorePointer (never AbsorbPointer); or don't build them
```
