# Questions for the manuals: round 3

Rounds 1 and 2 are answered and implemented — thank you. Between them they
caught four real bugs, including one where the firepower rule was gated exactly
backwards.

Same request: **cite book and page**, say which option is correct rather than
describing all of them, and if something is genuinely GM judgement rather than a
written rule, say so plainly.

**Priority: J1 first.** It blocks the player-side damage resolution outright —
nothing can work out how much armor absorbs until it is answered. K and L shape
the combat UI. M is an audit that touches saved characters, so it can wait.

---

## J. Armor — blocking

### J1. Does armor stack?
A character can have armor from several sources at once:

- **natural** armor from their species (a T'sa's scaled hide, `d4+1` LI /
  `d4` HI / `d4-1` En)
- **worn** armor from equipment
- **cybertech** plating
- armor from **mutations** or **psionic** effects

When a character has more than one of these, how is the absorption worked out?

- do the dice **add together** (roll each and sum)?
- does the **single best** source apply and the others are ignored?
- does worn armor **replace** natural armor specifically, while other sources
  stack?
- something else?

If the answer differs between sources — say, natural and worn stack but two worn
suits cannot both be used — please spell out which combinations do what.

### J2. Wearing more than one suit
Can a character wear two pieces of manufactured armor at once (a vest under a
jacket, say)? If so, how do they combine?

### J3. Armor and the action penalty
Armor carries a step penalty for wearing it. If armor does stack, do the
penalties stack too?

---

## K. The action economy

Round 1 established one action per phase, and that a character with three actions
who rolls Amazing acts in Amazing, Good and Ordinary.

### K1. Which action does a dodge cost?
Round 1 said a dodge "costs the defender their first action of the round" and
must be declared "during the first phase in which an action is available".

For a character with 3 actions who rolled Amazing: if they dodge, do they act in
Good and Ordinary (having spent the Amazing-phase action), or do they lose the
*last* of their three phases instead? In other words, does the dodge come off the
front of their schedule or the back?

### K2. Attacking repeatedly
A character with three actions can attack in three phases. Is there any
escalating penalty for the second and third attack in a round, or is each one
resolved at full skill?

### K3. Two Actions at Once
Round 1 gave +2 steps to the first activity and +4 to the second. To confirm:
does that let a character do two things using **one** action, or does it still
consume two actions and simply allow them in the same phase?

### K4. Do damage penalties affect the action check itself?
A wounded character carries step penalties. Does that penalty apply to the
**action check** at the top of the round — making a hurt character act later —
or only to the actions they then take? (Our engine currently applies it to the
action check's situation die but not to the score.)

---

## L. Awareness and unconsciousness

### L1. When is a target "unaware" mid-fight?
Losing the resistance modifier and the ability to dodge is a big swing, so we
want to apply it exactly when the books do.

Outside the surprise phase, what makes a target unaware? Specifically:
- an attacker the target cannot see (hidden, behind them, in darkness)?
- a rear attack — is that automatically unaware, or just the −2 step bonus?
- a target who has already acted in an earlier phase?
- a target who is prone, held, or pinned?

### L2. Unconscious from stun, and end-of-scene recovery
Round 2 said stun recovers **completely at the end of the scene**, and separately
that a character knocked out by stun stays out for the round it happened and the
next, then makes Resolve–physical checks once per round to wake.

These seem to point different ways for a fight that ends while someone is down.
When the scene ends with a character unconscious from stun:
- do they simply wake up, their stun having recovered?
- or do they keep making Resolve checks?

### L3. Does being unconscious end their participation in the round?
We have combatants dropping out of later phases when knocked out. Is there any
case where an unconscious character still does something in a later phase of the
same round?

---

## M. Optional rules audit — lower priority

Round 2 listed the rules the books explicitly label optional. Our app ships a
different set, and we would rather match the books than an earlier guess. For
**each** of the toggles below, please say whether it is a real labelled optional
rule and where, or whether it is a house rule that should not be presented as
official:

1. **"Alternate starting skill points"** — a different number of skill points at
   character creation.
2. **"Alternate broad skill limit"** — a different cap on how many broad skills
   a starting hero may take.
3. **"Flat specialty advancement cost"** — specialties cost a flat rate to
   improve rather than a scaling one.
4. **"Psionic Talents"** — non-Mindwalker heroes may buy Psionics skills.
5. **"Uncapped monetary awards"** — monetary awards continue past 24th level.
6. **"Age categories"** — a hero's age adjusts their ability scores.

Round 2 also named three we do **not** have. For each, please confirm what
turning it on and off actually changes, so we can implement them:

7. **Weapon Accuracy** (Gamemaster Guide p. 43) — we currently apply each
   weapon's accuracy modifier unconditionally. With the rule *off*, is a
   weapon's listed accuracy simply ignored?
8. **FX Achievement Points** (Beyond Science p. 3).
9. **Psionic Vulnerability** (Beyond Science p. 11).
