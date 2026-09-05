# Three jobs, written to be picked up cold

Each section below is a self-contained brief. Nothing in one depends on another,
and they can be done in any order or by different people. Read
[AGENTS.md](AGENTS.md) first — sections 5 (Development Guidelines), 6 (Local
Tooling vs. Committed State) and 8 (The table: one owner per document) are the
ones these touch.

Job 1 is a rules audit and needs the manuals. Job 2 is a small, contained bug
with a known fix. Job 3 is a new feature on the character sheet.

---

## How this repo expects work to be done

These are not suggestions. Every one of them exists because something was shipped
broken without it.

**Tests are the deliverable, not the evidence.** Every suite lives in `tools/` as
`smoke_*.gd`, extends `res://tools/test_harness.gd`, and is discovered
automatically. Run them all with:

```bash
tools/run_tests.sh
```

On Windows run it from Git Bash. Set `GODOT=/c/path/to/godot.exe` if `godot` is
not on the path. Exit code is 0 only if every suite passes; there are currently
56.

**Prove the test fails before you believe it passes.** Write the assertion, then
break the code it covers, run the suite, watch the specific check fail, and put
the code back. A test written after the fact that has never failed is a test that
proves nothing, and this repo has caught fabricated rules exactly this way. Do it
for every non-trivial claim you add.

**Render the UI; do not only assert about it.** Every layout defect reported by a
human so far had passed the full suite first. If you touch a screen:

```bash
godot --path . -s tools/capture_shell_screenshot.gd
```

It writes PNGs at 390x844 (phone), 1280x720 and 1920x1080 into the user data
`shots/` directory and prints the path. Look at them. The phone width is where
things break — buttons report their full text width as a minimum, so a row of
them silently pushes past the screen edge.

**Never invent a rule.** Everything in `scripts/alternity_rules*.gd` carries a
source citation in its comment (`Player's Handbook p. 71`, `Table G8`). If you
add or change a rule, cite the page. If you cannot find the page, say so in the
PR rather than guessing — a plausible-sounding wrong rule is worse than a gap.

**The manuals are in `manuals/`.** They are scanned PDFs with no text layer, so
grep and text extraction will return nothing useful. Render the pages as images
and read them:

```python
import fitz  # PyMuPDF
doc = fitz.open("manuals/Alternity 01 Players Handbook.pdf")
doc[245].get_pixmap(dpi=200).save("page246.png")   # 0-indexed
```

Beware the offset: printed page numbers do not match PDF page indices, and the
offset differs per book. Find it once per book by rendering a page and reading
its printed folio.

**Comments explain why, not what.** Match the surrounding prose. The house style
states the rule, then the consequence that made it worth writing down.

---

## Job 1 — Audit the optional rules against the books

**Status: not started. Deferred deliberately; nothing depends on it.**

### What exists now

`scripts/alternity_rules_constants.gd:215` holds `OPTIONAL_RULES`, eight toggles
a campaign can turn on. `scripts/ui/routes/optional_rules_route.gd` is the screen
that sets them. Each is honoured somewhere:

| id | Honoured at | What it changes |
|---|---|---|
| `2a` | `alternity_rules.gd:1512` | Starting skill points become 30 + 3×INT |
| `2b` | `alternity_rules.gd:1546`, `:2206` | Broad skill cap becomes 6 + INT RM |
| `2c` | `alternity_rules.gd:1596`, `alternity_rules_fx.gd:350` | Flat specialty advancement cost |
| `dazed` | `alternity_rules.gd:1116` | Step penalty at >50% Stun or Wound |
| `psionic_talents` | `alternity_rules.gd:2226`, `tab_psionics.gd:28` | Non-Mindwalkers may take Psionics |
| `monetary_awards_uncapped` | `alternity_rules_achievements.gd:285` | Monetary award past 24th level |
| `age_effects` | `alternity_rules.gd:686`, `tab_basics.gd:147` | Age category ability modifiers |
| `damage_upgrading` | `alternity_rules.gd:3000` | Firepower above toughness promotes the hit |

### The suspicion

An earlier pass over these — done from the app's own citations, **not** from the
books — raised four questions. **Treat every one of them as unverified.** They
are starting points for a manual read, not findings.

1. **Are these actually optional rules, or house rules wearing the label?** The
   `2a` / `2b` / `2c` set cites *Gamemaster Guide* Chapter 4 p. 68 and Table G5
   p. 31. `dazed` cites *Player's Handbook* Chapter 8 p. 88. Check whether each
   is presented in the book as an optional variant or as the standard rule. A
   standard rule sitting behind a toggle is off by default and therefore wrong
   for every campaign that does not know to turn it on.

2. **`psionic_talents` may be core, not optional.** The gate at
   `alternity_rules.gd:2226` produces a validation message when a non-Fraal
   non-Mindwalker selects a psionic skill and the toggle is off, and
   `tab_psionics.gd:28` hides the whole tab. The rule cites *Player's Handbook*
   Chapter 14. Read that chapter: if Psionic Talents is how the book expects
   anybody to learn psionics, this toggle is hiding a core subsystem behind an
   opt-in nobody finds.

3. **`monetary_awards_uncapped` may be inventing the cap it lifts.** The code at
   `alternity_rules_achievements.gd:275-289` counts eligible levels from a
   printed list that stops at 24th, and the toggle replaces that with
   `level / 3`. The reasoning in the comment — that the list carries no "etc." and
   therefore eight is the maximum — is an inference from typography. Read *Player's
   Handbook* p. 126-128 and *Gamemaster Guide* p. 113 and settle whether the
   books cap it at all. If they do not, the cap is a house rule and the toggle
   should go, with the uncapped behaviour becoming the only behaviour.

4. **Three real optional rules may be missing.** Look for Weapon Accuracy, FX
   Achievement Points, and Psionic Vulnerability, and any others the books offer.
   Note on Weapon Accuracy specifically: the catalogue already carries an
   `accuracy` field per weapon and
   `scripts/alternity_rules_equipment.gd:574-575` applies it to the step total
   **unconditionally**. So the question is not whether it is implemented but
   whether the books make it optional — if they do, it needs a toggle and a
   default; if they do not, nothing changes and that is a finding worth writing
   down.

### The work

Read the relevant pages. For each of the eight existing toggles and each
candidate new one, decide: core, optional, or house rule. Then:

- A **house rule** stays a toggle but says so in its `description`, which is user
  facing — a GM deserves to know the book does not contain this.
- A rule that is actually **core** loses its toggle and becomes unconditional.
  Removing a toggle means removing the `optional_rule_enabled` call sites listed
  in the table above, not just the constant; and existing saved characters carry
  the old flag, so check nothing reads it back.
- A **missing optional rule** gets an entry in `OPTIONAL_RULES` with a real page
  citation, an `optional_rule_enabled` gate wherever it applies, and tests.

Update every `description` you touch. They are the only explanation a GM gets, and
several currently argue a position rather than describing a rule.

### How to verify

`tools/smoke_rules_audit.gd` is the largest suite in the repo (1359 checks) and
is where cross-cutting rules assertions live. Add there, or to the matching
chapter suite (`smoke_con_chapter.gd`, `smoke_psionics_chapter.gd`, and so on).

Cite the page in the test's own comment. Then break each rule you added and watch
the check fail.

There is a fixture and golden-file set that will drift if character maths change:

```bash
godot --headless --path . -s tools/make_fixtures.gd
```

Regenerate **goldens only** unless a fixture genuinely changed; a blanket
regeneration silently absorbs unrelated catalogue drift, which has happened
before and hid a real change.

---

## Job 2 — Routes measure a viewport they are not in yet

**Status: known bug, one-line fix each, no design decisions.**

### The defect

`UiRouter.push()` (`scripts/ui/ui_router.gd:77-92`) instantiates a route, calls
`route.configure(props)`, and only then calls `_host.present(route, ...)`. So
during `configure` — and therefore during the `_build()` that every route calls
from it — **the route is not in the scene tree**.

Two routes ask for the viewport size during that window:

- `scripts/ui/routes/skill_pick_route.gd:167`
- `scripts/ui/routes/character_view_route.gd:124`

Both are:

```gdscript
func _is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH
```

Called from outside the tree, `get_viewport_rect()` logs
`Condition "!is_inside_tree()" is true. Returning: Rect2()` and returns an empty
rect, so `_is_wide()` is always false. The consequences:

- `skill_pick_route.gd:125` — `grid.columns = 3 if _is_wide() else 2`. The skill
  picker renders two columns on a 1920-wide desktop instead of three.
- `character_view_route.gd:105` — the `SheetContext` is built with
  `is_wide_layout` false, so the GM viewing a player's sheet gets the phone
  layout on desktop.

It is a real error in the log on every push of either route, not a silent
mis-measurement, which is how it was found.

### The fix

`scripts/ui/routes/combat_attack_route.gd` already solved this and is the pattern
to copy:

```gdscript
## Whether there is room for two columns of toggles.
##
## configure() runs before the router presents the route, so during the first
## build there is no viewport to measure and asking for one is an error. The
## panel is rebuilt in _ready, which is the first moment the answer is real.
func _is_wide() -> bool:
	if not is_inside_tree():
		return false
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


func _ready() -> void:
	_render_modifiers()
```

Two halves, and both are needed. The guard stops the error; the `_ready` rebuild
is what actually fixes the layout, because the first build already happened at
the wrong width.

For `skill_pick_route` the rebuild is the grid. For `character_view_route` it is
the `SheetContext`, which is passed to the sheet at
`character_view_route.gd:105` — rebuilding may mean re-running more of `_build()`,
so read it before deciding how much to redo.

**This changes how two existing screens look on desktop.** That is the point, but
it means the screenshots are the verification, not a formality.

### How to verify

```bash
godot --path . -s tools/capture_shell_screenshot.gd
```

Before the fix, `desktop_*` and `wide_*` shots of these routes show phone
layouts; after, they should show the wide ones. Confirm the
`Condition "!is_inside_tree()"` error no longer appears in the capture output —
it currently does.

Then grep the rest of the routes for the same shape, because two were found by
accident and nothing has swept for a third:

```bash
grep -rn "get_viewport_rect" scripts/ui/routes/
```

---

## Job 3 — The long recovery

**Status: rules exist and are tested; nothing in the UI offers them.**

### What exists

`scripts/alternity_rules_combat.gd` already models it, cited to *Gamemaster
Guide* p. 54:

- `RECOVERY` (`:506`) — the cadence, skill and per-degree amount for each of the
  four tracks.
- `recovery_amount(track, degree)` (`:536`) — how much one successful check
  restores.
- `recovers_naturally(track)` (`:546`) — false for mortal damage, which does not
  heal on its own at all.
- `end_scene(character)` (`:487`) — stun clears completely, and anybody it
  knocked out wakes up.

The cadences are deliberately unlike each other and that is the whole point of
the feature: stun is gone by the end of the scene, fatigue comes back hourly,
wounds take **weeks**, and mortal damage only ever comes back through surgery.

`end_scene` is already wired: the GM presses "End the scene" on the combat
section, it travels as `CampaignSession.EVENT_SCENE_END`, and each player's
device applies it to its own character (`table_session.gd`, `_end_the_scene`).
**Nothing else is offered anywhere.** `grep -rn "recovery_amount" scripts/ui/`
returns nothing.

### What to build

A recovery affordance on the character sheet — not on the table. This is
something a player does to their own hero between sessions, and it must work with
no GM and no network, which is why it does not belong on the Table tab.

The Summary tab (`scripts/ui/tabs/tab_summary.gd`) already renders the four
damage tracks as boxes (`_build_damage`, `:162`), which is where a
player looks at their damage and therefore where they will look to clear it.

For each track carrying damage, offer what the rules allow:

- **Fatigue** — a Resolve (physical resolve) check, one per hour of complete
  rest. A success restores 0-3 points by degree.
- **Wound** — the same skill, one check per week of rest, restoring 1-4 by
  degree.
- **Mortal** — no check. Medical Science (surgery) only; say so rather than
  offering a button that cannot work.
- **Stun** — nothing to offer. It clears when the scene ends, which the GM
  already drives.

Run the checks through `CheckRunner` (`scripts/ui/check_runner.gd`) so they use
the same dice tray and the same path as every other check —
`run_called(check, doc, skill)` takes a check whose step is already set and goes
straight to the tray. See `tab_table.gd`'s `_survives_the_hit` for a worked
example of building a `SkillCheck` for a named skill and reading the degree back.

Apply the result through `doc.apply([CharacterDoc.DAMAGE], func(c): ...)`, never
by mutating `doc.raw()` — mutating the raw dictionary skips the change
notification and the summary cache invalidation. Note that a lambda captures
locals **by value**, so read anything you need out of `apply`'s return value
rather than assigning to a variable declared outside it. That exact mistake
shipped once: the damage landed on the sheet while the report said nothing had
happened.

### Two things to settle before building

Neither is answered by the code, and guessing will produce a screen that lies:

1. **Does the app track elapsed time?** It does not. So a weekly wound check
   cannot be rate-limited by the app — either the player is trusted to press it
   once a week, or the screen says what the cadence is and leaves the honesty to
   them. Recommend the second and make the caption explicit.

2. **Does a dying character's Stamina-endurance check belong here?** *Gamemaster
   Guide* p. 54 has a dying hero checking at the end of the scene and every hour
   after, taking more mortal damage on a failure. That is a different shape from
   recovery — it is a countdown, not a repair — and it may belong on the table
   rather than the sheet. Read the page and decide; whatever you choose, say why
   in the comment.

### How to verify

Add to `tools/smoke_tabs_ui.gd` or a new `smoke_recovery.gd`. Assert the
cadences and amounts come from `RECOVERY` rather than being retyped, that mortal
damage is never offered a check, and that a failed check restores nothing.

Then break each one — make wound recovery restore a flat 1, make mortal
recoverable — and watch the checks fail before you restore it.

Screenshot the Summary tab with a hurt character. The capture tool already seeds
one: `tools/capture_shell_screenshot.gd` sets stun 3 and wound 1 on the seeded
hero, so `*_tab_summary.png` will show the new controls without any extra setup.
