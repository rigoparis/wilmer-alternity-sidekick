# Where the rules actually live

The books are in `manuals/` (gitignored — they are not redistributable, and they
are excluded from exports). They are **scans with no text layer**, so
`pdftotext` and `fitz.get_text()` both return nothing. Render the page and read
the image:

```python
import fitz
d = fitz.open('manuals/Alternity 01 Players Handbook.pdf')
d[229].get_pixmap(dpi=300).save('/tmp/p229.png')
```

150 dpi is legible for body text; 300–330 dpi with a column crop for tables.
`fitz`, `pypdf`, `pdfplumber`, `pdftotext` and `pdftoppm` are installed. numpy
is not; PIL is.

**In the Player's Handbook and in Beyond Science, the PDF page index equals the
printed page number.** No offset.

To find something without paging through: render every page at dpi=40 into a
labelled PIL contact sheet and read that one image. Table panels are visually
distinctive in both books.

## Player's Handbook — Table P1–P53 (index on p. 252)

| | Table | Page | Verified against the app |
|---|---|---|---|
| P2 | Resistance Modifiers | 32 | |
| P3 | Ability Score Limits | 33 | |
| P4 | Free Broad Skills for Heroes | 34 | |
| P5 | Hero Starting Skill Points | 34 | |
| P6 | Last Resort Points | 38 | |
| P7 | Actions Per Round | 38 | |
| P8 | Combat Movement Rates | 39 | |
| P9 | Strength & Damage | 40 | |
| P10 | Skills & Resistance Modifiers | 51 | **yes** — `resisted_by()` |
| P11 | Combat Movement Effects | 55 | |
| P12 | Encumbrance | 56 | |
| P13 | Overland Movement | 56 | |
| P14 | Throw Situation Modifiers | 57 | |
| P15 | Impact Damage | 58 | |
| P16 | Situation Die Modifiers | 62 | |
| P17 | Complex Skill Checks | 62 | |
| P18 | Base Situation Dice | 63 | |
| P19 | Skill List | 64–65 | |
| P20 | Accuracy by Range | 67 | |
| P21 | Heavy Weapons Range Modifiers | 67 | |
| P22 | Range Modifiers by Weapon Type | 73 | |
| P23 | Scratch-Built Explosives | 81 | |
| P24 | Knowledge Categories | 82 | |
| P25 | Encounter Skill Effects | 96 | |
| P26 | Perks | 103 | |
| P27 | Flaws | 107 | |
| P29 | Achievement Benefits | 127 | |
| P30 | Money on Hand | 129 | |
| P31 | Rich and Poor | 130 | |
| P32 | Progress Levels | 131 | |
| P33 | Personal Equipment | 135–136 | |
| P34 | Services | 148 | |
| P35 | Active Memory | 152 | |
| P36 | Computer Costs | 153 | |
| P37 | Computer Programs | 161 | |
| P38 | Melee Weapons | 172–173 | |
| P39 | Ranged Weapons | 176–177 | |
| P40 | Heavy Weapons | 182–183 | |
| P41 | Armor | 188 | |
| P42 | Vehicles | 194 | |
| P43 | Crash and Collision Damage | 201 | |
| P44 | Losing Control of a Vehicle | 201 | |
| P45 | Vehicle Scales | 204 | |
| P46 | Vehicle Scale Return Time | 204 | |
| P47 | Mutation Costs | 214 | |
| P48 | Mutant Origin | 214 | |
| P49 | Advantageous Mutations | 215 | |
| P50 | Mutation Drawbacks | 223 | |
| P51 | Related Abilities | 223 | |
| P52 | Psionic Skills | 229 | **yes** — all 33 rows |
| P53 | Cybernetic Gear | 240 | |

Other Player's Handbook pages already read:

- **p. 22** — fraal psionic energy: a talent or a Diplomat (Mindwalker) draws
  full Will where others draw one-half; a Mindwalker draws Will × 1.5.
- **p. 228** — the psionics chapter opening. The Talents sidebar (one broad
  skill, at most two specialties, one to rank 6 and the other to rank 3, +1 SP
  surcharge, pool = ceil(WIL ÷ 2)); the flat energy costs (specialty 1, broad 2,
  Critical Failure 3, and 2 points needed to attempt a broad at all); recovery
  (Will feat or Resolve–mental resolve after an hour: Critical Failure −1,
  Failure 0, Ordinary 1, Good 2, Amazing 3; eight hours restores everything with
  no check); "No psionic broad skill can be used untrained."
- **pp. 233, 235, 236** — psionic specialty descriptions. Sensitivity activates
  for 2 points, overriding the flat 1. Mind blast deals **stun** damage
  (d4+1s/d4+2s/d6+2s, rising at ranks 5 and 9), and armour does not protect.
- **pp. 246–248** — the compiled quick-reference tables.

## Beyond Science: A Guide to FX — 98 pages

| Table | Page | Verified |
|---|---|---|
| F1: FX Plans | 5 | |
| F3: Arcane Magic FX Skills | 14 | **yes** — prices and abilities |
| F4/F5 (FX cost / FX skills) | 27 | |
| F6: Faith FX Skills | 37 | **yes** — prices and abilities |
| F7: Super Power FX Skills | 57 | **yes** — prices and abilities |
| F8 (specialty skill blocks) | 95 | |

Chapters: 1 FX Rules (3–13), 2 Using FX in the Campaign (8–13), 3 Arcane Magic
(14–35), 4 Faith (36–56), 5 Super Power (57–69), 6 FX Creatures (70–90),
7 FX Devices (91–93), Appendix: Creating New FX Skills (94–96).

Each of F3, F6 and F7 prints every skill's price and, in parentheses, its
governing ability, and marks trained-only skills by ink colour: *"Skills that
cannot be used untrained are shown in color."*

**Do not try to read that colour programmatically.** Luminance separates
cleanly (white ≈ 205, colour ≈ 160) but mapping rows back to names slips on
wrapped entries, and a one-row slip silently encodes the wrong rule. Read the
individual skill description instead — a trained-only skill carries *"This skill
can't be used untrained."* on its own line under the cost line. Table P52 in the
Player's Handbook uses the same convention and is far cleaner to read.

## Still unread

The Gamemaster Guide (258 pages) entirely, including whatever defines the
optional rules this campaign uses. `Alternity Dataware.pdf` (98) and the Dark
Matter books (290 + a four-part split, plus a 100-page Arms & Equipment Guide),
which between them presumably hold the cybertech and equipment catalogs and the
Dark•Matter psionic and FX additions.
