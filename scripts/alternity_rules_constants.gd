class_name AlternityRulesConstants
extends RefCounted

const ABILITIES := ["STR", "DEX", "CON", "INT", "WIL", "PER"]
const MAX_SPECIALTY_RANK := 12

## Specialties may be bought up to rank 3 while the hero is being created.
## Source: Player's Handbook Table P28.
## Energy recovered per full, uninterrupted hour of rest, by the degree of the
## Resolve -- mental resolve check that ends it. The same table governs psionic
## and FX pools.
## Source: Player's Handbook Chapter 14 p. 202; Beyond Science: A Guide to FX p. 5.
const ENERGY_RECOVERY_PER_HOUR := {
	"failure": 0,
	"marginal": 0,
	"ordinary": 1,
	"good": 2,
	"amazing": 3,
}

## Resolve -- mental resolve. The check an hour of rest is settled with; a Will
## feat check may be rolled instead. Source: Player's Handbook p. 228.
const ENERGY_RECOVERY_SKILL_ID := 135

## Resolve -- physical resolve. The skill natural recovery of fatigue and wound
## damage is rolled against. Source: Gamemaster Guide p. 54.
const PHYSICAL_RESOLVE_SKILL_ID := 136

## What an FX talent begins with in Dark*Matter, and how far it can ever go.
##
## Flat, not derived: "All FX characters start with an FX energy pool of 5
## points... up to a maximum lifetime pool of 10 points." Elsewhere the starting
## pool is a number the player records and the ceiling is twice it, which lands
## on the same 5-and-10 only by coincidence -- so a Dark*Matter hero who recorded
## something else would otherwise be quietly playing a different game.
## Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.
const DARK_MATTER_FX_STARTING_POOL := 5

## What a point of FX energy pool costs a Dark*Matter hero.
##
## Ten, where the generic rules would charge a realistic campaign fifteen -- the
## setting prices its own. "This pool can be increased by spending achievement
## points, at a rate of 10 achievement points for 1 FX energy point."
## Source: Dark Matter Campaign Setting Part 2: Arcana p. 75.
const DARK_MATTER_FX_POOL_AP_COST := 10

## What a Dark*Matter talent may add to their psionic energy, and from when.
##
## "Only 1 additional point can be purchased at any given level, and a maximum of
## 3 additional points can be purchased over the hero's lifetime", beginning at
## 6th level. The book does not say whether an unspent level's allowance carries
## forward, so nothing here enforces the per-level half of it: that is the
## Gamemaster's call, and guessing would either block a legal purchase or wave
## through an illegal one with equal confidence.
## Source: Dark Matter Campaign Setting Part 1: Player Rules p. 59.
const DARK_MATTER_PEP_PURCHASE_MAX := 3
const DARK_MATTER_PEP_PURCHASE_MIN_LEVEL := 6

## How high a Dark*Matter FX talent may take their spells and miracles.
##
## "An FX talent can purchase any number of specialties, but their ranks are
## strictly capped at rank 6 in one specialty skill and rank 3 in all others."
## The shape is unlike the psionic caps above, which limit how many powers may be
## held; this limits only how far each may be taken.
## Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.
const DARK_MATTER_FX_TALENT_TOP_RANK := 6
const DARK_MATTER_FX_TALENT_OTHER_RANK := 3

## The perks that make somebody an FX talent in Dark*Matter.
##
## Ordinary Dark*Matter FX Talents enter through one of these perks. Adepts are
## independently selectable and use their profession rules instead.
## Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.
const DARK_MATTER_FX_PERKS := ["faith", "arcane_magic"]

## What a talent pays above the listed cost for an FX or psionic skill.
##
## Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.
const DARK_MATTER_TALENT_SURCHARGE := 1

## Requisition Subsystem (Arms & Equipment Guide p. 5)
## The check is rolled strictly against Administration-bureaucracy.
const REQUISITION_SKILL_ID := 120 # Administration-bureaucracy
const REQUISITION_AVAILABILITY_MODIFIERS := {
	"Any": 0,
	"Common": 0,
	"Controlled": 1,
	"Military": 2,
	"Restricted": 3,
}
const REQUISITION_URGENCY_MODIFIERS := {
	"emergency": 2,
	"short_notice": 1,
	"standard": 0,
	"advance": -1,
}
const REQUISITION_NECESSITY_MODIFIERS := {
	"essential": -2,
	"useful": 0,
	"luxury": 2,
}
const REQUISITION_OUTCOMES := {
	"amazing": "In stock locally; delivered within minutes.",
	"good": "Processed from local depot; delivered within d6 hours.",
	"ordinary": "Ordered from agency; delivered in time for assignment (requires 24h advance notice).",
	"failure": "Shipping delays occur; item fails to arrive in time. A new Administration-bureaucracy check is required to re-file.",
	"critical_failure": "Paperwork discrepancy catches up. Delayed d4 hours filling out correction forms with auditors; subject to GM reprimand or demotion.",
}

## Investigate Modifiers (Player's Handbook p. 93)
## Within each group, modifiers are mutually exclusive; across groups they are cumulative.
const INVESTIGATE_TIME_MODIFIERS := {
	"hasty": 2,
	"normal": 0,
	"careful": -2,
}
const INVESTIGATE_FRESHNESS_MODIFIERS := {
	"fresh": -1,
	"recent": 0,
	"days_old": 2,
	"old": 4,
}
const INVESTIGATE_CLUE_MODIFIERS := {
	"obvious": -2,
	"standard": 0,
	"small": 2,
	"concealed": 4,
}
const INVESTIGATE_SITE_MODIFIERS := {
	"undisturbed": 0,
	"disturbed": 2,
}

## Contacts & Allegiances (Table D8, Dark Matter p. 245 / GMG p. 104-105)
const CONTACT_RELATION_MODIFIERS := {
	"area_of_expertise": -1,
	"close_ally": -1,
	"casual": 0,
	"high_risk": 2,
	"extreme_danger": 4,
}
const CONTACT_OUTCOMES := {
	"amazing": "Immediate, enthusiastic help; provides requested resources, gear, or info plus additional assistance.",
	"good": "Reliable help delivered within reasonable time.",
	"ordinary": "Basic help delivered; bare minimum requirements met.",
	"failure": "Contact refuses or is unavailable / unable to assist.",
	"critical_failure": "Relationship damaged; contact becomes hostile, cuts ties, or launches internal inquiry.",
}


## What a psionic action costs, whatever power is used.
##
## The cost is flat and does not vary by discipline or specialty: a specialty
## check costs 1 point whether it succeeds or fails, leaning on the broad skill
## instead costs 2, and a Critical Failure costs 3. A hero must hold 2 points to
## attempt a broad skill at all. Source: Player's Handbook p. 228.
const PSIONIC_COST_SPECIALTY := 1
const PSIONIC_COST_BROAD := 2
const PSIONIC_COST_CRITICAL_FAILURE := 3

## Powers whose own description overrides the flat cost above.
## Source: Player's Handbook p. 233.
const PSIONIC_ACTIVATION_OVERRIDES := {
	90310: 2,   # Sensitivity: "Activating the skill requires the hero to use 2"
}

## An hour of rest that ends in a Critical Failure costs a point rather than
## returning one, and a hero with none to lose takes fatigue instead.
## Source: Player's Handbook p. 228.
const PSIONIC_REST_CRITICAL_FAILURE_LOSS := 1

## Eight unbroken hours without a psionic skill refill the pool outright, with
## no check at all. Source: Player's Handbook p. 228.
const PSIONIC_FULL_REST_HOURS := 8

## A talent holds one psionic broad skill and at most two specialties beneath
## it: one may reach rank 6, the other stops at rank 3.
## Source: Player's Handbook p. 228; p. 22 for the fraal case.
const PSIONIC_TALENT_MAX_BROADS := 1
const PSIONIC_TALENT_MAX_SPECIALTIES := 2
const PSIONIC_TALENT_RANK_CAPS := [6, 3]

const CREATION_SPECIALTY_RANK := 3
const ABILITY_NAMES := {
	"STR": "Strength",
	"DEX": "Dexterity",
	"CON": "Constitution",
	"INT": "Intelligence",
	"WIL": "Will",
	"PER": "Personality",
}

const AGE_CATEGORIES := [
	{"id": "young_adult", "name": "Young Adult", "summary": "Standard starting age. No ability modifiers."},
	{"id": "adolescent", "name": "Adolescent", "summary": "-1 STR, +1 DEX, -1 INT, -1 WIL."},
	{"id": "mature", "name": "Mature", "summary": "+1 INT, +1 PER."},
	{"id": "middle_aged", "name": "Middle-Aged", "summary": "-1 DEX, +1 INT, +1 WIL."},
	{"id": "old", "name": "Old", "summary": "-1 STR, -1 CON, -1 DEX, +1 WIL, +1 PER."},
	{"id": "ancient", "name": "Ancient", "summary": "-1 STR, -1 CON, -1 DEX."},
]

## Net ability adjustment for each age category, measured from young adult.
##
## Table G1 is an event list -- "when a hero reaches a new age category, adjust
## his ability scores as follows" -- so the rows accumulate as a hero ages
## rather than replacing one another. Stored here already summed, because the
## app picks a category rather than walking a lifetime.
##
## Treating the rows as exclusive was wrong twice over: it under-counted the
## physical decline, and it stripped an ancient hero of every mental gain earned
## through mature, middle age and old age, since the ancient row lists only
## physical penalties.
##
## Source: Gamemaster Guide ch. 2 p. 20, Table G1.
const AGE_MODIFIERS := {
	"young_adult": {},
	"adolescent": {"STR": -1, "DEX": 1, "INT": -1, "WIL": -1},
	"mature": {"INT": 1, "PER": 1},
	"middle_aged": {"DEX": -1, "INT": 2, "WIL": 1, "PER": 1},
	"old": {"STR": -1, "CON": -1, "DEX": -2, "INT": 2, "WIL": 2, "PER": 2},
	"ancient": {"STR": -2, "CON": -2, "DEX": -3, "INT": 2, "WIL": 2, "PER": 2},
}

## Table G1: Age Thresholds by Species and Progress Level (PL 0-3 through PL 9).
## Source: Gamemaster Guide p. 21.
## Format: [PL 0-3, PL 4, PL 5, PL 6, PL 7, PL 8, PL 9]
const AGE_THRESHOLDS_TABLE := {
	"human": {
		"adolescent": [12, 15, 17, 17, 17, 17, 17],
		"young_adult": [15, 21, 25, 35, 50, 72, 99],
		"mature": [28, 35, 40, 79, 122, 229, 549],
		"middle_aged": [41, 51, 62, 130, 172, 304, 849],
		"old": [50, 63, 85, 153, 201, 349, 999],
		"ancient_die": ["+2d12", "+2d12", "+2d12", "+3d12", "+4d12", "+6d12", "+10d12"],
	},
	"fraal": {
		"adolescent": [17, 22, 27, 27, 27, 27, 27],
		"young_adult": [32, 49, 61, 85, 113, 147, 169],
		"mature": [50, 77, 100, 136, 195, 259, 272],
		"middle_aged": [78, 118, 153, 205, 287, 362, 386],
		"old": [119, 176, 225, 287, 389, 489, 517],
		"ancient_die": ["+2d12", "+3d12", "+2d20", "+3d20", "+4d20", "+5d20", "+6d20"],
	},
	"mechalus": {
		"adolescent": [14, 17, 23, 23, 23, 23, 23],
		"young_adult": [23, 27, 41, 57, 72, 95, 121],
		"mature": [32, 47, 69, 95, 124, 159, 201],
		"middle_aged": [49, 69, 94, 134, 175, 223, 275],
		"old": [64, 89, 123, 178, 231, 296, 366],
		"ancient_die": ["+d8", "+d12", "+3d12", "+4d12", "+6d12", "+4d20", "+6d20"],
	},
	"sesheyan": {
		"adolescent": [13, 15, 18, 18, 18, 18, 18],
		"young_adult": [21, 25, 31, 37, 53, 75, 89],
		"mature": [33, 41, 48, 62, 94, 131, 163],
		"middle_aged": [49, 56, 69, 91, 131, 187, 221],
		"old": [64, 76, 91, 123, 173, 252, 302],
		"ancient_die": ["+2d6", "+2d6", "+2d12", "+3d12", "+4d12", "+5d12", "+6d12"],
	},
	"t_sa": {
		"adolescent": [7, 9, 12, 12, 12, 12, 12],
		"young_adult": [12, 15, 19, 24, 29, 39, 49],
		"mature": [18, 24, 31, 38, 46, 66, 81],
		"middle_aged": [25, 34, 41, 52, 64, 94, 111],
		"old": [33, 45, 54, 69, 81, 119, 141],
		"ancient_die": ["+d6", "+d6", "+d6", "+d8", "+2d8", "+2d12", "+4d12"],
	},
	"weren": {
		"adolescent": [10, 13, 15, 15, 15, 15, 15],
		"young_adult": [20, 25, 29, 37, 45, 55, 71],
		"mature": [35, 40, 47, 64, 76, 83, 112],
		"middle_aged": [51, 65, 73, 94, 115, 121, 167],
		"old": [71, 88, 98, 119, 151, 167, 219],
		"ancient_die": ["+d8", "+d8", "+d12", "+2d12", "+3d12", "+4d12", "+6d12"],
	},
}

## Table G2: Random Ability Rolls by Profession. Source: Gamemaster Guide p. 21.
const RANDOM_ABILITY_ROLLS_BY_PROFESSION := {
	"combat_spec": {"STR": "10+d4", "DEX": "8+d4",  "CON": "8+d6", "INT": "4+d8",  "WIL": "6+d6", "PER": "4+d8"},
	"diplomat":    {"STR": "4+d8",  "DEX": "4+d8",  "CON": "4+d8", "INT": "8+d6",  "WIL": "8+d6", "PER": "10+d4"},
	"free_agent":  {"STR": "6+d6",  "DEX": "10+d4", "CON": "6+d6", "INT": "8+d6",  "WIL": "6+d6", "PER": "6+d6"},
	"tech_op":     {"STR": "4+d6",  "DEX": "8+d6",  "CON": "4+d6", "INT": "10+d4", "WIL": "8+d6", "PER": "6+d6"},
	"mindwalker":  {"STR": "4+d6",  "DEX": "4+d8",  "CON": "8+d6", "INT": "8+d6",  "WIL": "10+d4", "PER": "6+d6"},
}

## Table G3: Random Ability Rolls by Species. Source: Gamemaster Guide p. 21.
const RANDOM_ABILITY_ROLLS_BY_SPECIES := {
	"human":    {"STR": "4+d10", "DEX": "4+d10", "CON": "4+d10", "INT": "4+d10", "WIL": "4+d10", "PER": "4+d10"},
	"fraal":    {"STR": "3+d6",  "DEX": "5+d6",  "CON": "3+d6",  "INT": "11+d4", "WIL": "8+d8",  "PER": "9+d6"},
	"mechalus": {"STR": "8+d6",  "DEX": "8+d6",  "CON": "4+d8",  "INT": "11+d4", "WIL": "5+d6",  "PER": "3+d8"},
	"weren":    {"STR": "10+d6", "DEX": "4+d6",  "CON": "9+d6",  "INT": "4+d8",  "WIL": "4+d6",  "PER": "5+d6"},
	"sesheyan": {"STR": "6+d6",  "DEX": "11+d4", "CON": "4+d6",  "INT": "4+d8",  "WIL": "7+d8",  "PER": "6+d6"},
	"t_sa":     {"STR": "3+d6",  "DEX": "10+d6", "CON": "4+d6",  "INT": "10+d4", "WIL": "4+d8",  "PER": "7+d6"},
}

## Table P30: Starting Funds by Profession. Source: Player's Handbook p. 132.
const STARTING_FUNDS_BY_PROFESSION := {
	0: "5d6",   # Combat Spec
	1: "5d12",  # Diplomat (Combat Spec)
	2: "5d12",  # Diplomat (Free Agent)
	3: "5d12",  # Diplomat (Tech Op)
	4: "5d8",   # Free Agent
	5: "5d8",   # Tech Op
	6: "5d4",   # Mindwalker
	7: "5d12",  # Diplomat (Mindwalker)
	8: "5d12",  # Diplomat (Adept)
	9: "5d6",   # Adept (Combat Spec)
	10: "5d12", # Adept (Diplomat)
	11: "5d8",  # Adept (Free Agent)
	12: "5d8",  # Adept (Tech Op)
	13: "5d4",  # Adept (Mindwalker)
	14: "5d6",  # Non-Professional (supporting character default)
}

## Passive Resistance Abilities (Table P2): STR, DEX, INT, WIL. CON and PER have no passive RM.
const PASSIVE_RESISTANCE_ABILITIES := ["STR", "DEX", "INT", "WIL"]

## Table G21: Breaking Objects via Strength Feats. Source: Gamemaster Guide p. 21.
const BREAKING_OBJECTS_TABLE := {
	"ordinary": {"toughness": "Ordinary", "durability": "Fragile", "step_modifier": 0, "situation_die": "+d4", "examples": "Standard doors, furniture, glass"},
	"good":     {"toughness": "Good",     "durability": "Average", "step_modifier": 1, "situation_die": "+d6", "examples": "Reinforced doors, light metal bulkheads"},
	"amazing":  {"toughness": "Amazing",  "durability": "High",    "step_modifier": 3, "situation_die": "+d12", "examples": "Armored airlocks, reinforced steel"},
}

const ENCUMBRANCE_TIERS := [
	{"name": "Normal", "limit_multiplier": 2.0, "movement_multiplier": 1.0, "penalty": 0},
	{"name": "Heavy", "limit_multiplier": 4.0, "movement_multiplier": 0.75, "penalty": 1},
	{"name": "Severe", "limit_multiplier": 5.0, "movement_multiplier": 0.50, "penalty": 2},
	{"name": "Extreme", "limit_multiplier": 6.0, "movement_multiplier": 0.25, "penalty": 3},
	{"name": "Immobile", "limit_multiplier": INF, "movement_multiplier": 0.0, "penalty": 3},
]

## FX campaign scale: what an extra point of FX energy pool costs in
## achievement points. Source: Beyond Science: A Guide to FX ch. 1 p. 8.
##
## Ordered cheapest-last so the list reads from grittiest to most powerful.
const FX_CAMPAIGN_SCALES := [
	{"id": "realistic", "name": "Realistic", "ap_per_point": 15},
	{"id": "heroic", "name": "Heroic", "ap_per_point": 10},
	{"id": "superheroic", "name": "Superheroic", "ap_per_point": 5},
]

## Used when a character has no scale recorded.
const FX_CAMPAIGN_SCALE_DEFAULT := "heroic"


const OPTIONAL_RULES := [
	{
		"id": "2a",
		"name": "Optional Rule 2A",
		"summary": "Alternate starting skill points",
		"description": "House rule originating from the legacy Alternity character manager / magazine patch. New characters have a number of skill points equal to 30 plus 3 times their INT score available to purchase skills during character creation. Human heroes receive a special bonus of 5 additional skill points (35 + 3 * INT). Not from the core rulebooks, which use Table P5 (INT * 5 - 5 for aliens, INT * 5 for humans).",
	},
	{
		"id": "2b",
		"name": "Optional Rule 2B",
		"summary": "Alternate broad skill limit",
		"description": "House rule originating from the legacy Alternity character manager / magazine patch. During initial skill purchase, a character may not learn more than six additional broad skills, not counting racial broad skills. Modified by the hero's INT resistance modifier (6 + INT RM, plus 1 for Humans). Not from the core rulebooks, which use Table P5 (floor(INT / 2) + 1 for Humans).",
	},
	{
		"id": "2c",
		"name": "Optional Rule 2C",
		"summary": "Flat specialty advancement cost",
		"description": "House rule originating from the legacy Alternity character manager / magazine patch. The cost to purchase rank 2 or higher in a specialty skill is either the list price or list price -1 (if matching profession). Current ranks do not increase the cost of advancing that skill. Not from the core rulebooks, where specialty rank advancement scales with current rank (Table G5 in the Gamemaster Guide p. 31 was a cumulative reference table for creating advanced characters, not flat progression).",
	},
	{
		"id": "dazed",
		"name": "Optional Rule: Dazed",
		"summary": "Step penalty for heavy Stun or Wound damage",
		"description": "If your hero suffers enough Stun or Wound damage to use up more than half of those points (> 50%), he is dazed (+1 step penalty each). Mortal and Fatigue damage always add +1 step penalty per point. Source: Player's Handbook Chapter 3 p. 51; Gamemaster Guide Chapter 3 p. 54.",
	},
	{
		"id": "psionic_talents",
		"name": "Optional Rule: Psionic Talents",
		"summary": "Allow non-Mindwalker heroes to purchase Psionics",
		"description": "Permits characters of any profession to learn Psionic broad and specialty skills with a +1 SP cost surcharge above the listed price. Psionic energy pool is ceil(WIL * 0.5) (or full WIL for Fraal). Source: Player's Handbook Chapter 14 p. 226, 228; Gamemaster Guide Chapter 16 p. 220-221.",
	},
	{
		"id": "monetary_awards_uncapped",
		"name": "Optional Rule: Uncapped Monetary Awards",
		"summary": "Monetary awards continue past 24th level",
		"description": "Table P29 lists the Monetary Award as available at 3rd, 6th, 9th, 12th, 15th, 18th, 21st and 24th level, and unlike the achievement track it prints no \"etc.\" -- so by the text eight purchases is the maximum. The designers stopped there because campaigns were not expected to run that long; the underlying pattern is simply every third level, with the payout doubling each time. Enable this for an epic campaign to keep the benefit available at every multiple of three beyond 24th. Source: Player's Handbook p. 126-128; Gamemaster Guide p. 113.",
	},
	{
		"id": "age_effects",
		"name": "Optional Rule: Age Categories",
		"summary": "Apply age category ability modifiers",
		"description": "A hero's age category adjusts their ability scores: an adolescent takes -1 STR, -1 INT and -1 WIL but gains +1 DEX, while an old hero loses STR, CON and DEX and gains WIL and PER. With this rule off, every hero in the campaign is treated as a Young Adult for all rules purposes and no age modifier applies -- players may still record an age for their character, it simply does not change their scores. Source: Gamemaster Guide Chapter 2 p. 20 and Table G1 p. 21.",
	},
	{
		"id": "damage_upgrading",
		"name": "Optional Rule: Upgrading Damage",
		"summary": "A weapon that outclasses its target hits harder",
		"description": "When a weapon's firepower exceeds the target's toughness, the quality of a hit is promoted -- one grade above and an Ordinary hit becomes Good and a Good hit becomes Amazing; two or more grades above and any hit is Amazing. The Gamemaster Guide is explicit that no standard rule exists for this and offers it as a guideline, which is why it is a toggle. Its counterpart, damage degradation when a weapon is too weak for its target, is core and always applies. Source: Gamemaster Guide Chapter 3 p. 52, sidebar \"Upgrading Damage?\".",
	},
	{
		"id": "dm_adept_unrestricted_ranks",
		"name": "Optional Rule: Full Adept Ranks in Dark*Matter",
		"summary": "Let Dark*Matter Adepts use the normal Rank 12 Adept ceiling",
		"description": "When off, Dark*Matter's weak-FX baseline limits an Adept to Rank 6 in any number of specialties from the chosen school and Rank 3 in other schools. When on, an Adept uses the normal Beyond Science ceiling, subject to the hero's level and the system maximum of Rank 12. This is a Gamemaster ruling for combining two rulesets; neither book defines the crossover. Sources: Beyond Science: A Guide to FX p. 6; Dark Matter Campaign Setting Part 2 p. 75.",
		"requires_setting": "Dark*Matter",
	},
	{
		"id": "weapon_accuracy",
		"name": "Optional Rule: Weapon Accuracy",
		"summary": "Weapon accuracy modifiers adjust attack situation die",
		"description": "Applies the weapon's inherent accuracy rating as a step bonus or penalty to the attack check (e.g. laser rifle provides a -1 bonus, flintlock pistol carries a +2 penalty). When disabled, listed weapon accuracy is ignored. Source: Player's Handbook Chapter 11 p. 174.",
	},
]


## The supplement books a campaign has in play, beyond the core two.
##
## Distinct from the campaign setting, and the distinction is load-bearing. A
## setting is one-of -- a hero plays in Core, or Star*Drive, or Dark*Matter -- and
## it says what world they are in. A supplement is a book the table happens to
## own, any number of them, in any setting: Beyond Science is the FX rules, and
## Dataware is the robot rules, and either can sit on the table of a Core game or
## a Dark*Matter one.
##
## They were originally tagged in the same "setting" field as the settings
## themselves, which made them permanently unreachable: nothing can select
## "Dataware" as its setting, so the twenty robot perks in that book had never
## been visible to anybody. Nothing errored -- the catalog simply never offered
## them.
##
## `default` is what a character that has never heard of the field gets, and the
## two defaults are chosen so that turning this on changes nothing anybody could
## see. Beyond Science is on because its FX catalog -- nineteen of the app's
## twenty-one schools and faiths -- has always been offered ungated, and defaulting
## it off would take every hero's powers away. Dataware is off because none of its
## content has ever appeared, so leaving it off is the state everyone is already in.
const SUPPLEMENTS := [
	{
		"id": "beyond_science",
		"name": "Beyond Science: A Guide to FX",
		"summary": "The FX rules: arcane schools, faiths, and the perks and flaws that go with them",
		"default": true,
		"description": "The full FX framework -- nineteen broad schools and faiths from Alienism to Voodoo, their spells and miracles, and eight FX perks and five FX flaws. Without it a hero has no FX at all beyond what their setting supplies directly. Dark*Matter replaces this framework with its own, so a Dark*Matter hero uses the Dark*Matter rules whether or not this is on. Source: Beyond Science: A Guide to FX.",
	},
	{
		"id": "dataware",
		"name": "Dataware",
		"summary": "Robot and artificial-intelligence heroes",
		"default": false,
		"description": "Perks and flaws for playing a robot or an artificial intelligence -- adaptive programming, composite structure, Asimov circuits, incomplete coding. Only useful at a table where somebody is playing a machine. Source: Dataware Chapter 6; Tables D21 and D22.",
	},
]

const FIREPOWER_GRADES := ["O", "G", "A"] # Ordinary, Good, Amazing

## Stamina - Endurance, the check an Amazing hit forces to stay conscious.
##
## Named rather than written as a bare 53 at the call site: a skill id in the
## middle of a combat function is unreadable and unsearchable.
const SKILL_ENDURANCE := 53

## How a judged situation becomes a step modifier.
##
## Table: Situation Die Modifiers, Player's Handbook p. 246, which is the
## compiled form of the categories described under "Types of Situations" on
## p. 59 -- circumstances are Slight, Moderate or Extreme; light and sound are
## Ordinary, Good or Amazing.
##
## This is the whole of "eyeballing it" as the book defines it: the GM decides
## which category the situation falls into, and the step follows. The worked
## examples people quote are instances of it rather than a separate table --
## light cover and moonlight are Slight (+1), heavy cover and total darkness are
## Extreme (+3).
const SITUATION_MODIFIERS := [
	{"id": "extreme", "name": "Extreme", "step": 3},
	{"id": "moderate", "name": "Moderate", "step": 2},
	{"id": "slight", "name": "Slight", "step": 1},
	{"id": "marginal", "name": "Marginal", "step": 0},
	{"id": "ordinary", "name": "Ordinary", "step": -1},
	{"id": "good", "name": "Good", "step": -2},
	{"id": "amazing", "name": "Amazing", "step": -3},
]

## Range modifiers, which depend on what kind of weapon is firing.
##
## Table P22: Range Modifiers by Weapon Type, Player's Handbook p. 73.
##
## A first version of this applied one scale to every weapon -- short -1, medium
## 0, long +1 -- which is right for a rifle and wrong for everything else. A
## pistol at long range is +3, not +1.
##
## The bands themselves come off the weapon's own stat line, which is written
## short/medium/long in metres. There is no band past long: a shot beyond a
## weapon's long range cannot be fired at all.
const RANGE_MODIFIERS_BY_WEAPON := {
	# Bow, crossbow, sling; also thrown weapons.
	"primitive": {"short": -1, "medium": 1, "long": 2},
	"pistol": {"short": -1, "medium": 1, "long": 3},
	"smg": {"short": -1, "medium": 1, "long": 3},
	"rifle": {"short": -1, "medium": 0, "long": 1},
	# Heavy weapons fired directly behave as rifles; indirect fire inverts,
	# being hopeless up close and designed for distance.
	"heavy_direct": {"short": -1, "medium": 0, "long": 1},
	"heavy_indirect": {"short": 2, "medium": -2, "long": 0},
}

## What a heavy weapon firing indirectly suffers inside melee range, and what a
## rifle or direct-fire heavy weapon suffers there. Both from the same table.
const RANGE_MODIFIER_MELEE_RANGE := {
	"rifle": 1,
	"heavy_direct": 1,
	"heavy_indirect": 4,
}

## Everything else that moves an attack up or down the step scale.
##
## Modifiers for Ranged Weapons, Gamemaster Guide p. 46, and Modifiers to Unarmed
## and Melee Attacks, Gamemaster Guide p. 44. A negative step is a bonus.
##
## `scope` says which table a row belongs to, because two of them genuinely
## disagree: a prone target is harder to shoot (+2) and easier to hit with a club
## (-2). Reading one table for both would make lying down a universal defence.
const ATTACK_MODIFIERS := [
	# --- The attacker's own situation, identical in both tables ---
	{"id": "attacker_rear", "group": "Attacker", "name": "Attacking from the rear", "step": -2, "scope": "both"},
	{"id": "attacker_flank", "group": "Attacker", "name": "Attacking from the flank", "step": -1, "scope": "both"},
	{"id": "attacker_high_ground", "group": "Attacker", "name": "Higher ground", "step": -1, "scope": "both"},
	{"id": "attacker_off_balance", "group": "Attacker", "name": "Off balance", "step": 2, "scope": "both"},
	{"id": "attacker_prone", "group": "Attacker", "name": "Attacker is prone", "step": 2, "scope": "both"},
	{"id": "attacker_running", "group": "Attacker", "name": "Attacker is running", "step": 2, "scope": "both"},
	{"id": "attacker_sprinting", "group": "Attacker", "name": "Attacker is sprinting", "step": 3, "scope": "both"},

	# --- The target, where the two tables part company ---
	{"id": "target_prone_ranged", "group": "Target", "name": "Target is prone", "step": 2, "scope": "ranged"},
	{"id": "target_kneeling_ranged", "group": "Target", "name": "Target is sitting or kneeling", "step": 1, "scope": "ranged"},
	{"id": "target_prone_melee", "group": "Target", "name": "Target is prone", "step": -2, "scope": "melee"},
	{"id": "target_kneeling_melee", "group": "Target", "name": "Target is sitting or kneeling", "step": -1, "scope": "melee"},

	# --- Cover. Ranged only; a club does not care about a low wall the way a
	# --- bullet does, and the melee table does not list it.
	{"id": "cover_light", "group": "Cover", "name": "Light cover", "step": 1, "scope": "ranged"},
	{"id": "cover_medium", "group": "Cover", "name": "Medium cover", "step": 2, "scope": "ranged"},
	{"id": "cover_heavy", "group": "Cover", "name": "Heavy cover", "step": 3, "scope": "ranged"},

	# --- Illumination, identical in both tables ---
	{"id": "light_twilight", "group": "Illumination", "name": "Twilight or poor visibility", "step": 1, "scope": "both"},
	{"id": "light_moonlight", "group": "Illumination", "name": "Moonlight", "step": 2, "scope": "both"},
	{"id": "light_none", "group": "Illumination", "name": "Total darkness", "step": 3, "scope": "both"},

	# --- Firing mode. Burst is steadier than a single shot; autofire spreads
	# --- across targets and is handled per target, not as one flat row.
	{"id": "mode_single", "group": "Firing mode", "name": "Single shot", "step": 0, "scope": "ranged"},
	{"id": "mode_burst", "group": "Firing mode", "name": "Burst", "step": -1, "scope": "ranged"},

	# --- Declared manoeuvres ---
	{"id": "called_shot", "group": "Manoeuvre", "name": "Called shot", "step": 4, "scope": "both"},
	{"id": "aimed", "group": "Manoeuvre", "name": "Aimed last phase", "step": -1, "scope": "both"},
	{"id": "charging", "group": "Manoeuvre", "name": "Charging", "step": -2, "scope": "melee"},
]

## The step penalty each target of an autofire sweep takes, in order.
##
## Gamemaster Guide p. 46. Autofire is walked across up to three targets within
## six metres of each other, and one control die is rolled against three
## situation dice at once -- so this is three separate results, not one attack.
const AUTOFIRE_TARGET_STEPS := [1, 2, 3]

## A called shot that lands is promoted one degree, the same promotion the
## firepower rule gives. Gamemaster Guide p. 50.
const CALLED_SHOT_PROMOTES := true
const COMPLEX_CHECK_RULES := {
	"summary": "Complex skill checks are used for tasks that take more than one roll or where the GM wants tension over time.",
	"successes": "Ordinary success counts as 1 success, Good as 2, and Amazing as 3.",
	"failures": "A Failure adds no progress. Three Failures ruin the attempt until conditions change; one Critical Failure can ruin it immediately.",
	"complexity": "Typical complexity: Marginal 2 successes, Ordinary 3-4, Good 5-7, Amazing 8-10. The GM chooses the exact target.",
}
const MUTATION_ADVANTAGE_TIERS := ["Ordinary", "Good", "Amazing"]
const MUTATION_DRAWBACK_TIERS := ["Slight", "Moderate", "Extreme"]
const MUTATION_ADVANTAGE_LABEL_ORDER := ["Amazing", "Good", "Ordinary"]
const MUTATION_DRAWBACK_LABEL_ORDER := ["Extreme", "Moderate", "Slight"]

## Table P51: Related Abilities. Source: Player's Handbook p. 223-224; Table P51.
const MUTATION_RELATED_ABILITIES_TABLE_P51 := {
	"STR": "INT",
	"DEX": "STR",
	"CON": "DEX",
	"INT": "PER",
	"WIL": "CON",
	"PER": "WIL"
}

## Advantageous mutations compatible with the Wild Mutation extreme drawback.
## Source: Player's Handbook p. 225.
const WILD_MUTATION_COMPATIBLE_MUTATIONS := [
	"adrenal_control",
	"acid_touch",
	"electric_aura",
	"increased_metabolism",
	"natural_attack",
	"chameleon_flesh",
	"hyper_metabolism",
	"improved_natural_attack"
]

const CORE_SKILL_ROLL_SOURCE := "Source: Player's Handbook p. 61-63."

## Table P10: which ability a target resists with, by the skill being used
## against them. Broad skill name -> resisting ability, or two of them where the
## Gamemaster picks whichever fits the attempt.
##
## Nothing else in the game opposes a skill check, so a skill absent from this
## table has no opposed roll at all.
## Source: Player's Handbook p. 51; Table P10.
const RESISTED_BY := {
	"Deception": ["INT"],
	"Entertainment": ["INT", "WIL"],
	"Heavy Weapons": ["DEX"],
	"Interaction": ["WIL"],
	"Leadership": ["WIL"],
	"Melee Weapons": ["STR"],
	"Modern Ranged Weapons": ["DEX"],
	"Primitive Ranged Weapons": ["DEX"],
	"Stealth": ["WIL"],
	"Street Smart": ["INT", "WIL"],
	"Unarmed Attack": ["STR"],
}

## Every psionic skill is resisted the same way, whichever discipline it belongs
## to: the table lists "Psionic Skills" as a single row.
## Source: Player's Handbook p. 51; Table P10.
const PSIONIC_RESISTED_BY := ["WIL"]
const COMPLEX_CHECK_SOURCE := "Source: Player's Handbook p. 62."

const SPECIES_FREE_SPECIALTY_IDS := {
	3: [24],
}

const MISSING_SKILL_LABELS := {
	525: "Telepathy",
}

const SPECIES_RULE_NOTES := {
	0: [
		"Skill Bonus: Humans begin with 5 more skill points than other species and may start with one more broad skill. Applied to skill budget and broad-skill limit. Source: Player's Handbook p. 30; Table P5 p. 34.",
	],
	1: [
		"Psionic Powers: Fraal use the optional psionics rules when fraal are present in a campaign. Source: Player's Handbook p. 21-22.",
		"Psionic Energy: Fraal talents or Diplomats with Mindwalker as secondary profession use WIL for psionic energy points instead of one-half WIL. Source: Player's Handbook p. 22.",
		"Mindwalkers: Fraal Mindwalkers use WIL x 1.5 for psionic energy points instead of WIL x 1. Source: Player's Handbook p. 22.",
		"Telepathy: Telepathy is one of every fraal hero's free broad skills. Source: Player's Handbook p. 22; Table P4 p. 34.",
	],
	2: [
		"Computer Operation Skill Bonus: Mechalus receive a -1 step bonus when using Knowledge-computer operation or Computer Science-hacking while merged with a computer; merging or disengaging takes one round. Applied to those skill dice. Source: Player's Handbook p. 24.",
		"Cybernetic Enhancements: Mechalus begin with two neural data slots, an internal processor equivalent to a Good nanocomputer, and bio-organic circuitry similar to a reflex device. Source: Player's Handbook p. 24.",
		"Cybergear Tolerance: Mechalus are not subject to cybernetic rejection, and their cybergear limit is CON +4 instead of CON. Source: Player's Handbook p. 24.",
	],
	3: [
		"Flight: Sesheyans can fly in atmospheres at least half Earth pressure and gravity no higher than Earth-normal. Applied to glide and fly movement rates. Source: Player's Handbook p. 26.",
		"Flight Checks: Sesheyans use the Acrobatics broad skill for flying checks and may buy the flight specialty. Source: Player's Handbook p. 26.",
		"Zero-G Training: Sesheyans function as if they have Acrobatics-zero-g training rank 1. Applied as a free specialty rank. Source: Player's Handbook p. 26.",
		"Falling: A conscious sesheyan able to use wings suffers no impact damage from a fall and glides safely; otherwise normal impact damage applies. Source: Player's Handbook p. 26; impact damage p. 58.",
		"Night Vision: Sesheyans ignore low-illumination penalties except in total darkness, unless wearing protective goggles against light sensitivity. Source: Player's Handbook p. 26.",
		"Light Sensitivity: Ordinary, Good, and Amazing illumination impose +1, +2, and +3 step penalties; protective goggles negate this. Source: Player's Handbook p. 26.",
	],
	4: [
		"Action Check Bonus: T'sa receive a -1 step situation die bonus to action checks. Applied to action check die. Source: Player's Handbook p. 27.",
		"Juryrig Bonus: T'sa receive a -1 step situation die bonus on Technical Science-juryrig checks. Applied to the juryrig skill die. Source: Player's Handbook p. 27.",
		"Body Armor: T'sa natural armor is d4+1 low impact, d4 high impact, and d4-1 energy. Source: Player's Handbook p. 27.",
	],
	5: [
		"Superior Durability: Weren durability scores use CON x 1.5, rounded down. Applied to durability. Source: Player's Handbook p. 28.",
		"Natural Weapon: On a successful Unarmed Attack-brawl or power martial arts check, weren claws deal d4w/d4+2w/d4m low-impact damage plus Strength bonuses. Source: Player's Handbook p. 28.",
		"Camouflage: In natural terrain, ranged weapon attacks aimed at a weren suffer a +1 step penalty. Source: Player's Handbook p. 28.",
		"Primitive Culture: Weren suffer a +2 step penalty when using PL4 or higher items; this can be reduced by paying 4 skill points, then removed at 6th level or higher by paying 4 more. Source: Player's Handbook p. 28-29.",
	],
	6: [
		"Mutants use the Chapter 13 mutation rules. Mutant heroes are derived from human stock, have the human free broad skills, do not receive the human skill point or broad skill bonus, and must have at least one advantageous mutation and one drawback. Source: Player's Handbook p. 213-214.",
	],
}

const SPECIES_ROLL_NOTES := {
	2: [
		"Mechalus: Knowledge-computer operation and Computer Science-hacking receive a -1 step bonus while merged with a computer. Source: Player's Handbook p. 24.",
	],
	3: [
		"Sesheyan: Acrobatics-zero-g training is treated as rank 1 before purchased ranks. Source: Player's Handbook p. 26.",
		"Sesheyan: Light sensitivity imposes +1/+2/+3 step penalties in Ordinary/Good/Amazing illumination unless protective goggles are worn. Source: Player's Handbook p. 26.",
	],
	4: [
		"T'sa: Action checks use a -d4 base situation die from the racial action check bonus. Source: Player's Handbook p. 27.",
		"T'sa: Technical Science-juryrig receives a -1 step situation die bonus. Source: Player's Handbook p. 27.",
	],
	5: [
		"Weren: Ranged weapon attacks against a weren in natural terrain suffer a +1 step penalty. Source: Player's Handbook p. 28.",
		"Weren: PL4 or higher item use suffers a +2 step penalty until the primitive culture penalty is bought down. Source: Player's Handbook p. 28-29.",
		"Weren: Claw attacks after successful Unarmed Attack-brawl or power martial arts checks deal d4w/d4+2w/d4m low-impact damage plus Strength bonuses. Source: Player's Handbook p. 28.",
	],
}

const MOVEMENT_EFFECTS := [
	{"mode": "Walk", "effect": "No penalty when moving and acting in the same phase."},
	{"mode": "Run", "effect": "+2 step penalty to another action in the same phase."},
	{"mode": "Sprint", "effect": "+3 step penalty to another action in the same phase."},
	{"mode": "Easy Swim", "effect": "+2 step penalty to another action in the same phase."},
	{"mode": "Swim", "effect": "No other actions in the same phase."},
	{"mode": "Glide", "effect": "+1 step penalty to another action in the same phase."},
	{"mode": "Fly", "effect": "+2 step penalty to another action in the same phase."},
	{"mode": "All-out", "effect": "Movement only; after stopping, no other action for the rest of the round."},
]

const MOVEMENT_RUN_BY_TOTAL := {
	6: 4,
	8: 6,
	10: 6,
	12: 8,
	14: 10,
	16: 10,
	18: 12,
	20: 12,
	22: 14,
	24: 16,
	26: 16,
	28: 18,
	30: 20,
	32: 22,
}

## Table P8: Combat Movement Rates (Meters per Phase). Source: Player's Handbook p. 33.
const MOVEMENT_RATES_TABLE := {
	6:  {"sprint": 6,  "run": 4,  "walk": 2, "easy_swim": 1, "swim": 2, "glide": 6,  "fly": 12},
	8:  {"sprint": 8,  "run": 6,  "walk": 2, "easy_swim": 1, "swim": 2, "glide": 8,  "fly": 16},
	10: {"sprint": 10, "run": 6,  "walk": 2, "easy_swim": 1, "swim": 2, "glide": 10, "fly": 20},
	12: {"sprint": 12, "run": 8,  "walk": 2, "easy_swim": 1, "swim": 2, "glide": 12, "fly": 24},
	14: {"sprint": 14, "run": 10, "walk": 4, "easy_swim": 2, "swim": 4, "glide": 14, "fly": 28},
	16: {"sprint": 16, "run": 10, "walk": 4, "easy_swim": 2, "swim": 4, "glide": 16, "fly": 32},
	18: {"sprint": 18, "run": 12, "walk": 4, "easy_swim": 2, "swim": 4, "glide": 18, "fly": 36},
	20: {"sprint": 20, "run": 12, "walk": 4, "easy_swim": 2, "swim": 4, "glide": 20, "fly": 40},
	22: {"sprint": 22, "run": 14, "walk": 4, "easy_swim": 2, "swim": 4, "glide": 22, "fly": 44},
	24: {"sprint": 24, "run": 16, "walk": 6, "easy_swim": 3, "swim": 6, "glide": 24, "fly": 48},
	26: {"sprint": 26, "run": 16, "walk": 6, "easy_swim": 3, "swim": 6, "glide": 26, "fly": 52},
	28: {"sprint": 28, "run": 18, "walk": 6, "easy_swim": 3, "swim": 6, "glide": 28, "fly": 56},
	30: {"sprint": 30, "run": 20, "walk": 8, "easy_swim": 4, "swim": 8, "glide": 30, "fly": 60},
	32: {"sprint": 32, "run": 22, "walk": 8, "easy_swim": 4, "swim": 8, "glide": 32, "fly": 64},
}


const BROAD_SKILL_SUMMARIES := {
	# Dark*Matter. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of
	# Dark Matter.
	165: "Collect the academic, conspiratorial and supernatural knowledge a Dark*Matter hero needs -- what is known, what is rumoured, and who says otherwise.",
	0: "Armor that is bulky, heavy, and cumulative hinders the character using it. This is reflected as a step penalty to their Action Check Score and a lessening or complete negation of their Dexterity resistance modifier. The Armor Operation broad skill and its specialties help to alleviate these heavy combat penalties.",
	3: "This broad skill represents physical conditioning, running speed, muscular coordination, and general athletic prowess. It resolves all physical feats of climbing, leaping, and throwing objects.",
	8: "Use heavy personal and crew-served weapons, including direct-fire and indirect-fire weapons.",
	11: "Measures proficiency with close-combat weaponry, from basic wooden clubs to advanced monomolecular-edged swords and energy blades.",
	15: "Hand-to-hand combat without weapons. Base damage for an untrained unarmed strike is d4s / d4+1s / d4+2s (LI/O) plus the character's Strength damage adjustment.",
	18: "Measures agility, balance, gymnastics, and the ability to maneuver dynamically or dodge incoming projectiles.",
	26: "Perform fine manual actions such as opening locks, picking pockets, and sleight of hand.",
	30: "Proficiency with modern personal firearms using chemical, magnetic, or rocket propulsion.",
	34: "Use older ranged weapons such as bows, crossbows, flintlocks, and slings.",
	39: "Avoid notice through hiding, shadowing, and silent movement.",
	43: "Operate common vehicles and specialized vehicle classes.",
	48: "Handle long-distance or demanding movement such as racing, swimming, and trailblazing.",
	52: "Physical fortitude, pain tolerance, and biological endurance against fatigue, poisons, and environmental hazards.",
	55: "Survive hostile environments by finding necessities and avoiding environmental danger.",
	57: "Understand commercial organizations, trade, and legal or illegal business practices.",
	61: "Operating, designing, attacking, and securing computational networks, mainframes, and Grid architectures.",
	65: "Handling, fabricating, placing, and safely neutralizing chemical and energetic explosives.",
	69: "Apply general education, languages, deduction, basic computer operation, and first aid.",
	75: "Understand law, court procedure, law enforcement practice, and legal specialties.",
	79: "Apply biological sciences such as biology, botany, genetics, xenology, and zoology.",
	85: "Diagnosis, physiology, wound treatment, pathology, surgical intervention, and pharmacology.",
	92: "Navigate by surface, system, or drivespace methods.",
	96: "Apply astronomy, chemistry, physics, and planetology.",
	101: "Understand security procedures, devices, and protection protocols.",
	104: "Operate ship, station, or installation systems such as sensors, defenses, engines, and weapons.",
	110: "Apply battlefield and operational planning for infantry, vehicle, and space combat.",
	114: "Applied physical engineering, electronics, mechanics, robotics, and structural maintenance.",
	119: "Navigate organizations through bureaucracy and management.",
	122: "Ride, train, and work with animals.",
	125: "Notice danger, read intuition, and perceive hidden details.",
	128: "Produce creative work in a chosen field.",
	130: "Systematic inquiry, clue analysis, interrogative questioning, and physical tracking.",
	134: "Resist mental and physical pressure.",
	137: "Understand street-level contacts, rumors, and criminal elements.",
	140: "Teach a specific field to another character.",
	142: "Understand cultures and manage diplomacy, etiquette, and first-contact situations.",
	146: "Subterfuge, misleading statements, bribery, imposture, and gaming.",
	150: "Perform as an actor, dancer, musician, singer, or similar entertainer.",
	155: "Negotiate, charm, interview, intimidate, seduce, taunt, and bargain.",
	162: "Lead others through command and inspiration.",
	900: "The following psionic broad skill and its specialty skills are connected to a character's Constitution score. The broad skill has a base situation die of +d4; each of the specialty skills has a base die of +d0. This skill can't be used untrained. This skill allows a character to harness the power of his mind to enhance his body's functions. With just the broad skill, a character can attempt to use any of the related specialty skills except those that can't be used untrained. The difficulty of such an action is reflected in the increased psionic energy cost and the higher base situation die for using just the broad skill.",
	901: "The following psionic broad skill and its specialty skills are connected to a character's Personality score. The broad skill has a base situation die of +d4; each of the specialty skills has a base die of +d0. This skill can't be used untrained. This skill allows a character to open his mind to the thoughts of others or send his own thoughts into the minds of others. With just the broad skill, a character can attempt to use any of the related specialty skills except those that can't be used untrained. The difficulty of such an action is reflected in the increased psionic energy cost and the higher base situation die for using just the broad skill.",
	902: "The following psionic broad skill and its specialty skills are connected to a character's Will score. The broad skill has a base situation die of +d4; each of the specialty skills has a base die of +d0. This skill can't be used untrained. This skill allows a hero to manipulate his physical environment with only the power of his mind. With just the broad skill, a character can attempt to use any of the related specialty skills except those that can't be used untrained. The difficulty of such an action is reflected in the increased psionic energy cost and the higher base situation die for using just the broad skill.",
	903: "The following psionic broad skill and its specialty skills are connected to a character's Intelligence score. The broad skill has a base situation die of +d4; each of the specialty skills has a base die of +d0. This skill can't be used untrained. This skill allows a character to experience his environment through an agency beyond the normal senses, using the power of his mind. With just the broad skill, a character can attempt to use any of the related specialty skills except those that can't be used untrained. The difficulty of such an action is reflected in the increased psionic energy cost and the higher base situation die for using just the broad skill."
}

const SPECIALTY_SUMMARIES := {
	# Dark*Matter. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of
	# Dark Matter.
	166: "Know the major cabals -- Illuminati, Templars, Freemasons -- and how their claimed histories fit together. At rank 4 the hero may once per adventure put a connection together with no research and no tools, at a +3 step penalty.",
	167: "Know the bizarre edges of physical science: cryptozoology, cold fusion, anomalies the journals will not print.",
	168: "Know traditional demonology, witchcraft and ritual history, and recognise the real thing among the theatre.",
	169: "Know the documented history of psychics, ESP phenomena and mindwalking, and what has actually been demonstrated.",
	170: "Know abduction accounts, saucer sightings and what has been recorded of Grey behaviour.",
	171: "Encode and decode ciphers. It cannot be attempted by somebody who has never learned it.",
	172: "Find what is already written down, in archives, libraries and digital records.",
	173: "Produce false documentation, and make it survive inspection. At rank 4 the hero gains a -1 step bonus to forge and anyone checking the result takes +1 step, improving to 2 steps at rank 8 and 3 at rank 12. It cannot be attempted untrained.",
	174: "Work between languages rather than in one. At rank 4 the hero picks a language family they already hold a member of at rank 3 and can translate anything in it at a +1 step penalty. It cannot be attempted untrained.",
	175: "Examine and repair extraterrestrial technology. Alien tech carries a +3 step penalty plus 1 more per Progress Level above the campaign's own, which a successful check reduces by 1, 2 or 3 steps; a critical failure ruins the device. It cannot be attempted untrained.",
	176: "The study of human society, cultures, languages, and historical development. It covers sociology, anthropology, history, and linguistic structures across civilizations. Source: Dark Matter Campaign Setting p. 51.",
	177: "The study of human cultures, beliefs, social practices, and physical remains. Source: Dark Matter Campaign Setting p. 51.",
	178: "Recalling factual historical timelines, events, and analyzing social trends across eras. Source: Dark Matter Campaign Setting p. 51.",
	179: "Familiarity with underground net forums, black market data exchanges, grayware sites, and digital netiquette to locate untraceable connections and illicit information. Source: Dark Matter Campaign Setting pp. 51, 57.",
	180: "Investigative reporting, interviewing, newsgathering, and media storytelling. Source: Player's Handbook p. 99; Dark Matter Campaign Setting p. 51.",
	181: "Visual composition, exposure, image processing, and forensic or documentary photography. Source: Player's Handbook p. 99; Dark Matter Campaign Setting p. 51.",

	1: "Specializes in standard, non-powered combat armor suits (such as Flak jackets, battle vests, and assault gear).",
	2: "Specializes in mechanically assisted, vacuum-sealed powered battle suits (such as body tanks and powered exo-armor). Untrained use prohibited.",
	4: "Escalating vertical surfaces, scaling walls, and ascending ropes.",
	5: "Performing horizontal, vertical, or running leaps.",
	6: "Launching hand-thrown objects, grenades, and daggers accurately at range.",
	9: "Fire direct-fire heavy weapons at visible targets.",
	10: "Use indirect-fire heavy weapons such as mortars or launchers against areas or concealed targets.",
	12: "Edged and stabbing weapons (swords, daggers, axes, katanas).",
	13: "Blunt impact weapons (clubs, maces, quarterstaffs, flails).",
	14: "High-tech vibrating or energy-channeling weapons (chainswords, stun batons, star swords). Untrained use prohibited.",
	16: "Rough-and-tumble street fighting, boxing, wrestling, and grappling.",
	17: "Disciplined martial arts focusing on leverage, high-impact kicks, and bone-shattering strikes. Untrained use prohibited.",
	19: "Vaulting, diving, high-wire balance, and extreme physical stunt-work.",
	20: "Soft-style martial arts (aikido, judo) focusing on throws, sweeps, and redirecting an opponent's force to deal stun damage. Untrained use prohibited.",
	21: "Ducking, weaving, and rolling to evade ranged and melee attacks.",
	22: "Techniques to break falls and minimize impact damage.",
	23: "Aerial maneuvers for species possessing wings or physical flight mutations.",
	24: "Operating fluidly in weightless or microgravity environments. Untrained use prohibited.",
	27: "Open locks and defeat mechanical locking systems.",
	28: "Steal small objects from another character without being noticed.",
	29: "Perform sleight of hand, palming, and stage-magic style manipulation.",
	31: "Single-handed firearms (semiautomatic pistols, heavy revolvers, machine pistols).",
	32: "Two-handed shoulder-fired long guns (assault rifles, sniper rifles, battle rifles).",
	33: "Compact automatic firearms designed for rapid bursts and close-quarters suppression.",
	35: "Use bows.",
	36: "Use crossbows.",
	37: "Use flintlock firearms.",
	38: "Use slings.",
	40: "Remain unnoticed by using cover, quiet, and stillness.",
	41: "Follow a target without being noticed.",
	42: "Move silently and avoid observation while moving.",
	44: "Operate a chosen air vehicle class; this skill cannot be used untrained.",
	45: "Operate a chosen land vehicle class.",
	46: "Operate a chosen space vehicle class; this skill cannot be used untrained.",
	47: "Operate a chosen water vehicle class.",
	49: "Run faster and sustain competitive ground movement; this skill cannot be used untrained.",
	50: "Swim effectively; this skill cannot be used untrained.",
	51: "Plan and maintain overland movement through difficult routes.",
	53: "Performing grueling physical tasks over hours without succumbing to exhaustion.",
	54: "Overriding the debilitating physical penalties of wounds and shock. Untrained use prohibited.",
	56: "Survive in a chosen environment or terrain type.",
	62: "Breaching access control, cracking encryption, evading intrusion detection, and electronic warfare. Untrained use prohibited.",
	63: "Physical computer components, storage media, fiber-optic pathways, and quantum processors.",
	64: "Writing, debugging, decompiling, and modifying algorithmic code and software agents.",
	66: "Safely disarming detonators, defusing mines, and disabling unexploded ordnance.",
	67: "Formulating explosive compounds from raw chemicals and improvised household materials. Untrained use prohibited.",
	68: "Precision placement of commercial or military explosives to maximize directional blast damage and structural failure.",
	70: "Use everyday computer systems; this skill cannot be used untrained.",
	71: "Reach conclusions from evidence and logic.",
	72: "Provide immediate medical aid; this skill cannot be used untrained.",
	73: "Speak, read, or understand a specific language; this skill cannot be used untrained.",
	74: "Know facts about a specific field.",
	89: "Invasive medical procedures to repair life-threatening trauma, organ damage, or install cybernetics. Untrained use prohibited.",
	90: "Immediate field medicine, wound dressing, trauma stabilization, and critical life support. Untrained use prohibited.",
	91: "Practice medicine on a specific nonhuman species; this skill cannot be used untrained.",
	93: "Plot drivespace courses; this skill cannot be used untrained.",
	94: "Navigate within a star system.",
	95: "Navigate on or near a planetary surface.",
	102: "Understand protective procedures and security protocols.",
	103: "Find, bypass, or operate security devices.",
	115: "Designing and constructing new technology.",
	116: "Improvising rapid field repairs with whatever materials are on hand.",
	117: "Proper maintenance, overhaul, and restoration of machinery, electronics, and vehicles.",
	118: "Theoretical engineering principles, blueprints, and schematic comprehension.",
	124: "Train a chosen animal type.",
	126: "Sense motives, danger, or the direction of a situation.",
	127: "Notice hidden or subtle physical details.",
	131: "Questioning persons of interest to elicit admissions, intelligence, or contradictions.",
	132: "Meticulously combing physical environments for concealed compartments, hidden clues, or tampering.",
	133: "Following footprints, tire treads, scent markers, or disturbed foliage across various terrains.",
	135: "Resist mental pressure, fear, or psychic strain.",
	136: "Resist physical pressure, exhaustion, and bodily stress.",
	145: "Handle first contact with an unfamiliar culture or species; this skill cannot be used untrained.",
	156: "Negotiate price, exchange, or terms.",
	157: "Win friendly reactions through personal appeal.",
	158: "Draw information from a subject through conversation.",
	159: "Pressure another character through threat or presence.",
	160: "Use attraction and social pressure to influence another character.",
	161: "Provoke or distract an opponent.",
	163: "Direct others in a structured chain of command.",
	164: "Encourage others and improve morale; this skill cannot be used untrained.",
	90001: "Extended duration. When employing this skill, a character generates a staff or club of bio-kinetic energy that extends from his hand and can be used as a melee weapon. The bioweapon requires the Melee Attack-bludgeon skill to be wielded effectively. The bioweapon has a damage rating of d4/d4+2/d6+2 (plus any adjustment for Strength, if applicable), depending on the result of each Melee Attack-bludgeon skill check. The initial skill check used to generate the weapon determines the type of damage the weapon does for as long as the current weapon is maintained: Ordinary, stun; Good, wound; Amazing, mortal.",
	90002: "Extended duration. Through the use of this skill, a character can regulate his metabolic processes. This allows him to survive longer without food and water, in extreme climates, and in other hostile conditions. He can also slow his bodily functions to a point where he can pretend to be dead, should he need to fool others in some situation. A check is made when a character enters a hostile environment or otherwise wants to employ this skill. In the case of a hostile environment, the result of a skill check determines the type of protection a character can simulate by manipulating his own body: Ordinary, vacuum mask; Good, jumpsuit; Amazing, soft e-suit. After the initial use of the skill, the level of protection can be maintained every hour thereafter at a cost of 1 psionic energy point.",
	90003: "This skill can't be used untrained. By concentrating, a character using this skill can heal himself of wound damage or disease. How much damage can be healed depends on the result of a skill check: Ordinary, 1 wound point; Good, 2 points; Amazing, 3 points. For disease, the following results apply: Ordinary, reduce the degree of illness by one grade; Good, reduce by two grades; Amazing, reduce by three grades. Psionic healing requires time. The results are immediate, but the body's reaction to the use of the skill lasts one hour. For this reason, the heal skill can't be attempted more than once per hour, even if the check result is a Failure. Healing Mortal Damage: At rank 6, a character becomes able to heal mortal damage. Skill check results change to: Ordinary, 2 wounds; Good, 3 wounds or 1 mortal; Amazing, 4 wounds or 2 mortals.",
	90004: "This skill can't be used untrained. By using this skill, a character can alter his features so as to disguise himself or to accomplish something he wouldn't be able to do in his normal form, such as squeeze into a small hole, reach higher than his height or arm length normally allows, or shift his body mass to slip loose of bonds. Morphing requires an entire round (4 phases) to complete, from the moment the alteration starts to when it is finished. The character can do nothing else while this process is taking place. The initial check determines how long the morphed form lasts: Ordinary, 1 round; Good, 2 rounds; Amazing, 3 rounds. Extendable at 1 psionic energy point per round. Volume can be expanded/compressed, but mass cannot change. Original characteristics are retained; no game statistics change except those directly related to the morphing (e.g. elongated fingers can grant a -1 bonus to Manipulation-pickpocket checks). Has no effect on clothing/possessions.",
	90005: "When using this skill, a character can offset fatigue or stun damage, or some of each, that he has suffered. The skill does nothing to alleviate psionic energy loss. A successful skill check provides the character with a certain number of \"rejuvenation points.\" It costs 2 of these points to restore 1 point of fatigue damage, and 1 of these points to restore 1 point of stun damage. On an Ordinary success, the character receives 2 \"rejuvenation points\"; on a Good success, 4 points; and on an Amazing success, 6 points. The character can use these points in any combination to restore stun points, fatigue points, or some of each. \"Rejuvenation points\" that can't be used immediately are lost. Psionic rejuvenation requires time. The results are immediate, but the body's reaction to the use of the skill lasts one hour. For this reason, the rejuvenate skill can't be attempted more than once per hour.",
	90006: "By laying hands upon another character and making a successful skill check, the hero alleviates that character's damage or disease by absorbing it into himself. The damage that can be absorbed is tied to the result of a skill check: Critical Failure, character suffers 1 wound; Failure, no effect; Ordinary, hero absorbs 1 wound; Good, hero absorbs 2 wounds; Amazing, hero absorbs 3 wounds or 1 mortal. An Ordinary result reduces the patient's illness by one grade, simultaneously infecting the hero with that one grade of disease; a Good result reduces the patient's disease by two grades, transferring the ailment into the hero; and an Amazing result transfers any illness from the patient into the hero. Once the hero absorbs the damage or disease, he must either use the heal specialty skill, heal naturally, or receive medical or psionic attention.",
	90101: "Extended duration. With this skill, a character can send and receive thoughts to and from another character, usually for the purpose of exchanging information. Modifiers may apply, depending on the range, familiarity, and willingness of the target mind to be contacted. The type of thoughts that can be exchanged depends on the result of a skill check: On an Ordinary success, simple concepts (brief questions and one-word answers) can be exchanged. On a Good success, moderate discussion (pass notes back and forth, one note per 2 phases) can occur. On an Amazing success, the communicating characters can have a detailed discussion, as though they were conversing vocally. If the target mind is unwilling to communicate, its Will resistance modifier is applied as a penalty. If contact is established anyway, the unwilling mind can expel the user by making a successful Will feat check or Resolve-mental resolve check with a +1/+2/+3 penalty.",
	90102: "Extended duration. This skill can't be used untrained. This skill is the ability to link one's mind with a computer or a cybernetic machine without using a physical connection of any kind. The datalink skill can be used to operate computers with mental commands, to project one's mind into the datastream, or to examine computer data by mentally scanning the storage unit. To initiate the link, the user must be within 6 meters of the point of entry (+1 penalty if >2m, +2 if >4m). A computer's normal defenses provide a penalty to the psionics-user's skill check. Otherwise, datalink can be used to accomplish any task that can be performed with the use of any computer.",
	90103: "Extended duration. This skill enables a character to fool a target's mind by projecting an illusion into it. An illusion can be a sight or a sound, but no other senses can be affected. An illusion is not capable of directly causing damage. The skill is usable only against targets the character can see, and it has a maximum range of 5 meters per skill rank of the user. Any actions the user attempts while maintaining an illusion receive a +1 penalty. The result of the character's skill check determines how powerful the illusion is, which provides a penalty to the target's Awareness-intuition skill check to realize he's seeing an illusion: Ordinary, +1; Good, +2; Amazing, +3. Multiple targets provide a cumulative +1 penalty per extra target.",
	90104: "This skill can't be used untrained. This skill allows the user to direct a powerful blast of pure mental energy at another mind. The target must be within visual contact and no more than 40 meters away (range 10/20/40). Penalties for medium and long range are +1 and +2 respectively. Damage depends on the result of a skill check and the user's rank in the skill. Armor doesn't protect against a mind blast. When a character first acquires this skill, he is able to cause damage of d4+1s/d4+2s/d6+2s. Increased Damage: At rank 5, damage becomes d4+2s/d6+2s/d8+2s. At rank 9, the damage caused by the skill goes to 2d4+2s/2d6+2s/2d8+2s.",
	90105: "This skill allows a character to establish a mental defense against psionic powers: contact, empathy, illusion, mind reading, mind blast, suggest, and tire. A mind shield provides a penalty to the skill check of another psionic character attempting to use any of these skills: Ordinary, +1; Good, +2; Amazing, +3. These penalties are cumulative with any other resistances. The shield remains in place for d4+4 hours or until it fails to stop a psionic power directed against it.",
	90106: "This specialty skill allows a character to mesmerize another character, planting a thought into their mind and convincing them that the thought is her own. No suggestion can have a permanent or immediately detrimental effect. A suggestion lasts for as long as 1, 2, or 3 hours (Ordinary, Good, or Amazing). The GM assigns a bonus or a penalty based on extremity (+3 or more penalty for opposed to nature, -1 or -2 bonus for inclined acts). The target is entitled to a Will check after suggest wears off to realize they were suggesting, with a modifier that is the reverse of the situation die used for the skill check.",
	90107: "This skill inflicts fatigue damage upon a target. The target must be within visual contact and no more than 30 meters away (range 10/20/30). Penalties for medium and long range are +1 and +2 respectively. The amount of damage inflicted depends on the result of a skill check: Ordinary, 1 fatigue point; Good, 2 points; Amazing, 3 points.",
	90201: "This skill can't be used untrained. With this skill, a character can cause an electrical charge to build up in the air around him, and he can direct that charge up to 16 meters away (range 4/8/16), delivering a shock to a single target. During the phase in which the character makes a successful skill check, the charge builds up. It can be released (for no added point cost) in any phase after that during the current round or the next one, but discharging the energy requires an additional skill check. If the charge is not released, it simply dissipates. The character can't initiate any other psionic skill while the charge is present around his body. The amount of energy damage caused by the shock depends on the result of the skill check made when it is discharged and the character's rank in the skill. When a character first acquires this skill, he is able to cause damage of d4+2s/d6+2s/d4w. Increased Damage: At rank 5, damage becomes d6+2s/d4w/d4+2w. At rank 9, the damage caused by the skill goes to d4+2w/d6+2w/d8+2w.",
	90202: "Extended duration. This skill can't be used untrained. This skill allows a character to create an invisible defensive barrier that moves with him and provides protection from physical attacks (high impact or low impact damage) by manipulating the air molecules around him. The barrier is so close to his body that it doesn't hinder other actions the hero might take. The quality of the shield depends on the result of a skill check: Ordinary, HI +1/LI +2; Good, HI +2/LI +3; Amazing, HI +3/LI +4. If the shielded character wants to perform other actions while maintaining the shield, those actions receive a +1 penalty due to the character's need to concentrate on maintaining the shield.",
	90203: "Extended duration. This skill allows a character, with only the power of his mind, to lift himself into the air and propel himself as though he were flying. How high and how fast a character can move while levitating depends on the result of a skill check, as shown below. The first entry is how many meters he can ascend or descend per phase, the second is the speed at which he can fly. These figures are doubled in gravity conditions lighter than Earth normal and halved in gravity conditions heavier than Earth normal: Ordinary: 2 meters/walk x 1; Good: 4 meters/walk x 1.5; Amazing: 6 meters/walk x 2. If a character chooses to stop levitating or runs out of psionic energy points while he's out of touch with the ground, he suffers damage from a fall as indicated on TABLE P15: IMPACT DAMAGE. Performing an additional action while levitating provides a +1 penalty to that action.",
	90204: "With this skill, a character can excite the molecules in an object so that they give off illumination. It takes one phase for the object to reach maximum luminosity, and the molecules remain excited for the rest of the current round and all of the next round. The object provides Ordinary light (roughly the same as normal daylight) that illuminates an area of up to 6 meters in diameter, depending on the result of a skill check: Ordinary, 2 meters; Good, 4 meters; Amazing, 6 meters.",
	90205: "Extended duration. This skill is the ability to move objects using the power of the mind. A character can lift objects that weigh a number of kilograms equal to his Will score x 10, or push objects that weigh his Will score x 20 in kilograms. How high and how fast an object can move while being influenced by psychokinetics depends on the result of a skill check. The first entry is how many meters an object can be lifted, the second is the speed at which it can be pushed, both in meters per phase (doubled in light gravity, halved in heavy gravity): Ordinary: Lift 1 / Push 2; Good: Lift 2 / Push 4; Amazing: Lift 3 / Push 6. If a character chooses to stop using psychokinetics or runs out of psionic energy points while the object he's manipulating is out of touch with the ground, the object immediately falls and suffers damage as indicated on TABLE P15: IMPACT DAMAGE.",
	90206: "This skill can't be used untrained. This skill allows a character to excite molecules within an object or even in the air until enough heat is generated to cause the object or area to burst into flame. In the phase following a successful skill check, the target catches fire and sustains energy damage (range 10/20/30). Armor provides protection against this attack form. If the user targets the air around a character or object, the result is a flash fire storm that has an effect similar to that of an incendiary grenade. Objects and characters up to 6 meters away from the blast can be hurt, but the fire is less intense. The primary and secondary damage from this use of pyrokinetics, as indicated by the psionics-user's rank and skill check, is reduced by 2 points for targets within 2 meters of the blast, by 3 points for targets out to 4 meters away, and by 4 points for targets out to 6 meters away. If a character or object is targeted, the result is an intense burn from the initial damage and the possibility of the character or object catching fire and taking more damage in every phase thereafter until the fire goes out or is extinguished. The intensity of the fire depends on the result of a skill check and the character's rank in the skill. When a character first acquires this skill, he is able to cause damage of d4+2w/d6+2w/d8+2w. Increased Damage: At rank 5, damage becomes d6+2w/d8+2w/d4m. At rank 9, the damage caused by the skill goes to d8+2w/d4m/d4+2m.",
	90301: "Extended duration. This skill can't be used untrained. To use this skill, a hero focuses on the battle at hand and makes a skill check. The success achieved indicates the benefit he receives while the current application of the skill remains active. A successful skill check gives the hero a bonus to his action checks: Ordinary, -1; Good, -2; Amazing, -3.",
	90302: "With this skill, a hero selects a location and projects his mind to that spot, hearing sounds as though he was physically there. Clairaudience doesn't screen out noise around the user, so he might have trouble hearing what's going on at a distance. It provides no help in interpreting unknown languages or recognizing unfamiliar sounds, and the mental ear can't move from the location it's projected to. Because the user remains conscious within his body, he is aware of what's happening around his body. The better the result of the skill check, the longer the ability lasts: Ordinary, 1 round; Good, 2 rounds; Amazing, 3 rounds. This duration can be extended by spending 1 psionic energy point for every additional round. Situation modifiers apply.",
	90303: "To employ this skill, a hero selects a location and projects his mind to that spot. He can then see everything going on around that spot as though he was physically there. This projection must be to an unobstructed location, not to a place inside a solid object. The use of the skill doesn't block the user's normal vision, so he sees double images unless he closes his eyes. It also provides no help in seeing through obscuring elements, such as walls, closed doors, or darkness, and the mental eye can't move from the selected spot. Because the user remains conscious within his body, he is aware of what's happening around his body. The better the result of the skill check, the longer the ability lasts: Ordinary, 1 round; Good, 2 rounds; Amazing, 3 rounds. This duration can be extended by spending 1 psionic energy point for every additional round. Situation modifiers apply.",
	90304: "This skill allows a hero to \"read\" the surface emotions of another character. This ability assists the user in encounter situations. The skill user must be in visual contact with the target. A successful use of empathy provides a character with an understanding of the target's emotional state (Combative, Hostile, Neutral, Friendly, Charmed, or Fanatic) and provides a bonus when using encounter skills upon that target character (-1, -2, or -3 steps, depending on the degree of success achieved).",
	90305: "This skill enables a hero to \"read\" the surface thoughts of another character with whom the user is in visual contact. The mental contact remains in effect for a limited time and can't be extended by the use of psionic energy points. The better the degree of success achieved, the longer the contact lasts and the clearer the impressions of the thoughts being read: On an Ordinary success, the contact lasts for 1 phase after the skill check is made. Only random and disjointed thoughts are perceived, such as the target's name or the identity of someone or something he is thinking about or looking at. On a Good success, the contact lasts for 2 phases after the skill check is made. In addition to random thoughts, more detail and more coherence is received, such as why the target is thinking about someone or something, or why the target is in his present location. On an Amazing success, the contact lasts for 3 phases after the skill check is made. Complete surface thoughts can be read—the sort of information that's recovered on an Ordinary or Good success, plus some key fact that's related to what the psionics-user hoped to discover.",
	90306: "This skill can't be used untrained. A character who uses this skill can instinctively determine his present location and mentally plot a course to a distant location. This can be accomplished on a planetary surface, in normal space, and even through drivespace, depending on how the character applies this skill. This mental ability replaces the use of the Navigation skill (if the character has it) whenever the character decides to spend psionic energy points. All the modifiers that pertain to the use of the Navigation skill apply, except the character doesn't make use of charts, instruments, or computers to determine his location and plot courses. At rank 1, the character selects one specialty of the Navigation skill to which to apply this mental ability, either surface navigation, system astrogation, or drivespace astrogation. Extra Specialty Skills: At rank 5, a second Navigation specialty can be selected. At rank 9, the remaining specialty becomes available.",
	90307: "With this skill, a character can sense the mood of an area and even \"see\" events that happened there in the recent past. What a character senses depends on the result of a skill check: On an Ordinary success, the character senses general emotions that have been left in an area. On a Good success, he also receives brief flashes of events that may or may not make sense to him. On an Amazing success, he actually experiences a brief encounter as though he were at the scene when the events occurred. One successful skill check can be made in an area, and only recent events can be revealed. In general, a character can see a number of time units (usually hours or days) into the past equal to his skill rank. (With just the broad skill, less than one time unit is available to the character.) This skill can be used by a player to gain clues for his hero, or it can be used by the Gamemaster to provide clues or direct story elements in a certain direction. The Gamemaster can automatically activate this skill (no psionic energy point cost) to provide clues.",
	90308: "This skill is the ability to receive impressions about possible future events—what the psionics-user sees will probably happen if he takes no action to change it. A character usually doesn't consciously employ this skill. Instead, the Gamemaster calls for a character to make a skill check whenever a precognitive flash might occur. If the character is not willing to spend psionic energy points to make the skill check, nothing happens and the scene continues. What a character senses depends on the result of a skill check: On an Ordinary success, the character perceives vague images of a future event. On a Good success, he receives brief flashes of coming events that may or may not make sense to him. On an Amazing success, he actually experiences a brief encounter as though he is at the scene when the events transpire. In general, a character can see a number of hours or days into the future equal to his skill rank. (With the broad skill, less than one hour or day is available to the character.) If a character wants to force a precognitive flash, the cost in psionic energy points is doubled—2 points to use the specialty skill, 4 points if he has only the broad skill, and 6 points if the check results in a Critical Failure. In addition, a +3 penalty is applied, and whether the check succeeds or not, the skill can't be used again consciously for 2d6 days.",
	90309: "This skill gives a hero the ability to read psychic impressions from inanimate objects. The character must touch the object to gain insight into who has used it and in what context. What a character senses depends on the result of a skill check: On an Ordinary success, the character receives simple emotions associated with the object. On a Good success, he receives simple images associated with the object. On an Amazing success, he experiences a brief encounter as though he is the person using the object or its owner. To be affected by this skill, an object must be an item that the character can hold and manipulate to pick up psionic impressions. Dirt, the ground, dust, or other casually encountered objects aren't affected because people don't make the sorts of connections with these objects that result in psionic residue being left behind (though postcognition picks up impressions left in an area). The Gamemaster can automatically activate this skill (no psionic energy point cost) to provide a clue or otherwise direct a story.",
	90310: "This skill enables a hero to realize when a psionic skill is being used in his or her vicinity. Unlike the Psionic Awareness perk, the sensitivity specialty is consciously invoked by the hero whenever he or she desires to do so, and the check to determine success is made by the player of the hero, not by the Gamemaster. Activating the skill requires the hero to use 2 psionic energy points. The sensitivity persists for 1 minute, and can be kept active in subsequent minutes by expending 1 psionic energy point per minute thereafter. The skill check made when the specialty is first invoked determines the extent of what the hero learns during all the time when the specialty remains in use: On an Ordinary success, the hero becomes aware that one or more psionic skills are being employed within a range of 20 meters, and can tell which character(s) the psionic energy is emanating from. A Good success also enables the hero to identify the broad skill(s) being used, and an Amazing success tells the hero the exact specialty skill(s) being used. (The use of sensitivity can itself be detected by another character who successfully employs the skill.)",
	## Dark*Matter psionics. Gated by setting, so a Core campaign never
	## offers them. Source: Dark*Matter campaign setting.
	90311: "A dowsing power that finds lost or hidden objects that are not alive. An Ordinary success gives the direction, a Good or Amazing success the exact distance as well, within a 30-meter radius. It cannot find living creatures. Working through a focus such as a dowsing rod grants a -1 step bonus; working without one costs a +1 step penalty. Longer Reach: at rank 6 the radius grows to 100 meters, at rank 9 to 1 kilometer, and at rank 12 to 100 kilometers.",
	90108: "The hero clouds the minds of onlookers so that they overlook, disregard or misremember him for the scene. A witness trying to recall what they saw makes a Will feat check at a +1 step penalty on an Ordinary success, +2 on a Good, and +3 on an Amazing. Memories lost this way come back only through Medical Science - psychology, as a complex check needing 8 successes at one check per 5 minutes.",
	90109: "This skill can't be used untrained. The hero overrides a victim's conscious mind and takes command of their body, moving it while the host's own mind lies paralysed. The attempt is opposed by the target's Will resistance modifier.",

	# Specialties that previously fell through to the generated stub.
	7: "Choose a specific athletic pursuit when buying this specialty. It covers feats of strength and stamina in that pursuit that the other Athletics specialties do not.",
	25: "Choose a specific acrobatic pursuit when buying this specialty. It covers agility and balance feats in that pursuit not already covered by the other Acrobatics specialties.",
	58: "Knowledge of how corporations operate: structure, hierarchy, contracts, mergers, and who inside one to approach for what.",
	59: "Knowledge of black markets and criminal enterprise: fencing goods, smuggling routes, protection rackets, and what things fetch off the books.",
	60: "Running or reading a small commercial operation: stock, payroll, suppliers, margins, and whether a given business is sound.",
	76: "Knowledge of how courts operate: filings, procedure, precedent, and how a case is argued or delayed.",
	77: "Knowledge of policing: jurisdiction, investigation procedure, evidence handling, arrest and detention practice.",
	78: "Choose a specific body of law when buying this specialty -- a nation, a corporation, a stellar authority. Covers statutes, rights and penalties under that code.",
	80: "The study of living organisms: cell function, physiology, ecology, and identifying what an unfamiliar organism is and how it lives.",
	81: "The study of plants: identification, toxicity, cultivation, and reading an environment from its flora.",
	82: "The study of heredity and gene manipulation: reading a genome, identifying engineered traits, and understanding inherited conditions.",
	83: "The study of alien life: unfamiliar biologies, behaviour and biochemistry that terrestrial biology does not account for.",
	84: "The study of animals: identification, behaviour, habitat and what a given creature is likely to do.",
	86: "Post-mortem examination, ballistics matching, blood splatter analysis, and toxicological screening.",
	87: "Non-surgical clinical medicine, disease pathology, pharmacology, and physiological diagnosis.",
	88: "The study of the mind: diagnosing disorders, reading motive and mental state, and understanding how a person is likely to behave.",
	97: "The study of stars and space: stellar bodies, orbital mechanics, and interpreting astronomical observations.",
	98: "The study of matter and its reactions: compounds, synthesis, reagents, and identifying an unknown substance.",
	99: "The study of matter, energy and their laws: mechanics, radiation, fields, and working out what is physically possible.",
	100: "The study of worlds: geology, atmosphere, weather and hazards, and assessing whether a planet can be lived on.",
	105: "Operating a vessel's or installation's communications systems: transmission, reception, encryption and jamming.",
	106: "Operating defensive systems: shields, screens, countermeasures and damage control.",
	107: "Operating engineering systems: power plants, drives and the repairs and rerouting that keep them running.",
	108: "Operating sensor systems: scanning, detection, identification and interpreting a return.",
	109: "Operating mounted weapon systems: targeting, firing solutions and battery management.",
	111: "Directing troops on the ground: formations, cover, fire discipline and reading a battlefield.",
	112: "Directing forces in space: fleet manoeuvre, engagement ranges and orbital positioning.",
	113: "Directing vehicles in combat: convoy and squadron movement, terrain use and coordinated attack.",
	120: "Working a bureaucracy: forms, channels, precedence and getting a decision made or a record retrieved.",
	121: "Running an organisation: assigning people, allocating resources, scheduling and holding a group to a plan.",
	123: "Riding a trained animal, and controlling it under stress or in difficult terrain.",
	129: "Choose a specific creative craft when buying this specialty -- writing, sculpture, design. Covers producing and critiquing work in that craft.",
	138: "Knowing the criminal world: who runs what, which gang holds which ground, and how to make contact without being marked.",
	139: "Choose a specific place when buying this specialty. Covers its neighbourhoods, rumours, dangers and who to ask about them.",
	141: "Choose a specific subject when buying this specialty. Covers conveying that subject so someone else can learn it.",
	143: "Formal negotiation between parties or powers: protocol, mediation, and reaching terms both sides will hold to.",
	144: "Choose a specific culture when buying this specialty. Covers its manners, customs and expectations, and moving through them without giving offence.",
	147: "Convincing someone of something untrue -- a false identity, a false account, a phony reason for presence.",
	148: "Offering an inducement without it being refused or reported, and judging what a target wants.",
	149: "Games of chance and skill, understanding odds, spotting cheats, and reading table tells.",
	151: "Performing a role convincingly, on a stage or as sustained pretence.",
	152: "Performing dance, whether formally, socially or as part of a ceremony.",
	153: "Choose a specific instrument when buying this specialty. Covers performance on it and reading music for it.",
	154: "Singing, whether performing for an audience or as part of a ceremony.",
}

const COMPLEX_SKILL_NOTES := {
	4: "Long climbs and challenge-scene climbing can be run as complex checks.",
	27: "Opening difficult locks can require a complex check; complexity depends on the lock and conditions.",
	62: "Hacking commonly uses a complex check against the target system's security.",
	64: "Writing or modifying software can use a complex check over time.",
	66: "Disarming explosives can use a complex check when the device is complicated or dangerous.",
	67: "Scratch-built explosives can require multiple successes to assemble safely.",
	89: "Surgery is normally handled as a complex medical task.",
	90: "Treatment can require a complex check for serious injuries or extended care.",
	115: "Invention is a complex technical task whose successes represent progress toward a working design.",
	117: "Major repairs can use complex checks; time and required successes depend on damage and equipment.",
	124: "Animal training uses complex checks; harder training takes more successes and more time.",
	133: "Tracking a long or difficult trail can use complex checks; failures can lose the trail.",
	145: "First encounter scenes can use complex checks to build understanding and avoid offense.",
	156: "Important bargaining can be run as a social complex check.",
	157: "Extended attempts to win trust can use complex social checks.",
	158: "Interviews can use complex checks when the information is hard to draw out.",
	160: "Extended seduction or influence attempts can use complex social checks.",
}

const RANK_BENEFIT_NOTES := {
	# Dark*Matter skills. Source: Dark Matter Campaign Setting, Chapter 3: Heroes
	# of Dark Matter.
	166: {
		4: "Seeing the Puzzle: once per adventure the hero may attempt a Conspiracy Theories check at a +3 step penalty with no research time and no tools. On a success the Gamemaster hands them a connection they had no way of making. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
	},
	173: {
		4: "Increased Skill: a -1 step bonus to create false documentation, and anyone trying to identify the forgery takes a +1 step penalty. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
		8: "The forgery bonus and the penalty to spot it both improve to 2 steps. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
		12: "The forgery bonus and the penalty to spot it both improve to 3 steps. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
	},
	174: {
		4: "Translate Documents: the hero picks a language family they already hold one member of at rank 3, and can translate any document in it at a +1 step penalty. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
		8: "Either a second language family, or the first family's +1 step penalty is dropped. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
		12: "A permanent -1 step bonus to translating the family, spoken or written. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
	},
	175: {
		6: "Improved Familiarity: the alien tech penalty is reduced by 1 step automatically. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
		12: "The automatic reduction improves to 2 steps. It never becomes a bonus. Source: Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
	},
	1: {
		1: "Armor penalties for the appropriate armor type are reduced by 1 additional step beyond the broad skill reduction. Source: Player's Handbook p. 66.",
		2: "Stun damage suffered while wearing the appropriate armor type is reduced by 1 point. Source: Player's Handbook p. 66.",
		4: "Armor penalty reduction improves to 2 additional steps, and armor-worn stun reduction improves to 2 points. These reductions never create a bonus. Source: Player's Handbook p. 66.",
		6: "Armor-worn stun reduction improves to 3 points. Source: Player's Handbook p. 66.",
		7: "Armor penalty reduction improves to 3 additional steps. These reductions never create a bonus. Source: Player's Handbook p. 66.",
		8: "Armor-worn stun reduction improves to 4 points. Source: Player's Handbook p. 66.",
		10: "Armor penalty reduction improves to 4 additional steps, and armor-worn stun reduction improves to 5 points. Source: Player's Handbook p. 66.",
		12: "Armor-worn stun reduction reaches 6 points. Source: Player's Handbook p. 66.",
	},
	2: {
		1: "Armor penalties for the appropriate armor type are reduced by 1 additional step beyond the broad skill reduction. Source: Player's Handbook p. 66.",
		2: "Stun damage suffered while wearing the appropriate armor type is reduced by 1 point. Source: Player's Handbook p. 66.",
		4: "Armor penalty reduction improves to 2 additional steps, and armor-worn stun reduction improves to 2 points. These reductions never create a bonus. Source: Player's Handbook p. 66.",
		6: "Armor-worn stun reduction improves to 3 points. Source: Player's Handbook p. 66.",
		7: "Armor penalty reduction improves to 3 additional steps. These reductions never create a bonus. Source: Player's Handbook p. 66.",
		8: "Armor-worn stun reduction improves to 4 points. Source: Player's Handbook p. 66.",
		10: "Armor penalty reduction improves to 4 additional steps, and armor-worn stun reduction improves to 5 points. Source: Player's Handbook p. 66.",
		12: "Armor-worn stun reduction reaches 6 points. Source: Player's Handbook p. 66.",
	},
	5: {
		3: "Running jump distance increases by 1 meter. Source: Player's Handbook p. 67.",
		4: "Standing jump distance increases by 1 meter. Source: Player's Handbook p. 67.",
		5: "Vertical jump distance increases by 0.5 meter. Source: Player's Handbook p. 67.",
		6: "Running jump distance increases by another 1 meter. Source: Player's Handbook p. 67.",
		7: "Standing jump distance increases by another 1 meter. Source: Player's Handbook p. 67.",
		8: "Vertical jump distance increases by another 0.5 meter. Source: Player's Handbook p. 67.",
		9: "Running jump distance increases by another 1 meter. Source: Player's Handbook p. 67.",
		10: "Standing jump distance increases by another 1 meter. Source: Player's Handbook p. 67.",
		11: "Vertical jump distance increases by another 0.5 meter. Source: Player's Handbook p. 67.",
		12: "Running jump distance increases by another 1 meter. Source: Player's Handbook p. 67.",
	},
	12: {
		4: "Strength resistance modifier improves by +1 for close-quarters defense, and reaction parry becomes available: an incoming melee or unarmed attack may be parried using the next available action. Source: Player's Handbook p. 68.",
		6: "Double-strike becomes available: two attacks in one phase with one control die and two situation dice at +1 and +2 step penalties. Source: Player's Handbook p. 68.",
		8: "Strength resistance modifier improves by another +1 (to +2) for close-quarters defense. Source: Player's Handbook p. 68.",
		9: "Multistrike becomes available: three attacks in one phase, with +1, +2, and +3 step penalties on the situation dice. Source: Player's Handbook p. 68.",
		12: "Strength resistance modifier improves by another +1 (to +3) for close-quarters defense. Source: Player's Handbook p. 68.",
	},
	13: {
		4: "Strength resistance modifier improves by +1 for close-quarters defense, and reaction parry becomes available: an incoming melee or unarmed attack may be parried using the next available action. Source: Player's Handbook p. 68.",
		6: "Double-strike becomes available: two attacks in one phase with one control die and two situation dice at +1 and +2 step penalties. Source: Player's Handbook p. 68.",
		8: "Strength resistance modifier improves by another +1 (to +2) for close-quarters defense. Source: Player's Handbook p. 68.",
		9: "Multistrike becomes available: three attacks in one phase, with +1, +2, and +3 step penalties on the situation dice. Source: Player's Handbook p. 68.",
		12: "Strength resistance modifier improves by another +1 (to +3) for close-quarters defense. Source: Player's Handbook p. 68.",
	},
	14: {
		4: "Strength resistance modifier improves by +1 for close-quarters defense, and reaction parry becomes available: an incoming melee or unarmed attack may be parried using the next available action. Source: Player's Handbook p. 68.",
		6: "Double-strike becomes available: two attacks in one phase with one control die and two situation dice at +1 and +2 step penalties. Source: Player's Handbook p. 68.",
		8: "Strength resistance modifier improves by another +1 (to +2) for close-quarters defense. Source: Player's Handbook p. 68.",
		9: "Multistrike becomes available: three attacks in one phase, with +1, +2, and +3 step penalties on the situation dice. Source: Player's Handbook p. 68.",
		12: "Strength resistance modifier improves by another +1 (to +3) for close-quarters defense. Source: Player's Handbook p. 68.",
	},
	16: {
		4: "Knockout attempts impose a +1 step penalty on the opponent's Stamina-endurance check after an Amazing success. Source: Player's Handbook p. 69.",
		8: "Knockout penalty improves to +2 steps, and unarmed damage improves to d6s/d6+2s/d4w before Strength bonuses. Source: Player's Handbook p. 69.",
		12: "Knockout penalty improves to +3 steps. Source: Player's Handbook p. 69.",
	},
	17: {
		3: "Knockout attempts impose a +1 step penalty on the opponent's Stamina-endurance check after an Amazing success. Source: Player's Handbook p. 69.",
		4: "Strength resistance modifier improves by +1 for close-combat defense. Source: Player's Handbook p. 70.",
		5: "Can make Unarmed Attack checks even when hands are bound, cuffed, or unusable. Source: Player's Handbook p. 69.",
		6: "Knockout penalty improves to +2 steps. Source: Player's Handbook p. 69.",
		7: "Unarmed damage improves to d6+2s/d4w/d4+2w before Strength bonuses. Source: Player's Handbook p. 69.",
		8: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 70.",
		9: "Knockout penalty improves to +3 steps. Source: Player's Handbook p. 69.",
		12: "Strength resistance modifier improves by another +1 for close-combat defense, and knockout penalty improves to +4 steps. Source: Player's Handbook p. 69-70.",
	},
	20: {
		2: "Can block or counter unarmed attacks with Defensive Martial Arts. Source: Player's Handbook p. 71.",
		4: "Can attempt a reaction block against unarmed attacks, using the next available action; Strength resistance modifier improves by +1 for close-combat defense. Source: Player's Handbook p. 71.",
		8: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 71.",
		12: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 71.",
	},
	21: {
		# Dodge is an active defence and grants no passive resistance at any rank.
		# Entries at 4, 8 and 12 used to promise a Dexterity resistance
		# improvement, carrying a citation to this same page -- the martial-arts
		# template copied onto a skill the manuals never give it to. They are
		# gone, along with the calculation that honoured them.
		3: "Can dodge and still take an action in the same phase; the action carries a +2 step penalty. Source: Player's Handbook p. 71.",
		7: "Can perform a reaction dodge immediately, but gives up other actions for the round. Source: Player's Handbook p. 71.",
	},
	23: {
		3: "Glide movement improves by +2 meters. Source: Player's Handbook p. 71.",
		4: "Fly movement improves by +3 meters. Source: Player's Handbook p. 71.",
		7: "Glide movement improves by another +2 meters. Source: Player's Handbook p. 71.",
		8: "Fly movement improves by another +3 meters. Source: Player's Handbook p. 71.",
		11: "Glide movement improves by another +2 meters. Source: Player's Handbook p. 71.",
		12: "Fly movement improves by another +3 meters. Source: Player's Handbook p. 71.",
	},
	24: {
		1: "Zero-g penalty is reduced to +2 steps, and light-gravity penalties are eliminated. Source: Player's Handbook p. 72.",
		4: "Zero-g penalty is reduced to +1 step, and light-gravity physical actions gain a -1 step bonus. Source: Player's Handbook p. 72.",
		7: "Zero-g penalty is eliminated. Source: Player's Handbook p. 72.",
		10: "Zero-g physical actions gain a -1 step bonus. Source: Player's Handbook p. 72.",
	},
	28: {
		3: "Targets suffer a +1 step penalty to notice a pickpocket attempt. Source: Player's Handbook p. 72.",
		6: "Targets suffer a +2 step penalty to notice a pickpocket attempt. Source: Player's Handbook p. 72.",
		9: "Targets suffer a +3 step penalty to notice a pickpocket attempt. Source: Player's Handbook p. 72.",
		12: "Targets suffer a +4 step penalty to notice a pickpocket attempt. Source: Player's Handbook p. 72.",
	},
	31: {
		3: "Quick Draw removes the usual +1 step penalty for drawing and firing a pistol in the same phase. Source: Player's Handbook p. 73.",
		5: "Distance Precision removes the medium-range penalty and reduces the long-range penalty by 1 step for pistol attacks. Source: Player's Handbook p. 75.",
		6: "Double-Shot allows two pistol shots in one action; the first shot uses a +1 step penalty and the second uses a +2 step penalty. Source: Player's Handbook p. 75.",
	},
	32: {
		3: "Improved Aim grants a -1 step bonus to rifle attacks. Source: Player's Handbook p. 73.",
		5: "Distance Precision removes the medium-range penalty and reduces the long-range penalty by 1 step for rifle attacks. Source: Player's Handbook p. 75.",
		6: "Precision Shooting reduces autofire attack penalties to 0, +1, and +2 steps. Source: Player's Handbook p. 73.",
	},
	33: {
		3: "Rock-n-Roll reduces the penalty for changing a clip and firing an SMG in the same action to +1 step. Source: Player's Handbook p. 73.",
		6: "Precision Shooting reduces autofire attack penalties to 0, +1, and +2 steps. Source: Player's Handbook p. 73.",
		9: "Extra Burst allows four bursts on autofire; the fourth situation die has a +3 step penalty and uses one additional burst. Source: Player's Handbook p. 73.",
	},
	35: {
		3: "Distance Precision removes the medium-range penalty and reduces the long-range penalty by 1 step for bow attacks. Source: Player's Handbook p. 75.",
		6: "Double-Shot allows two bow shots in one action; the first shot uses a +1 step penalty and the second uses a +2 step penalty. Source: Player's Handbook p. 75.",
	},
	36: {
		3: "Distance Precision removes the medium-range penalty and reduces the long-range penalty by 1 step for crossbow attacks. Source: Player's Handbook p. 75.",
		6: "Rate of Fire Increase lets a crossbow be loaded and fired in the same action. Source: Player's Handbook p. 75.",
	},
	37: {
		3: "Distance Precision removes the medium-range penalty and reduces the long-range penalty by 1 step for flintlock attacks. Source: Player's Handbook p. 75.",
		6: "Rate of Fire Increase lets a flintlock pistol be loaded and fired in the same action, and lets a flintlock rifle be loaded in one action. Source: Player's Handbook p. 75.",
		12: "Rate of Fire Increase lets a flintlock rifle be loaded and fired in the same action. Source: Player's Handbook p. 75.",
	},
	38: {
		3: "Distance Precision removes the medium-range penalty and reduces the long-range penalty by 1 step for sling attacks. Source: Player's Handbook p. 75.",
		6: "Double-Shot allows two sling shots at a single target in one action; the shots use +1 and +2 step penalties. Source: Player's Handbook p. 75.",
	},
	40: {
		4: "Stealth Increased Effect applies to Hide: Marginal/Ordinary/Good/Amazing results impose +1/+2/+3/+4 step observer penalties. Source: Player's Handbook p. 75.",
	},
	41: {
		5: "Stealth Increased Effect applies to Shadow: Marginal/Ordinary/Good/Amazing results impose +1/+2/+3/+4 step observer penalties. Source: Player's Handbook p. 75.",
	},
	42: {
		6: "Stealth Increased Effect applies to Sneak: Marginal/Ordinary/Good/Amazing results impose +1/+2/+3/+4 step observer penalties. Source: Player's Handbook p. 75.",
	},
	49: {
		1: "Run movement improves by +2 meters. Source: Player's Handbook p. 77.",
		4: "Sprint movement improves by +2 meters. Source: Player's Handbook p. 77.",
		5: "Run movement improves by another +2 meters. Source: Player's Handbook p. 77.",
		7: "Sprint movement improves by another +2 meters. Source: Player's Handbook p. 77.",
		9: "Run movement improves by another +2 meters. Source: Player's Handbook p. 77.",
		12: "Sprint movement improves by another +2 meters. Source: Player's Handbook p. 77.",
	},
	50: {
		1: "Stamina-endurance checks for holding breath or avoiding underwater stun damage gain a -1 step bonus. Source: Player's Handbook p. 77.",
		4: "Breath-holding bonus improves to -2 steps, and swim/easy swim movement each increase by 1 meter. Source: Player's Handbook p. 77.",
		8: "Breath-holding bonus improves to -3 steps, and swim/easy swim movement each increase by another 1 meter. Source: Player's Handbook p. 77.",
		12: "Breath-holding bonus improves to -4 steps, and swim/easy swim movement each increase by another 1 meter. Source: Player's Handbook p. 77.",
	},
	53: {
		4: "Checks to resist physical exhaustion, fatigue damage, and knockout attempts gain a -1 step bonus. Source: Player's Handbook p. 77.",
		8: "Exhaustion and knockout resistance bonus improves to -2 steps. Source: Player's Handbook p. 77.",
		12: "Exhaustion and knockout resistance bonus improves to -3 steps. Source: Player's Handbook p. 77.",
	},
	54: {
		4: "Checks to resist pain, shock, and wound penalties gain a -1 step bonus. Source: Player's Handbook p. 77.",
		8: "Resist pain bonus improves to -2 steps. Source: Player's Handbook p. 77.",
		12: "Resist pain bonus improves to -3 steps. Source: Player's Handbook p. 77.",
	},
	56: {
		3: "May select a second specific environmental biome specialization. Source: Player's Handbook p. 77.",
		6: "May select a third biome or gain a -1 step bonus in an existing environment. Source: Player's Handbook p. 77.",
	},
	59: {
		1: "Illegal-transaction penalties are reduced by 1 step; this can eliminate but never create a bonus. Source: Player's Handbook p. 79.",
		4: "Illegal-transaction penalty reduction improves to 2 steps. Source: Player's Handbook p. 79.",
		7: "Illegal-transaction penalty reduction improves to 3 steps. Source: Player's Handbook p. 79.",
		10: "Illegal-transaction penalty reduction improves to 4 steps. Source: Player's Handbook p. 79.",
	},
	60: {
		1: "Small-business deals, haggling, and small-business finances gain a -1 step bonus. Source: Player's Handbook p. 79.",
		4: "Small-business bonus improves to -2 steps. Source: Player's Handbook p. 79.",
		8: "Small-business bonus improves to -3 steps. Source: Player's Handbook p. 79.",
		12: "Small-business bonus improves to -4 steps. Source: Player's Handbook p. 79.",
	},
	62: {
		4: "Hacking checks gain a -1 step bonus. Source: Player's Handbook p. 80.",
		8: "Hacking checks gain a -2 step bonus. Source: Player's Handbook p. 80.",
		12: "Hacking checks gain a -3 step bonus. Source: Player's Handbook p. 80.",
	},
	63: {
		4: "Hardware checks gain a -1 step bonus. Source: Player's Handbook p. 80.",
		8: "Hardware checks gain a -2 step bonus. Source: Player's Handbook p. 80.",
		12: "Hardware checks gain a -3 step bonus. Source: Player's Handbook p. 80.",
	},
	64: {
		1: "Can modify source code of Ordinary quality and Ordinary complexity. Source: Player's Handbook p. 80.",
		3: "Can modify existing programs of Good quality/complexity and create new programs of Marginal quality/complexity. Source: Player's Handbook p. 80.",
		6: "Can modify any existing program and create Ordinary quality/complexity programs. Source: Player's Handbook p. 80.",
		9: "Can create Good quality/complexity programs. Source: Player's Handbook p. 80.",
		12: "Can create Amazing quality/complexity programs. Source: Player's Handbook p. 80.",
	},
	71: {
		4: "Intelligence resistance modifier improves by +1. Source: Player's Handbook p. 82.",
		8: "Intelligence resistance modifier improves by another +1. Source: Player's Handbook p. 82.",
		12: "Intelligence resistance modifier improves by another +1. Source: Player's Handbook p. 82.",
	},
	72: {
		4: "First-aid situation penalties are reduced by 1 step; this can eliminate but never create a bonus. Source: Player's Handbook p. 82.",
		8: "First-aid situation penalty reduction improves to 2 steps. Source: Player's Handbook p. 82.",
		12: "First-aid situation penalty reduction improves to 3 steps. Source: Player's Handbook p. 82.",
	},
	73: {
		1: "Communication in the language carries a +3 step penalty. Source: Player's Handbook p. 83.",
		2: "Communication penalty improves to +1 step. Source: Player's Handbook p. 83.",
		3: "Communication has no language-rank modifier. Source: Player's Handbook p. 83.",
		6: "Communication in the language gains a -1 step bonus. Source: Player's Handbook p. 83.",
		9: "Communication in the language gains a -2 step bonus. Source: Player's Handbook p. 83.",
		12: "Communication in the language gains a -3 step bonus. Source: Player's Handbook p. 83.",
	},
	78: {
		3: "Checks involving this legal system gain a -1 step bonus when using Law, court procedures, or law enforcement as appropriate. Source: Player's Handbook p. 84.",
		6: "Legal-system bonus improves to -2 steps. Source: Player's Handbook p. 84.",
		9: "Legal-system bonus improves to -3 steps. Source: Player's Handbook p. 84.",
		12: "Legal-system bonus improves to -4 steps. Source: Player's Handbook p. 84.",
	},
	80: {
		3: "Checks assisted by Biology gain a -1 step bonus. Source: Player's Handbook p. 84.",
		6: "Biology-assisted bonus improves to -2 steps. Source: Player's Handbook p. 84.",
		9: "Biology-assisted bonus improves to -3 steps. Source: Player's Handbook p. 84.",
		12: "Biology-assisted bonus improves to -4 steps. Source: Player's Handbook p. 84.",
	},
	81: {
		3: "Checks assisted by Botany gain a -1 step bonus. Source: Player's Handbook p. 84.",
		6: "Botany-assisted bonus improves to -2 steps. Source: Player's Handbook p. 84.",
		9: "Botany-assisted bonus improves to -3 steps. Source: Player's Handbook p. 84.",
		12: "Botany-assisted bonus improves to -4 steps. Source: Player's Handbook p. 84.",
	},
	82: {
		3: "Checks assisted by Genetics gain a -1 step bonus. Source: Player's Handbook p. 84.",
		6: "Genetics-assisted bonus improves to -2 steps. Source: Player's Handbook p. 84.",
		9: "Genetics-assisted bonus improves to -3 steps. Source: Player's Handbook p. 84.",
		12: "Genetics-assisted bonus improves to -4 steps. Source: Player's Handbook p. 84.",
	},
	83: {
		3: "Checks assisted by Xenology gain a -1 step bonus. Source: Player's Handbook p. 84.",
		6: "Xenology-assisted bonus improves to -2 steps. Source: Player's Handbook p. 84.",
		9: "Xenology-assisted bonus improves to -3 steps. Source: Player's Handbook p. 84.",
		12: "Xenology-assisted bonus improves to -4 steps. Source: Player's Handbook p. 84.",
	},
	84: {
		3: "Checks assisted by Zoology gain a -1 step bonus. Source: Player's Handbook p. 84.",
		6: "Zoology-assisted bonus improves to -2 steps. Source: Player's Handbook p. 84.",
		9: "Zoology-assisted bonus improves to -3 steps. Source: Player's Handbook p. 84.",
		12: "Zoology-assisted bonus improves to -4 steps. Source: Player's Handbook p. 84.",
	},
	86: {
		3: "Checks assisted by Forensics gain a -1 step bonus. Source: Player's Handbook p. 85.",
		6: "Forensics-assisted bonus improves to -2 steps. Source: Player's Handbook p. 85.",
		9: "Forensics-assisted bonus improves to -3 steps. Source: Player's Handbook p. 85.",
		12: "Forensics-assisted bonus improves to -4 steps. Source: Player's Handbook p. 85.",
	},
	87: {
		2: "Medical Science-treatment checks gain a -1 step bonus. Source: Player's Handbook p. 85.",
		5: "Treatment-support bonus improves to -2 steps. Source: Player's Handbook p. 85.",
		8: "Treatment-support bonus improves to -3 steps. Source: Player's Handbook p. 85.",
		12: "Treatment-support bonus improves to -4 steps. Source: Player's Handbook p. 85.",
	},
	88: {
		3: "Checks assisted by Psychology gain a -1 step bonus. Source: Player's Handbook p. 85.",
		6: "Psychology-assisted bonus improves to -2 steps. Source: Player's Handbook p. 85.",
		9: "Psychology-assisted bonus improves to -3 steps. Source: Player's Handbook p. 85.",
		12: "Psychology-assisted bonus improves to -4 steps. Source: Player's Handbook p. 85.",
	},
	89: {
		3: "Cybernetic Surgery allows repair or healing of organisms with existing cybernetic implants when the campaign includes cybertech. Source: Player's Handbook p. 86.",
		6: "Cybernetic Surgery allows installation of cybernetic implants when the campaign includes cybertech. Source: Player's Handbook p. 86.",
	},
	90: {
		3: "Treatment situation penalties are reduced by 1 step; this can eliminate but never create a bonus. Source: Player's Handbook p. 86.",
		6: "Treatment penalty reduction improves to 2 steps. Source: Player's Handbook p. 86.",
		9: "Treatment penalty reduction improves to 3 steps. Source: Player's Handbook p. 86.",
		12: "Treatment penalty reduction improves to 4 steps. Source: Player's Handbook p. 86.",
	},
	91: {
		3: "Alien-patient penalty is reduced from +3 steps to +2 steps for the selected species. Source: Player's Handbook p. 86.",
		6: "Alien-patient penalty is reduced to +1 step for the selected species. Source: Player's Handbook p. 86.",
		9: "Alien-patient penalty is eliminated for the selected species. Source: Player's Handbook p. 86.",
		12: "Treating the selected species gains a -1 step bonus. Source: Player's Handbook p. 86.",
	},
	97: {
		3: "Checks assisted by Astronomy gain a -1 step bonus. Source: Player's Handbook p. 88.",
		6: "Astronomy-assisted bonus improves to -2 steps. Source: Player's Handbook p. 88.",
		9: "Astronomy-assisted bonus improves to -3 steps. Source: Player's Handbook p. 88.",
		12: "Astronomy-assisted bonus improves to -4 steps. Source: Player's Handbook p. 88.",
	},
	98: {
		3: "Checks assisted by Chemistry gain a -1 step bonus. Source: Player's Handbook p. 88.",
		6: "Chemistry-assisted bonus improves to -2 steps. Source: Player's Handbook p. 88.",
		9: "Chemistry-assisted bonus improves to -3 steps. Source: Player's Handbook p. 88.",
		12: "Chemistry-assisted bonus improves to -4 steps. Source: Player's Handbook p. 88.",
	},
	99: {
		3: "Checks assisted by Physics gain a -1 step bonus. Source: Player's Handbook p. 88.",
		6: "Physics-assisted bonus improves to -2 steps. Source: Player's Handbook p. 88.",
		9: "Physics-assisted bonus improves to -3 steps. Source: Player's Handbook p. 88.",
		12: "Physics-assisted bonus improves to -4 steps. Source: Player's Handbook p. 88.",
	},
	100: {
		3: "Checks assisted by Planetology gain a -1 step bonus. Source: Player's Handbook p. 88.",
		6: "Planetology-assisted bonus improves to -2 steps. Source: Player's Handbook p. 88.",
		9: "Planetology-assisted bonus improves to -3 steps. Source: Player's Handbook p. 88.",
		12: "Planetology-assisted bonus improves to -4 steps. Source: Player's Handbook p. 88.",
	},
	111: {
		4: "Tactics checks against opposing infantry gain a -1 step bonus. Source: Player's Handbook p. 89.",
		8: "Infantry tactics bonus improves to -2 steps. Source: Player's Handbook p. 89.",
		12: "Infantry tactics bonus improves to -3 steps. Source: Player's Handbook p. 89.",
	},
	112: {
		4: "Tactics checks against opposing spaceships gain a -1 step bonus. Source: Player's Handbook p. 89.",
		8: "Space tactics bonus improves to -2 steps. Source: Player's Handbook p. 89.",
		12: "Space tactics bonus improves to -3 steps. Source: Player's Handbook p. 89.",
	},
	113: {
		4: "Tactics checks against opposing vehicles gain a -1 step bonus. Source: Player's Handbook p. 89.",
		8: "Vehicle tactics bonus improves to -2 steps. Source: Player's Handbook p. 89.",
		12: "Vehicle tactics bonus improves to -3 steps. Source: Player's Handbook p. 89.",
	},
	116: {
		6: "Improved Juryrig upgrades success quality: Ordinary functions as Good, Good as Amazing, and Amazing counts as a regular repair. Source: Player's Handbook p. 90.",
	},
	118: {
		3: "Checks involving Technical Science or its specialties gain a -1 step bonus. Source: Player's Handbook p. 90.",
		6: "Technical Science support bonus improves to -2 steps. Source: Player's Handbook p. 90.",
		9: "Technical Science support bonus improves to -3 steps. Source: Player's Handbook p. 90.",
		12: "Technical Science support bonus improves to -4 steps. Source: Player's Handbook p. 90.",
	},
	123: {
		3: "Trick Riding becomes available; mounted cover can impose opponent attack penalties of +1/+2/+3 steps on Ordinary/Good/Amazing riding results. Source: Player's Handbook p. 91-92.",
	},
	133: {
		1: "Select one terrain type when buying Track and one additional terrain type at each new rank; tracking in a selected terrain gains a -1 step bonus, while unselected terrain carries a +1 step penalty. Source: Player's Handbook p. 94.",
	},
	135: {
		4: "Will resistance modifier improves by +1 against encounter skills, mental powers, and similar influence. Source: Player's Handbook p. 94.",
		8: "Will resistance modifier improves by another +1 against encounter skills, mental powers, and similar influence. Source: Player's Handbook p. 94.",
		12: "Will resistance modifier improves by another +1 against encounter skills, mental powers, and similar influence. Source: Player's Handbook p. 94.",
	},
	144: {
		3: "Culture-diplomacy checks with the selected culture gain a -1 step bonus. Source: Player's Handbook p. 97.",
		6: "Selected-culture diplomacy bonus improves to -2 steps. Source: Player's Handbook p. 97.",
		9: "Selected-culture diplomacy bonus improves to -3 steps. Source: Player's Handbook p. 97.",
		12: "Selected-culture diplomacy bonus improves to -4 steps. Source: Player's Handbook p. 97.",
	},
	151: {
		1: "Can enhance an appropriate paired skill with a -1 step bonus when the GM agrees the Act performance applies. Source: Player's Handbook p. 99.",
		4: "Paired-skill enhancement improves to -2 steps, and Disguise becomes available as a complex Act check; observers suffer +1/+2/+3 step penalties on Ordinary/Good/Amazing disguises. Source: Player's Handbook p. 99.",
		8: "Paired-skill enhancement improves to -3 steps. Source: Player's Handbook p. 99.",
		12: "Paired-skill enhancement improves to -4 steps. Source: Player's Handbook p. 99.",
	},
	152: {
		1: "Can enhance an appropriate paired skill with a -1 step bonus when the GM agrees the Dance performance applies. Source: Player's Handbook p. 99.",
		4: "Paired-skill enhancement improves to -2 steps. Source: Player's Handbook p. 99.",
		8: "Paired-skill enhancement improves to -3 steps. Source: Player's Handbook p. 99.",
		12: "Paired-skill enhancement improves to -4 steps. Source: Player's Handbook p. 99.",
	},
	153: {
		1: "Can enhance an appropriate paired skill with a -1 step bonus when the GM agrees the Musical Instrument performance applies. Source: Player's Handbook p. 99.",
		4: "Paired-skill enhancement improves to -2 steps. Source: Player's Handbook p. 99.",
		8: "Paired-skill enhancement improves to -3 steps. Source: Player's Handbook p. 99.",
		12: "Paired-skill enhancement improves to -4 steps. Source: Player's Handbook p. 99.",
	},
	154: {
		1: "Can enhance an appropriate paired skill with a -1 step bonus when the GM agrees the Sing performance applies. Source: Player's Handbook p. 99.",
		4: "Paired-skill enhancement improves to -2 steps. Source: Player's Handbook p. 99.",
		8: "Paired-skill enhancement improves to -3 steps. Source: Player's Handbook p. 99.",
		12: "Paired-skill enhancement improves to -4 steps. Source: Player's Handbook p. 99.",
	},
	163: {
		4: "Leadership skill checks gain a -1 step bonus; Command and Inspire benefits do not stack with each other. Source: Player's Handbook p. 101.",
		8: "Leadership skill-check bonus improves to -2 steps; Command and Inspire benefits do not stack with each other. Source: Player's Handbook p. 101.",
		12: "Leadership skill-check bonus improves to -3 steps; Command and Inspire benefits do not stack with each other. Source: Player's Handbook p. 101.",
	},
	164: {
		4: "Leadership skill checks gain a -1 step bonus; Command and Inspire benefits do not stack with each other. Source: Player's Handbook p. 101.",
		8: "Leadership skill-check bonus improves to -2 steps; Command and Inspire benefits do not stack with each other. Source: Player's Handbook p. 101.",
		12: "Leadership skill-check bonus improves to -3 steps; Command and Inspire benefits do not stack with each other. Source: Player's Handbook p. 101.",
	},
	90003: {
		6: "Can heal mortal damage. Skill check results change to: Ordinary, 2 wounds; Good, 3 wounds or 1 mortal; Amazing, 4 wounds or 2 mortals. Source: Player's Handbook p. 229."
	},
	90004: {
		1: "Select one of these forms: Elongate fingers, adding one-half meter to reach. Elongate arms, adding 1 meter to reach. Elongate legs, adding 1 meter to height. Source: Player's Handbook p. 229-230.",
		3: "Select one of these forms: Elongate fingers, adding one-half meter to reach. Elongate arms, adding 1 meter to reach. Elongate legs, adding 1 meter to height. Source: Player's Handbook p. 229-230.",
		5: "Choose one of these forms: Disguise; alter one's facial features to hide identity (+2 penalty to Awareness checks involving an attempt to recognize the character). Elongate arms and legs simultaneously. Elongate entire body and alter bone construction to allow passage through small openings (as small as one-half meter wide). Source: Player's Handbook p. 229-230.",
		7: "Choose one of these forms: Disguise; alter one's facial features to hide identity (+2 penalty to Awareness checks involving an attempt to recognize the character). Elongate arms and legs simultaneously. Elongate entire body and alter bone construction to allow passage through small openings (as small as one-half meter wide). Source: Player's Handbook p. 229-230.",
		10: "Choose one of these forms: Improved disguise; alter facial and body features to hide identity (+4 penalty to Awareness checks). Lessen damage; body becomes so flexible and malleable as to reduce the effects of low impact damage. A skill check is made (at no psionic energy cost) to determine how much damage is reduced: Ordinary, d4; Good, d4+2; Amazing, d6+2. Note that this benefit isn't received if the character is wearing armor. Morph control; activate any two forms simultaneously. Source: Player's Handbook p. 229-230.",
		12: "Choose one of these forms: Improved disguise; alter facial and body features to hide identity (+4 penalty to Awareness checks). Lessen damage; body becomes so flexible and malleable as to reduce the effects of low impact damage. A skill check is made (at no psionic energy cost) to determine how much damage is reduced: Ordinary, d4; Good, d4+2; Amazing, d6+2. Note that this benefit isn't received if the character is wearing armor. Morph control; activate any two forms simultaneously. Source: Player's Handbook p. 229-230."
	},
	90104: {
		5: "Damage becomes d4+2s/d6+2s/d8+2s. Source: Player's Handbook p. 236.",
		9: "Damage caused by the skill goes to 2d4+2s/2d6+2s/2d8+2s. Source: Player's Handbook p. 236."
	},
	90106: {
		6: "Programmed Suggestion: can implant a suggestion that activates when the subject experiences a sensory cue (up to 1 hour, 1 day, or 1 month later depending on check result). Source: Dark*Matter p. 74."
	},
	90108: {
		4: "Greater Duration: need only expend psionic energy points once every 5 rounds (1 minute) to maintain the skill activation. Source: Dark*Matter p. 74.",
		8: "Selective Amnesia: can will onlookers to completely ignore specific aspects of a scene (a number of individuals equal to rank). Each receives an additional +2 penalty on Will feat check to recall. Source: Dark*Matter p. 74."
	},
	90109: {
		4: "Increased Mastery: victim's Resolve-mental resolve checks to break control suffer a +1 step penalty (+2 at rank 8, +3 at rank 12). Source: Dark*Matter p. 74.",
		6: "Greater Duration: duration between target's Resolve-mental resolve skill checks increases to 1 minute, 1 hour, and 1 day, respectively. Source: Dark*Matter p. 74.",
		8: "Increased Mastery: victim's mental resolve penalty improves to +2 steps. Source: Dark*Matter p. 74.",
		9: "Greater Duration: duration between target's Resolve-mental resolve skill checks increases to 1 hour, 1 day, and 1 week, respectively. Source: Dark*Matter p. 74.",
		12: "Increased Mastery: victim's mental resolve penalty improves to +3 steps. Source: Dark*Matter p. 74."
	},
	90201: {
		4: "Short Circuit: can disable an electronic device or security system by touch. Source: Dark*Matter p. 72.",
		5: "Damage becomes d6+2s/d4w/d4+2w. Source: Player's Handbook p. 233.",
		8: "System Override: can remotely operate powered machinery or electronic locks up to 16 meters away. Source: Dark*Matter p. 72.",
		9: "Damage caused by the skill goes to d4+2w/d6+2w/d8+2w. Source: Player's Handbook p. 233.",
		12: "Jamming: can jam electromagnetic signals within 20 meters (+20m per extra PEP) for 5 rounds. Source: Dark*Matter p. 72."
	},
	90206: {
		5: "Damage becomes d6+2w/d8+2w/d4m. Source: Player's Handbook p. 234.",
		9: "Damage caused by the skill goes to d8+2w/d4m/d4+2m. Source: Player's Handbook p. 234."
	},
	90306: {
		1: "Select one Navigation specialty (surface, system astrogation, or drivespace astrogation) to apply this mental ability. Source: Player's Handbook p. 232.",
		5: "A second Navigation specialty becomes available. Source: Player's Handbook p. 232.",
		9: "The remaining Navigation specialty becomes available. Source: Player's Handbook p. 232."
	},
	90311: {
		6: "Dowsing radius expands from 30 meters to 100 meters. Source: Dark*Matter p. 72.",
		9: "Dowsing radius expands to 1 kilometer. Source: Dark*Matter p. 72.",
		12: "Dowsing radius expands to 100 kilometers. Source: Dark*Matter p. 72."
	},
	68: {
		4: "Hidden Charges: an Amazing success applies a +1 step penalty to spot the concealed explosive (+1 step per tier above Amazing, up to +4 steps). Source: Player's Handbook p. 81.",
		6: "Structural Vulnerability: complex check of Good complexity upgrades blast damage by one grade (Ordinary to Good); Amazing upgrades by two grades. Source: Player's Handbook p. 81.",
	},
	131: {
		4: "Interrogation Resistance Override: the interrogator receives a -1 step bonus to bypass the target's passive Willpower resistance modifier. Source: Player's Handbook p. 93.",
		8: "Interrogation Resistance Override bonus improves to -2 steps. Source: Player's Handbook p. 93.",
		12: "Interrogation Resistance Override bonus reaches maximum of -3 steps. Source: Player's Handbook p. 93.",
	},
	149: {
		1: "Gambling Cheater Mechanics: Gamble checks receive a permanent -2 step bonus against untrained opponents, and a +2 step penalty against trained card-sharps of higher rank. Source: Player's Handbook p. 98.",
	},
}


const NON_FX_STRUCTURED_SECTIONS := {
	0: [
		{"kind": "text", "title": "Description", "body": "Armor that is bulky, heavy, and cumulative hinders the character using it. This is reflected as a step penalty to their Action Check Score and a lessening or complete negation of their Dexterity resistance modifier. The Armor Operation broad skill and its specialties help to alleviate these heavy combat penalties."},
		{"kind": "text", "title": "Specialty Skills", "body": "Combat Armor: Standard, non-powered combat armor suits (flak jackets, battle vests, assault gear).\nPowered Armor: Mechanically assisted, vacuum-sealed powered battle suits (body tanks, exo-armor). Untrained use prohibited."},
		{"kind": "text", "title": "Combat Profile", "body": "Defense / Protection Form: Negates bulk-related action check penalties and Dexterity resistance penalties. Passive stun-absorption shield active while wearing armor."},
	],
	1: [
		{"kind": "text", "title": "Description", "body": "Specializes in standard, non-powered combat armor suits (such as Flak jackets, battle vests, and assault gear)."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 1, "title": "Improved Operation", "body": "Reduces the action check and Dexterity resistance modifier penalty associated with combat armor by 1 step."},
			{"rank": 2, "title": "Shaking Off Stuns", "body": "Any stun damage inflicted upon the character is automatically reduced by 1 point while wearing combat armor."},
			{"rank": 4, "title": "Advanced Operation & Stun Resistance", "body": "Penalty reduction increases to 2 steps (making net benefit 3 steps when combined with broad skill). Stun damage reduction increases to 2 points."},
			{"rank": 6, "title": "Shaking Off Stuns", "body": "Stun damage reduction increases to 3 points while wearing combat armor."},
			{"rank": 7, "title": "Elite Operation", "body": "Penalty reduction increases to 3 steps (net 4-step reduction when combined with broad skill)."},
			{"rank": 8, "title": "Shaking Off Stuns", "body": "Stun damage reduction increases to 4 points while wearing combat armor."},
			{"rank": 10, "title": "Master Operation & Stun Resistance", "body": "Penalty reduction increases to 4 steps (net 5-step reduction when combined with broad skill). Stun damage reduction increases to 5 points."},
			{"rank": 12, "title": "Shaking Off Stuns", "body": "Stun damage reduction reaches maximum of 6 points while wearing combat armor."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Defense / Protection Form: Negates bulk-related action check penalties and Dexterity resistance penalties. Passive stun-absorption shield active while wearing combat armor."},
	],
	2: [
		{"kind": "text", "title": "Description", "body": "Specializes in mechanically assisted, vacuum-sealed powered battle suits (such as body tanks and powered exo-armor). Untrained use prohibited."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 1, "title": "Improved Operation", "body": "Reduces the action check and Dexterity resistance modifier penalty associated with powered armor by 1 step."},
			{"rank": 2, "title": "Shaking Off Stuns", "body": "Any stun damage inflicted upon the character is automatically reduced by 1 point while wearing powered armor."},
			{"rank": 4, "title": "Advanced Operation & Stun Resistance", "body": "Penalty reduction increases to 2 steps (making net benefit 3 steps when combined with broad skill). Stun damage reduction increases to 2 points."},
			{"rank": 6, "title": "Shaking Off Stuns", "body": "Stun damage reduction increases to 3 points while wearing powered armor."},
			{"rank": 7, "title": "Elite Operation", "body": "Penalty reduction increases to 3 steps (net 4-step reduction when combined with broad skill)."},
			{"rank": 8, "title": "Shaking Off Stuns", "body": "Stun damage reduction increases to 4 points while wearing powered armor."},
			{"rank": 10, "title": "Master Operation & Stun Resistance", "body": "Penalty reduction increases to 4 steps (net 5-step reduction when combined with broad skill). Stun damage reduction increases to 5 points."},
			{"rank": 12, "title": "Shaking Off Stuns", "body": "Stun damage reduction reaches maximum of 6 points while wearing powered armor."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Defense / Protection Form: Negates bulk-related action check penalties and Dexterity resistance penalties. Passive stun-absorption shield active while wearing powered armor."},
	],
	3: [
		{"kind": "text", "title": "Description", "body": "This broad skill represents physical conditioning, running speed, muscular coordination, and general athletic prowess. It resolves all physical feats of climbing, leaping, and throwing objects."},
		{"kind": "text", "title": "Specialty Skills", "body": "Climb: Escalating vertical surfaces, scaling walls, and ascending ropes.\nJump: Performing horizontal, vertical, or running leaps.\nThrow: Launching hand-thrown objects, grenades, and daggers accurately at range.\nAthletics-Specific: Focused on a single, player-defined sport or training regime."},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Hand-thrown weapon and grenade targeting engine using Table P20.\nUtility Form: High-impact physical navigation and obstacle traversal."},
	],
	4: [
		{"kind": "text", "title": "Description", "body": "Escalating vertical surfaces, scaling walls, and ascending ropes."},
		{"kind": "outcomes", "title": "Climber Mechanics", "ordinary": "Climbs 1 meter per phase.", "good": "Climbs 2 meters per phase.", "amazing": "Climbs 3 meters per phase."},
		{"kind": "text", "title": "Climb Fall Rule & Situation Modifiers", "body": "Critical Failure: The climber loses their grip and falls. They are entitled to a Dexterity feat check at a +1 step penalty to catch themselves; failure results in falling damage (Table P15).\n\nClimb Situation Modifiers (PHB p. 66):\n* Sheer surface: +3 steps\n* Icy or slippery surface: +2 steps\n* Darkness: +1 step\n* Wet surface: +1 step\n* Surface with some handholds and footholds: -1 step\n* Surface with many handholds and footholds: -2 steps\n* Minimal climbing gear (gloves & sturdy shoes): -1 step\n* Partial climbing gear: -2 steps\n* Full climbing gear: -3 steps"},
	],
	5: [
		{"kind": "text", "title": "Description", "body": "Performing horizontal, vertical, or running leaps."},
		{"kind": "text", "title": "Jump Distance Base Scale", "body": "Standing Jump Base: Ordinary = 1m | Good = 2m | Amazing = 3m.\nRunning Jump Base (Requires 4m run-up): Ordinary = 2m | Good = 4m | Amazing = 6m.\nVertical Jump Base: Ordinary = 1m | Good = 1.5m | Amazing = 2m.\nPole Vaulting: Using a vaulting pole adds a flat +2 meters to vertical leap checks. Having both Athletics-jump and Acrobatics broad skills adds a flat +1 meter to any vertical jump."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Running Jump Extension", "body": "Running jump distance improves by +1 meter (+1m total)."},
			{"rank": 4, "title": "Standing Jump Extension", "body": "Standing jump distance improves by +1 meter (+1m total)."},
			{"rank": 5, "title": "Vertical Jump Extension", "body": "Vertical jump distance improves by +0.5 meters (+0.5m total)."},
			{"rank": 6, "title": "Running Jump Extension", "body": "Running jump distance improves by an additional +1 meter (+2m total)."},
			{"rank": 7, "title": "Standing Jump Extension", "body": "Standing jump distance improves by an additional +1 meter (+2m total)."},
			{"rank": 8, "title": "Vertical Jump Extension", "body": "Vertical jump distance improves by an additional +0.5 meters (+1.0m total)."},
			{"rank": 9, "title": "Running Jump Extension", "body": "Running jump distance improves by an additional +1 meter (+3m total)."},
			{"rank": 10, "title": "Standing Jump Extension", "body": "Standing jump distance improves by an additional +1 meter (+3m total)."},
			{"rank": 11, "title": "Vertical Jump Extension", "body": "Vertical jump distance improves by an additional +0.5 meters (+1.5m total)."},
			{"rank": 12, "title": "Running Jump Extension", "body": "Running jump distance improves by an additional +1 meter (+4m total)."},
		]},
	],
	6: [
		{"kind": "text", "title": "Description", "body": "Launching hand-thrown objects, grenades, and daggers accurately at range."},
		{"kind": "text", "title": "Throw Accuracy Scaling (Table P20)", "body": "Short Range: Ordinary, Good, or Amazing successes hit the target exactly.\nMedium Range: Good or Amazing hits target; Ordinary misses by 2m; Failure misses by 4m.\nLong Range: Amazing hits target; Good misses by 2m; Ordinary misses by 4m; Failure misses by 6m."},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Hand-thrown weapon and grenade targeting engine using Table P20."},
	],
	11: [
		{"kind": "text", "title": "Description", "body": "Measures proficiency with close-combat weaponry, from basic wooden clubs to advanced monomolecular-edged swords and energy blades."},
		{"kind": "text", "title": "Specialty Skills", "body": "Blade: Edged and stabbing weapons (swords, daggers, axes, katanas).\nBludgeon: Blunt impact weapons (clubs, maces, quarterstaffs, flails).\nPowered Weapon: High-tech vibrating or energy-channeling weapons (chainswords, stun batons, star swords)."},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Hand-to-hand weapon combat rolls, applying Strength damage adjustments (Table P9).\nDefense Form: Active Reaction Parry at Rank 4, intercepting and deflecting physical attacks."},
	],
	12: [
		{"kind": "text", "title": "Description", "body": "Edged and stabbing weapons (swords, daggers, axes, katanas)."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Reaction Parry & Strength Resistance", "body": "Can actively attempt to parry incoming melee or unarmed attacks using next available phase action (parry roll must equal or exceed attacker's success tier to negate damage). Improves passive Strength resistance modifier by +1 for close-quarters defense."},
			{"rank": 6, "title": "Double-Strike", "body": "Can swing twice in a single action against one or two targets in close-combat range. First strike rolled with +1 step penalty situation die; second strike with +2 step penalty situation die."},
			{"rank": 8, "title": "Strength Resistance Modifier", "body": "Passive Strength resistance modifier bonus increases to +2 for close-quarters defense."},
			{"rank": 9, "title": "Multistrike", "body": "Can make three attacks in a single phase against a single target or up to three separate targets within 2 meters. Strike 1 has +1 step penalty; Strike 2 has +2 step penalty; Strike 3 has +3 step penalty."},
			{"rank": 12, "title": "Strength Resistance Modifier", "body": "Passive Strength resistance modifier bonus reaches maximum of +3 for close-quarters defense."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Close-quarters weapon strikes applying Strength damage adjustments (Table P9).\nDefense Form: Active Reaction Parry at Rank 4; passive close-quarters Strength resistance modifier bonus (+1 at Rank 4, +2 at Rank 8, +3 at Rank 12)."},
	],
	13: [
		{"kind": "text", "title": "Description", "body": "Blunt impact weapons (clubs, maces, quarterstaffs, flails)."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Reaction Parry & Strength Resistance", "body": "Can actively attempt to parry incoming melee or unarmed attacks using next available phase action (parry roll must equal or exceed attacker's success tier to negate damage). Improves passive Strength resistance modifier by +1 for close-quarters defense."},
			{"rank": 6, "title": "Double-Strike", "body": "Can swing twice in a single action against one or two targets in close-combat range. First strike rolled with +1 step penalty situation die; second strike with +2 step penalty situation die."},
			{"rank": 8, "title": "Strength Resistance Modifier", "body": "Passive Strength resistance modifier bonus increases to +2 for close-quarters defense."},
			{"rank": 9, "title": "Multistrike", "body": "Can make three attacks in a single phase against a single target or up to three separate targets within 2 meters. Strike 1 has +1 step penalty; Strike 2 has +2 step penalty; Strike 3 has +3 step penalty."},
			{"rank": 12, "title": "Strength Resistance Modifier", "body": "Passive Strength resistance modifier bonus reaches maximum of +3 for close-quarters defense."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Close-quarters weapon strikes applying Strength damage adjustments (Table P9).\nDefense Form: Active Reaction Parry at Rank 4; passive close-quarters Strength resistance modifier bonus (+1 at Rank 4, +2 at Rank 8, +3 at Rank 12)."},
	],
	14: [
		{"kind": "text", "title": "Description", "body": "High-tech vibrating or energy-channeling weapons (chainswords, stun batons, star swords)."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Reaction Parry & Strength Resistance", "body": "Can actively attempt to parry incoming melee or unarmed attacks using next available phase action (parry roll must equal or exceed attacker's success tier to negate damage). Improves passive Strength resistance modifier by +1 for close-quarters defense."},
			{"rank": 6, "title": "Double-Strike", "body": "Can swing twice in a single action against one or two targets in close-combat range. First strike rolled with +1 step penalty situation die; second strike with +2 step penalty situation die."},
			{"rank": 8, "title": "Strength Resistance Modifier", "body": "Passive Strength resistance modifier bonus increases to +2 for close-quarters defense."},
			{"rank": 9, "title": "Multistrike", "body": "Can make three attacks in a single phase against a single target or up to three separate targets within 2 meters. Strike 1 has +1 step penalty; Strike 2 has +2 step penalty; Strike 3 has +3 step penalty."},
			{"rank": 12, "title": "Strength Resistance Modifier", "body": "Passive Strength resistance modifier bonus reaches maximum of +3 for close-quarters defense."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Close-quarters weapon strikes applying Strength damage adjustments (Table P9).\nDefense Form: Active Reaction Parry at Rank 4; passive close-quarters Strength resistance modifier bonus (+1 at Rank 4, +2 at Rank 8, +3 at Rank 12)."},
	],
	15: [
		{"kind": "text", "title": "Description", "body": "Hand-to-hand combat without weapons. Base damage for an untrained unarmed strike is d4s / d4+1s / d4+2s (LI/O) plus the character's Strength damage adjustment."},
		{"kind": "text", "title": "Specialty Skills", "body": "Brawl: Rough-and-tumble street fighting, boxing, wrestling, and grappling.\nPower Martial Arts: Disciplined martial arts focusing on leverage, high-impact kicks, and bone-shattering strikes. Untrained use prohibited."},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Brawl and Power Martial Arts striking engine, capable of inducing knockouts on Amazing successes."},
	],
	16: [
		{"kind": "text", "title": "Description", "body": "Rough-and-tumble street fighting, boxing, wrestling, and grappling."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Knockout Surcharge", "body": "When rolling an Amazing success on an unarmed attack, forces a knockout recovery check; victim's Stamina-endurance check suffers a +1 step penalty."},
			{"rank": 8, "title": "Increased Base Damage & Knockout Surcharge", "body": "Base unarmed damage permanently increases to d6s / d6+2s / d4w (LI/O) plus Strength damage adjustment. Knockout penalty increases to +2 steps."},
			{"rank": 12, "title": "Knockout Surcharge", "body": "Knockout penalty reaches +3 steps on the victim's Stamina-endurance check."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Street fighting strikes with knockout surcharge on Amazing successes and increased base damage at Rank 8."},
	],
	17: [
		{"kind": "text", "title": "Description", "body": "Disciplined martial arts focusing on leverage, high-impact kicks, and bone-shattering strikes. Untrained use prohibited."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Knockout Surcharge", "body": "Forces a knockout recovery check on an Amazing success with a +1 step penalty to the victim's Stamina-endurance check."},
			{"rank": 4, "title": "Strength Resistance Modifier", "body": "Improves passive close-quarters Strength resistance modifier by +1."},
			{"rank": 5, "title": "No Hands", "body": "Can execute full-damage unarmed strikes even if hands are bound, handcuffed, or pinned behind the back."},
			{"rank": 6, "title": "Knockout Surcharge", "body": "Knockout penalty increases to +2 steps on the victim's Stamina-endurance check."},
			{"rank": 7, "title": "Increased Base Damage", "body": "Base unarmed damage permanently increases to d6+2s / d4w / d4+2w (LI/O) plus Strength damage adjustment."},
			{"rank": 8, "title": "Strength Resistance Modifier", "body": "Passive close-quarters Strength resistance modifier bonus increases to +2."},
			{"rank": 9, "title": "Knockout Surcharge", "body": "Knockout penalty increases to +3 steps on the victim's Stamina-endurance check."},
			{"rank": 12, "title": "Strength Resistance & Knockout Master", "body": "Passive close-quarters Strength resistance modifier reaches +3; knockout penalty reaches +4 steps."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: High-leverage strikes with knockout penalties, bound-hands striking at Rank 5, and lethal wound damage scaling at Rank 7.\nDefense Form: Passive close-quarters Strength resistance modifier bonus (+1 at Rank 4, +2 at Rank 8, +3 at Rank 12)."},
	],
	18: [
		{"kind": "text", "title": "Description", "body": "Measures agility, balance, gymnastics, and the ability to maneuver dynamically or dodge incoming projectiles."},
		{"kind": "text", "title": "Specialty Skills", "body": "Daredevil: Vaulting, diving, high-wire balance, and extreme physical stunt-work.\nDefensive Martial Arts: Soft-style martial arts (aikido, judo) focusing on throws, sweeps, and redirecting force. Untrained use prohibited.\nDodge: Ducking, weaving, and rolling to evade ranged and melee attacks.\nFall: Techniques to break falls and minimize impact damage.\nFlight: Aerial maneuvers for winged species or flight mutations.\nZero-G Training: Operating fluidly in weightless environments. Untrained use prohibited."},
		{"kind": "text", "title": "Combat Profile", "body": "Defense Form (Dodge / Block): Adds highly active evasion modes to avoid ranged bullets or block physical close-quarters strikes."},
	],
	20: [
		{"kind": "text", "title": "Description", "body": "Soft-style martial arts (aikido, judo) focusing on throws, sweeps, and redirecting an opponent's force to deal stun damage. Untrained use prohibited."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 2, "title": "Block", "body": "Can attempt to block unarmed strikes. Roll a defensive martial arts check; if success tier matches or beats attacker's, all damage is blocked."},
			{"rank": 4, "title": "Reaction Block & Strength Resistance", "body": "Can block unarmed attacks as a reaction, consuming next phase action. Improves passive Strength resistance modifier by +1 for close-quarters defense."},
			{"rank": 8, "title": "Strength Resistance Modifier", "body": "Passive Strength resistance modifier bonus increases to +2 for close-quarters defense."},
			{"rank": 12, "title": "Strength Resistance Modifier", "body": "Passive Strength resistance modifier bonus reaches maximum of +3 for close-quarters defense."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Defense Form: Active Block at Rank 2, Reaction Block at Rank 4, and passive close-quarters Strength resistance modifier bonus (+1 at Rank 4, +2 at Rank 8, +3 at Rank 12)."},
	],
	21: [
		{"kind": "text", "title": "Description", "body": "Ducking, weaving, and rolling to evade ranged and melee attacks."},
		{"kind": "outcomes", "title": "Dodge Mechanics (Active Round Defense)", "ordinary": "+1 step bonus to defender's Dexterity or Strength resistance modifier.", "good": "+2 steps bonus to resistance modifiers.", "amazing": "+3 steps bonus to resistance modifiers."},
		{"kind": "text", "title": "Dodge Execution & Action Tax", "body": "A character declares they are Dodging by spending an action. A single skill check is made at the start of the first phase the character acts, and the defensive step modifier applies to all subsequent phases in the round.\n* Critical Failure: -2 steps (The hero fumbles, making themselves easier to hit).\n* Failure: 0 steps (No effect).\n* The Action Tax: Any other action the dodging character attempts during the remainder of the round suffers a +1 step penalty due to constant weaving."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Action Dodge", "body": "Can initiate a dodge and perform a second physical action in the exact same phase. Secondary action suffers a +2 step penalty."},
			{"rank": 7, "title": "Reaction Dodge", "body": "Can declare a dodge as an immediate reaction before action check phase arrives. Locks the character into dodging for the entire round and consumes all other phase actions."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Defense Form: Active evasion against ranged and melee attacks, granting +1/+2/+3 step resistance modifiers on success."},
	],
	22: [
		{"kind": "text", "title": "Description", "body": "Techniques to break falls and minimize impact damage."},
		{"kind": "text", "title": "Fall Specialty Check", "body": "Adds the character's specialty rank directly to their Acrobatics score, allowing a Dexterity-based check with a +d0 situation die to negate impact damage from falling (Table P15)."},
	],
	30: [
		{"kind": "text", "title": "Description", "body": "Proficiency with modern personal firearms using chemical, magnetic, or rocket propulsion."},
		{"kind": "text", "title": "Specialty Skills", "body": "Pistol: Single-handed firearms.\nRifle: Two-handed shoulder-fired long guns.\nSMG: Compact automatic firearms."},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Primary firearm accuracy engines, utilizing firing modes (Single Fire, Burst, Autofire) and range modifier metrics (Table P22)."},
	],
	31: [
		{"kind": "text", "title": "Description", "body": "Single-handed firearms (semiautomatic pistols, heavy revolvers, machine pistols)."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Quick Draw", "body": "Can draw and fire the pistol in the exact same phase without suffering standard +1 step penalty for drawing mid-combat."},
			{"rank": 5, "title": "Distance Precision", "body": "Step penalty for firing at medium range is completely eliminated, and penalty for firing at long range is reduced by 1 step."},
			{"rank": 6, "title": "Double-Shot", "body": "Allows two pistol shots in one action; first shot uses +1 step penalty and second uses +2 step penalty."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Single-handed firearm combat with Quick Draw and medium-range penalty elimination."},
	],
	32: [
		{"kind": "text", "title": "Description", "body": "Two-handed shoulder-fired long guns (assault rifles, sniper rifles, battle rifles)."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Distance Precision & Improved Aim", "body": "Step penalty for firing at medium range is completely eliminated, and long-range penalty is reduced by 1 step. Improved Aim grants -1 step bonus to rifle attacks."},
			{"rank": 5, "title": "Autofire Precision", "body": "Reduces standard autofire situation penalties to a flat 0, +1 step, and +2 steps (rather than standard +1, +2, +3 steps)."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: High-precision shoulder-fired weapons with medium-range penalty negation and reduced autofire penalties."},
	],
	33: [
		{"kind": "text", "title": "Description", "body": "Compact automatic firearms designed for rapid bursts and close-quarters suppression."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Rock-n-Roll", "body": "Reloading a clip and firing in the same phase inflicts only a +1 step penalty (reduced from standard +2 step penalty)."},
			{"rank": 6, "title": "Autofire Precision", "body": "Reduces standard autofire situation penalties to a flat 0, +1 step, and +2 steps (rather than standard +1, +2, +3 steps)."},
			{"rank": 9, "title": "Extra Burst", "body": "Can walk an extra burst of ammunition on a single action, targeting up to four separate enemies. Receives a fourth situation die at a +3 step penalty and consumes one additional burst."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: High-speed automatic bursts with rapid reloading, tighter autofire grouping, and four-target walking bursts."},
	],
	52: [
		{"kind": "text", "title": "Description", "body": "Physical fortitude, pain tolerance, and biological endurance against fatigue, poisons, and environmental hazards."},
		{"kind": "text", "title": "Specialty Skills", "body": "Endurance: Performing grueling physical tasks over hours without succumbing to exhaustion.\nResist Pain: Overriding the debilitating physical penalties of wounds and shock. Untrained use prohibited."},
		{"kind": "text", "title": "Combat Profile", "body": "Defense / Passive Form: Provides systematic protection against pain penalties and exhaustion."},
	],
	53: [
		{"kind": "text", "title": "Description", "body": "Performing grueling physical tasks over hours without succumbing to exhaustion. Permanently replaces standard, flat Constitution checks with specialized Stamina-endurance score."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Breath Holding", "body": "Bonus to Stamina-endurance checks made while holding breath under water improves to -2 steps."},
			{"rank": 8, "title": "Breath Holding", "body": "Breath holding bonus improves to -3 steps."},
			{"rank": 12, "title": "Breath Holding", "body": "Breath holding bonus reaches maximum of -4 steps."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Defense Form: Replaces flat CON checks with skilled score and resists exhaustion/suffocation."},
	],
	54: [
		{"kind": "text", "title": "Description", "body": "Overriding the debilitating physical penalties of wounds and shock. Untrained use prohibited."},
		{"kind": "outcomes", "title": "Resist Pain Outcomes", "ordinary": "Ignores 1 step of damage penalty.", "good": "Ignores 2 steps of damage penalty.", "amazing": "Ignores 3 steps of damage penalty."},
		{"kind": "text", "title": "Resist Pain Execution & Rules", "body": "Trigger: When receiving damage equal to more than half maximum Stun or Wound points, or at least 1 point of Mortal damage, make an immediate Resist Pain check. Does not count as an action and takes place before any phase actions.\n* Critical Failure: The hero collapses in agony, becoming incapacitated and unable to act for 2d4 phases.\n* Failure: Suffers all damage step penalties normally.\n* Excess Reduction: Extra steps of cushion remain active to absorb further damage penalties suffered later in the scene (cannot grant a bonus)."},
	],
	61: [
		{"kind": "text", "title": "Description", "body": "Operating, designing, attacking, and securing computational networks, mainframes, and Grid architectures."},
		{"kind": "text", "title": "Specialty Skills", "body": "Hacking: Breaching access control, cracking encryption, evading intrusion detection, and electronic warfare. Untrained use prohibited.\nHardware: Physical computer components, storage media, fiber-optic pathways, and quantum processors.\nProgramming: Writing, debugging, decompiling, and modifying algorithmic code and software agents."},
		{"kind": "text", "title": "Combat Profile", "body": "Utility / Attack Form: Operating software defense barriers (Shields/Fortress) and executing digital attacks (Gridwipe/Attack programs) within virtual Grid environments."},
	],
	62: [
		{"kind": "text", "title": "Description", "body": "Breaching access control, cracking encryption, evading intrusion detection, and electronic warfare. Untrained use prohibited."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Hacking Step Bonus", "body": "Permanent -1 step bonus to all checks made to bypass security codes, breach file systems, or defeat hostiles in the Grid."},
			{"rank": 8, "title": "Hacking Step Bonus", "body": "Hacking step bonus improves to -2 steps."},
			{"rank": 12, "title": "Hacking Step Bonus", "body": "Hacking step bonus reaches maximum of -3 steps."},
		]},
	],
	63: [
		{"kind": "text", "title": "Description", "body": "Physical computer components, storage media, fiber-optic pathways, and quantum processors."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Hardware Step Bonus", "body": "Permanent -1 step bonus to all checks made to assemble, repair, or diagnose physical computing systems."},
			{"rank": 8, "title": "Hardware Step Bonus", "body": "Hardware step bonus improves to -2 steps."},
			{"rank": 12, "title": "Hardware Step Bonus", "body": "Hardware step bonus reaches maximum of -3 steps."},
		]},
	],
	64: [
		{"kind": "text", "title": "Description", "body": "Writing, debugging, decompiling, and modifying algorithmic code and software agents."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 1, "title": "Modify Ordinary Code", "body": "Can modify source code of Ordinary quality and Ordinary complexity."},
			{"rank": 3, "title": "Modify Good / Compile Marginal", "body": "Can modify existing programs of Good quality/complexity and compile new programs of Marginal quality/complexity."},
			{"rank": 6, "title": "Modify Any / Compile Ordinary", "body": "Can modify any existing software program and compile new Ordinary quality/complexity programs."},
			{"rank": 9, "title": "Compile Good Programs", "body": "Can compile new Good quality/complexity programs."},
			{"rank": 12, "title": "Compile Amazing Programs", "body": "Can compile new Amazing quality/complexity programs."},
		]},
	],
	65: [
		{"kind": "text", "title": "Description", "body": "Handling, fabricating, placing, and safely neutralizing chemical and energetic explosives."},
		{"kind": "text", "title": "Specialty Skills", "body": "Disarm: Safely disarming detonators, defusing mines, and disabling unexploded ordnance.\nScratch-built: Formulating explosive compounds from raw chemicals and improvised household materials. Untrained use prohibited.\nSet Explosives: Precision placement of commercial or military explosives to maximize directional blast damage and structural failure."},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Custom explosive design and high-impact structural breaching."},
	],
	67: [
		{"kind": "text", "title": "Description", "body": "Formulating explosive compounds from raw chemicals and improvised household materials. Untrained use prohibited."},
		{"kind": "outcomes", "title": "Scratch-Built Explosive Damage (Table P23)", "ordinary": "d4w / d4+1w / d4+2w (En/O)", "good": "d6w / d6+2w / d4m (En/O)", "amazing": "d8w / d8+2w / d6m (En/O)"},
	],
	68: [
		{"kind": "text", "title": "Description", "body": "Precision placement of commercial or military explosives to maximize directional blast damage and structural failure."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Hidden Charges", "body": "When concealing an explosive, an Amazing success applies a +1 step penalty to any opponent's active Awareness-perception or Investigate-search check to spot it (+1 step per success tier above Amazing, up to +4 steps max)."},
			{"rank": 6, "title": "Structural Vulnerability", "body": "Completing a complex check of Good complexity while setting explosives identifies a structural weak-point, upgrading blast damage by one success grade (Ordinary to Good). An Amazing success upgrades blast damage by two full grades."},
		]},
		{"kind": "text", "title": "Combat Profile", "body": "Attack Form: Precision demolition placement with concealed charges and structural damage amplification."},
	],
	85: [
		{"kind": "text", "title": "Description", "body": "Diagnosis, physiology, wound treatment, pathology, surgical intervention, and pharmacology."},
		{"kind": "text", "title": "Specialty Skills", "body": "Forensics: Post-mortem examination, ballistics matching, blood splatter analysis, and toxicological screening.\nMedical Knowledge: Non-surgical clinical medicine, disease pathology, pharmacology, and physiological diagnosis.\nSurgery: Invasive medical procedures to repair life-threatening trauma, organ damage, or install cybernetics. Untrained use prohibited.\nTreatment: Immediate field medicine, wound dressing, trauma stabilization, and critical life support. Untrained use prohibited."},
		{"kind": "text", "title": "Combat Profile", "body": "Healing Form: Active touch-based healing to restore lost Stun, Wound, and Mortal rating boxes."},
	],
	86: [
		{"kind": "text", "title": "Description", "body": "Post-mortem examination, ballistics matching, blood splatter analysis, and toxicological screening."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Forensics Synergy", "body": "Checks assisted by Forensics gain a -1 step bonus."},
			{"rank": 6, "title": "Forensics Synergy", "body": "Forensics-assisted bonus improves to -2 steps."},
			{"rank": 9, "title": "Forensics Synergy", "body": "Forensics-assisted bonus improves to -3 steps."},
			{"rank": 12, "title": "Forensics Synergy", "body": "Forensics-assisted bonus reaches maximum of -4 steps."},
		]},
	],
	87: [
		{"kind": "text", "title": "Description", "body": "Non-surgical clinical medicine, disease pathology, pharmacology, and physiological diagnosis."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 2, "title": "Treatment Support Synergy", "body": "Medical Science-treatment checks gain a -1 step bonus."},
			{"rank": 5, "title": "Treatment Support Synergy", "body": "Treatment-support bonus improves to -2 steps."},
			{"rank": 8, "title": "Treatment Support Synergy", "body": "Treatment-support bonus improves to -3 steps."},
			{"rank": 12, "title": "Treatment Support Synergy", "body": "Treatment-support bonus reaches maximum of -4 steps."},
		]},
	],
	89: [
		{"kind": "text", "title": "Description", "body": "Invasive medical procedures to repair life-threatening trauma, organ damage, or install cybernetics. Untrained use prohibited."},
		{"kind": "text", "title": "Surgery Success Resolution", "body": "Surgery requires a complex skill check of 8 successes plus 1 success per point of Mortal damage the patient has suffered. Surgeon makes one check per hour of surgery."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Cybernetic Surgery (Repair)", "body": "Can operate on and repair organisms with active cybertech implants when campaign includes cybertech."},
			{"rank": 6, "title": "Cybernetic Surgery (Installation)", "body": "Can perform surgical implant installations of new cybernetic devices when campaign includes cybertech."},
		]},
	],
	90: [
		{"kind": "text", "title": "Description", "body": "Immediate field medicine, wound dressing, trauma stabilization, and critical life support. Untrained use prohibited."},
		{"kind": "text", "title": "Treatment Situation Modifiers", "body": "* Sterile operating suite: -2 steps\n* Field hospital or infirmary: -1 step\n* Hostile combat zone / in vehicle: +1 step\n* Poor lighting / darkness: +1 step\n* Improvising medical supplies: +2 steps"},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Improved Treatment", "body": "Treatment situation penalties are reduced by 1 step (can eliminate penalties, but never create a bonus)."},
			{"rank": 6, "title": "Improved Treatment", "body": "Treatment penalty reduction improves to 2 steps."},
			{"rank": 9, "title": "Improved Treatment", "body": "Treatment penalty reduction improves to 3 steps."},
			{"rank": 12, "title": "Improved Treatment", "body": "Treatment penalty reduction reaches maximum of 4 steps."},
		]},
	],
	114: [
		{"kind": "text", "title": "Description", "body": "Applied physical engineering, electronics, mechanics, robotics, and structural maintenance."},
		{"kind": "text", "title": "Specialty Skills", "body": "Invention: Designing and constructing new technology.\nJuryrig: Improvising rapid field repairs with whatever materials are on hand.\nRepair: Proper maintenance, overhaul, and restoration of machinery, electronics, and vehicles.\nTechnical Knowledge: Theoretical engineering principles, blueprints, and schematic comprehension."},
		{"kind": "text", "title": "Combat Profile", "body": "Utility Form: Combat repairs, shield restoration, vehicle patching, and advanced xeno-tech analysis."},
	],
	116: [
		{"kind": "text", "title": "Description", "body": "Improvising rapid field repairs with whatever materials are on hand."},
		{"kind": "outcomes", "title": "Juryrig Repair Resolution Matrix", "ordinary": "Device operates at reduced efficiency (+1 step penalty) for 1d6 hours.", "good": "Device operates normally for 2d6 hours before needing proper repair.", "amazing": "Device operates normally for 1d6 days; subsequent proper repairs gain -1 step bonus."},
		{"kind": "text", "title": "Failure & Synergy Rules", "body": "Critical Failure: Device ruined permanently beyond all repair; components melt or fry.\nFailure: Repair fails; no further attempt possible for 1 hour.\nTechnical Science Synergy: Ranks in Technical Knowledge grant step bonuses to Juryrig checks."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 6, "title": "Improved Juryrig", "body": "The success matrix permanently upgrades: Ordinary produces Ordinary result; Good produces Amazing result; Amazing means item is considered fully repaired and in regular working order (no future repairs needed)."},
		]},
	],
	118: [
		{"kind": "text", "title": "Description", "body": "Theoretical engineering principles, blueprints, and schematic comprehension."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 3, "title": "Technical Science Support", "body": "Checks involving Technical Science or its specialties gain a -1 step bonus."},
			{"rank": 6, "title": "Technical Science Support", "body": "Technical Science support bonus improves to -2 steps."},
			{"rank": 9, "title": "Technical Science Support", "body": "Technical Science support bonus improves to -3 steps."},
			{"rank": 12, "title": "Technical Science Support", "body": "Technical Science support bonus reaches maximum of -4 steps."},
		]},
	],
	130: [
		{"kind": "text", "title": "Description", "body": "Systematic inquiry, clue analysis, interrogative questioning, and physical tracking."},
		{"kind": "text", "title": "Specialty Skills", "body": "Interrogate: Questioning persons of interest to elicit admissions, intelligence, or contradictions.\nSearch: Meticulously combing physical environments for concealed compartments, hidden clues, or tampering.\nTrack: Following footprints, tire treads, scent markers, or disturbed foliage across various terrains."},
		{"kind": "text", "title": "Combat Profile", "body": "Utility Form: Physical tracking, cryptanalysis, file recovery, and hidden compartment detection."},
	],
	131: [
		{"kind": "text", "title": "Description", "body": "Questioning persons of interest to elicit admissions, intelligence, or contradictions."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 4, "title": "Interrogation Resistance Override", "body": "Receives a -1 step bonus to bypass the target's passive Willpower resistance modifier."},
			{"rank": 8, "title": "Interrogation Resistance Override", "body": "Interrogation resistance bypass bonus improves to -2 steps."},
			{"rank": 12, "title": "Interrogation Resistance Override", "body": "Interrogation resistance bypass bonus reaches maximum of -3 steps."},
		]},
	],
	133: [
		{"kind": "text", "title": "Description", "body": "Following footprints, tire treads, scent markers, or disturbed foliage across various terrains."},
		{"kind": "text", "title": "Track Terrain Modifiers (Table P24)", "body": "* Terrain: Soft ground (mud/snow): -2 steps | Normal ground: 0 steps | Hard ground (rock/concrete): +2 steps\n* Age of Trail: 1 hour: 0 steps | 1 day: +1 step | 1 week: +2 steps | 1 month: +3 steps\n* Weather: Rain/Snow during passage: +2 steps | Wind: +1 step"},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 1, "title": "Terrain Specialization", "body": "When acquiring Track and at each new rank, select one terrain family (Forest, Desert, Mountain, Arctic, Jungle, Swamp, Ocean, Urban, Space Station, Starship). Tracking in selected terrain gains -1 step bonus; unselected terrain carries +1 step penalty."},
		]},
	],
	146: [
		{"kind": "text", "title": "Description", "body": "Subterfuge, misleading statements, bribery, imposture, and gaming."},
		{"kind": "text", "title": "Specialty Skills", "body": "Bluff: Convincing someone of something untrue -- a false identity, a false account, a phony reason for presence.\nBribe: Offering an inducement without it being refused or reported, and judging what a target wants.\nGamble: Games of chance and skill, understanding odds, spotting cheats, and reading table tells."},
		{"kind": "text", "title": "Combat Profile", "body": "Utility / Social Form: Active misdirection, table play manipulation, and attitude shifts."},
	],
	147: [
		{"kind": "text", "title": "Description", "body": "Convincing someone of something untrue -- a false identity, a false account, a phony reason for presence."},
		{"kind": "outcomes", "title": "Bluff Success Scale", "ordinary": "Target's attitude improves by 1 grade for d12+1 time units.", "good": "Target's attitude improves by 1 grade for d8+1 time units (highly cooperative).", "amazing": "Target's attitude improves by 2 grades for d12+2 time units."},
	],
	149: [
		{"kind": "text", "title": "Description", "body": "Games of chance and skill, understanding odds, spotting cheats, and reading table tells."},
		{"kind": "ranks", "title": "Specialty Rank Benefits", "entries": [
			{"rank": 1, "title": "Gambling Cheater Mechanics", "body": "Gamble checks receive a permanent -2 step bonus if playing against an untrained opponent, and a +2 step penalty if playing against a trained card-sharp of a higher specialty rank."},
		]},
	],
}


const SKILL_SOURCE_REFERENCES := {
	0: ["Player's Handbook p. 66."],
	1: ["Player's Handbook p. 66."],
	2: ["Player's Handbook p. 66."],
	3: ["Player's Handbook p. 66-67."],
	8: ["Player's Handbook p. 68."],
	11: ["Player's Handbook p. 68-69."],
	12: ["Player's Handbook p. 68-69."],
	13: ["Player's Handbook p. 68-69."],
	14: ["Player's Handbook p. 68-69."],
	15: ["Player's Handbook p. 69-70.", "Gamemaster Guide, overpowering rules."],
	16: ["Player's Handbook p. 69."],
	17: ["Player's Handbook p. 69-70."],
	18: ["Player's Handbook p. 70-72."],
	26: ["Player's Handbook p. 72-73."],
	30: ["Player's Handbook p. 73-75."],
	34: ["Player's Handbook p. 74-75."],
	39: ["Player's Handbook p. 75."],
	43: ["Player's Handbook p. 76."],
	48: ["Player's Handbook p. 76-77."],
	52: ["Player's Handbook p. 77-78."],
	55: ["Player's Handbook p. 78."],
	57: ["Player's Handbook p. 79-80."],
	61: ["Player's Handbook p. 80-81.", "Gamemaster Guide p. 124-125 for computer challenges."],
	65: ["Player's Handbook p. 81."],
	69: ["Player's Handbook p. 81-83."],
	75: ["Player's Handbook p. 83-84."],
	79: ["Player's Handbook p. 84-85."],
	85: ["Player's Handbook p. 85-87."],
	92: ["Player's Handbook p. 87-88."],
	96: ["Player's Handbook p. 88."],
	101: ["Player's Handbook p. 89."],
	104: ["Player's Handbook p. 88-89."],
	110: ["Player's Handbook p. 89."],
	114: ["Player's Handbook p. 89-90."],
	119: ["Player's Handbook p. 90-91."],
	122: ["Player's Handbook p. 91-92."],
	125: ["Player's Handbook p. 92-93."],
	128: ["Player's Handbook p. 93."],
	130: ["Player's Handbook p. 93-94."],
	134: ["Player's Handbook p. 94-95."],
	137: ["Player's Handbook p. 95-96."],
	140: ["Player's Handbook p. 96."],
	142: ["Player's Handbook p. 97-98."],
	146: ["Player's Handbook p. 98-99."],
	150: ["Player's Handbook p. 99-100."],
	155: ["Player's Handbook p. 100-101."],
	162: ["Player's Handbook p. 101."],
	900: ["Player's Handbook p. 229."],
	90001: ["Player's Handbook p. 229."],
	90002: ["Player's Handbook p. 229."],
	90003: ["Player's Handbook p. 229."],
	90004: ["Player's Handbook p. 229-230."],
	90005: ["Player's Handbook p. 230."],
	90006: ["Player's Handbook p. 230."],
	901: ["Player's Handbook p. 234."],
	90101: ["Player's Handbook p. 235."],
	90102: ["Player's Handbook p. 235."],
	90103: ["Player's Handbook p. 235-236."],
	90104: ["Player's Handbook p. 236."],
	90105: ["Player's Handbook p. 236."],
	90106: ["Player's Handbook p. 236."],
	90107: ["Player's Handbook p. 236."],
	902: ["Player's Handbook p. 233."],
	90201: ["Player's Handbook p. 233."],
	90202: ["Player's Handbook p. 233-234."],
	90203: ["Player's Handbook p. 234."],
	90204: ["Player's Handbook p. 234."],
	90205: ["Player's Handbook p. 234."],
	90206: ["Player's Handbook p. 234."],
	903: ["Player's Handbook p. 230."],
	90301: ["Player's Handbook p. 230."],
	90302: ["Player's Handbook p. 230."],
	90303: ["Player's Handbook p. 230-231."],
	90304: ["Player's Handbook p. 231."],
	90305: ["Player's Handbook p. 231-232."],
	90306: ["Player's Handbook p. 232."],
	90307: ["Player's Handbook p. 232."],
	90108: ["Dark Matter Campaign Setting p. 74."],
	90109: ["Dark Matter Campaign Setting p. 74."],
	90308: ["Player's Handbook p. 232."],
	90309: ["Player's Handbook p. 232."],
	90310: ["Player's Handbook p. 233."],
	90311: ["Dark Matter Campaign Setting p. 72."]
}


const PERK_DEFINITIONS := [
	{
		"id": "alien_artifact",
		"name": "Alien Artifact",
		"cost_options": [8],
		"ability": "Special",
		"activation": "Special",
		"summary": "A GM-designed alien item, experiment, or process gives the hero a useful benefit, but it is rare, coveted, and carries a downside.",
		"source": "Player's Handbook p. 103-104; Table P26.",
	},
	{
		"id": "ambidextrous",
		"name": "Ambidextrous",
		"cost_options": [4],
		"ability": "DEX",
		"activation": "Active",
		"summary": "Reduces off-hand or two-weapon penalties: the primary hand has no penalty and the off-hand action has a +2 step penalty.",
		"source": "Player's Handbook p. 103-104; Table P26.",
	},
	{
		"id": "animal_friend",
		"name": "Animal Friend",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Conscious",
		"summary": "Normal animals trust the hero. Animal encounter rolls gain a -2 step bonus, and Animal Handling checks gain a -1 step bonus.",
		"source": "Player's Handbook p. 104; Table P26.",
	},
	{
		"id": "celebrity",
		"name": "Celebrity",
		"cost_options": [3],
		"ability": "PER",
		"activation": "Conscious",
		"summary": "The hero is famous in an agreed circle. A perk check can modify Personality-based checks in a scene from a penalty on bad results to bonuses on success; the base check improves at achievement levels 5, 10, and 15.",
		"source": "Player's Handbook p. 104-105; Table P26.",
	},
	{
		"id": "concentration",
		"name": "Concentration",
		"cost_options": [3],
		"ability": "INT",
		"activation": "Conscious",
		"summary": "The hero spends an action concentrating on a stated next task. Success grants a -1, -2, or -3 step bonus; interruption loses the bonus.",
		"source": "Player's Handbook p. 105; Table P26.",
	},
	{
		"id": "danger_sense",
		"name": "Danger Sense",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Active",
		"summary": "The hero anticipates danger and receives a -2 step bonus to Awareness-intuition checks.",
		"source": "Player's Handbook p. 105; Table P26.",
	},
	{
		"id": "faith",
		"name": "Faith",
		"cost_options": [5],
		"ability": "WIL",
		"activation": "Conscious",
		"summary": "The hero has deep faith in a belief, power, nation, or similar tenet. A qualifying Faith check can improve the degree of success of a later skill check; repeated use in an adventure becomes harder.",
		"source": "Player's Handbook p. 105; Table P26.",
	},
	{
		"id": "filthy_rich",
		"name": "Filthy Rich",
		"cost_options": [6],
		"ability": "PER",
		"activation": "Conscious",
		"summary": "The hero starts wealthy and may gain access to funds with a perk check. Revealing status can modify Personality-based checks, but the GM can invert the effect where wealth is a liability.",
		"source": "Player's Handbook p. 105-106; Table P26.",
	},
	{
		"id": "fists_of_iron",
		"name": "Fists of Iron",
		"cost_options": [2, 5],
		"ability": "STR",
		"activation": "Active",
		"summary": "Adds +1 damage to successful Unarmed Attack checks. The 5-point improved version requires power martial arts and can increase damage further based on a perk check.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "fortitude",
		"name": "Fortitude",
		"cost_options": [4],
		"ability": "CON",
		"activation": "Active",
		"summary": "The hero receives a -1 step bonus to Stamina-endurance checks.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "good_luck",
		"name": "Good Luck",
		"cost_options": [3],
		"ability": "WIL",
		"activation": "Conscious",
		"summary": "Once per scene before another action, a Good Luck check modifies that next activity. Poor results can impose bad luck; better results grant bonuses.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "great_looks",
		"name": "Great Looks",
		"cost_options": [3],
		"ability": "PER",
		"activation": "Active",
		"summary": "When appearance helps an encounter, the hero gains a -1 step bonus to Personality-based skill checks, subject to GM and cultural context.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "heightened_ability",
		"name": "Heightened Ability",
		"cost_options": [10],
		"ability": "Special",
		"activation": "Active",
		"summary": "Raises one Ability Score by 1, without exceeding the species maximum; update derived values as needed.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "observant",
		"name": "Observant",
		"cost_options": [3],
		"ability": "WIL",
		"activation": "Active",
		"summary": "The hero gains a -1 step bonus to Awareness-perception checks.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "photo_memory",
		"name": "Photo Memory",
		"cost_options": [3],
		"ability": "INT",
		"activation": "Conscious",
		"summary": "A perk check can let the hero recall details such as names, faces, documents, or other remembered information; the GM sets the situation die.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "powerful_ally",
		"name": "Powerful Ally",
		"cost_options": [4],
		"ability": "PER",
		"activation": "Conscious",
		"summary": "The hero has an agreed ally. A perk check determines the quality of aid if the hero can contact the ally and the ally can respond.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "psionic_awareness",
		"name": "Psionic Awareness",
		"cost_options": [3],
		"ability": "INT",
		"activation": "Active",
		"summary": "If psionics are allowed, the hero may receive an Intelligence feat check to notice psionic power use nearby.",
		"source": "Player's Handbook p. 106; Table P26.",
	},
	{
		"id": "reflexes",
		"name": "Reflexes",
		"cost_options": [4],
		"ability": "DEX",
		"activation": "Active",
		"summary": "The hero's Dexterity resistance modifier improves by 1 step.",
		"source": "Player's Handbook p. 107; Table P26.",
	},
	{
		"id": "reputation",
		"name": "Reputation",
		"cost_options": [3],
		"ability": "WIL",
		"activation": "Active",
		"summary": "A known reputation can grant a situation die bonus to agreed encounter skills. The base check improves at achievement levels 5, 10, and 15.",
		"source": "Player's Handbook p. 107; Table P26.",
	},
	{
		"id": "tough_as_nails",
		"name": "Tough as Nails",
		"cost_options": [4],
		"ability": "STR",
		"activation": "Active",
		"summary": "The hero's Strength resistance modifier improves by 1 step.",
		"source": "Player's Handbook p. 107; Table P26.",
	},
	{
		"id": "vigor",
		"name": "Vigor",
		"cost_options": [2, 3, 4],
		"ability": "CON",
		"activation": "Active",
		"summary": "Raises a durability rating: 2 points for +1 stun, 3 points for +1 wound, or 4 points for +1 mortal and +1 fatigue. Each listed benefit can be bought once.",
		"source": "Player's Handbook p. 107; Table P26.",
	},
	{
		"id": "willpower",
		"name": "Willpower",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Active",
		"summary": "The hero's Will resistance modifier improves by 1 step.",
		"source": "Player's Handbook p. 108; Table P26.",
	},

	# Dark Matter Perks (Dark Matter Campaign Setting Chapter 3 p. 60-61, Table D2)
	{
		"id": "arcane_magic",
		"name": "Arcane Magic",
		"cost_options": [5],
		"ability": "INT",
		"activation": "Active",
		"setting": "Dark Matter",
		"summary": "The hero is an arcane FX talent and may buy a school of magic and its spells. Under standard Dark*Matter rules this perk is the path into arcane FX; a talent pays 1 skill point above the listed cost for every FX skill.",
		"source": "Dark Matter Campaign Setting, Chapter 3: Heroes of Dark Matter.",
	},
	{
		"id": "gearhead",
		"name": "Gearhead",
		"cost_options": [4],
		"ability": "PER",
		"activation": "Active",
		"setting": "Dark Matter",
		"summary": "Natural affinity with mechanical systems. Gains a -1 step bonus to all Technical Science-repair and juryrig skill checks.",
		"source": "Dark Matter Campaign Setting p. 60; Table D2.",
	},
	{
		"id": "hidden_identity",
		"name": "Hidden Identity",
		"cost_options": [3, 6],
		"ability": "PER",
		"activation": "Active",
		"setting": "Dark Matter",
		"summary": "Hidden or false identity. 3 SP: no database records, transactions in cash only (incompatible with Criminal Record). 6 SP: complete false identity.",
		"source": "Dark Matter Campaign Setting p. 60; Table D2.",
	},
	{
		"id": "high_tech",
		"name": "High Tech",
		"cost_options": [4],
		"ability": "Special",
		"activation": "Special",
		"setting": "Dark Matter",
		"summary": "The hero owns an object of advanced (PL 6) technology that functions normally until a Critical Failure damages it.",
		"source": "Dark Matter Campaign Setting p. 60; Table D2.",
	},
	{
		"id": "networked",
		"name": "Networked",
		"cost_options": [2],
		"ability": "PER",
		"activation": "Active",
		"setting": "Dark Matter",
		"summary": "The hero gains a -1 step bonus to the use of contacts or allegiances.",
		"source": "Dark Matter Campaign Setting p. 60; Table D2.",
	},
	{
		"id": "second_sight",
		"name": "Second Sight",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Conscious",
		"setting": "Dark Matter",
		"summary": "Allows the hero to see through illusions and visual trickery (psionic illusions, FX phantasms, holograms), granting a -1 step bonus on resistance checks or a Will feat check.",
		"source": "Dark Matter Campaign Setting p. 60; Table D2.",
	},
	{
		"id": "superior_talent",
		"name": "Superior Talent",
		"cost_options": [4, 6],
		"ability": "WIL",
		"activation": "Active",
		"setting": "Dark Matter",
		"summary": "For heroes with psionic talents. 4 SP: purchase 2 psionic broad skills and up to 2 specialty skills each. 6 SP: purchase up to 4 specialty skills of a single broad skill.",
		"source": "Dark Matter Campaign Setting p. 60; Table D2.",
	},
	{
		"id": "well_traveled",
		"name": "Well Traveled",
		"cost_options": [4],
		"ability": "PER",
		"activation": "Conscious",
		"setting": "Dark Matter",
		"summary": "The hero may make a perk check in remote or foreign locations to remember an acquaintance who can act as a contact (+1 step penalty to solicit help).",
		"source": "Dark Matter Campaign Setting p. 60-61; Table D2.",
	},

	# Beyond Science FX Perks (Beyond Science: A Guide to FX Chapter 1 p. 6, Table F1)
	{
		"id": "combat_master",
		"name": "Combat Master",
		"cost_options": [5],
		"ability": "Special",
		"activation": "Active",
		"supplement": "beyond_science",
		"summary": "Allows an FX hero to select combat specialty skills from Modern Ranged Weapons or Melee Weapons without taking the broad skill.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F1.",
	},
	{
		"id": "efficient_fx_energy",
		"name": "Efficient FX Energy",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Active",
		"supplement": "beyond_science",
		"summary": "Reduces the FX energy point cost of all FX powers by 1 (minimum 1 FX point).",
		"source": "Beyond Science: A Guide to FX p. 6; Table F1.",
	},
	{
		"id": "extended_fx_duration",
		"name": "Extended FX Duration",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Active",
		"supplement": "beyond_science",
		"summary": "Doubles the duration of all maintained or sustained FX powers.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F1.",
	},
	{
		"id": "fast_fx_recovery",
		"name": "Fast FX Recovery",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Active",
		"supplement": "beyond_science",
		"summary": "FX energy recovers at twice the normal rate: recovery checks every 30 minutes, or 4 hours of rest for full pool.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F1.",
	},
	{
		"id": "fx_resistance",
		"name": "FX Resistance",
		"cost_options": [3, 6, 9],
		"ability": "WIL",
		"activation": "Active",
		"supplement": "beyond_science",
		"summary": "Grants a +2 step bonus to resistance modifier against 1 (3 SP), 2 (6 SP), or 3 (9 SP) types of FX.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F1.",
	},
	{
		"id": "improved_fx_area",
		"name": "Improved FX Area",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Active",
		"supplement": "beyond_science",
		"summary": "Increases the area of effect of all area-affecting FX powers by 50%.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F1.",
	},
	{
		"id": "improved_fx_range",
		"name": "Improved FX Range",
		"cost_options": [4],
		"ability": "WIL",
		"activation": "Active",
		"supplement": "beyond_science",
		"summary": "Increases the range of all ranged FX powers by 50%.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F1.",
	},
	{
		"id": "increased_fx_energy",
		"name": "Increased FX Energy",
		"cost_options": [3, 6, 9],
		"ability": "WIL",
		"activation": "Active",
		"supplement": "beyond_science",
		"summary": "Increases the hero's FX energy pool by +2 (3 SP), +4 (6 SP), or +6 (9 SP) points.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F1.",
	},

	# Dataware Robot Perks (Dataware Chapter 6 p. 78, Table D21)
	{
		"id": "adaptive_programming",
		"name": "Adaptive Programming",
		"cost_options": [4],
		"ability": "INT",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "The robot can learn non-robotics skills at standard costs without cross-career penalties.",
		"source": "Dataware p. 78; Table D21.",
	},
	{
		"id": "composite_structure",
		"name": "Composite Structure",
		"cost_options": [3],
		"ability": "CON",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "Lightweight composite internal frame reduces chassis weight by 25% without sacrificing durability.",
		"source": "Dataware p. 78; Table D21.",
	},
	{
		"id": "environmental_shielding",
		"name": "Environmental Shielding",
		"cost_options": [4],
		"ability": "CON",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "Internal components are sealed against vacuum, radiation, corrosive atmospheres, and extreme temperatures.",
		"source": "Dataware p. 78; Table D21.",
	},
	{
		"id": "heavy_chassis",
		"name": "Heavy Chassis",
		"cost_options": [4],
		"ability": "CON",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "Reinforced heavy chassis adds +2 to wound and stun durability ratings.",
		"source": "Dataware p. 78; Table D21.",
	},
	{
		"id": "hidden_system",
		"name": "Hidden System",
		"cost_options": [2],
		"ability": "DEX",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "One weapon, tool, or sensor array is concealed within internal compartments (+2 step penalty for others to detect). Incompatible with Unarmored.",
		"source": "Dataware p. 78; Table D21.",
	},
	{
		"id": "modular_mounts",
		"name": "Modular Mounts",
		"cost_options": [3],
		"ability": "INT",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "Quick-swap modular sockets allow equipment and tools to be swapped in minutes rather than hours.",
		"source": "Dataware p. 78; Table D21.",
	},
	{
		"id": "overclocked",
		"name": "Overclocked",
		"cost_options": [4],
		"ability": "INT",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "Overclocked processors grant a -1 step bonus to initiative rolls and reaction checks.",
		"source": "Dataware p. 78; Table D21.",
	},
	{
		"id": "reinforced_casing",
		"name": "Reinforced Casing",
		"cost_options": [4],
		"ability": "CON",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "Adds +1 point of natural armor protection against ordinary damage types.",
		"source": "Dataware p. 78; Table D21.",
	},
	{
		"id": "self_repair",
		"name": "Self Repair",
		"cost_options": [4],
		"ability": "CON",
		"activation": "Active",
		"supplement": "dataware",
		"summary": "Internal nano-repair systems automatically restore 1 stun or wound point per hour of low-power rest.",
		"source": "Dataware p. 78; Table D21.",
	},
]

const FLAW_DEFINITIONS := [
	# Core Flaws (Player's Handbook Chapter 7 p. 108-111, Table P27; Gamemaster Guide Chapter 5 p. 82-88)
	{
		"id": "alien_artifact_flaw",
		"name": "Alien Artifact",
		"bonus_options": [5],
		"ability": "Special",
		"summary": "A GM-designed alien item, experiment, or process that is mostly a disadvantage, though it also has an unrelated positive side. Highly coveted and rare.",
		"source": "Player's Handbook p. 108-109, Table P27; Gamemaster Guide p. 83, 87, 164-175.",
	},
	{
		"id": "bad_luck",
		"name": "Bad Luck",
		"bonus_options": [6],
		"ability": "WIL",
		"summary": "The hero suffers a Critical Failure when the control die shows 19 or 20.",
		"source": "Player's Handbook p. 108, Table P27; Gamemaster Guide p. 83.",
	},
	{
		"id": "clueless",
		"name": "Clueless",
		"bonus_options": [2, 4, 6],
		"ability": "INT",
		"summary": "The GM secretly chooses a non-profession specialty skill the hero overestimates. The bonus option sets a +1, +2, or +3 step penalty to that skill.",
		"source": "Player's Handbook p. 108, Table P27; Gamemaster Guide p. 83-84.",
	},
	{
		"id": "clumsy",
		"name": "Clumsy",
		# Table P27 on p. 107 reads "Clumsy 5", between Clueless 2/4/6 and Code
		# of Honor 3. The catalog carried a spurious [5, 6] ladder; collapsing it
		# to one value was right, but the value is 5.
		"bonus_options": [5],
		"ability": "DEX",
		"summary": "The hero has poor coordination and an unsteady hand, taking a +1 step penalty to all Dexterity-based skill checks and Dexterity feat checks.",
		"source": "Player's Handbook p. 108, Table P27; Gamemaster Guide p. 84.",
	},
	{
		"id": "code_of_honor",
		"name": "Code of Honor",
		"bonus_options": [3],
		"ability": "WIL",
		"summary": "The hero follows a binding ethical code agreed with the GM with real restrictions and consequences. Achievement awards can be reduced if the flaw is not roleplayed.",
		"source": "Player's Handbook p. 108-109, Table P27; Gamemaster Guide p. 84, 87.",
	},
	{
		"id": "delicate",
		"name": "Delicate",
		"bonus_options": [3],
		"ability": "STR",
		"summary": "Successful Unarmed Attack checks inflict 1 stun on the hero. If current stun drops below half, the hero cannot use Unarmed Attack until recovering enough stun.",
		"source": "Player's Handbook p. 109, Table P27; Gamemaster Guide p. 84.",
	},
	{
		"id": "dirt_poor",
		"name": "Dirt Poor",
		"bonus_options": [5],
		"ability": "PER",
		"summary": "The hero begins play with only 1 die of starting funds (e.g. 1d6 for Combat Spec instead of 5d6), has a creditor or obligation set by the GM, and takes a +1 step penalty to Personality-based checks when dealing upward socially or financially.",
		"source": "Player's Handbook p. 109, Table P27, Table P30 p. 132; Gamemaster Guide p. 84, 87-88.",
	},
	{
		"id": "forgetful",
		"name": "Forgetful",
		"bonus_options": [5],
		"ability": "INT",
		"summary": "The hero has trouble recalling details and takes a +1 step penalty to all Intelligence-based skill checks.",
		"source": "Player's Handbook p. 109, Table P27; Gamemaster Guide p. 84, 88.",
	},
	{
		"id": "fragile",
		"name": "Fragile",
		"bonus_options": [3],
		"ability": "CON",
		"summary": "Damage hampers the hero, imposing a +1 step penalty to Stamina-endurance skill checks made as a result of damage suffered.",
		"source": "Player's Handbook p. 109, Table P27; Gamemaster Guide p. 84, 88.",
	},
	{
		"id": "infamy",
		"name": "Infamy",
		"bonus_options": [2, 4, 6],
		"ability": "PER",
		"summary": "The hero is publicly known for a minor (2 SP, +1 step), moderate (4 SP, +2 steps), or severe (6 SP, +3 steps) criminal or evil act, taking that penalty to Personality-based skill checks when recognized.",
		"source": "Player's Handbook p. 109, Table P27; Gamemaster Guide p. 84, 88.",
	},
	{
		"id": "oblivious",
		"name": "Oblivious",
		"bonus_options": [4],
		"ability": "WIL",
		"summary": "The hero has trouble noticing details and takes a +1 step penalty to Awareness-perception checks (and Investigate-search or track when perceptiveness plays a role).",
		"source": "Player's Handbook p. 109, Table P27; Gamemaster Guide p. 85, 88.",
	},
	{
		"id": "obsessed",
		"name": "Obsessed",
		"bonus_options": [2, 4, 6],
		"ability": "INT",
		"summary": "An agreed trigger distracts the hero. The bonus option sets a +1 (2 SP), +2 (4 SP), or +3 (6 SP) step penalty to actions not related to the obsession.",
		"source": "Player's Handbook p. 109, Table P27; Gamemaster Guide p. 85, 88.",
	},
	{
		"id": "old_injury",
		"name": "Old Injury",
		"bonus_options": [2, 4, 6],
		"ability": "STR",
		"summary": "An agreed physical trigger (run, jump, dodge, close-quarters attack) can flare once per scene: 1 wound (2 SP), 2 wound + 1 stun (4 SP), or 3 wound + 1 stun (6 SP). Armor does not reduce damage; removal requires a medical procedure.",
		"source": "Player's Handbook p. 109, Table P27; Gamemaster Guide p. 85, 88.",
	},
	{
		"id": "phobia",
		"name": "Phobia",
		"bonus_options": [2, 4, 6],
		"ability": "WIL",
		"summary": "An agreed broad irrational fear hampers the hero: +1 step penalty to all actions (2 SP), +2 step penalty (4 SP), or freezes/flees (6 SP) while in effect.",
		"source": "Player's Handbook p. 109-110, Table P27; Gamemaster Guide p. 85, 88.",
	},
	{
		"id": "poor_looks",
		"name": "Poor Looks",
		"bonus_options": [3],
		"ability": "PER",
		"summary": "When appearance hurts an encounter, the hero takes a +1 step penalty to Personality-based skill checks, subject to GM and cultural context.",
		"source": "Player's Handbook p. 110, Table P27; Gamemaster Guide p. 85, 88.",
	},
	{
		"id": "powerful_enemy",
		"name": "Powerful Enemy",
		"bonus_options": [2, 4, 6],
		"ability": "PER",
		"summary": "The hero has a far-reaching enemy (minor 2 SP, moderate 4 SP, truly powerful 6 SP). The bonus option determines how often, how broadly, and through what subordinates the enemy affects the hero.",
		"source": "Player's Handbook p. 110, Table P27; Gamemaster Guide p. 85, 88.",
	},
	{
		"id": "primitive",
		"name": "Primitive",
		"bonus_options": [2, 4, 6],
		"ability": "INT",
		"summary": "The hero struggles with modern technology of higher Progress Levels, taking a +1 (2 SP), +2 (4 SP), or +3 (6 SP) step penalty when using it, with awe/terror for d4+1 time units on unseen wonders at 6 SP.",
		"source": "Player's Handbook p. 110, Table P27; Gamemaster Guide p. 86, 88.",
	},
	{
		"id": "slow",
		"name": "Slow",
		"bonus_options": [6],
		"ability": "DEX",
		"summary": "The hero has reduced reaction time and takes a +1 step penalty to action checks (and a +2 step penalty in contests of pure reaction time).",
		"source": "Player's Handbook p. 110, Table P27; Gamemaster Guide p. 86.",
	},
	{
		"id": "spineless",
		"name": "Spineless",
		"bonus_options": [2, 4, 6],
		"ability": "WIL",
		"summary": "The hero's Will resistance modifier is reduced by 1, 2, or 3 steps based on the selected bonus option, and takes a +1, +2, or +3 step penalty to Resolve-mental resolve checks regarding character or courage.",
		"source": "Player's Handbook p. 110, Table P27; Gamemaster Guide p. 86.",
	},
	{
		"id": "temper",
		"name": "Temper",
		"bonus_options": [2, 4, 6],
		"ability": "WIL",
		"summary": "An agreed trigger sets off the hero: gruff/mean +1 step penalty (2 SP), unthinking +2 step penalty (4 SP), or berserk rage +3 step penalty (6 SP) to actions until calm.",
		"source": "Player's Handbook p. 110, Table P27; Gamemaster Guide p. 86, 88.",
	},

	# Dark Matter Flaws (Dark Matter Campaign Setting Chapter 3 p. 61-62, Table D3)
	{
		"id": "abductee",
		"name": "Abductee",
		"bonus_options": [4],
		"ability": "CON",
		"setting": "Dark Matter",
		"summary": "The hero was abducted by aliens and subjected to tests. In the presence of the abductor alien species, must make a Resolve-mental resolve check each round to declare fight (attacks d4 rounds) or flight (flees d12 rounds, suffering 1 fatigue); on a Critical Failure, disappears for d4 days or battles to death.",
		"source": "Dark Matter Campaign Setting p. 61; Table D3.",
	},
	{
		"id": "criminal_record",
		"name": "Criminal Record",
		"bonus_options": [4],
		"ability": "PER",
		"setting": "Dark Matter",
		"summary": "The hero has a felony conviction on file with all law enforcement agencies. Distrusted, difficult to gain employment, activities and fingerprints tracked. Incompatible with Hidden Identity (3 pt).",
		"source": "Dark Matter Campaign Setting p. 61; Table D3.",
	},
	{
		"id": "dilettante",
		"name": "Dilettante",
		"bonus_options": [5],
		"ability": "WIL",
		"setting": "Dark Matter",
		"summary": "The hero may not have any skill rank greater than his current achievement level, nor purchase rank benefits early.",
		"source": "Dark Matter Campaign Setting p. 61; Table D3.",
	},
	{
		"id": "divided_loyalty",
		"name": "Divided Loyalty",
		"bonus_options": [4],
		"ability": "PER",
		"setting": "Dark Matter",
		"summary": "The hero owes deep loyalty to an outside organization, conspiracy, or person, and must place that loyalty ahead of other obligations when the GM triggers it.",
		"source": "Dark Matter Campaign Setting p. 61-62; Table D3.",
	},
	{
		"id": "illiterate",
		"name": "Illiterate",
		"bonus_options": [5],
		"ability": "INT",
		"setting": "Dark Matter",
		"summary": "The hero cannot read or write. Cannot purchase or use untrained any skills requiring literacy (Business, Investigate-research, Science skills) or read text/screens.",
		"source": "Dark Matter Campaign Setting p. 62; Table D3.",
	},
	{
		"id": "implants",
		"name": "Implants",
		"bonus_options": [2],
		"ability": "CON",
		"setting": "Dark Matter",
		"summary": "The hero is tracked by an implanted device in the spine or a major artery with an explosive failsafe, allowing enemies to monitor location and health.",
		"source": "Dark Matter Campaign Setting p. 62; Table D3.",
	},
	{
		"id": "possessed",
		"name": "Possessed",
		"bonus_options": [4, 8],
		"ability": "WIL",
		"setting": "Dark Matter",
		"summary": "The hero is host to a spirit entity (+4 SP neutral/harmless, +8 SP hostile). Whenever rendered unconscious (loss of stun/fatigue) or failing Stamina-endurance from Amazing damage, the spirit seizes control under GM direction. Exorcised or daily Resolve check to regain control.",
		"source": "Dark Matter Campaign Setting p. 62; Table D3.",
	},
	{
		"id": "rampant_paranoia",
		"name": "Rampant Paranoia",
		"bonus_options": [2],
		"ability": "PER",
		"setting": "Dark Matter",
		"summary": "Persecution complex. Must make a Personality feat check when trusting someone; failure imposes a +1 step penalty to all actions for d6 hours; Critical Failure induces a delusional state until a successful daily Resolve-mental resolve check.",
		"source": "Dark Matter Campaign Setting p. 62; Table D3.",
	},
	{
		"id": "rebellious",
		"name": "Rebellious",
		"bonus_options": [2],
		"ability": "PER",
		"setting": "Dark Matter",
		"summary": "The hero takes a +2 step penalty to Personality-based skill checks when dealing with law enforcement or government agencies.",
		"source": "Dark Matter Campaign Setting p. 62; Table D3.",
	},
	{
		"id": "wild_talent",
		"name": "Wild Talent",
		"bonus_options": [6],
		"ability": "WIL",
		"setting": "Dark Matter",
		"summary": "For heroes with psionic talents. The hero has limited control: if dazed or failing Stamina-endurance or any Resolve check, must make a Will feat check or psionic power erupts uncontrollably for d4 phases, losing 1 psionic energy point per phase.",
		"source": "Dark Matter Campaign Setting p. 62; Table D3.",
	},

	# Beyond Science FX Flaws (Beyond Science: A Guide to FX Chapter 1 p. 6-7, Table F2)
	{
		"id": "fixed_fx_recovery",
		"name": "Fixed FX Recovery",
		"bonus_options": [3],
		"ability": "WIL",
		"supplement": "beyond_science",
		"summary": "The hero cannot regain FX energy on an hourly basis. Instead, all FX energy points return once per day at a specific chosen time.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F2.",
	},
	{
		"id": "inhibited_fx_recovery",
		"name": "Inhibited FX Recovery",
		"bonus_options": [1, 3, 5],
		"ability": "WIL",
		"supplement": "beyond_science",
		"summary": "Sensitive to a material within 100 meters (1 SP rare, 3 SP uncommon, 5 SP common), preventing all FX energy recovery while in its presence.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F2.",
	},
	{
		"id": "fx_require_recharging",
		"name": "FX Require Recharging",
		"bonus_options": [5],
		"ability": "WIL",
		"supplement": "beyond_science",
		"summary": "FX energy does not recover naturally. Only a specific daily ritual, event, or power source (taking 1 minute to 1 hour) restores the FX energy pool.",
		"source": "Beyond Science: A Guide to FX p. 6; Table F2.",
	},
	{
		"id": "fx_susceptibility",
		"name": "FX Susceptibility",
		"bonus_options": [3, 6, 9],
		"ability": "WIL",
		"supplement": "beyond_science",
		"summary": "Vulnerable to FX powers. Grants a -2 step penalty to resistance modifier against 1 (3 SP), 2 (6 SP), or 3 (9 SP) types of FX (Arcane Magic, Faith, Super Power).",
		"source": "Beyond Science: A Guide to FX p. 7; Table F2.",
	},
	{
		"id": "slow_fx_energy_recovery",
		"name": "Slow FX Energy Recovery",
		"bonus_options": [5],
		"ability": "WIL",
		"supplement": "beyond_science",
		"summary": "FX energy recovers at half normal rate: recovery rolls occur every 2 hours instead of 1 hour, and 16 hours of rest are required for full pool recovery.",
		"source": "Beyond Science: A Guide to FX p. 7; Table F2.",
	},

	# Dataware Robot Flaws (Dataware Chapter 6 p. 79-81, Table D22)
	{
		"id": "asimov_circuits",
		"name": "Asimov Circuits",
		"bonus_options": [3],
		"ability": "WIL",
		"supplement": "dataware",
		"summary": "The robot must prioritize the survival of its creator species and cannot use lethal force or permit villains of that species to come to harm through inaction.",
		"source": "Dataware p. 79; Table D22.",
	},
	{
		"id": "command_circuitry",
		"name": "Command Circuitry",
		"bonus_options": [4],
		"ability": "WIL",
		"supplement": "dataware",
		"summary": "Anyone with a comm link, operating frequency, and passcodes can issue orders the robot cannot disobey unless self-destructive.",
		"source": "Dataware p. 79; Table D22.",
	},
	{
		"id": "doublespeak",
		"name": "Doublespeak",
		"bonus_options": [2],
		"ability": "PER",
		"supplement": "dataware",
		"summary": "The robot repeats words or phrases in speech, taking a +1 step penalty to all Personality skill checks and feats. On Critical Failure, stutters or repeats last action.",
		"source": "Dataware p. 79; Table D22.",
	},
	{
		"id": "honesty",
		"name": "Honesty",
		"bonus_options": [2],
		"ability": "PER",
		"supplement": "dataware",
		"summary": "The robot cannot lie and is compelled to state embarrassing truths on failed Personality checks. A Will feat is required to lie; Critical Failure causes a processor overload knockout.",
		"source": "Dataware p. 79; Table D22.",
	},
	{
		"id": "incomplete_coding",
		"name": "Incomplete Coding",
		"bonus_options": [2, 4],
		"ability": "INT",
		"supplement": "dataware",
		"summary": "Faulty code. 2 SP: Marginal results lose action for clarification, Critical Failure enters loop until Will check or repair. 4 SP: Marginal executes wrong harmless action, Critical Failure executes wrong harmful action.",
		"source": "Dataware p. 79-80; Table D22.",
	},
	{
		"id": "inferior_tech",
		"name": "Inferior Tech",
		"bonus_options": [4],
		"ability": "CON",
		"supplement": "dataware",
		"summary": "The robot has a fatigue rating like biological heroes. A Critical Failure on any STR, DEX, or CON skill check inflicts 1 fatigue point.",
		"source": "Dataware p. 80; Table D22.",
	},
	{
		"id": "memory_lapse",
		"name": "Memory Lapse",
		"bonus_options": [5],
		"ability": "INT",
		"supplement": "dataware",
		"summary": "Faulty memory processors impose a +1 step penalty to all Intelligence-based skill checks.",
		"source": "Dataware p. 80; Table D22.",
	},
	{
		"id": "overheat",
		"name": "Overheat",
		"bonus_options": [6],
		"ability": "CON",
		"supplement": "dataware",
		"summary": "Conditions that would cause human fatigue require a Stamina-endurance check; failure causes processor overheating and emergency shutdown knockout.",
		"source": "Dataware p. 80; Table D22.",
	},
	{
		"id": "secret_orders",
		"name": "Secret Orders",
		"bonus_options": [3],
		"ability": "WIL",
		"supplement": "dataware",
		"summary": "Hidden hardcoded instructions override all other commands (including Asimov circuits and command bolts) when triggered.",
		"source": "Dataware p. 80; Table D22.",
	},
	{
		"id": "short_circuit",
		"name": "Short Circuit",
		"bonus_options": [4],
		"ability": "INT",
		"supplement": "dataware",
		"summary": "A core processor short circuit inflicts 2 stun damage on any Critical Failure, and drains battery power at 1.5x normal rate.",
		"source": "Dataware p. 80; Table D22.",
	},
	{
		"id": "unarmored",
		"name": "Unarmored",
		"bonus_options": [2],
		"ability": "CON",
		"supplement": "dataware",
		"summary": "Chassis is uncovered with no protective casing. Suffers full combat damage, hazard step penalties, and cannot take the Hidden System perk.",
		"source": "Dataware p. 81; Table D22.",
	},
]

const PROFESSION_DEFINITIONS := [
	{
		"id": 0,
		"name": "Combat Spec",
		"code": "C",
		"secondary_code": "",
		"action_bonus": 3,
		"last_resort_bonus": 0,
		"ability_minimums": {
			"STR": 11,
			"DEX": 9,
			"CON": 9,
		},
		"notes": [
			"Combat Specs rely on physical power and endurance to supplement their training in battle techniques. These warriors are walking arsenals who employ both technology and their own bodies as weapons. Source: Player's Handbook p. 30.",
			"Action Check Score Increase: action check score increased by 3. Source: Player's Handbook p. 30.",
			"Situation Bonus: choose one specialty skill under Armor Operation, Unarmed Attack, Heavy Weapons, Modern Ranged Weapons, Melee Weapons, or Primitive Ranged Weapons; its base situation die improves from +d0 to -d4. Source: Player's Handbook p. 30.",
			"Profession requirements: STR 11, DEX 9, CON 9. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 1,
		"name": "Diplomat (Combat Spec)",
		"code": "D",
		"secondary_code": "C",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {
			"WIL": 9,
			"PER": 11,
			"INT": 9,
		},
		"notes": [
			"Diplomats are negotiators, political figures, managers, deal-makers, and any others who use interaction skills and personal resolve to accomplish their jobs. They specialize in getting things done through bargaining, heated discussion, and even guile. Source: Player's Handbook p. 31.",
			"Action Check Score Increase: action check score increased by 1. Source: Player's Handbook p. 31.",
			"Contacts or Resources: a Diplomat starts with contacts or resources as described in the Gamemaster Guide; the Gamemaster informs you of the details. Source: Player's Handbook p. 31.",
			"Secondary Profession (Combat Spec): purchase skills from the secondary profession for list price -1 instead of list price. Source: Player's Handbook p. 31.",
			"Profession requirements: PER 11, WIL 9, INT 9. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 2,
		"name": "Diplomat (Free Agent)",
		"code": "D",
		"secondary_code": "F",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {
			"WIL": 9,
			"PER": 11,
			"INT": 9,
		},
		"notes": [
			"Diplomats are negotiators, political figures, managers, deal-makers, and any others who use interaction skills and personal resolve to accomplish their jobs. They specialize in getting things done through bargaining, heated discussion, and even guile. Source: Player's Handbook p. 31.",
			"Action Check Score Increase: action check score increased by 1. Source: Player's Handbook p. 31.",
			"Contacts or Resources: a Diplomat starts with contacts or resources as described in the Gamemaster Guide; the Gamemaster informs you of the details. Source: Player's Handbook p. 31.",
			"Secondary Profession (Free Agent): purchase skills from the secondary profession for list price -1 instead of list price. Source: Player's Handbook p. 31.",
			"Profession requirements: PER 11, WIL 9, INT 9. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 3,
		"name": "Diplomat (Tech Op)",
		"code": "D",
		"secondary_code": "T",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {
			"WIL": 9,
			"PER": 11,
			"INT": 9,
		},
		"notes": [
			"Diplomats are negotiators, political figures, managers, deal-makers, and any others who use interaction skills and personal resolve to accomplish their jobs. They specialize in getting things done through bargaining, heated discussion, and even guile. Source: Player's Handbook p. 31.",
			"Action Check Score Increase: action check score increased by 1. Source: Player's Handbook p. 31.",
			"Contacts or Resources: a Diplomat starts with contacts or resources as described in the Gamemaster Guide; the Gamemaster informs you of the details. Source: Player's Handbook p. 31.",
			"Secondary Profession (Tech Op): purchase skills from the secondary profession for list price -1 instead of list price. Source: Player's Handbook p. 31.",
			"Profession requirements: PER 11, WIL 9, INT 9. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 7,
		"name": "Diplomat (Mindwalker)",
		"code": "D",
		"secondary_code": "M",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {
			"WIL": 9,
			"PER": 11,
			"INT": 9,
		},
		"notes": [
			"Diplomats are negotiators, political figures, managers, deal-makers, and any others who use interaction skills and personal resolve to accomplish their jobs. They specialize in getting things done through bargaining, heated discussion, and even guile. Source: Player's Handbook p. 31.",
			"Action Check Score Increase: action check score increased by 1. Source: Player's Handbook p. 31.",
			"Contacts or Resources: a Diplomat starts with contacts or resources as described in the Gamemaster Guide; the Gamemaster informs you of the details. Source: Player's Handbook p. 31.",
			"Secondary Profession (Mindwalker): purchase skills from the secondary profession for list price -1 instead of list price. Diplomats in a campaign that allows Mindwalkers can use that profession as their secondary profession. Source: Player's Handbook p. 31 and p. 227.",
			"Gains access to psionic broad skills and uses full WIL for psionic energy points instead of one-half WIL. Source: Player's Handbook p. 22 and Chapter 14.",
			"Profession requirements: PER 11, WIL 9, INT 9. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 4,
		"name": "Free Agent",
		"code": "F",
		"secondary_code": "",
		"action_bonus": 2,
		"last_resort_bonus": 1,
		"ability_minimums": {
			"DEX": 11,
			"INT": 9,
			"WIL": 9,
		},
		"notes": [
			"Free Agents are troubleshooters or field operatives who rely on agility, intuition, and their natural resolve to get a job done. They may have ties to a specific government or organization, but they work better alone or in small groups. Source: Player's Handbook p. 31.",
			"Action Check Score Increase: action check score increased by 2. Source: Player's Handbook p. 31.",
			"Resistance Bonus: choose one ability and improve its resistance modifier by 1 step (Constitution has no resistance modifier). Source: Player's Handbook p. 31-32.",
			"Last Resort Bonus: maximum last resort points increased by 1, and a Free Agent can spend 2 last resort points to alter an action instead of the usual 1. Source: Player's Handbook p. 31.",
			"Profession requirements: DEX 11, INT 9, WIL 9. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 5,
		"name": "Tech Op",
		"code": "T",
		"secondary_code": "",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {
			"INT": 11,
			"DEX": 9,
			"CON": 9,
		},
		"notes": [
			"Tech Ops are operatives accomplished in the use of high-tech equipment or specialists trained to create or maintain high-tech equipment. They rely on natural genius, agility, and expert training, as well as the benefits of their technological devices. Source: Player's Handbook p. 32.",
			"Action Check Score Increase: action check score increased by 1. Source: Player's Handbook p. 32.",
			"Accelerated Learning: at every new achievement level a Tech Op receives the usual skill points plus extra points by level attained: +1 at levels 2-5, +2 at 6-10, +3 at 11-15, +4 at 16-20, +5 at 21+. Source: Player's Handbook p. 32.",
			"Profession requirements: INT 11, DEX 9, CON 9. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 6,
		"name": "Mindwalker",
		"code": "M",
		"secondary_code": "",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {
			"WIL": 11,
			"INT": 9,
			"CON": 9,
		},
		"notes": [
			"Mindwalkers are a select group of characters who are gifted with great mental powers and trained to use them. These individuals may be extremely rare, depending on the setting, and some may be trained in a particular tradition. Source: Player's Handbook p. 227.",
			"Action Check Score Increase: action check score increased by 1. Source: Player's Handbook p. 227.",
			"Situation Bonus: choose one psionic broad skill; that broad skill and all of its specialty skills receive a situation die improvement of 1 step (broad skill +d0, specialties -d4). Source: Player's Handbook p. 227.",
			"Profession requirements: WIL 11, INT 9, CON 9. Source: Player's Handbook Table P1 p. 30 and p. 227.",
		],
	},
	{
		"id": 8,
		"name": "Diplomat (Adept)",
		"code": "D",
		"secondary_code": "A",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {"WIL": 9, "PER": 11, "INT": 9},
		"supplement": "beyond_science",
		"adept_role": "secondary",
		"advancement_profile": "diplomat",
		"notes": [
			"A Diplomat who studies a single FX tradition as a secondary profession. Source: Beyond Science: A Guide to FX p. 6.",
			"Action Check Score Increase: action check score increased by 1. Source: Player's Handbook p. 31.",
			"Contacts or Resources: a Diplomat starts with contacts or resources as described in the Gamemaster Guide. Source: Player's Handbook p. 31.",
			"Secondary Profession (Adept): choose one FX broad skill; that broad skill and all its specialty skills cost list price -1. The hero has a Talent-sized FX energy pool rather than a primary Adept's full pool. Source: Beyond Science: A Guide to FX p. 6.",
			"Profession requirements: PER 11, WIL 9, INT 9. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 9,
		"name": "Adept (Combat Spec)",
		"code": "A",
		"secondary_code": "C",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {"STR": 11, "DEX": 9, "CON": 9},
		"supplement": "beyond_science",
		"adept_role": "primary",
		"advancement_profile": "combat_spec",
		"notes": [
			"A dedicated FX practitioner with Combat Spec as the secondary profession. Source: Beyond Science: A Guide to FX p. 6.",
			"Action Check Score Increase: action check score increased by 1. Source: Beyond Science: A Guide to FX p. 6.",
			"Adept School: choose one FX broad skill; that broad skill and all its specialty skills cost list price -1 and may advance to Rank 12, subject to level. Source: Beyond Science: A Guide to FX p. 6.",
			"Secondary Profession (Combat Spec): Combat Spec skills cost list price -1; the secondary profession also determines starting money and achievement-benefit costs. Source: Beyond Science: A Guide to FX p. 6.",
			"Begins with the campaign's full FX energy pool (10 in a heroic campaign). Source: Beyond Science: A Guide to FX pp. 4, 6.",
		],
	},
	{
		"id": 10,
		"name": "Adept (Diplomat)",
		"code": "A",
		"secondary_code": "D",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {"WIL": 9, "PER": 11, "INT": 9},
		"supplement": "beyond_science",
		"adept_role": "primary",
		"advancement_profile": "diplomat",
		"notes": [
			"A dedicated FX practitioner with Diplomat as the secondary profession; this does not grant another secondary profession. Source: Beyond Science: A Guide to FX p. 6.",
			"Action Check Score Increase: action check score increased by 1. Source: Beyond Science: A Guide to FX p. 6.",
			"Adept School: choose one FX broad skill; that broad skill and all its specialty skills cost list price -1 and may advance to Rank 12, subject to level. Source: Beyond Science: A Guide to FX p. 6.",
			"Secondary Profession (Diplomat): Diplomat skills cost list price -1; the secondary profession also determines starting money and achievement-benefit costs. Source: Beyond Science: A Guide to FX p. 6.",
			"Begins with the campaign's full FX energy pool (10 in a heroic campaign). Source: Beyond Science: A Guide to FX pp. 4, 6.",
		],
	},
	{
		"id": 11,
		"name": "Adept (Free Agent)",
		"code": "A",
		"secondary_code": "F",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {"DEX": 11, "INT": 9, "WIL": 9},
		"supplement": "beyond_science",
		"adept_role": "primary",
		"advancement_profile": "free_agent",
		"notes": [
			"A dedicated FX practitioner with Free Agent as the secondary profession. Source: Beyond Science: A Guide to FX p. 6.",
			"Action Check Score Increase: action check score increased by 1. Source: Beyond Science: A Guide to FX p. 6.",
			"Adept School: choose one FX broad skill; that broad skill and all its specialty skills cost list price -1 and may advance to Rank 12, subject to level. Source: Beyond Science: A Guide to FX p. 6.",
			"Secondary Profession (Free Agent): Free Agent skills cost list price -1; the secondary profession also determines starting money and achievement-benefit costs. Source: Beyond Science: A Guide to FX p. 6.",
			"Begins with the campaign's full FX energy pool (10 in a heroic campaign). Source: Beyond Science: A Guide to FX pp. 4, 6.",
		],
	},
	{
		"id": 12,
		"name": "Adept (Tech Op)",
		"code": "A",
		"secondary_code": "T",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {"INT": 11, "DEX": 9, "CON": 9},
		"supplement": "beyond_science",
		"adept_role": "primary",
		"advancement_profile": "tech_op",
		"notes": [
			"A dedicated FX practitioner with Tech Op as the secondary profession. Source: Beyond Science: A Guide to FX p. 6.",
			"Action Check Score Increase: action check score increased by 1. Source: Beyond Science: A Guide to FX p. 6.",
			"Adept School: choose one FX broad skill; that broad skill and all its specialty skills cost list price -1 and may advance to Rank 12, subject to level. Source: Beyond Science: A Guide to FX p. 6.",
			"Secondary Profession (Tech Op): Tech Op skills cost list price -1; the secondary profession also determines starting money and achievement-benefit costs. Source: Beyond Science: A Guide to FX p. 6.",
			"Begins with the campaign's full FX energy pool (10 in a heroic campaign). Source: Beyond Science: A Guide to FX pp. 4, 6.",
		],
	},
	{
		"id": 13,
		"name": "Adept (Mindwalker)",
		"code": "A",
		"secondary_code": "M",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {"WIL": 11, "INT": 9, "CON": 9},
		"supplement": "beyond_science",
		"adept_role": "primary",
		"advancement_profile": "mindwalker",
		"notes": [
			"A dedicated FX practitioner with Mindwalker as the secondary profession. Psionic energy and FX energy are separate pools. Source: Beyond Science: A Guide to FX p. 6.",
			"Action Check Score Increase: action check score increased by 1. Source: Beyond Science: A Guide to FX p. 6.",
			"Adept School: choose one FX broad skill; that broad skill and all its specialty skills cost list price -1 and may advance to Rank 12, subject to level. Source: Beyond Science: A Guide to FX p. 6.",
			"Secondary Profession (Mindwalker): psionic skills cost list price -1; the secondary profession also determines starting money and achievement-benefit costs. Source: Beyond Science: A Guide to FX p. 6.",
			"Begins with the campaign's full FX energy pool (10 in a heroic campaign). Source: Beyond Science: A Guide to FX pp. 4, 6.",
		],
	},
	{
		"id": 14,
		"name": "Non-Professional",
		"code": "",
		"secondary_code": "",
		"action_bonus": 0,
		"last_resort_bonus": 0,
		"ability_minimums": {},
		"notes": [
			"A supporting character without a heroic profession. Source: Alternity Gamemaster Guide p. 89.",
			"No profession action-check increase and no professional skill-cost reductions. Source: Alternity Gamemaster Guide p. 89.",
			"Uses standard durability from Constitution. Source: Alternity Gamemaster Guide p. 89.",
		],
	},
]

