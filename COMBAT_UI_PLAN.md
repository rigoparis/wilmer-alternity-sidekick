# Combat: the UI plan

What the screens become once tactical time is running. The rules and the round
model are built and tested; nothing below exists yet.

The shape follows the rule that already governs everything else here: **the GM
runs the game, the player's device owns the character.** The GM declares and
rolls; the target's own device works out what it did to them and reports back.

---

## The loop

```
GM: Start combat
        │
        ▼
GM: Start round ──────► every connected player is asked for an action check
        │                              │
        │                     players roll on their own tray
        │                              │
        ▼                              ▼
    Round starts. Phase board appears on both sides.
        │
        ├─ Amazing phase ─┐
        │                 │  GM works down the acting order.
        ├─ Good phase ────┤  Declares attacks. Players declare dodges.
        │                 │  Nothing lands yet.
        ├─ Ordinary ──────┤
        │                 │
        └─ Marginal ──────┘
                 │
                 ▼
        GM: Advance phase ──► queued results land together;
                              anyone dropped is out of the phases after
                 │
                 ▼
        Round ends ──► next round, everyone rolls again
```

The two things that make this Alternity rather than a turn tracker: a combatant
acts in the phase they earned **and every phase after it, up to their number of
actions**, and results apply **when the phase closes**, not when they are
declared. Both are in `ActionRound` already.

---

## GM screen

### A Combat section, above Checks

Above Checks because during a fight this is the thing with people waiting on it.
Collapsed to a single button when no fight is running.

**Not in combat:** one button, `Start combat`.

**In combat:**

```
┌─ Combat ──────────────────────────────────────────┐
│ Round 3 — Good phase                              │
│                                                   │
│ Acting now                                        │
│   1. Alice        (score 14)      [ Attack ]      │
│   2. Bob          (score 12)      [ Attack ]      │
│                                                   │
│ Waiting: Cy (Marginal), Dana (out — unconscious)  │
│                                                   │
│ [ Advance phase ]              [ End combat ]     │
└───────────────────────────────────────────────────┘
```

- The acting order is `ActionRound.acting_now()`, already sorted correctly.
- Anyone dropped this phase shows as *falling* rather than out, since they are
  still finishing what they declared.
- While waiting on action checks the section instead lists who still owes one,
  with a `Roll for them` escape hatch for a player who has gone to make tea.

### Roster rows gain a condition

Each player row picks up a badge from `combat.condition_of()` — Unhurt, Hurt
(+2 steps), Dying, Unconscious, Dead — and, during a fight, the phase they
earned. That is the line a GM scans between actions.

### What moves, and what does not

Nothing moves out of Table settings. Combat is a game activity, not table
management, so it belongs on the main screen with the roster and the chat.

---

## Player: the Table tab

### Phase board

Mirrors the GM's, read-only, plus the one thing only this player cares about:

```
┌─ Round 3 — Good phase ────────────────────────────┐
│ You act in: Good, Ordinary, Marginal              │
│ ▶ It is your turn now.                            │
│                                                   │
│ Order this phase:  Alice · you                    │
│                                                   │
│ [ Dodge ]   (costs your first action)             │
└───────────────────────────────────────────────────┘
```

- "You act in" is computed from their degree and their actions per round, so a
  player can see what a good roll bought them.
- The dodge button appears only in a phase they can act in, and says what it
  costs — one dodge covers every attack for the rest of the round.

### Action check prompt

When the GM starts a round, the Table tab shows a single prominent prompt:
`The GM called for initiative — roll your action check`. It runs through the
existing `CheckRunner` and tray, so it is the same machinery as any other check.

### Incoming attack

The card a player actually reacts to:

```
┌─ Incoming ────────────────────────────────────────┐
│ A thug fires a charge pistol at you.              │
│ Good hit · 7 points · High Impact · wound         │
│                                                   │
│ Your armor: d6-1 (HI)                             │
│                                                   │
│ [ Resolve ]        [ Spend a last resort point ]  │
└───────────────────────────────────────────────────┘
```

Resolving on this device, in order: roll armor for that impact type, apply
`rules.apply_damage()` to their own sheet, roll the Amazing knockout check if
one is forced, save, push the updated snapshot, and report back what happened.
The GM sees the outcome in the feed and the roster badge changes.

Spending a last resort point blunts the attack one grade first, which is the
only moment it can be spent.

---

## New routes

| Route | Whose | What it does |
|---|---|---|
| `combat_attack_route` | GM | Declare one attack: target, weapon, damage entries, impact type, firepower, modifiers, roll or set the degree |
| `combat_modifiers_route` | GM | The modifier panel — eyeball dial plus the real tables, netting to a step total the GM can override |
| `incoming_attack_route` | Player | The card above, and the resolution |

`combat_modifiers_route` is where the tables built last week get used:
`attack_modifiers_for("ranged"|"melee")` for cover, illumination, position and
manoeuvres, and `range_step_for(weapon_type, band)` for the band, with the band
itself derived from the weapon's own short/medium/long metres.

The GM does not type a weapon's numbers. The equipment catalogue already holds
every weapon with its damage triple, impact type, firepower grade and ranges, so
the attack route picks one — which is also how an NPC gets an attack without an
NPC stat block existing yet.

---

## Over the wire

| Message | Direction | Payload |
|---|---|---|
| `round` | host → all | the whole `ActionRound` dict, resent on every change |
| `action_check` | client → host | degree, check score, roll, critical |
| `attack` | host → one client | the declaration, already rolled |
| `attack_result` | client → host | damage taken, new condition, whether they went down |
| `defence` | client → host | dodge or parry declared, and its degree |

The round is resent whole rather than diffed. It is a small dictionary, it
changes a few times a round, and a player joining mid-fight then needs no catch
-up path at all.

---

## Gaps

1. ~~**Equipped armor absorption.**~~ Closed. `combat.armor_layers(character,
   impact_type)` returns every layer that could answer an attack — worn armor, a
   T'sa's hide, cybertech plating, mutation and psionic shields — and
   `best_absorption(rolls)` keeps the highest of them. Layers do not add up; the
   penalties do. The two shapes armor is written in are both read: the catalogue
   and everything derived from it write `combat.li/hi/en`, and species armor
   writes a flat `armor_li`. A search that knew only one shape found a hide and
   missed every suit in the book.

2. ~~**Weapon type for range.**~~ Closed. `combat.weapon_range_class(skill_id)`
   derives it from the skill the weapon is fired with: 31 pistol, 32 rifle, 33
   SMG, 34 primitive, 8 heavy. Melee skills return "", which is a caller's cue to
   use the melee modifier table instead of asking for a band.

3. ~~**Awareness.**~~ Closed. Three toggles on the attack route, because the
   books do not treat awareness as one flag: cannot see the attacker (no
   resistance, no defence), from behind (resists, cannot turn to meet it), pinned
   (nothing at all). `combat.target_defence()` answers all three.

4. ~~**Actions spent.**~~ Closed, and not by tracking. Nothing in the app can
   know everything that costs an action — reloading, being restrained, an
   argument about what a character is doing — so the number is the GM's to set,
   with a `−  n  +` dial on every combat row. Zero is allowed and means they do
   nothing this round. It resets to what the character's own Constitution and
   Will allow at the start of the next round, so an action taken away for being
   stunned does not quietly cost them one for the rest of the fight.

   A dodge needs no deduction at all: the phase window already gives one action
   per phase from the phase a combatant earned, so the dodge *is* their action
   for that phase.

5. **Toughness.** `combat.toughness_of(character)` reads it off the best armor
   worn, defaulting to Ordinary. That is the other half of the firepower
   comparison and it was not there before.

---

## Staging

1. ~~**Round over the wire.**~~ Done. Start a round, players roll, phase board on
   both sides, advance and end.
2. ~~**Attacks.**~~ Done. `combat_attack_route` declares one — attacker, weapon
   from the catalogue, the modifier tables and the awareness toggles — the GM
   rolls to hit and rolls the damage, and the target's device rolls its own
   armor, applies it to its own sheet, makes any endurance check and reports
   back. `combat_modifiers_route` was not needed: the panel is part of the attack
   route, which is where a GM wants it.
3. ~~**Defence.**~~ Done. A dodge is declared on the player's device, travels to
   the GM on its own message, lands on the round, and is added as a step penalty
   to every attack the GM rolls against them for the rest of it. A parry is
   offered on the incoming-attack card, against melee only, and is decided where
   the character lives: a parry as good as the attack stops it outright and
   nothing is applied.
4. **The rest.** Weapon failures on a natural 20, blasts, and the recovery
   prompts between sessions — all have rules and tests already; they need
   somewhere to be shown.

### What stage 3 actually built

| Piece | Where |
|---|---|
| The actions dial and the dodge on the round | `action_round.set_actions` / `adjust_actions` / `declare_dodge` |
| The dial, on every combat row | `gm_screen._combat_row` |
| A dodge on the wire, before the attack it defends against | `MSG_DEFENCE`, `transport.send_defence` |
| Declaring one | `tab_table._on_dodge_pressed` → `table_session.send_dodge` |
| Applying it to the attack roll | `gm_screen._on_attack_pressed` |
| The parry | `tab_table._on_parry_pressed`, `combat.parry_blocks` |

The two defences are not the same shape, and the code says so. A dodge is
declared once and covers the round, so it has to reach the GM *before* the next
attack — the GM is the one rolling those. A parry answers a single attack and is
decided on the device that owns the character, like everything else about it.

A dodge only counts if the target could defend at all: somebody who never saw
this one coming is not dodging it, however well they rolled.


### What stage 2 actually built

| Piece | Where |
|---|---|
| The attack as a travelling document | `scripts/core/session/combat_attack.gd` |
| Declaring one | `scripts/ui/routes/combat_attack_route.gd` |
| The GM's half — declare, roll to hit, roll damage, send | `gm_screen._on_attack_pressed` |
| The player's half — armor, damage, endurance check, report | `tab_table._on_resolve_attack_pressed` |
| Applying it to a sheet, which only the owner does | `table_session.apply_attack` / `report_attack` |
| A plain notation throw on the tray | `check_runner.roll_notation` |

Two things settled in the building of it. A called shot that lands and a weapon
that outclasses the target's toughness both promote the hit, and both are settled
before the damage dice, because the degree picks which of the weapon's three
damage entries gets rolled. And the endurance check an Amazing hit forces is
rolled *after* the damage lands: being hurt is part of what makes it hard to stay
conscious.
