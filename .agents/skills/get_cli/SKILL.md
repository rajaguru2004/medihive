---
name: get_cli
description: >
  GetX Command Line Interface (get_cli) operations and procedures.
  Use when creating or updating modules, pages, views, controllers, providers,
  models, routes, and translations in GetX-based projects.
---

Instructions and procedures for managing the project structure, generating boilerplate code, and integrating modules using `get_cli`.

## Core Commands & Reference

Always execute `get_cli` subcommands from the project root directory.

| Component / Action | CLI Command | Target Output Path (Typical) |
|:---|:---|:---|
| **Full Module / Page** | `get create page:<name>` | `lib/app/modules/<name>/` |
| **Separate Controller** | `get create controller:<name> on <module>` | `lib/app/modules/<module>/controllers/` |
| **Separate View** | `get create view:<name> on <module>` | `lib/app/modules/<module>/views/` |
| **Data Provider / API Client**| `get create provider:<name> on <module>` | `lib/app/modules/<module>/providers/` |
| **Class Model** | `get create model:<name> on <module>` | `lib/app/modules/<module>/models/` |
| **Model from JSON** | `get generate model on <module> with <json_file>`| `lib/app/modules/<module>/models/` |
| **Translations / Locales** | `get generate locales <locales_folder>` | `lib/generated/locales.g.dart` |
| **Install Package** | `get install <package>` | Adds to `pubspec.yaml` (dependencies) |
| **Install Dev Package** | `get install <package> --dev` | Adds to `pubspec.yaml` (dev_dependencies) |
| **Remove Package** | `get remove <package>` | Removes from `pubspec.yaml` |
| **Sort / Format Imports** | `get sort` | Formats and organizes imports in Dart files |

---

## Procedures

### 1. Generating a New Module / Page
To create a complete page with a corresponding Controller, View, and Binding:
1. Run:
   ```bash
   get create page:<page_name>
   ```
   *Example:* `get create page:profile`
2. **Post-generation checks**:
   - Verify that the files were created at `lib/app/modules/<page_name>/`.
   - Verify that `lib/app/routes/app_pages.dart` has been updated with the new route entry.
   - Verify that `lib/app/routes/app_routes.dart` has been updated with the new route string constants.
   - If routes fail to compile, ensure the path imports in `app_pages.dart` are relative and correct.

### 2. Creating Components on a Specific Module
When you need to add a controller or view to an existing module without creating a new full page structure:
1. Run:
   ```bash
   get create controller:<controller_name> on <module_name>
   ```
   *Example:* `get create controller:avatar on profile`
2. Run:
   ```bash
   get create view:<view_name> on <module_name>
   ```
   *Example:* `get create view:avatar on profile`
3. Link the new components manually in the Binding file (e.g. `lib/app/modules/<module_name>/bindings/<module_name>_binding.dart`) if they need to be lazily/permanently put into the GetX dependency injection container.

### 3. Generating Models from JSON
When converting raw JSON assets into Dart class models:
1. Prepare a valid, plain JSON file in the project (e.g. `assets/json/user.json`).
2. Run:
   ```bash
   get generate model on <module_name> with <path_to_json>
   ```
   *Example:* `get generate model on home with assets/json/user.json`
3. Open the generated model file and verify:
   - Nested models/objects are properly serialized/deserialized.
   - Any reserved keywords used as JSON keys are handled (e.g. rename or escape variables).

### 4. Setting Up Translations
To generate localization classes from JSON translation files:
1. Create a locales folder containing JSON translation files (e.g., `assets/locales/en.json`, `assets/locales/es.json`).
2. Run:
   ```bash
   get generate locales <locales_folder_path>
   ```
   *Example:* `get generate locales assets/locales`
3. Configure `GetMaterialApp` in `lib/main.dart` to use the generated translations:
   ```dart
   import 'lib/generated/locales.g.dart';
   ...
   GetMaterialApp(
     ...
     translationsKeys: AppTranslation.translations,
     locale: Get.deviceLocale,
     fallbackLocale: const Locale('en', 'US'),
   )
   ```

### 5. Dependency Management
Use the CLI to cleanly install or uninstall pub packages:
- To add dependencies:
  ```bash
  get install <package_name>
  ```
- To add dev dependencies:
  ```bash
  get install <package_name> --dev
  ```
- To remove dependencies:
  ```bash
  get remove <package_name>
  ```

---

## Troubleshooting & Best Practices

1. **Import Conflicts and Pathing**:
   - `get_cli` may generate absolute package imports or incorrect relative imports.
   - Run `get sort` or manually organize imports if you face lint/analyzer complaints.
2. **Route Generator issues**:
   - Do not manually edit the comments or the structure of `app_routes.dart` and `app_pages.dart` if you plan to continue using `get_cli` page generation. Manual changes might cause subsequent `get create page` invocations to fail to parse these files.
   - If routing files become corrupted, restore them from Git history and re-generate using CLI.
3. **Analyze & Format**:
   - After executing any `get` generator commands, always run `flutter analyze` to verify that all code compiles correctly and there are no syntax/dependency errors.
