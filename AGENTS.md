# Agent Architecture Guide (AGENTS.md)

Developer rules and architectural guide for **Wilmer Alternity Sidekick** (Godot 4.6.3, Portrait-first).

---

## 1. System Architecture

Layered, with no UI dependency below `scripts/ui/`:

```
scripts/core/      model and services, all headless-testable
  num.gd             numeric coercion for stored JSON (as_int / as_float)
  character_doc.gd   owns one character; mutations go through apply()
  character_store.gd load / save / list / delete under user://
  skill_detail.gd    typed sections for skill and FX reference text
  theme_service.gd   autoload; owns the active theme
  theme_palette.gd   the eight semantic colours
  dice/              notation, seeded RNG, RollResult
  session/           campaign document and transport interface

scripts/ui/        presentation
  app_shell.gd       root scene; routes between screens, handles back
  ui_router.gd       navigation stack (RefCounted)
  modal_host.gd      CanvasLayer owning the scrim, stacking and sizing
  sheet_tab.gd       tab contract; declares watched sections
  sheet_context.gd   what a tab is handed
  widgets.gd         stateless builders, palette-aware
  widgets/           controls with behaviour (SearchField, NumberStepper, SkillPicker)
  screens/           character select, character sheet
  tabs/              the ten sheet tabs
  routes/            catalog, confirm, import, optional rules, theme, skill detail

scripts/alternity_rules*.gd   the rules engine: catalog data plus pure functions
data/rules/*.json             the rules data
scenes/ui/                    the .tscn files for the above
```

**Key contracts**

- A tab never triggers a global re-render. It declares `watched_sections()` and
  the base rebuilds it only when one of those changes; a hidden tab defers.
- Every character mutation goes through `doc.apply(sections, callable)`, which
  is what announces the change.
- Catalogs filter through `rules.is_entry_available(character, entry)` so
  optional-setting content (Dark Matter) only appears when that setting is
  selected. Forgetting this does not error -- it silently offers the wrong
  content -- so use the helper rather than re-deriving the check.
- Dice results come from a `RandomSource`. The rules layer uses the seeded
  `RngSource`; a physical dice tray will implement the same interface.

## 2. Layout Overrides (Desktop vs. Mobile)
- **Desktop (Default)**: `1280x720` (Landscape).
- **Mobile (`.mobile` suffix)**: ``390x844` on mobile (`1280x720` is the desktop default)` (Portrait).
- **Warning**: `window/handheld/orientation` in `project.godot` must be `1` (Integer Enum for Portrait). A string value like `"portrait"` will fail parser. Never use external `override.cfg`.

---

## 3. Touch Scrolling on Mobile
- Godot controls intercept drag events (`MOUSE_FILTER_STOP`) by default.
- **Touch-Pass Mode**: `_update_mouse_filters_for_touch(node, touch_pass)` traverses descendants of active `ScrollContainers`:
  - **Mobile (`touch_pass = true`)**: Sets `mouse_filter` to `Control.MOUSE_FILTER_PASS` (allows dragging/scrolling while preserving taps).
  - **Desktop (`touch_pass = false`)**: Restores defaults (e.g. `MOUSE_FILTER_STOP` / `MOUSE_FILTER_IGNORE`).
- **Hook Location**: Invoked during `_apply_responsive_layout()` and at the end of `_render()`.

---

## 4. Build Environment
- **Script**: `tools/build.ps1`
- **SDK Path**: `C:\AndroidSDK` (API 34/35, Build-tools 34.0.0/35.0.1, NDK 28b, CMake 3.10)
- **Java Home**: `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot` (JDK 17)
- **Keystore**: `debug.keystore` in project root (password: `android`, alias: `androiddebugkey`).
- **Wireless Debugging**: Connect phone to same Wi-Fi, enable *Wireless debugging* in developer options, pair with `adb pair <IP:PairingPort>`, connect with `adb connect <IP:ConnectionPort>`, and use Godot's one-click deploy Android button.
- **GitHub Release Automation**: Version tag pushes (`v*`) trigger a GitHub Action (`.github/workflows/release.yml`) that compiles the app and publishes it with Windows/Android binaries attached as Release assets.

---

## 5. Development Guidelines
- **Colors**: Query from active theme variables (`color_surface`, `color_accent`, `color_text`), never hardcode.
- **Scroll Rebuilds**: Apply `_update_mouse_filters_for_touch` to any dynamic scrolling list.
- **Mobile Labels**: Set `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` and `custom_minimum_size = Vector2(1, 0)` to prevent labels from stretching viewport width.
- **RM Calculations**: Do not calculate Resistance Modifiers or rank step-bonuses locally in GUI code. Query `rules.character_resistance_modifier(character, ability)` for consistent evaluation.
- **Excluding Media**: Keep builds small; `manuals/` is ignored in `export_presets.cfg`.
- **UI SVG Assets**: All UI icons must be drawn in white (`#ffffff`) at a small size (e.g. 48px), have `mipmaps/generate = true` in their `.import` files, and use `texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`. This allows Godot to crisp-render and dynamically tint them to match the active theme's colors using button theme overrides.
- **Theme Overrides Safety**: When modifying button styleboxes in script dynamically (e.g. changing padding margins on theme change), always call `btn.remove_theme_stylebox_override(state)` first before fetching the stylebox. This prevents the button from locking into a duplicated stale stylebox from a previous theme.
- **Build Exclusion**: Compiled binaries under `builds/` are git-ignored and must never be tracked or committed to the repository. Release binaries should be distributed via GitHub Releases.


---

## 6. Local Tooling vs. Committed State

- **Godot AI MCP addon**: `/addons/godot_ai/` is a local, editor-only development tool and is
  git-ignored, along with `godot-ai-LICENSE.txt`. It is not part of the app.
- **Never commit its `project.godot` entries.** Enabling the addon in the editor writes an
  `_mcp_game_helper` autoload and an `[editor_plugins]` block into `project.godot`. The
  autoload is a **runtime** dependency: committing it without `addons/` breaks every clone
  and every CI export with an unresolvable autoload path.
- **Before committing**, if `project.godot` shows unexpected changes, run:
  ```
  pwsh tools/clean_project_settings.ps1
  ```
  It is idempotent and safe to run any time; `-WhatIf` previews without writing.
- **`.uid` files are tracked.** Godot 4.4+ uses them to keep resource references stable
  across machines. Do not add them to `.gitignore`. Delete a `.uid` only when its script is
  deleted.

---

## 7. Android Export Notes

- `permissions/internet` and `permissions/access_network_state` are enabled in
  `export_presets.cfg` and must stay that way. Debug exports get INTERNET
  implicitly for the remote debugger, so anything networked (the planned GM
  connection) would appear to work in testing and fail only in a release APK.
- Architectures ship **arm64-v8a only**. Enabling `architectures/x86_64` allows
  running on an Android emulator but takes the APK from roughly 33 MB to 61 MB,
  so turn it on for emulator testing and back off before tagging a release.
- Release builds are currently signed with the debug keystore. Reconcile that
  before distributing outside the group.
