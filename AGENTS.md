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
  session/           the table: campaign document and store, ENet transport,
                     LAN discovery, player identity, character snapshot

scripts/ui/        presentation
  app_shell.gd       root scene; routes between screens, handles back
  ui_router.gd       navigation stack (RefCounted)
  modal_host.gd      CanvasLayer owning the scrim, stacking and sizing
  sheet_tab.gd       tab contract; declares watched sections
  sheet_context.gd   what a tab is handed
  widgets.gd         stateless builders, palette-aware
  widgets/           controls with behaviour (SearchField, NumberStepper, SkillPicker)
  screens/           character select, character sheet, campaign select,
                     GM screen, table join, player table
  tabs/              the ten sheet tabs
  routes/            catalog, confirm, import, optional rules, theme,
                     skill detail, text prompt, AP award

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
  implicitly for the remote debugger, so the GM connection would appear to work
  in testing and fail only in a release APK. **This has not been verified from a
  release build yet** -- see the open items in `MULTIPLAYER.md`.
- Architectures ship **arm64-v8a only**. Enabling `architectures/x86_64` allows
  running on an Android emulator but takes the APK from roughly 33 MB to 61 MB,
  so turn it on for emulator testing and back off before tagging a release.
- Release builds are currently signed with the debug keystore. Reconcile that
  before distributing outside the group.

---

## 8. The table: one owner per document

Multiplayer is built (see `MULTIPLAYER.md`). Three rules decide where anything
new belongs, and all three fail silently when broken -- nothing errors, the two
devices simply diverge, and it surfaces weeks later as a sheet nobody can
explain.

- **Identity is a `CampaignSession` `player_id`, never an ENet peer id.** Peer
  ids are random per connection; a player returning next week gets a new one.
  `EnetTransport` maps peer to `player_id` on handshake and exposes only the
  stable id upward. A peer id must never reach a signal, a log event or a UI
  label. `PlayerIdentity` is where a player device stores the id it was issued.

- **The GM's device owns the campaign. The player's device owns the character.**
  Sequence numbers are assigned only by the host, so one history exists. AP
  awards are events the player's device applies to its own character file -- a
  GM never writes to a hero they cannot see. What crosses the wire the other way
  is a `CharacterSnapshot`: read-only numbers, no skills or equipment, because
  anything a GM could edit would create a second writer.

- **Rolls travel as settled facts.** Resolved on the roller's device and sent as
  a `RollResult`; nothing re-simulates or re-rolls on receipt. See section 9.

The event log is append-only with a sequence, which is what makes reconnect
"replay everything after seq N". Two consequences:

- Never derive the next sequence number from `events.size()`. The log can be
  compacted (`CampaignStore.compact`) or loaded as a tail, and deriving it would
  reissue numbers already spent. `CampaignSession` tracks the mark, and the
  campaign header stores it so a lost log still continues the sequence.
- Never make correctness depend on replaying the log. Seats carry current state
  -- AP totals, character bindings, who the GM is -- so trimming history costs
  history and nothing else.

Both transports poll explicitly rather than off a frame signal, so the screen
that owns a connection is what pumps it and tearing that screen down closes the
socket. `LanDiscovery` is a convenience and is allowed to fail on its own:
typing the GM's address is a supported path, never a degraded one.

---

## 9. Dice: the simulation is authoritative

When the 3D dice tray is built, the result is **read from where the dice
settle**. Dice collide with each other and with the tray walls, and those
collisions determine the outcome. Do not "optimise" this into a predetermined
result with an animation played over it -- that would silently make the dice
fake, and nothing would fail.

Three consequences that invert the usual networking advice:

- **Cross-platform determinism is not required, and must never be relied on.**
  A roll is never re-simulated anywhere else. The roller simulates locally, the
  dice settle, the faces are read, and *that outcome* is broadcast as a fact.
  The GM waits for the settle.
- **Rolls are client-authoritative, and that is correct here.** Physical dice at
  a real table are client-authoritative too. Do not build anti-cheat around it.
- **The rules layer must not depend on the tray.** Mutation-table rolls happen
  headless and in tests, where no physics scene exists. Randomness enters
  through `RandomSource`: `RngSource` (seeded) for rules and tests,
  `PhysicalDiceSource` for rolls made at the table. Both return a `RollResult`.

Randomness lives on the *input* side -- the launch impulse is randomised, and
the outcome emerges from the simulation.

`3d/physics_engine="Jolt Physics"` and the `Die` / `TrayWall` / `TrayFloor`
physics layers are all in use by `core/dice/dice_tray.gd`.

The three hard parts are settled, and each is worth knowing before touching this
code:

- **Reading which face is up.** `DieShape` frames it as "which declared
  direction points most upward", so the d4 -- which has no up-face -- is read by
  its apex through the same code path as every other die. Meshes are generated,
  so the normals used to read a die are the numbers that built it.
- **The settle.** A hard per-attempt timeout freezes the simulation and forces a
  result, because a die spinning in a corner must never leave a GM waiting.
- **Cocked dice.** One voids the whole throw and every die goes again, capped,
  recorded in `RollResult.rerolls`.

Two things that will bite anyone editing the tray:

- **Build it at unit scale, not life size.** An 11mm die in a 32cm tray falls
  through the floor: it crosses a centimetre of geometry in well under a physics
  step. How big a die looks is a camera question.
- **Godot winds front faces clockwise seen from outside.** Getting it backwards
  does not draw an inside-out die -- every triangle is culled and you look
  through the die at its unlit interior, which reads as a dark blob rather than
  as a winding bug. `smoke_die_shape` checks the convention against `BoxMesh`
  rather than hardcoding it.

**A result was produced and the dice settled are different claims.** The first
version of the tray satisfied the first while failing the second, and the whole
suite passed. `DiceTray.was_forced()` exists so tests can tell them apart.
