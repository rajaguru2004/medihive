# MediHive — Agent Coding Rules
> Version: 1.0 | Updated: 2026-06-22
> Apply these rules in EVERY file you generate or modify.

---

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
Never instantiate `Dio()` directly in providers or repositories.

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
