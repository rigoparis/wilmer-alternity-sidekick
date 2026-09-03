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

## Gaps to close first

These are needed before the player side can resolve anything, and none of them
exists yet.

1. **Equipped armor absorption.** Armor rows carry `armor_li`, `armor_hi` and
   `armor_en` as dice notation, but nothing returns the absorption for a given
   impact type from what a character is actually wearing. Needs
   `equipped_armor_absorption(character, impact_type)`, and a decision about
   whether natural armor (a T'sa's hide), worn armor and cybertech stack or the
   best one wins — **a rules question I do not have an answer for.**

2. **Weapon type for range.** `range_step_for` wants "pistol", "rifle", "smg",
   "primitive" or heavy. The catalogue records a weapon's skill and category but
   not that classification directly; it probably has to be derived from the
   combat skill the weapon uses.

3. **Awareness.** The attack route needs an "they did not see it coming" toggle,
   because that zeroes the target's resistance modifier and forbids a dodge.
   Nothing tracks awareness today, and the GM is the only one who knows.

4. **Actions spent.** `ActionRound` knows how many actions a combatant has and
   which phases that reaches, but nothing decrements as they act. Dodging costs
   the first action; that has to come off the same pool.

---

## Staging

1. **Round over the wire.** Start a round, players roll, phase board on both
   sides, advance and end. No attacks yet — this alone is usable, and it is the
   part with the most moving pieces.
2. **Attacks.** The declaration route, the modifier panel, and the damage round
   trip. Closes gaps 1–3 above.
3. **Defence.** Dodge and parry, which needs gap 4.
4. **The rest.** Weapon failures on a natural 20, blasts, and the recovery
   prompts between sessions — all have rules and tests already; they need
   somewhere to be shown.

Suggested: do 1 and stop for a look, since it changes both screens and is the
foundation everything else sits on.
