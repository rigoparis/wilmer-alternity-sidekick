# Questions for the manual AI — Dark•Matter, round 5

Context to paste in first:

> I'm building a Dark•Matter character builder. Four earlier rounds are done and
> in the app: the five alien hero species from Table D14, the Enochian school and
> its seven spells, Hermeticism's setting-specific reprice, Lore and its five
> specialties, Cryptography, Research, Forgery, Linguistics, Xenoengineering, the
> psionic and FX talent gateways and surcharges, the FX energy pool rules, the PEP
> purchase limits, and the alien tech penalty. Please answer with page citations,
> and say explicitly when the book does not state something rather than filling
> the gap — I would rather leave a thing out than ship a guess.

---

## Part 1 — Three things I have already built that may be wrong

These matter most. Each is code shipping now against a reading I am no longer
sure of.

### 1.1 Superior Talent's rank caps — my table disagrees with yours, in both versions

My app enforces these psionic limits for a Dark•Matter talent:

| Case | Broads | Specialties | Rank caps |
|---|---:|---:|---|
| No Superior Talent | 1 | 2 | 12, 6 |
| Superior Talent (4 pt) | 2 | 4 | **12, 6, 6, 6** — plus at most 2 specialties per broad |
| Superior Talent (6 pt) | 1 | 4 | **12, 6, 6, 6** |

Your round-1 answer described them differently:

- 4-point: "2 psionic broad skills and 2 specialties from each, **up to Rank 6**"
  — which reads as caps of **6, 6, 6, 6**, with nothing at rank 12 at all.
- 6-point: "4 psionic specialties up to Rank 12, **only 2 can go beyond Rank 6**"
  — which reads as caps of **12, 12, 6, 6**.

Your round-3 answer described it a third way: "allowing the character to buy more
specialties and take one specialty up to Rank 12 instead of Rank 6."

**Please quote Table D2's Superior Talent entry and the paragraph under it
verbatim.** For each of the 4-point and 6-point versions: how many broad skills,
how many specialties, and what is the maximum rank for each? If the 4-point
version really caps everything at 6, my app is handing out a rank-12 power nobody
paid for.

### 1.2 Can a Dark•Matter talent take Biokinesis?

Your round-3 answer gave the talent prices as "6/7/6" and named exactly three
broad skills: ESP 6, Telekinesis 7, Telepathy 6. Alternity has a fourth,
**Biokinesis** (base 6, so 7 for a talent). My app currently lets a Dark•Matter
talent buy it.

**Is Biokinesis available to a Dark•Matter human talent, or does the setting limit
talents to ESP, Telekinesis and Telepathy?** If it is available, why does the
setting's own price list name only three?

### 1.3 Untrained FX in Dark•Matter — blanket ban, or per-spell?

Your round-1 answer said: "Spells and Miracles Untrained Prohibited: No FX
specialty skill can be used untrained."

But the Enochian table you sent in round 3 marks **White salamander as untrained:
Yes**, while its six siblings are No. Both cannot be true.

My app currently honours each spell's own flag and applies **no** blanket
Dark•Matter prohibition — so a Dark•Matter caster can untrained-cast any Faith
miracle whose entry allows it, which is most of them.

**Which is right?** Does Dark•Matter override every spell's own untrained flag, or
is the blanket statement a generalisation with exceptions like White salamander?

---

## Part 2 — The one disagreement that touches existing characters

### 2.1 Do mutants keep the human +5 skill points and +1 broad skill?

Asked last round; repeated because it is the only outstanding answer that would
change numbers on characters people have already built, so I have not acted on it.

You said mutants "retain the starting human human-species resource bonuses of +5
skill points and +1 free Broad Skill" (Part 1 p. 59). My app gives its Mutant
species **0 and 0**, justified in its own description — "Mutants use the human
ability range and gain no fixed racial benefits. Instead they receive mutation
points" — which carries no page citation and may be somebody's inference.

The logic cuts both ways: the +5/+1 is Table P4/P5's compensation for humans
having no special abilities, and a mutant's compensation is mutation points, so
granting both looks like double-dipping.

1. **Does a Mutant row exist in Table P4 (free skills) and Table P5 (skill points
   and broad skill allowance)?** If so, what does it say?
2. Is the +5/+1 **stated**, or inferred from mutants being human? I would rather
   have the sentence than the reasoning.
3. **Is Mutant a Dark•Matter species or a core one?** My app offers it in every
   setting, but every mutation in its catalogue cites the Dark•Matter book, which
   suggests it should be gated with the other five.

### 2.2 Interrogate's profession code

Asked twice; you have noted both times that it did not reach you, so it is
probably worth pasting on its own.

Your worked example of the Corporate Security Specialist priced
*Investigate—interrogate* at **4**, "not in-profession". My catalogue has it as
**CF** (Combat Spec and Free Agent), which makes it **3** for a Combat Spec. Every
other number in that example matched my catalogue exactly.

**What profession code does the Player's Handbook skill list (p. 65, Table P19)
print for Interrogate?**

---

## Part 3 — One thing nobody has ever verified

### 3.1 Incantation

Incantation is the one Dark•Matter school that predates all of this work, and it
has never been checked against a page. My app has it as a **Faith** school costing
**8**, with four specialties: *Battle spirits*, *Calming voice*, *Shatter*, *Voice
of rage*.

**Please confirm its category (Faith or Arcane Magic), governing ability pair and
cost, and give its full specialty list** — each spell's cost, governing ability,
FX energy cost, untrained flag and rank benefits, in the same shape you gave
Enochian. If there are specialties beyond those four, I am missing them.

---

## Part 4 — What I would need to build the three subsystems you described

Only worth answering if you think they are worth having. Requisition looks the
most valuable of the three.

### 4.1 Requisition (Arms & Equipment Guide p. 5)

I have Table 1's modifiers. What I lack is the check itself:

- **What is it rolled against** — the Administration–bureaucracy skill score, or
  something else?
- **What does each result mean?** Does Ordinary get the item and Good or Amazing
  get more? What happens on a Failure, and on a Critical Failure?
- **How often may a hero requisition** — once per assignment, once per session, or
  unlimited with escalating penalties?
- **"Hero's level + years of service"** appears in the price modifiers. Is years of
  service a number the player tracks on the sheet, and where does it start?
- **Do the availability codes match the equipment tables?** My catalogue already
  tags every item Any / Common / Controlled / Military / Restricted. Are those the
  same five the requisition table means?

### 4.2 Investigate modifiers (p. 93)

I have the table. To turn it into a picker I need to know how the groups combine:

- Are modifiers within a group **mutually exclusive** — one site freshness, one
  clue size, one tracking terrain — or may several apply at once?
- Can a hero be under a time-unit modifier **and** a site modifier **and** a clue
  modifier at once, so they sum?
- **"Hero has a related skill at rank 1–4 / 5–8 / 9–12"** — related to what, and
  who decides? Is there a list, or is it the Gamemaster's call?

### 4.3 Table D8, contacts and allegiances (p. 245)

- **What is the check rolled against** — a Personality skill, a flat feat check,
  or an organisation rating?
- **What does success get you, and what does failure cost?** Is there a lasting
  consequence, given one modifier is "hero has abused contact in past"?

---

## Part 5 — Still open from earlier, unchanged

**The career packages.** They still do not reconcile with their own printed costs:
under the best-fitting reading only 1 of 17 lands, and the misses run from −8 to
+15. Your round-2 worked example also priced pistol, security devices and
interrogate at **rank 1**, where the package list you sent had all three at **rank
2** — so the ranks are unreliable in a second, independent way.

The questions from that round still stand: what the printed cost counts, what a
bare skill name means, a re-read of Forensics Expert / Xenoengineer / Gadgeteer /
Soldier of Fortune (Mercenary), whether Occultist got the right package, whether
Soldier of Fortune is one career or two, and the three skills missing from my
catalogue — **Social Science** (with anthropology and history), **Street Smart—net
savvy**, and **Creativity—journalism**.

I have encoded none of them, and will not until this settles.
