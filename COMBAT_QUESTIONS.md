# Questions for the manuals: Alternity tactical combat

Context for whoever answers: we are implementing Alternity's action round and
combat resolution in an app. The rules engine already implements degrees of
success (including natural 1 and natural 20), action check scores, the step→die
chain, the damage pipeline (armor on primary damage only, secondary stun from
wound, secondary wound+stun from mortal, both 2-for-1 overflows), and the
cumulative penalty table including Dazed.

**Please cite book and page for each answer** (e.g. "Player's Handbook p. 57").
Answers get quoted in source comments, and a rule we cannot attribute is a rule
we will eventually mistrust. If a rule genuinely is not in the books and is GM
judgement, say so plainly — that is a useful answer.

Where a question offers options, please say which is correct rather than
describing all of them.

---

## A. Blocking — we have already implemented these and may have them wrong

### A1. Order of actions inside a phase

Within a single phase, when several characters act, what decides who goes first?

This matters because Alternity is roll-under: a *lower* d20 result is a better
check. We currently sort by **highest action check roll total first**, which we
suspect is backwards.

Which is it?
- highest **roll total** first
- lowest **roll total** first
- highest **Action Check score** (the character's own target number) first
- something else (please describe)

And does the order affect anything mechanically, given that results apply
simultaneously at the end of the phase — or is it purely about who declares
first?

### A2. How often is the action check rolled?

Does every combatant roll a new action check at the start of **every** round, or
is it rolled once when combat begins and kept for the whole fight?

### A3. The surprise phase

Player's Handbook p. 59 mentions a special *surprise phase* where unsurprised
characters may act, after which "normal action rounds start."

- Is the surprise phase a fifth phase inside the first normal round, or a
  separate pre-round that happens before round 1?
- Do characters roll an action check to act in it, or does everyone unsurprised
  simply act?
- How many actions does a character get in the surprise phase?

### A4. Is the p. 246 "Situation Die Modifiers" table the right one for combat?

We are using the compiled **Situation Die Modifiers** table (Extreme +3,
Moderate +2, Slight +1, Marginal none, Ordinary −1, Good −2, Amazing −3) as the
general step scale, treating "light cover", "moonlight" etc. as instances of
those categories.

Is there a **separate, specific combat modifiers table** (range, cover,
visibility, movement, called shots, aiming...) that we should be using instead
or in addition? If so, please transcribe it in full with its page.

---

## B. Blocking — needed for the next piece of work

### B1. Which armor rating applies to which attack?

Armor has three ratings: LI (low impact), HI (high impact), En (energy).

- What decides which of the three applies to a given attack? Is it a property of
  the weapon, of the damage type (s/w/m), of the ammunition, or something else?
- Where is that property recorded on a weapon's stat line?

### B2. How is armor absorption rolled and applied?

- The armor rating is written like `d6−3`. Is that rolled fresh **per hit**?
- Is it subtracted from primary damage only? (Our engine assumes yes.)
- If the roll comes out negative, is it treated as 0?
- Does armor apply against every damage type it is rated for, including Stun?

### B3. Where do Firepower and Toughness grades come from?

The Firepower/Toughness rule compares a weapon's firepower grade (Ordinary,
Good, Amazing) against a target's toughness grade.

- Where is a **weapon's** firepower grade recorded? Is it on the weapon's stat
  line, derived from its damage, or assigned by the GM?
- Where is a **character's or vehicle's** toughness grade recorded? Is an
  ordinary human always Ordinary toughness?
- Is Firepower/Toughness an optional rule, or core? (Our app currently treats it
  as optional and gates it behind a setting.)

### B4. Range bands and their modifiers

Weapons carry a range like `10/20/40`.

- Are those the maximum distances in metres for short / medium / long?
- What step modifier does each band impose? We currently use short −1,
  medium 0, long +1 — is that right?
- Is there a band beyond long (extreme), and can a weapon fire past its longest
  listed range at all?

### B5. What is an "action", and how do actions relate to phases?

A character gets 1–4 actions per round based on CON + WIL.

- Is it **one action per phase** (so a character with 3 actions who rolled
  Amazing acts in Amazing, Good and Ordinary but not Marginal), or may a
  character spend several actions in the same phase?
- Which activities cost a full action? Specifically: attacking, moving,
  reloading, drawing a weapon, standing up, using a skill.
- Are there free actions, and if so what qualifies?

### B6. Knockout recovery

An Amazing hit forces a Stamina–endurance check or the character is knocked
unconscious "for the rest of the round and all of the next."

- After those two rounds, PHB p. 94 mentions **Resolve–physical resolve** checks
  to regain consciousness, one per round. Please confirm this is the right skill
  and cadence.
- On waking, how much stun damage is recovered? (p. 94 suggests it depends on the
  degree of success — please give the exact numbers.)
- Does the knocked-out character lose their remaining actions in the current
  round entirely?

---

## C. Useful — will shape the attack UI

### C1. Firing modes

- What firing modes exist (single, burst, full auto) and what does each do
  mechanically — extra attacks, a step modifier, extra damage?
- How is a weapon's available mode recorded on its stat line?

### C2. Does the target do anything?

- Is an attack purely attacker-rolls-against-their-own-skill-score, or does the
  target contribute a defence, dodge or resistance modifier?
- If the target can react, does reacting cost them an action from their own
  allotment?

### C3. Called shots and aiming

- Is there a called-shot rule (targeting a specific location), and what step
  penalty does it carry?
- Is there an aim action that grants a step bonus, and what does it cost?

### C4. Cover

- Is cover purely a step penalty on the attacker's check, or does it also reduce
  damage / block line of fire entirely?
- How many grades of cover are there, and what is each worth?

### C5. Multiple opponents and flanking

- Are there modifiers for attacking a target who is engaged with someone else, or
  for being outnumbered?

### C6. Movement in combat

- The Combat Movement Rates table (PHB p. 246) gives Sprint / Run / Walk / Easy
  Swim / Swim / Glide / Fly in metres.
- Does moving cost an action? Does moving impose a step penalty on attacks made
  in the same round, and if so how much?

---

## D. Lower priority — for later

### D1. NPC stat blocks

What is the minimum stat block the books use for an NPC or creature in combat?
We want to know exactly which fields a GM must fill in: action check score,
durability, armor, attacks, firepower/toughness, actions per round, anything
else.

### D2. Vehicles and scale

Does the same action round structure govern vehicle and starship combat, or is
there a separate initiative/phase system for those?

### D3. Ongoing conditions

Besides Dazed, Fatigue and Mortal-damage penalties, are there other ongoing
combat conditions that impose step penalties and would need tracking (stunned,
prone, blinded, grappled, on fire)?
