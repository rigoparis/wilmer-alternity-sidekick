# Questions for the manuals: Alternity combat, round 2

Round 1 (action round order, surprise, range bands, armor, firepower, actions,
knockout recovery, firing modes, defence costs, cover, movement) has been
answered and implemented. Thank you — three of those answers caught real bugs.

Same request as before: **cite book and page**, say which option is correct
rather than describing all of them, and if something is genuinely GM judgement
rather than a written rule, say so plainly.

**Priority: sections E and F.** E settles a contradiction with what the app
already does, and F is needed before any attack can be resolved end to end. G
and H can wait if budget is tight.

---

## E. Is Firepower vs Toughness core or optional?

The app currently ships Firepower/Toughness as an **optional rule**, off by
default, described as "When an Ordinary weapon hits Good armor or toughness, its
damage degrades one step... Source: Gamemaster Guide Chapter 3 p. 48."

Round 1 said it is **core**, citing Gamemaster Guide p. 52.

This matters because turning it on changes damage results for every character
already saved, so we want to be certain before flipping it.

### E1.
Is Firepower vs Toughness a core rule that always applies, or is it presented as
optional anywhere in the books?

- If it is core: is there any explicitly labelled *optional* variant of it, or an
  "if you prefer a simpler game, ignore this" note?
- What is actually on **Gamemaster Guide p. 48**, and how does it relate to
  p. 52? We may have conflated two different rules.

### E2.
Does the **upgrade** half (firepower above toughness promoting hit quality) come
from the same rule and the same page as the **degradation** half, or are they
separate rules that could be adopted independently?

### E3.
Alternity labels some rules explicitly as optional — "Optional Rule: Dazed", for
instance. Please list the combat-related rules the books explicitly label
optional, so we can be sure our optional-rule toggles match the books rather
than an earlier guess.

---

## F. The exact attack resolution pipeline

We need the canonical order of operations. Our engine currently does damage as:
firepower degradation → subtract armor from primary → assess primary → derive
secondary from what got through → overflow stun into wound and wound into mortal.

### F1. The full sequence
Please give the step-by-step order for resolving **one attack**, from declaring
it to marking the damage, including exactly where each of these happens:

- netting the situation modifiers into a step total
- the target's resistance modifier
- rolling control die + situation die
- determining the degree of success
- a called shot's promotion of the degree
- the firepower **upgrade** of hit quality
- choosing which of the weapon's three damage entries to roll
- rolling damage
- the firepower **degradation** of the damage type
- rolling armor and subtracting it
- secondary damage
- overflow between tracks
- the Amazing-damage knockout check

If two of those can happen in either order without changing the result, say so —
that is useful too.

### F2. The target's resistance modifier
Round 1 said ranged attacks are penalised by the target's Dexterity resistance
modifier and melee by Strength.

- Is that modifier **added to the attacker's step total** like any other
  situation modifier, before the situation die is chosen?
- Is it the value from Table P2 (ability score → steps)?
- Does it apply to *every* attack, or only when the target is aware and able to
  move?

### F3. Rolling damage
- Is the damage die rolled **once per attack**, regardless of degree?
- The Strength damage bonus: which attacks does it apply to (melee only, thrown,
  unarmed?), and is it added to the damage roll or to the weapon's listed damage?
- Does a burst or autofire hit roll damage once per target, or once per round
  that connects?

### F4. Critical failure on an attack
What happens on a natural 20 attacking? Round 1 mentioned a weapon jam on burst
fire specifically — is there a general critical-failure result for attacks, or is
it left to the GM?

---

## G. Defence in detail

Round 1 gave the action costs for dodge and parry. We still need what they
actually *do* mechanically.

### G1. Dodge
When a character spends an action to dodge:
- Is it an opposed check, a flat step penalty applied to the attacker, or
  something else?
- If it is a check, what is rolled against what, and what does each degree of
  success do?
- Does one dodge cover every attack against that character for the round, or only
  one attack?

### G2. Parry
Same three questions for parry.

### G3. Awareness
- Can a character dodge or parry an attack they did not see coming (attacker
  hidden, attack from the rear, surprise phase)?

---

## H. After the hit

### H1. Running out of Mortal
What happens when the last Mortal box is filled? Please give the exact rule —
immediate death, dying and stabilisable, a check to survive?

### H2. Recovery rates
Our campaigns run for months, so recovering between sessions matters. For each
of Stun, Wound, Mortal and Fatigue: how much is recovered, how often, and does
it require rest, treatment or a skill check?

### H3. Last resort points in combat
- At what exact moment must a last resort point be declared, relative to rolling
  the dice and applying results?
- It shifts the degree of success by one grade — can it shift a Failure to an
  Ordinary success, or only improve an existing success?
- Can it be spent to reduce or negate damage after a hit lands?

---

## I. Area effects — only if budget allows

### I1.
How do grenades and explosions work? Specifically: is there a blast radius with
different damage grades by distance (the "Amazing radius" phrasing suggests so),
who rolls what, and can a target dodge to reduce it?
