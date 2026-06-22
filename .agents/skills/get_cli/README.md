# Get CLI Skill

A reusable Antigravity skill for executing and managing `get_cli` workflows inside the project.

## What it does

This skill equips the Antigravity agent to interact with `get_cli` to scaffold pages, controllers, views, bindings, and generate class models or translations safely and efficiently.

## Core Commands

You can ask the agent to perform the following workflows using this skill:

*   **Create a new module/page**: Scaffold a full module containing a controller, view, and binding.
    *   *Usage:* `get create page:profile`
*   **Add standalone components**: Add a controller or view to an existing module.
    *   *Usage:* `get create controller:avatar on profile`
*   **Generate models**: Generate model classes directly from JSON files.
    *   *Usage:* `get generate model on home with assets/json/user.json`
*   **Generate localizations**: Generate translations class from JSON files.
    *   *Usage:* `get generate locales assets/locales`
*   **Manage dependencies**: Cleanly install or uninstall dart/flutter packages.
    *   *Usage:* `get install dio`

## Setup & Implementation

1. Make sure `get_cli` is globally activated:
   ```bash
   flutter pub global activate get_cli
   ```
2. The skill instructions are defined in [`SKILL.md`](./SKILL.md).
