# Agent Development Context & Architecture Guide (AGENTS.md)

Welcome, agent! This document details the inner architecture, design systems, compilation details, and core guidelines of the **Wilmer Alternity Sidekick** project to help you ramp up quickly and preserve system integrity.

---

## 1. System Architecture

The application is a single-scene, multi-panel digital companion.

### Main Entry & Controller
- **Main Scene:** [main.tscn](file:///c:/Users/rodri/Projects/Godot/wilmer-alternity-sidekick/main.tscn)
- **Controller script:** [main.gd](file:///c:/Users/rodri/Projects/Godot/wilmer-alternity-sidekick/scripts/main.gd) (handles UI layout, dynamic control rendering, modal overlays, event hookups, and user state serialization).

### Database Engine & Rulesets
- **Script:** [alternity_rules.gd](file:///c:/Users/rodri/Projects/Godot/wilmer-alternity-sidekick/scripts/alternity_rules.gd)
- **Data location:** `data/rules/` (holds JSON databases for equipment, achievements, species, professions, and mutations).
- The class loads the rulesets on start and exposes searching, filtering, and indexing methods (like `get_species_by_id`, `get_profession_by_id`, etc.).

### Theme Manager (Autoload)
- **Script:** [theme_manager.gd](file:///c:/Users/rodri/Projects/Godot/wilmer-alternity-sidekick/scripts/theme_manager.gd)
- Manages switching and persisting active themes.
- Themes are defined under `themes/` (e.g., `synthwave.tres`, `cyber_dark.tres`, `cyber_light.tres`).

---

## 2. Layout Overrides (Desktop vs. Mobile)

Godot uses key-level feature tag suffixes to dynamically switch window settings at startup:

- **Desktop (Default):** Runs wide, landscape layout (**1280x720**).
- **Mobile (`.mobile` tag):** Overrides viewport size to (**390x844**).
- **Orientation Lock:** Handheld devices are locked to **Portrait** mode.

```ini
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/viewport_width.mobile=390
window/size/viewport_height.mobile=844
window/handheld/orientation=1
```

> [!WARNING]
> In `project.godot`, `window/handheld/orientation` is an **Integer Enum** (value `1` represents Portrait). Do not write a string value like `"portrait"` or it will fail parsing and default to `0` (Landscape).
> Do not introduce an external `override.cfg` file as it can cause setting conflicts or mapping failures between editor imports and export compiles.

---

## 3. Touch Scrolling Mechanism on Mobile

Godot UI controls (like `PanelContainer`, `Panel`, `Button`, `LineEdit`, `Slider`) use `mouse_filter = Control.MOUSE_FILTER_STOP` by default, which intercepts drag gestures and prevents them from bubbling up to parent `ScrollContainer` nodes.

To solve this on mobile, the layout cycle invokes recursive pass-through configurations:
1. **Recursion Helper:** `_update_mouse_filters_for_touch(node: Node, touch_pass: bool)` traverses descendants of active `ScrollContainers`.
2. **Behavior on Mobile (`touch_pass = true`):** Sets `mouse_filter` to `Control.MOUSE_FILTER_PASS` on all buttons, panels, background textures, and line entries. Taps still register as presses, but drags pass up to the ScrollContainer to scroll the panel.
3. **Behavior on Desktop (`touch_pass = false`):** Reverts elements to their standard defaults (e.g. `MOUSE_FILTER_STOP` for interactive elements and `MOUSE_FILTER_IGNORE` for labels) to preserve standard hover and focus behaviors.
4. **Hook Location:** This is called inside `_apply_responsive_layout()` and at the exit paths of `_render()` to cover active tab content and modal overlay forms (like the Perks/Flaws catalog, Mutation panel, and character select grid).

---

## 4. Build Environment Configuration

If you need to compile new Windows executables or Android APKs, use the automated build tool:

- **Build Script:** `tools/build.ps1`
- **Android SDK Path:** `C:\AndroidSDK` (Requires API 34 & 35, Build-tools 34.0.0 & 35.0.1, NDK 28b, CMake 3.10)
- **Java Home:** `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot` (JDK 17)
- **Signing Keystore:** Locates `debug.keystore` in the project root. Password/alias are set to standard Android defaults (`android` / `androiddebugkey`).

---

## 5. Guidelines for Future Agent Development
- **Theme Color References:** Always query colors from the active theme or local theme variables (e.g., `color_surface`, `color_accent`, `color_text`) rather than hardcoding colors.
- **Dynamic Control Rebuilds:** If you create new screens or panels with scrolling lists, make sure the controls are updated with `_update_mouse_filters_for_touch` to ensure mobile swipe-scrolling behaves correctly.
- **Excluding Media:** Keep final binaries small. The `manuals/` directory containing large reference sheets is explicitly ignored during exports in `export_presets.cfg`.
