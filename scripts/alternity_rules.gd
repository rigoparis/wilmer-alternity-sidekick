class_name AlternityRules
extends RefCounted

const ABILITIES := ["STR", "DEX", "CON", "INT", "WIL", "PER"]
const MAX_SPECIALTY_RANK := 12
const ABILITY_NAMES := {
	"STR": "Strength",
	"DEX": "Dexterity",
	"CON": "Constitution",
	"INT": "Intelligence",
	"WIL": "Will",
	"PER": "Personality",
}

const OPTIONAL_RULES := [
	{
		"id": "2a",
		"name": "Optional Rule 2A",
		"summary": "Alternate starting skill points",
		"description": "New characters have skill points equal to 30 plus 3 times their INT score. Human heroes receive 5 additional skill points at character creation.",
	},
	{
		"id": "2b",
		"name": "Optional Rule 2B",
		"summary": "Alternate broad skill limit",
		"description": "During initial skill purchase, a character may not learn more than six additional broad skills, not counting racial broad skills. Modify this number by the hero's INT resistance modifier.",
	},
	{
		"id": "2c",
		"name": "Optional Rule 2C",
		"summary": "Flat specialty advancement cost",
		"description": "The cost to purchase rank 2 or higher in a specialty skill is either the list price or list price -1. Current ranks do not increase the cost of advancing that skill.",
	},
]

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
const CORE_SKILL_ROLL_SOURCE := "Source: Player's Handbook p. 61-63."
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
	32: 20,
}

const BROAD_SKILL_SUMMARIES := {
	0: "Operate armor effectively and reduce armor-related action check and Dexterity resistance penalties.",
	3: "Handle athletic feats of strength such as climbing, jumping, and throwing.",
	8: "Use heavy personal and crew-served weapons, including direct-fire and indirect-fire weapons.",
	11: "Fight with hand weapons and use melee defenses such as parrying when appropriate.",
	15: "Fight without weapons, brawl, use martial arts, and attempt overpowering holds.",
	18: "Perform agile movement, stunts, dodges, controlled falls, and zero-g or flight maneuvers.",
	26: "Perform fine manual actions such as opening locks, picking pockets, and sleight of hand.",
	30: "Use modern firearms such as pistols, rifles, and submachine guns.",
	34: "Use older ranged weapons such as bows, crossbows, flintlocks, and slings.",
	39: "Avoid notice through hiding, shadowing, and silent movement.",
	43: "Operate common vehicles and specialized vehicle classes.",
	48: "Handle long-distance or demanding movement such as racing, swimming, and trailblazing.",
	52: "Endure fatigue, pain, harsh activity, and injury-related checks.",
	55: "Survive hostile environments by finding necessities and avoiding environmental danger.",
	57: "Understand commercial organizations, trade, and legal or illegal business practices.",
	61: "Work with computer systems, hardware, hacking, and programming.",
	65: "Use, build, place, and disarm explosives.",
	69: "Apply general education, languages, deduction, basic computer operation, and first aid.",
	75: "Understand law, court procedure, law enforcement practice, and legal specialties.",
	79: "Apply biological sciences such as biology, botany, genetics, xenology, and zoology.",
	85: "Apply medical sciences, diagnosis, psychology, surgery, treatment, and xenomedicine.",
	92: "Navigate by surface, system, or drivespace methods.",
	96: "Apply astronomy, chemistry, physics, and planetology.",
	101: "Understand security procedures, devices, and protection protocols.",
	104: "Operate ship, station, or installation systems such as sensors, defenses, engines, and weapons.",
	110: "Apply battlefield and operational planning for infantry, vehicle, and space combat.",
	114: "Build, invent, juryrig, repair, and understand technical systems.",
	119: "Navigate organizations through bureaucracy and management.",
	122: "Ride, train, and work with animals.",
	125: "Notice danger, read intuition, and perceive hidden details.",
	128: "Produce creative work in a chosen field.",
	130: "Interrogate, search, and track as part of formal investigation.",
	134: "Resist mental and physical pressure.",
	137: "Understand street-level contacts, rumors, and criminal elements.",
	140: "Teach a specific field to another character.",
	142: "Understand cultures and manage diplomacy, etiquette, and first-contact situations.",
	146: "Mislead, bluff, bribe, and gamble.",
	150: "Perform as an actor, dancer, musician, singer, or similar entertainer.",
	155: "Negotiate, charm, interview, intimidate, seduce, taunt, and bargain.",
	162: "Lead others through command and inspiration.",
}

const SPECIALTY_SUMMARIES := {
	1: "Specialized operation of standard combat armor, including reducing armor penalties and shield parries.",
	2: "Specialized operation of powered armor; this skill cannot be used untrained.",
	4: "Climb walls, mountains, lines, and similar obstacles.",
	5: "Jump horizontally or vertically; distance depends on the result of the skill check.",
	6: "Throw objects accurately or for distance.",
	9: "Fire direct-fire heavy weapons at visible targets.",
	10: "Use indirect-fire heavy weapons such as mortars or launchers against areas or concealed targets.",
	12: "Use knives, swords, axes, and similar bladed weapons.",
	13: "Use clubs, maces, staffs, and similar blunt weapons.",
	14: "Use powered melee weapons.",
	16: "Use unarmed street fighting, boxing, wrestling, and similar close combat.",
	17: "Use offensive martial arts focused on strikes and power; this skill cannot be used untrained.",
	19: "Perform dangerous activities such as parachuting, diving, surfing, and other high-risk stunts.",
	20: "Use defensive martial arts focused on redirection, throws, sweeps, holds, and blocks.",
	21: "Use tumbling, rolling, cover, and evasive movement as a combat defense.",
	22: "Reduce harm from falling through controlled movement and landing technique.",
	23: "Perform difficult maneuvers while flying or gliding.",
	24: "Function in zero-g or low-g environments; this skill cannot be used untrained.",
	27: "Open locks and defeat mechanical locking systems.",
	28: "Steal small objects from another character without being noticed.",
	29: "Perform sleight of hand, palming, and stage-magic style manipulation.",
	31: "Use pistols.",
	32: "Use rifles.",
	33: "Use submachine guns.",
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
	53: "Resist fatigue and the worsening of mortal damage.",
	54: "Resist pain and keep functioning under injury; this skill cannot be used untrained.",
	56: "Survive in a chosen environment or terrain type.",
	62: "Break into, bypass, or exploit computer systems; this skill cannot be used untrained.",
	63: "Work with computer hardware.",
	64: "Write, modify, and understand software.",
	66: "Disarm explosive devices.",
	67: "Build explosive devices from available materials; this skill cannot be used untrained.",
	68: "Place explosives for intended effect.",
	70: "Use everyday computer systems; this skill cannot be used untrained.",
	71: "Reach conclusions from evidence and logic.",
	72: "Provide immediate medical aid; this skill cannot be used untrained.",
	73: "Speak, read, or understand a specific language; this skill cannot be used untrained.",
	74: "Know facts about a specific field.",
	89: "Perform surgery; this skill cannot be used untrained.",
	90: "Treat injuries and illness; this skill cannot be used untrained.",
	91: "Practice medicine on a specific nonhuman species; this skill cannot be used untrained.",
	93: "Plot drivespace courses; this skill cannot be used untrained.",
	94: "Navigate within a star system.",
	95: "Navigate on or near a planetary surface.",
	102: "Understand protective procedures and security protocols.",
	103: "Find, bypass, or operate security devices.",
	115: "Design or create new technical solutions.",
	116: "Make quick field repairs or improvised technical fixes.",
	117: "Repair damaged devices and systems.",
	118: "Know technical facts and principles.",
	124: "Train a chosen animal type.",
	126: "Sense motives, danger, or the direction of a situation.",
	127: "Notice hidden or subtle physical details.",
	131: "Question a subject under pressure.",
	132: "Search an area or object for hidden information.",
	133: "Follow tracks and signs of passage.",
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
		4: "Strength resistance modifier improves by +1 for close-combat defense, and reaction parry becomes available. Source: Player's Handbook p. 68.",
		6: "Double-strike becomes available: two attacks in one phase with one control die and two situation dice at +1 and +2 step penalties. Source: Player's Handbook p. 68.",
		8: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 68.",
		9: "Multistrike becomes available: three attacks in one phase, with +1, +2, and +3 step penalties on the situation dice. Source: Player's Handbook p. 68.",
		12: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 68.",
	},
	13: {
		4: "Strength resistance modifier improves by +1 for close-combat defense, and reaction parry becomes available. Source: Player's Handbook p. 68.",
		6: "Double-strike becomes available: two attacks in one phase with one control die and two situation dice at +1 and +2 step penalties. Source: Player's Handbook p. 68.",
		8: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 68.",
		9: "Multistrike becomes available: three attacks in one phase, with +1, +2, and +3 step penalties on the situation dice. Source: Player's Handbook p. 68.",
		12: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 68.",
	},
	14: {
		4: "Strength resistance modifier improves by +1 for close-combat defense, and reaction parry becomes available. Source: Player's Handbook p. 68.",
		6: "Double-strike becomes available: two attacks in one phase with one control die and two situation dice at +1 and +2 step penalties. Source: Player's Handbook p. 68.",
		8: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 68.",
		9: "Multistrike becomes available: three attacks in one phase, with +1, +2, and +3 step penalties on the situation dice. Source: Player's Handbook p. 68.",
		12: "Strength resistance modifier improves by another +1 for close-combat defense. Source: Player's Handbook p. 68.",
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
		3: "Can dodge and still take an action in the same phase; the action carries a +2 step penalty. Source: Player's Handbook p. 71.",
		4: "Dexterity resistance modifier improves by +1 against ranged combat. Source: Player's Handbook p. 71.",
		7: "Can perform a reaction dodge immediately, but gives up other actions for the round. Source: Player's Handbook p. 71.",
		8: "Dexterity resistance modifier improves by another +1 against ranged combat. Source: Player's Handbook p. 71.",
		12: "Dexterity resistance modifier improves by another +1 against ranged combat. Source: Player's Handbook p. 71.",
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
]

const FLAW_DEFINITIONS := [
	{
		"id": "alien_artifact_flaw",
		"name": "Alien Artifact",
		"bonus_options": [5],
		"ability": "Special",
		"summary": "A GM-designed alien item, experiment, or process is mostly a disadvantage, though it also has an unrelated positive side.",
		"source": "Player's Handbook p. 108-109; Table P27.",
	},
	{
		"id": "bad_luck",
		"name": "Bad Luck",
		"bonus_options": [6],
		"ability": "WIL",
		"summary": "The hero suffers a Critical Failure when the control die shows 19 or 20.",
		"source": "Player's Handbook p. 108; Table P27.",
	},
	{
		"id": "clueless",
		"name": "Clueless",
		"bonus_options": [2, 4, 6],
		"ability": "INT",
		"summary": "The GM secretly chooses a non-profession specialty skill the hero overestimates. The bonus option sets a +1, +2, or +3 step penalty to that skill.",
		"source": "Player's Handbook p. 108; Table P27.",
	},
	{
		"id": "clumsy",
		"name": "Clumsy",
		"bonus_options": [5],
		"ability": "DEX",
		"summary": "The hero has poor coordination and takes a +1 step penalty to Dexterity-based skill checks.",
		"source": "Player's Handbook p. 108; Table P27.",
	},
	{
		"id": "code_of_honor",
		"name": "Code of Honor",
		"bonus_options": [3],
		"ability": "WIL",
		"summary": "The hero follows a binding code agreed with the GM. Achievement awards can be reduced if the flaw is not roleplayed.",
		"source": "Player's Handbook p. 108-109; Table P27.",
	},
	{
		"id": "delicate",
		"name": "Delicate",
		"bonus_options": [3],
		"ability": "STR",
		"summary": "Successful Unarmed Attack checks inflict 1 stun on the hero. If current stun drops below half, the hero cannot use Unarmed Attack until recovering enough stun.",
		"source": "Player's Handbook p. 109; Table P27.",
	},
	{
		"id": "dirt_poor",
		"name": "Dirt Poor",
		"bonus_options": [5],
		"ability": "PER",
		"summary": "The hero starts impoverished, has a creditor or obligation set by the GM, and takes a +1 step penalty to Personality-based checks when dealing upward socially or financially.",
		"source": "Player's Handbook p. 109; Table P27.",
	},
	{
		"id": "forgetful",
		"name": "Forgetful",
		"bonus_options": [5],
		"ability": "INT",
		"summary": "The hero has trouble recalling details and takes a +1 step penalty to Intelligence-based skill checks.",
		"source": "Player's Handbook p. 109; Table P27.",
	},
	{
		"id": "fragile",
		"name": "Fragile",
		"bonus_options": [3],
		"ability": "CON",
		"summary": "Damage hampers the hero, imposing a +1 step penalty to Stamina-endurance checks.",
		"source": "Player's Handbook p. 109; Table P27.",
	},
	{
		"id": "infamy",
		"name": "Infamy",
		"bonus_options": [2, 4, 6],
		"ability": "PER",
		"summary": "The hero is known for a criminal or evil act. When triggered, the bonus option sets a +1, +2, or +3 step penalty to Personality-based skill checks.",
		"source": "Player's Handbook p. 109; Table P27.",
	},
	{
		"id": "oblivious",
		"name": "Oblivious",
		"bonus_options": [4],
		"ability": "WIL",
		"summary": "The hero has trouble noticing details and takes a +1 step penalty to Awareness-perception checks.",
		"source": "Player's Handbook p. 109; Table P27.",
	},
	{
		"id": "obsessed",
		"name": "Obsessed",
		"bonus_options": [2, 4, 6],
		"ability": "INT",
		"summary": "An agreed trigger distracts the hero. The bonus option sets a +1, +2, or +3 step penalty to actions not related to the obsession.",
		"source": "Player's Handbook p. 109; Table P27.",
	},
	{
		"id": "old_injury",
		"name": "Old Injury",
		"bonus_options": [2, 4, 6],
		"ability": "STR",
		"summary": "An agreed physical trigger can flare once per scene. The bonus option sets wound damage of 1, 2 plus 1 stun, or 3 plus 1 stun; armor does not reduce it.",
		"source": "Player's Handbook p. 109; Table P27.",
	},
	{
		"id": "phobia",
		"name": "Phobia",
		"bonus_options": [2, 4, 6],
		"ability": "WIL",
		"summary": "An agreed broad fear hampers the hero. The bonus option sets a +1 or +2 step penalty to all actions, or freezing/fleeing for the highest option.",
		"source": "Player's Handbook p. 109-110; Table P27.",
	},
	{
		"id": "poor_looks",
		"name": "Poor Looks",
		"bonus_options": [3],
		"ability": "PER",
		"summary": "When appearance hurts an encounter, the hero takes a +1 step penalty to Personality-based skill checks, subject to GM and cultural context.",
		"source": "Player's Handbook p. 110; Table P27.",
	},
	{
		"id": "powerful_enemy",
		"name": "Powerful Enemy",
		"bonus_options": [2, 4, 6],
		"ability": "PER",
		"summary": "The hero has a far-reaching enemy. The bonus option determines how often and how broadly that enemy can affect the hero.",
		"source": "Player's Handbook p. 110; Table P27.",
	},
	{
		"id": "primitive",
		"name": "Primitive",
		"bonus_options": [2, 4, 6],
		"ability": "INT",
		"summary": "The hero struggles with modern technology. The bonus option sets a +1, +2, or +3 step penalty when using it, with possible awe or terror at the highest option.",
		"source": "Player's Handbook p. 110; Table P27.",
	},
	{
		"id": "slow",
		"name": "Slow",
		"bonus_options": [6],
		"ability": "DEX",
		"summary": "The hero has reduced reaction time and takes a +1 step penalty to action checks.",
		"source": "Player's Handbook p. 110; Table P27.",
	},
	{
		"id": "spineless",
		"name": "Spineless",
		"bonus_options": [2, 4, 6],
		"ability": "WIL",
		"summary": "The hero's Will resistance modifier is reduced by 1, 2, or 3 steps based on the selected bonus option.",
		"source": "Player's Handbook p. 110; Table P27.",
	},
	{
		"id": "temper",
		"name": "Temper",
		"bonus_options": [2, 4, 6],
		"ability": "WIL",
		"summary": "An agreed trigger sets off the hero. The bonus option imposes a +1, +2, or +3 step penalty to actions until the trigger ends and the hero calms down.",
		"source": "Player's Handbook p. 110; Table P27.",
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
			"CON": 9,
		},
		"notes": [
			"Action check score increased by 3.",
			"Choose one combat specialty for a -1 step situation bonus.",
			"Profession requirements: STR 11, CON 9. Source: Player's Handbook Table P1 p. 30.",
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
		},
		"notes": [
			"Action check score increased by 1.",
			"Starts with either Contacts or Resources.",
			"Secondary profession receives the skill cost bonus.",
			"Profession requirements: WIL 9, PER 11. Source: Player's Handbook Table P1 p. 30.",
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
		},
		"notes": [
			"Action check score increased by 1.",
			"Starts with either Contacts or Resources.",
			"Secondary profession receives the skill cost bonus.",
			"Profession requirements: WIL 9, PER 11. Source: Player's Handbook Table P1 p. 30.",
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
		},
		"notes": [
			"Action check score increased by 1.",
			"Starts with either Contacts or Resources.",
			"Secondary profession receives the skill cost bonus.",
			"Profession requirements: WIL 9, PER 11. Source: Player's Handbook Table P1 p. 30.",
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
			"WIL": 9,
		},
		"notes": [
			"Action check score increased by 2.",
			"Maximum last resorts increased by 1.",
			"Choose one resistance modifier for the Free Agent bonus.",
			"Profession requirements: DEX 11, WIL 9. Source: Player's Handbook Table P1 p. 30.",
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
			"DEX": 9,
			"INT": 11,
		},
		"notes": [
			"Action check score increased by 1.",
			"Uses Accelerated Learning when advancing.",
			"Profession requirements: DEX 9, INT 11. Source: Player's Handbook Table P1 p. 30.",
		],
	},
	{
		"id": 6,
		"name": "Mindwalker",
		"code": "",
		"secondary_code": "",
		"action_bonus": 1,
		"last_resort_bonus": 0,
		"ability_minimums": {
			"CON": 9,
			"INT": 9,
			"WIL": 11,
		},
		"notes": [
			"Action check score increased by 1.",
			"Choose one psionic broad skill and its specialties for a -1 step bonus.",
			"Profession requirements: CON 9, INT 9, WIL 11. Source: Player's Handbook Table P1 p. 30.",
		],
	},
]

var data: Dictionary = {}
var species: Array = []
var skills: Array = []
var equipment_sources: Array = []
var equipment_catalog: Array = []
var equipment_by_id: Dictionary = {}
var achievement_profiles: Array = []
var achievement_sources: Array = []
var achievement_rules: Array = []
var achievement_catalog: Array = []
var achievements_by_id: Dictionary = {}
var mutation_rules: Array = []
var mutation_origins: Array = []
var mutation_origins_by_id: Dictionary = {}
var mutation_advantages: Array = []
var mutation_drawbacks: Array = []
var mutation_advantages_by_id: Dictionary = {}
var mutation_drawbacks_by_id: Dictionary = {}
var skills_by_id: Dictionary = {}
var broad_skills: Array = []
var specialty_skills_by_broad_id: Dictionary = {}


func load_core_data(path := "res://data/rules/alternity_core.json") -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity rule data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity rule data is not valid JSON: %s" % path)
		return

	data = parsed
	species = data.get("species", [])
	skills = data.get("skills", [])
	_index_skills()
	_load_equipment_catalog()
	_load_achievement_catalog()
	_load_mutation_catalog()


func _load_equipment_catalog(path := "res://data/rules/equipment_core.json") -> void:
	equipment_sources.clear()
	equipment_catalog.clear()
	equipment_by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity equipment data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity equipment data is not valid JSON: %s" % path)
		return

	equipment_sources = parsed.get("sources", [])
	equipment_catalog = parsed.get("items", [])
	_index_equipment()


func _load_achievement_catalog(path := "res://data/rules/achievements_core.json") -> void:
	achievement_profiles.clear()
	achievement_sources.clear()
	achievement_rules.clear()
	achievement_catalog.clear()
	achievements_by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity achievement data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity achievement data is not valid JSON: %s" % path)
		return

	achievement_profiles = parsed.get("profiles", [])
	achievement_sources = parsed.get("sources", [])
	achievement_rules = parsed.get("rules", [])
	achievement_catalog = parsed.get("items", [])
	_index_achievements()


func _load_mutation_catalog(path := "res://data/rules/mutations_core.json") -> void:
	mutation_rules.clear()
	mutation_origins.clear()
	mutation_origins_by_id.clear()
	mutation_advantages.clear()
	mutation_drawbacks.clear()
	mutation_advantages_by_id.clear()
	mutation_drawbacks_by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity mutation data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity mutation data is not valid JSON: %s" % path)
		return

	mutation_rules = parsed.get("rules", [])
	mutation_origins = parsed.get("origins", [])
	for item_value in mutation_origins:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			mutation_origins_by_id[item_id] = item
	mutation_advantages = parsed.get("advantages", [])
	mutation_drawbacks = parsed.get("drawbacks", [])
	for item_value in mutation_advantages:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			mutation_advantages_by_id[item_id] = item
	for item_value in mutation_drawbacks:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			mutation_drawbacks_by_id[item_id] = item


func default_character() -> Dictionary:
	return {
		"hero_name": "New Hero",
		"player_name": "",
		"career": "",
		"notes": "",
		"setting": data.get("setting", "Core"),
		"achievement_level": 1,
		"achievement_points": 0,
		"achievement_points_available": 0,
		"achievement_points_spent_other": 0,
		"species_id": 0,
		"profession_id": 0,
		"abilities": {
			"STR": 10,
			"DEX": 10,
			"CON": 10,
			"INT": 10,
			"WIL": 10,
			"PER": 10,
		},
		"selected_skills": {},
		"selected_perks": {},
		"selected_flaws": {},
		"selected_achievements": [],
		"mutations": {
			"generation_mode": "random",
			"origin": "engineered",
			"uniqueness": "engineered_community",
			"advantage_points": 0,
			"drawback_points": 0,
			"advantage_distribution": {},
			"drawback_distribution": {},
			"advantages": [],
			"drawbacks": [],
		},
		"optional_rules": {
			"2a": false,
			"2b": false,
			"2c": false,
		},
		"damage": {
			"stun": 0,
			"wound": 0,
			"mortal": 0,
			"fatigue": 0,
		},
		"last_resorts_used": 0,
		"equipment": {
			"carried": [],
			"custom_items": [],
		},
	}


func ensure_character_shape(character: Dictionary) -> Dictionary:
	if not character.has("abilities"):
		character["abilities"] = {}
	for ability in ABILITIES:
		if not character["abilities"].has(ability):
			character["abilities"][ability] = 10

	if not character.has("selected_skills"):
		character["selected_skills"] = {}
	else:
		_normalize_selected_skills(character)
	if not character.has("selected_perks"):
		character["selected_perks"] = {}
	else:
		_normalize_selected_character_options(character, "selected_perks", PERK_DEFINITIONS, "cost_options")
	if not character.has("selected_flaws"):
		character["selected_flaws"] = {}
	else:
		_normalize_selected_character_options(character, "selected_flaws", FLAW_DEFINITIONS, "bonus_options")
	if not character.has("selected_achievements"):
		character["selected_achievements"] = []
	else:
		_normalize_selected_achievements(character)
	if not character.has("mutations"):
		character["mutations"] = {}
	_normalize_mutations(character)
	if not character.has("optional_rules"):
		character["optional_rules"] = {}
	for rule in OPTIONAL_RULES:
		var rule_id := String(rule.get("id", ""))
		if not character["optional_rules"].has(rule_id):
			character["optional_rules"][rule_id] = false
	if not character.has("species_id"):
		character["species_id"] = 0
	if not character.has("profession_id"):
		character["profession_id"] = 0
	if not character.has("notes"):
		character["notes"] = ""
	character["notes"] = String(character.get("notes", ""))
	if not character.has("achievement_level"):
		character["achievement_level"] = 1
	if not character.has("achievement_points"):
		character["achievement_points"] = 0
	character["achievement_points"] = max(0, _as_int(character.get("achievement_points", 0)))
	character["achievement_level"] = achievement_level_for_points(_as_int(character.get("achievement_points", 0)))
	if not character.has("achievement_points_available"):
		character["achievement_points_available"] = 0
	if not character.has("achievement_points_spent_other"):
		character["achievement_points_spent_other"] = 0
	character["achievement_points_spent_other"] = max(0, _as_int(character.get("achievement_points_spent_other", 0)))
	character["achievement_points_available"] = achievement_points_available(character)
	if not character.has("damage"):
		character["damage"] = {}
	for damage_type in ["stun", "wound", "mortal", "fatigue"]:
		if not character["damage"].has(damage_type):
			character["damage"][damage_type] = 0
	if not character.has("last_resorts_used"):
		character["last_resorts_used"] = 0
	if not character.has("equipment"):
		character["equipment"] = {}
	_normalize_equipment(character)
	clamp_trackers(character)
	return character


func achievement_points_for_level(level: int) -> int:
	var safe_level: int = max(1, level)
	return int(((safe_level * safe_level) + (9 * safe_level) - 10) / 2.0)


func achievement_level_for_points(points: int) -> int:
	var safe_points: int = max(0, points)
	var level := 1
	while safe_points >= achievement_points_for_level(level + 1):
		level += 1
	return level


func achievement_next_level_points(points: int) -> int:
	return achievement_points_for_level(achievement_level_for_points(points) + 1)


func set_achievement_points(character: Dictionary, points: int) -> void:
	character["achievement_points"] = max(0, points)
	character["achievement_level"] = achievement_level_for_points(_as_int(character["achievement_points"]))
	character["achievement_points_available"] = achievement_points_available(character)


func achievement_points_used(character: Dictionary) -> int:
	var skill_points_from_achievements: int = max(0, skill_points_used(character) - starting_skill_budget(character) - achievement_skill_bonus(character))
	var other_spending: int = max(0, _as_int(character.get("achievement_points_spent_other", 0)))
	return skill_points_from_achievements + other_spending


func achievement_points_available(character: Dictionary) -> int:
	return _as_int(character.get("achievement_points", 0)) - achievement_points_used(character)


func achievement_skill_bonus(character: Dictionary) -> int:
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	if String(profession.get("name", "")) != "Tech Op":
		return 0

	var bonus := 0
	var current_level := achievement_level_for_points(_as_int(character.get("achievement_points", 0)))
	for level in range(2, current_level + 1):
		if level <= 5:
			bonus += 1
		elif level <= 10:
			bonus += 2
		elif level <= 15:
			bonus += 3
		elif level <= 20:
			bonus += 4
		else:
			bonus += 5
	return bonus


func get_species_by_id(species_id: int) -> Dictionary:
	for item in species:
		if _as_int(item.get("id", -1)) == species_id:
			return item
	return species[0] if not species.is_empty() else {}


func get_profession_by_id(profession_id: int) -> Dictionary:
	for profession in PROFESSION_DEFINITIONS:
		if _as_int(profession.get("id", -1)) == profession_id:
			return profession
	return PROFESSION_DEFINITIONS[0]


func get_skill_by_id(skill_id: int) -> Dictionary:
	return skills_by_id.get(skill_id, {})


func get_equipment_item_by_id(item_id: String) -> Dictionary:
	return equipment_by_id.get(item_id, {})


func get_achievement_by_id(achievement_id: String) -> Dictionary:
	return achievements_by_id.get(achievement_id, {})


func get_mutation_advantage_by_id(mutation_id: String) -> Dictionary:
	return mutation_advantages_by_id.get(mutation_id, {})


func get_mutation_drawback_by_id(drawback_id: String) -> Dictionary:
	return mutation_drawbacks_by_id.get(drawback_id, {})


func mutant_species_id() -> int:
	for item in species:
		if String(item.get("name", "")) == "Mutant":
			return _as_int(item.get("id", -1))
	return 6


func mutations_enabled(character: Dictionary) -> bool:
	return _as_int(character.get("species_id", -1)) == mutant_species_id()


func mutation_origin_options() -> Array:
	return mutation_origins


func mutation_uniqueness_options(origin_id: String) -> Array:
	var origin := get_mutation_origin_by_id(origin_id)
	if origin.is_empty():
		return []
	var rows: Array = origin.get("uniqueness", [])
	return rows


func get_mutation_origin_by_id(origin_id: String) -> Dictionary:
	return mutation_origins_by_id.get(origin_id, {})


func get_mutation_uniqueness_by_id(origin_id: String, uniqueness_id: String) -> Dictionary:
	for uniqueness_value in mutation_uniqueness_options(origin_id):
		if typeof(uniqueness_value) != TYPE_DICTIONARY:
			continue
		var uniqueness: Dictionary = uniqueness_value
		if String(uniqueness.get("id", "")) == uniqueness_id:
			return uniqueness
	return {}


func set_mutation_generation_mode(character: Dictionary, mode: String) -> void:
	var mutations := _mutation_data(character)
	mutations["generation_mode"] = "player" if mode == "player" else "random"
	character["mutations"] = mutations


func set_mutation_origin(character: Dictionary, origin_id: String) -> void:
	var mutations := _mutation_data(character)
	var origin := get_mutation_origin_by_id(origin_id)
	if origin.is_empty():
		return
	mutations["origin"] = origin_id
	if get_mutation_uniqueness_by_id(origin_id, String(mutations.get("uniqueness", ""))).is_empty():
		var uniqueness_rows: Array = origin.get("uniqueness", [])
		if not uniqueness_rows.is_empty() and typeof(uniqueness_rows[0]) == TYPE_DICTIONARY:
			mutations["uniqueness"] = String(uniqueness_rows[0].get("id", ""))
	character["mutations"] = mutations


func set_mutation_uniqueness(character: Dictionary, uniqueness_id: String) -> void:
	var mutations := _mutation_data(character)
	var origin_id := String(mutations.get("origin", "engineered"))
	if get_mutation_uniqueness_by_id(origin_id, uniqueness_id).is_empty():
		return
	mutations["uniqueness"] = uniqueness_id
	character["mutations"] = mutations


func set_mutation_points(character: Dictionary, advantage_points: int, drawback_points: int) -> void:
	var mutations := _mutation_data(character)
	mutations["advantage_points"] = max(0, advantage_points)
	mutations["drawback_points"] = max(0, drawback_points)
	character["mutations"] = mutations
	_ensure_mutation_distributions(character)


func set_mutation_point_total(character: Dictionary, kind: String, points: int) -> void:
	var mutations := _mutation_data(character)
	if kind == "drawback":
		mutations["drawback_points"] = max(0, points)
	else:
		mutations["advantage_points"] = max(0, points)
	character["mutations"] = mutations
	_ensure_mutation_distribution(character, kind)


func roll_mutation_origin(character: Dictionary) -> Dictionary:
	var origin_roll := randi_range(1, 8)
	var origin_id := "engineered" if origin_roll <= 5 else "natural"
	var uniqueness_roll := randi_range(1, 8)
	var uniqueness_id := ""
	if origin_id == "engineered":
		uniqueness_id = "engineered_community" if uniqueness_roll <= 5 else "engineered_unique"
	else:
		uniqueness_id = "natural_community" if uniqueness_roll <= 3 else "natural_unique"

	var mutations := _mutation_data(character)
	mutations["origin"] = origin_id
	mutations["uniqueness"] = uniqueness_id
	character["mutations"] = mutations
	return {
		"origin_roll": origin_roll,
		"uniqueness_roll": uniqueness_roll,
		"origin": get_mutation_origin_by_id(origin_id),
		"uniqueness": get_mutation_uniqueness_by_id(origin_id, uniqueness_id),
	}


func roll_mutation_origin_and_points(character: Dictionary) -> Dictionary:
	var origin_result := roll_mutation_origin(character)
	var points_result := roll_mutation_points(character)
	origin_result["points"] = points_result
	return origin_result


func roll_mutation_points(character: Dictionary) -> Dictionary:
	var mutations := _mutation_data(character)
	var uniqueness := get_mutation_uniqueness_by_id(String(mutations.get("origin", "engineered")), String(mutations.get("uniqueness", "engineered_community")))
	if uniqueness.is_empty():
		return {}
	var advantage_points := _roll_mutation_formula(String(uniqueness.get("advantage_points", "0")))
	var drawback_points := _roll_mutation_formula(String(uniqueness.get("drawback_points", "0")))
	mutations["advantage_points"] = advantage_points
	mutations["drawback_points"] = drawback_points
	character["mutations"] = mutations
	_ensure_mutation_distributions(character)
	return {
		"advantage_points": advantage_points,
		"drawback_points": drawback_points,
		"uniqueness": uniqueness,
	}


func roll_mutation_point_total(character: Dictionary, kind: String) -> int:
	var mutations := _mutation_data(character)
	var uniqueness := get_mutation_uniqueness_by_id(String(mutations.get("origin", "engineered")), String(mutations.get("uniqueness", "engineered_community")))
	if uniqueness.is_empty():
		return 0
	var formula_key := "drawback_points" if kind == "drawback" else "advantage_points"
	var points := _roll_mutation_formula(String(uniqueness.get(formula_key, "0")))
	set_mutation_point_total(character, kind, points)
	return points


func mutation_distribution_options(kind: String, points: int) -> Array:
	var safe_points: int = max(0, points)
	if kind == "drawback":
		return _mutation_drawback_distribution_options(safe_points)
	return _mutation_advantage_distribution_options(safe_points)


func mutation_distribution(character: Dictionary, kind: String) -> Dictionary:
	var mutations := _mutation_data(character)
	_ensure_mutation_distribution(character, kind)
	var distribution_key := "drawback_distribution" if kind == "drawback" else "advantage_distribution"
	var value = mutations.get(distribution_key, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func set_mutation_distribution(character: Dictionary, kind: String, distribution_id: String) -> void:
	var mutations := _mutation_data(character)
	var points_key := "drawback_points" if kind == "drawback" else "advantage_points"
	var distribution_key := "drawback_distribution" if kind == "drawback" else "advantage_distribution"
	var options := mutation_distribution_options(kind, _as_int(mutations.get(points_key, 0)))
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_value
		if String(option.get("id", "")) == distribution_id:
			mutations[distribution_key] = option.get("counts", {}).duplicate(true)
			character["mutations"] = mutations
			return


func roll_mutation_distribution(character: Dictionary, kind: String) -> Dictionary:
	var mutations := _mutation_data(character)
	var points_key := "drawback_points" if kind == "drawback" else "advantage_points"
	var options := mutation_distribution_options(kind, _as_int(mutations.get(points_key, 0)))
	if options.is_empty():
		return {}
	var option: Dictionary = options[randi_range(0, options.size() - 1)]
	set_mutation_distribution(character, kind, String(option.get("id", "")))
	return option


func mutation_distribution_id(character: Dictionary, kind: String) -> String:
	var distribution := mutation_distribution(character, kind)
	var order := MUTATION_DRAWBACK_TIERS if kind == "drawback" else MUTATION_ADVANTAGE_TIERS
	return _mutation_distribution_id(distribution, order)


func mutation_distribution_label(character: Dictionary, kind: String) -> String:
	var distribution := mutation_distribution(character, kind)
	var order := MUTATION_DRAWBACK_LABEL_ORDER if kind == "drawback" else MUTATION_ADVANTAGE_LABEL_ORDER
	return _mutation_distribution_label(distribution, order)


func selected_mutation_advantages(character: Dictionary) -> Array:
	var rows := []
	var mutations := _mutation_data(character)
	for mutation_id_value in mutations.get("advantages", []):
		var mutation_id := String(mutation_id_value)
		var mutation := get_mutation_advantage_by_id(mutation_id)
		if mutation.is_empty():
			continue
		rows.append(mutation.duplicate(true))
	return rows


func selected_mutation_drawbacks(character: Dictionary) -> Array:
	var rows := []
	var mutations := _mutation_data(character)
	for drawback_id_value in mutations.get("drawbacks", []):
		var drawback_id := String(drawback_id_value)
		var drawback := get_mutation_drawback_by_id(drawback_id)
		if drawback.is_empty():
			continue
		rows.append(drawback.duplicate(true))
	return rows


func mutation_advantage_points_used(character: Dictionary) -> int:
	var total := 0
	for mutation in selected_mutation_advantages(character):
		total += _as_int(mutation.get("points", 0))
	return total


func mutation_drawback_points_used(character: Dictionary) -> int:
	var total := 0
	for drawback in selected_mutation_drawbacks(character):
		total += _as_int(drawback.get("points", 0))
	return total


func mutation_advantage_points_remaining(character: Dictionary) -> int:
	var mutations := _mutation_data(character)
	return _as_int(mutations.get("advantage_points", 0)) - mutation_advantage_points_used(character)


func mutation_drawback_points_remaining(character: Dictionary) -> int:
	var mutations := _mutation_data(character)
	return _as_int(mutations.get("drawback_points", 0)) - mutation_drawback_points_used(character)


func can_add_mutation_advantage(character: Dictionary, mutation: Dictionary) -> Dictionary:
	if not mutations_enabled(character):
		return {"allowed": false, "reason": "Only Mutant heroes use mutation rules."}
	var mutation_id := String(mutation.get("id", ""))
	if mutation_id.is_empty() or get_mutation_advantage_by_id(mutation_id).is_empty():
		return {"allowed": false, "reason": "Unknown mutation."}
	if _mutation_selected(character, "advantages", mutation_id):
		return {"allowed": false, "reason": "Already selected."}
	var remaining := mutation_advantage_points_remaining(character)
	var points := _as_int(mutation.get("points", 0))
	if remaining < points:
		return {"allowed": false, "reason": "Requires %d available advantageous mutation points." % points}
	var tier := String(mutation.get("tier", "Ordinary"))
	var distribution := mutation_distribution(character, "advantage")
	var allowed_count := _as_int(distribution.get(tier, 0))
	if allowed_count <= 0:
		return {"allowed": false, "reason": "The point distribution has no %s mutation slot." % tier}
	if _mutation_tier_count(selected_mutation_advantages(character), tier) >= allowed_count:
		return {"allowed": false, "reason": "The selected point distribution has no remaining %s mutation slot." % tier}
	var cap := _mutation_advantage_tier_cap(tier)
	if cap > 0 and _mutation_tier_count(selected_mutation_advantages(character), tier) >= cap:
		return {"allowed": false, "reason": "A mutant can have no more than %d %s advantageous mutation%s." % [cap, tier, "" if cap == 1 else "s"]}
	return {"allowed": true, "reason": ""}


func can_add_mutation_drawback(character: Dictionary, drawback: Dictionary) -> Dictionary:
	if not mutations_enabled(character):
		return {"allowed": false, "reason": "Only Mutant heroes use mutation rules."}
	var drawback_id := String(drawback.get("id", ""))
	if drawback_id.is_empty() or get_mutation_drawback_by_id(drawback_id).is_empty():
		return {"allowed": false, "reason": "Unknown drawback."}
	if _mutation_selected(character, "drawbacks", drawback_id):
		return {"allowed": false, "reason": "Already selected."}
	var remaining := mutation_drawback_points_remaining(character)
	var points := _as_int(drawback.get("points", 0))
	if remaining < points:
		return {"allowed": false, "reason": "Requires %d available drawback mutation points." % points}
	var tier := String(drawback.get("tier", "Slight"))
	var distribution := mutation_distribution(character, "drawback")
	var allowed_count := _as_int(distribution.get(tier, 0))
	if allowed_count <= 0:
		return {"allowed": false, "reason": "The point distribution has no %s drawback slot." % tier}
	if _mutation_tier_count(selected_mutation_drawbacks(character), tier) >= allowed_count:
		return {"allowed": false, "reason": "The selected point distribution has no remaining %s drawback slot." % tier}
	return {"allowed": true, "reason": ""}


func add_mutation_advantage(character: Dictionary, mutation_id: String) -> Dictionary:
	var mutation := get_mutation_advantage_by_id(mutation_id)
	var check := can_add_mutation_advantage(character, mutation)
	if not bool(check.get("allowed", false)):
		return {"ok": false, "reason": String(check.get("reason", ""))}
	var mutations := _mutation_data(character)
	var selected: Array = mutations.get("advantages", [])
	selected.append(mutation_id)
	mutations["advantages"] = selected
	character["mutations"] = mutations
	clamp_trackers(character)
	return {"ok": true}


func add_mutation_drawback(character: Dictionary, drawback_id: String) -> Dictionary:
	var drawback := get_mutation_drawback_by_id(drawback_id)
	var check := can_add_mutation_drawback(character, drawback)
	if not bool(check.get("allowed", false)):
		return {"ok": false, "reason": String(check.get("reason", ""))}
	var mutations := _mutation_data(character)
	var selected: Array = mutations.get("drawbacks", [])
	selected.append(drawback_id)
	mutations["drawbacks"] = selected
	character["mutations"] = mutations
	clamp_trackers(character)
	return {"ok": true}


func remove_mutation_advantage(character: Dictionary, mutation_id: String) -> void:
	_remove_mutation_selection(character, "advantages", mutation_id)
	clamp_trackers(character)


func remove_mutation_drawback(character: Dictionary, drawback_id: String) -> void:
	_remove_mutation_selection(character, "drawbacks", drawback_id)
	clamp_trackers(character)


func roll_mutations_for_distribution(character: Dictionary, kind: String) -> Dictionary:
	if kind == "drawback":
		return _roll_mutation_selection(character, "drawbacks", mutation_drawbacks, "drawback")
	return _roll_mutation_selection(character, "advantages", mutation_advantages, "advantage")


func mutation_summary(character: Dictionary) -> Dictionary:
	var mutations := _mutation_data(character)
	var origin_id := String(mutations.get("origin", "engineered"))
	var uniqueness_id := String(mutations.get("uniqueness", "engineered_community"))
	return {
		"enabled": mutations_enabled(character),
		"rules": mutation_rules,
		"generation_mode": String(mutations.get("generation_mode", "random")),
		"origin": get_mutation_origin_by_id(origin_id),
		"uniqueness": get_mutation_uniqueness_by_id(origin_id, uniqueness_id),
		"advantage_points": _as_int(mutations.get("advantage_points", 0)),
		"drawback_points": _as_int(mutations.get("drawback_points", 0)),
		"advantage_points_used": mutation_advantage_points_used(character),
		"drawback_points_used": mutation_drawback_points_used(character),
		"advantage_points_remaining": mutation_advantage_points_remaining(character),
		"drawback_points_remaining": mutation_drawback_points_remaining(character),
		"advantage_distribution": mutation_distribution(character, "advantage"),
		"drawback_distribution": mutation_distribution(character, "drawback"),
		"advantage_distribution_label": mutation_distribution_label(character, "advantage"),
		"drawback_distribution_label": mutation_distribution_label(character, "drawback"),
		"advantages": selected_mutation_advantages(character),
		"drawbacks": selected_mutation_drawbacks(character),
	}


func achievement_profile_key(character: Dictionary) -> String:
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var profession_name := String(profession.get("name", ""))
	if profession_name.begins_with("Diplomat"):
		return "diplomat"
	if profession_name == "Combat Spec":
		return "combat_spec"
	if profession_name == "Free Agent":
		return "free_agent"
	if profession_name == "Tech Op":
		return "tech_op"
	if profession_name == "Mindwalker":
		return "mindwalker"
	return "combat_spec"


func achievement_profile_index(character: Dictionary) -> int:
	var key := achievement_profile_key(character)
	for index in range(achievement_profiles.size()):
		if String(achievement_profiles[index]) == key:
			return index
	return 0


func achievement_cost_entry(achievement: Dictionary, character: Dictionary) -> Dictionary:
	var costs: Array = achievement.get("costs", [])
	var index := achievement_profile_index(character)
	if index < 0 or index >= costs.size():
		return {"cost": 0, "min_level": 99}
	var row = costs[index]
	if typeof(row) != TYPE_ARRAY or row.size() < 2:
		return {"cost": 0, "min_level": 99}
	var cost := _as_int(row[0])
	var min_level := _as_int(row[1])
	var effect: Dictionary = achievement.get("effect", {})
	if String(effect.get("type", "")) == "remove_flaw":
		cost = 0
	return {
		"cost": cost,
		"min_level": min_level,
	}


func achievement_purchase_cost(character: Dictionary, achievement: Dictionary, target_value := 0) -> int:
	var effect: Dictionary = achievement.get("effect", {})
	if String(effect.get("type", "")) == "remove_flaw":
		return max(0, _as_int(target_value)) * max(1, _as_int(effect.get("cost_multiplier", 2)))
	return _as_int(achievement_cost_entry(achievement, character).get("cost", 0))


func get_character_equipment_item(character: Dictionary, item_id: String) -> Dictionary:
	var catalog_item := get_equipment_item_by_id(item_id)
	if not catalog_item.is_empty():
		return catalog_item
	var equipment: Dictionary = character.get("equipment", {})
	for item in equipment.get("custom_items", []):
		if typeof(item) == TYPE_DICTIONARY and String(item.get("id", "")) == item_id:
			return item
	return {}


func equipment_source_options() -> Array:
	var result := []
	var seen := {}
	for source in equipment_sources:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		var source_id := String(source.get("id", source.get("name", ""))).to_lower()
		if source_id.is_empty() or seen.has(source_id):
			continue
		seen[source_id] = true
		result.append({
			"id": source_id,
			"name": String(source.get("name", source_id.capitalize())),
			"reference": String(source.get("reference", "")),
		})
	return result


func equipment_category_options() -> Array:
	return _equipment_string_options("category")


func equipment_class_options(category := "") -> Array:
	var options := []
	var seen := {}
	var category_filter := String(category)
	for item in equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if not category_filter.is_empty() and String(item.get("category", "")) != category_filter:
			continue
		var value := String(item.get("class", ""))
		if value.is_empty() or seen.has(value):
			continue
		seen[value] = true
		options.append(value)
	options.sort()
	return options


func filtered_equipment(filters: Dictionary) -> Array:
	var search := String(filters.get("search", "")).strip_edges().to_lower()
	var pl_min := _as_int(filters.get("pl_min", 0))
	var pl_max := _as_int(filters.get("pl_max", 8))
	if pl_min > pl_max:
		var swap := pl_min
		pl_min = pl_max
		pl_max = swap
	var category := String(filters.get("category", ""))
	var class_filter := String(filters.get("class", ""))
	var kind := String(filters.get("kind", ""))
	var source_filter: Dictionary = filters.get("sources", {})
	var use_source_filter := not source_filter.is_empty()
	var result := []

	for item in equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_pl := _as_int(item.get("pl", 0))
		if item_pl < pl_min or item_pl > pl_max:
			continue
		var source_id := String(item.get("source_code", item.get("source", ""))).to_lower()
		if use_source_filter and not bool(source_filter.get(source_id, false)):
			continue
		if not kind.is_empty() and String(item.get("kind", "")) != kind:
			continue
		if not category.is_empty() and String(item.get("category", "")) != category:
			continue
		if not class_filter.is_empty() and String(item.get("class", "")) != class_filter:
			continue
		if not search.is_empty() and not _equipment_matches_search(item, search):
			continue
		result.append(item)
	return result


func add_equipment_to_character(character: Dictionary, item_id: String, quantity := 1) -> String:
	_normalize_equipment(character)
	if get_character_equipment_item(character, item_id).is_empty():
		return ""
	var equipment: Dictionary = character.get("equipment", {})
	var carried: Array = equipment.get("carried", [])
	var line_id := _next_equipment_line_id(character)
	carried.append({
		"line_id": line_id,
		"item_id": item_id,
		"quantity": max(1, quantity),
		"equipped": false,
		"slot": "",
		"notes": "",
	})
	equipment["carried"] = carried
	character["equipment"] = equipment
	return line_id


func add_custom_equipment_to_character(character: Dictionary, item: Dictionary, quantity := 1) -> String:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var custom_items: Array = equipment.get("custom_items", [])
	var custom_item := _normalize_equipment_item(item.duplicate(true), _next_custom_equipment_id(character))
	custom_items.append(custom_item)
	equipment["custom_items"] = custom_items
	character["equipment"] = equipment
	return add_equipment_to_character(character, String(custom_item.get("id", "")), quantity)


func update_carried_equipment(character: Dictionary, line_id: String, quantity: int, equipped: bool, slot: String, notes: String) -> void:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var carried: Array = equipment.get("carried", [])
	for index in range(carried.size()):
		if typeof(carried[index]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = carried[index]
		if String(row.get("line_id", "")) != line_id:
			continue
		row["quantity"] = max(1, quantity)
		row["equipped"] = equipped
		row["slot"] = slot
		row["notes"] = notes
		carried[index] = row
		break
	equipment["carried"] = carried
	character["equipment"] = equipment


func update_custom_equipment_item(character: Dictionary, item_id: String, item: Dictionary) -> void:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var custom_items: Array = equipment.get("custom_items", [])
	for index in range(custom_items.size()):
		if typeof(custom_items[index]) != TYPE_DICTIONARY:
			continue
		var current: Dictionary = custom_items[index]
		if String(current.get("id", "")) != item_id:
			continue
		var normalized := _normalize_equipment_item(item.duplicate(true), item_id)
		normalized["id"] = item_id
		custom_items[index] = normalized
		break
	equipment["custom_items"] = custom_items
	character["equipment"] = equipment


func remove_carried_equipment(character: Dictionary, line_id: String) -> void:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var carried: Array = equipment.get("carried", [])
	var next_carried := []
	var removed_item_id := ""
	for row in carried:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if String(row.get("line_id", "")) == line_id:
			removed_item_id = String(row.get("item_id", ""))
			continue
		next_carried.append(row)
	equipment["carried"] = next_carried
	character["equipment"] = equipment
	_remove_unused_custom_equipment(character, removed_item_id)


func carried_equipment(character: Dictionary) -> Array:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var rows: Array = []
	for row in equipment.get("carried", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = get_character_equipment_item(character, String(row.get("item_id", "")))
		if item.is_empty():
			continue
		var quantity: int = max(1, _as_int(row.get("quantity", 1)))
		var result: Dictionary = row.duplicate(true)
		result["item"] = item
		result["quantity"] = quantity
		result["total_mass"] = _as_float(item.get("mass", 0.0)) * float(quantity)
		result["total_cost"] = _as_int(item.get("cost", 0)) * quantity
		rows.append(result)
	return rows


func equipment_summary(character: Dictionary) -> Dictionary:
	var rows := carried_equipment(character)
	var total_mass := 0.0
	var total_cost := 0
	var combat_weapons := []
	var combat_armor := []
	var equipped_weapons := []
	var equipped_armor := []
	for row in rows:
		total_mass += _as_float(row.get("total_mass", 0.0))
		total_cost += _as_int(row.get("total_cost", 0))
		var item: Dictionary = row.get("item", {})
		if equipment_has_combat_role(item, "weapon"):
			combat_weapons.append(row)
			if bool(row.get("equipped", false)):
				equipped_weapons.append(row)
		if equipment_has_combat_role(item, "armor"):
			combat_armor.append(row)
			if bool(row.get("equipped", false)):
				equipped_armor.append(row)
	for mutation_armor in mutation_armor_rows(character):
		combat_armor.append(mutation_armor)
		equipped_armor.append(mutation_armor)
	return {
		"carried_count": rows.size(),
		"total_mass": total_mass,
		"total_cost": total_cost,
		"combat_weapons": combat_weapons,
		"combat_armor": combat_armor,
		"equipped_weapons": equipped_weapons,
		"equipped_armor": equipped_armor,
		"attack_forms": attack_forms_for_character(character),
	}


func attack_forms_for_character(character: Dictionary) -> Array:
	var forms := [_unarmed_attack_form(character)]
	for row in carried_equipment(character):
		var item: Dictionary = row.get("item", {})
		if not equipment_has_combat_role(item, "weapon"):
			continue
		var form := _weapon_attack_form(character, item)
		form["quantity"] = _as_int(row.get("quantity", 1))
		form["equipped"] = bool(row.get("equipped", false))
		form["slot"] = String(row.get("slot", ""))
		forms.append(form)
	for form in mutation_attack_forms(character):
		forms.append(form)
	return forms


func equipment_has_combat_role(item: Dictionary, role: String) -> bool:
	var normalized_role := role.to_lower()
	if String(item.get("kind", "")).to_lower() == normalized_role:
		return true
	if String(item.get("combat_role", "")).to_lower() == normalized_role:
		return true
	var combat = item.get("combat", null)
	if typeof(combat) == TYPE_DICTIONARY and String(combat.get("role", "")).to_lower() == normalized_role:
		return true
	var roles = item.get("combat_roles", [])
	if typeof(roles) != TYPE_ARRAY:
		return false
	for entry in roles:
		if String(entry).to_lower() == normalized_role:
			return true
	return false


func _unarmed_attack_form(character: Dictionary) -> Dictionary:
	var score := _combat_skill_score(character, 15)
	var abilities := effective_abilities(character)
	var strength_bonus := strength_damage_bonus(_as_int(abilities.get("STR", 10)))
	return {
		"name": "Unarmed",
		"score": _score_text(score),
		"base_die": action_step_die(_as_int(score.get("step", 1))),
		"type": "LI/O",
		"range": "Personal",
		"damage": _damage_with_bonus("d4s/d4+1s/d4+2s", strength_bonus),
		"hide": "3",
		"clip_size": "-",
		"mass": "",
	}


func _weapon_attack_form(character: Dictionary, item: Dictionary) -> Dictionary:
	var combat_value = item.get("combat", {})
	var combat: Dictionary = combat_value if typeof(combat_value) == TYPE_DICTIONARY else {}
	var score := _combat_skill_score(character, _as_int(combat.get("skill_id", -1)))
	var accuracy := _as_int(combat.get("accuracy", 0))
	score["step"] = _as_int(score.get("step", 1)) + accuracy
	var damage := String(combat.get("damage", ""))
	if bool(combat.get("strength_based", false)):
		var abilities := effective_abilities(character)
		damage = _damage_with_bonus(damage, strength_damage_bonus(_as_int(abilities.get("STR", 10))))
	return {
		"name": String(item.get("name", "Weapon")),
		"score": _score_text(score),
		"base_die": action_step_die(_as_int(score.get("step", 0))),
		"type": String(combat.get("damage_type", combat.get("type", ""))),
		"range": String(combat.get("range", "")),
		"damage": damage,
		"hide": _dash_for_empty_or_hidden(combat.get("hide", "")),
		"clip_size": _dash_for_empty_or_zero(combat.get("clip_size", "")),
		"mass": _format_rules_number(_as_float(item.get("mass", 0.0))),
	}


func _combat_skill_score(character: Dictionary, skill_id: int) -> Dictionary:
	var skill := get_skill_by_id(skill_id)
	if skill.is_empty():
		return _untrained_combat_score(character, "STR", 1)

	var use_skill := skill
	var rank := skill_rank(character, skill_id)
	if rank <= 0:
		var broad_id := _as_int(skill.get("broad_id", skill_id))
		var broad := get_skill_by_id(broad_id)
		if String(skill.get("type", "")) == "specialty" and not broad.is_empty() and skill_rank(character, broad_id) > 0 and bool(skill.get("untrained", true)):
			use_skill = broad
		else:
			return _untrained_combat_score(character, String(skill.get("stat", "STR")), 1)

	var abilities := effective_abilities(character)
	var selected_skill_id := _as_int(use_skill.get("id", skill_id))
	var rank_bonus := 0 if String(use_skill.get("type", "")) == "broad" else skill_rank(character, selected_skill_id)
	var ordinary := _as_int(abilities.get(String(use_skill.get("stat", "STR")), 10)) + rank_bonus
	var step := 1 if String(use_skill.get("type", "")) == "broad" else 0
	step += _species_skill_step_bonus(character, selected_skill_id)
	step += mutation_skill_step_bonus(character, selected_skill_id)
	return _combat_score_from_ordinary(ordinary, step)


func _untrained_combat_score(character: Dictionary, ability: String, step: int) -> Dictionary:
	var abilities := effective_abilities(character)
	return _combat_score_from_ordinary(untrained_score(_as_int(abilities.get(ability, 10))), step)


func _combat_score_from_ordinary(ordinary: int, step: int) -> Dictionary:
	var good := int(floor(ordinary / 2.0))
	return {
		"ordinary": ordinary,
		"good": good,
		"amazing": int(floor(good / 2.0)),
		"step": step,
	}


func _score_text(score: Dictionary) -> String:
	return "%d/%d/%d" % [
		_as_int(score.get("ordinary", 0)),
		_as_int(score.get("good", 0)),
		_as_int(score.get("amazing", 0)),
	]


func strength_damage_bonus(score: int) -> int:
	if score <= 4:
		return -2
	if score <= 8:
		return -1
	if score <= 12:
		return 0
	if score <= 16:
		return 1
	return 2


func _damage_with_bonus(damage: String, bonus: int) -> String:
	if bonus == 0 or damage.strip_edges().is_empty():
		return damage
	var adjusted := []
	for segment in damage.split("/"):
		adjusted.append(_damage_segment_with_bonus(String(segment).strip_edges(), bonus))
	return "/".join(adjusted)


func _damage_segment_with_bonus(segment: String, bonus: int) -> String:
	if segment.length() < 2:
		return segment
	var suffix := segment.right(1)
	if not ["s", "w", "m"].has(suffix):
		return segment
	var core := segment.left(segment.length() - 1)
	var die_index := core.find("d")
	if die_index < 0:
		return segment
	var modifier_index := -1
	for index in range(die_index + 1, core.length()):
		var character := core.substr(index, 1)
		if character == "+" or character == "-":
			modifier_index = index
	var base := core
	var current_modifier := 0
	if modifier_index >= 0:
		base = core.left(modifier_index)
		current_modifier = _as_int(core.substr(modifier_index), 0)
	var next_modifier := current_modifier + bonus
	if next_modifier == 0:
		return "%s%s" % [base, suffix]
	var sign := "+" if next_modifier > 0 else ""
	return "%s%s%d%s" % [base, sign, next_modifier, suffix]


func _dash_for_empty_or_zero(value) -> String:
	if typeof(value) == TYPE_STRING:
		var text := String(value).strip_edges()
		if text.is_empty() or text == "0":
			return "-"
		if not text.is_valid_int() and not text.is_valid_float():
			return text
	if _as_int(value, 0) <= 0:
		return "-"
	return str(_as_int(value, 0))


func _dash_for_empty_or_hidden(value) -> String:
	if _as_int(value, -1000) <= -1000:
		return "-"
	return str(_as_int(value, 0))


func _format_rules_number(value: float) -> String:
	if is_equal_approx(value, float(int(value))):
		return str(int(value))
	return "%.2f" % value


func skill_name_for_id(skill_id: int) -> String:
	var skill := get_skill_by_id(skill_id)
	if not skill.is_empty():
		return skill_label(skill)
	return String(MISSING_SKILL_LABELS.get(skill_id, ""))


func get_perk_by_id(perk_id: String) -> Dictionary:
	return _get_character_option_by_id(PERK_DEFINITIONS, perk_id)


func get_flaw_by_id(flaw_id: String) -> Dictionary:
	return _get_character_option_by_id(FLAW_DEFINITIONS, flaw_id)


func get_free_skill_ids(character: Dictionary) -> Array:
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var result := []
	for skill_id in current_species.get("free_skill_ids", []):
		result.append(_as_int(skill_id))
	return result


func get_free_specialty_skill_ids(character: Dictionary) -> Array:
	var species_id := _as_int(character.get("species_id", 0))
	var result := []
	for skill_id in SPECIES_FREE_SPECIALTY_IDS.get(species_id, []):
		result.append(_as_int(skill_id))
	return result


func free_species_skill_rank(character: Dictionary, skill_id: int) -> int:
	var skill := get_skill_by_id(skill_id)
	if skill.is_empty():
		return 0
	if skill.get("type", "") == "broad" and get_free_skill_ids(character).has(skill_id):
		return 1
	if skill.get("type", "") == "specialty" and get_free_specialty_skill_ids(character).has(skill_id):
		return 1
	return 0


func species_rule_notes(character: Dictionary) -> Array:
	return _species_notes_for_character(character, SPECIES_RULE_NOTES)


func species_roll_notes_for_character(character: Dictionary) -> Array:
	return _species_notes_for_character(character, SPECIES_ROLL_NOTES)


func optional_rule_enabled(character: Dictionary, rule_id: String) -> bool:
	var optional_rules: Dictionary = character.get("optional_rules", {})
	return bool(optional_rules.get(rule_id, false))


func set_optional_rule(character: Dictionary, rule_id: String, enabled: bool) -> void:
	var optional_rules: Dictionary = character.get("optional_rules", {})
	optional_rules[rule_id] = enabled
	character["optional_rules"] = optional_rules


func base_abilities(character: Dictionary) -> Dictionary:
	return character.get("abilities", {})


func achievement_adjusted_abilities(character: Dictionary) -> Dictionary:
	var result := {}
	var abilities: Dictionary = character.get("abilities", {})
	for ability in ABILITIES:
		result[ability] = _as_int(abilities.get(ability, 10))
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) != "ability":
			continue
		var ability := String(effect.get("ability", ""))
		if not ABILITIES.has(ability):
			continue
		var limits := ability_limits(character, ability)
		result[ability] = clampi(_as_int(result.get(ability, 10)) + _as_int(effect.get("amount", 1)), _as_int(limits[0]), _as_int(limits[1]))
	return result


func effective_abilities(character: Dictionary) -> Dictionary:
	var result := achievement_adjusted_abilities(character)
	for ability in ABILITIES:
		result[ability] = max(1, _as_int(result.get(ability, 10)) + mutation_ability_bonus(character, ability))
	return result


func achievement_ability_bonus(character: Dictionary, ability: String) -> int:
	return _as_int(effective_abilities(character).get(ability, 10)) - _as_int(character.get("abilities", {}).get(ability, 10))


func ability_total(character: Dictionary) -> int:
	var total := 0
	var abilities: Dictionary = character.get("abilities", {})
	for ability in ABILITIES:
		total += _as_int(abilities.get(ability, 0))
	return total


func ability_point_total() -> int:
	return _as_int(data.get("ability_point_total", 60))


func profession_ability_minimums(character: Dictionary) -> Dictionary:
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var minimums: Dictionary = profession.get("ability_minimums", {})
	return minimums


func profession_ability_minimum(character: Dictionary, ability: String) -> int:
	return _as_int(profession_ability_minimums(character).get(ability, 0))


func ability_limits(character: Dictionary, ability: String) -> Array:
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var limits: Dictionary = current_species.get("ability_limits", {})
	var species_limits: Array = limits.get(ability, [4, 14])
	var minimum: int = max(_as_int(species_limits[0]), profession_ability_minimum(character, ability))
	var maximum: int = _as_int(species_limits[1])
	return [minimum, maximum]


func effective_ability_limits(character: Dictionary, ability: String) -> Array:
	var limits := ability_limits(character, ability)
	var bonus := mutation_ability_bonus(character, ability)
	var maximum: int = _as_int(limits[1]) + maxi(0, bonus)
	if bonus < 0:
		maximum += bonus
	return [_as_int(limits[0]), maximum]


func clamp_abilities_to_species(character: Dictionary) -> void:
	var abilities: Dictionary = character.get("abilities", {})
	for ability in ABILITIES:
		var limits := ability_limits(character, ability)
		abilities[ability] = clampi(_as_int(abilities.get(ability, 10)), _as_int(limits[0]), _as_int(limits[1]))
	character["abilities"] = abilities


func untrained_score(score: int) -> int:
	return int(floor(score / 2.0))


func resistance_modifier(score: int) -> int:
	if score <= 2:
		return -3
	if score <= 4:
		return -2
	if score <= 6:
		return -1
	if score <= 10:
		return 0
	if score <= 12:
		return 1
	if score <= 14:
		return 2
	return 3


func action_check(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var base := int(floor((_as_int(abilities.get("DEX", 10)) + _as_int(abilities.get("INT", 10))) / 2.0))
	var ordinary := base + _as_int(profession.get("action_bonus", 0)) + achievement_effect_total(character, "action_check_score")
	var good := int(floor(ordinary / 2.0))
	var amazing := int(floor(good / 2.0))
	var action_step := _as_int(current_species.get("action_step", 0)) + achievement_effect_total(character, "action_check_step") + mutation_action_check_step(character)
	return {
		"marginal": ordinary + 1,
		"ordinary": ordinary,
		"good": good,
		"amazing": amazing,
		"die": action_step_die(action_step),
		"actions": actions_per_round(character),
	}


func durability(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var constitution := _as_int(abilities.get("CON", 10))
	var multiplier := _as_float(current_species.get("durability_multiplier", 1.0))
	var durability_base := int(floor(constitution * multiplier))
	return {
		"stun": durability_base + achievement_durability_bonus(character, "stun") + mutation_durability_bonus(character, "stun"),
		"wound": durability_base + achievement_durability_bonus(character, "wound") + mutation_durability_bonus(character, "wound"),
		"mortal": int(ceil(durability_base / 2.0)) + achievement_durability_bonus(character, "mortal") + mutation_durability_bonus(character, "mortal"),
		"fatigue": int(ceil(durability_base / 2.0)) + achievement_durability_bonus(character, "fatigue") + mutation_durability_bonus(character, "fatigue"),
	}


func movement(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var movement_total := _as_int(abilities.get("STR", 10)) + _as_int(abilities.get("DEX", 10))
	var table_total := clampi(movement_total, 6, 32)
	if table_total % 2 != 0:
		table_total -= 1
	var sprint := table_total
	var run := _as_int(MOVEMENT_RUN_BY_TOTAL.get(table_total, 12))
	var mutation_movement := mutation_movement_modes(character)
	return {
		"total": movement_total,
		"sprint": sprint,
		"run": run,
		"walk": 4,
		"easy_swim": 2,
		"swim": 4,
		"glide": run if bool(current_species.get("can_glide", false)) or bool(mutation_movement.get("glide", false)) else "-",
		"fly": sprint if bool(current_species.get("can_fly", false)) or bool(mutation_movement.get("fly", false)) else "-",
		"effects": MOVEMENT_EFFECTS,
	}


func actions_per_round(character: Dictionary) -> int:
	var abilities := effective_abilities(character)
	var total := _as_int(abilities.get("CON", 10)) + _as_int(abilities.get("WIL", 10))
	var bonus := achievement_effect_total(character, "extra_action")
	var base := 1
	if total <= 15:
		base = 1
	elif total <= 24:
		base = 2
	elif total <= 32:
		base = 3
	else:
		base = 4
	return min(4, base + bonus)


func last_resorts(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var personality := _as_int(abilities.get("PER", 10))
	var base := _last_resort_base(personality)
	var bonus := _as_int(profession.get("last_resort_bonus", 0))
	var max_points := _as_int(base.get("max", 0)) + bonus
	var used := clampi(_as_int(character.get("last_resorts_used", 0)), 0, max_points)
	character["last_resorts_used"] = used
	return {
		"personality": personality,
		"base_max": _as_int(base.get("max", 0)),
		"profession_bonus": bonus,
		"max": max_points,
		"used": used,
		"available": max_points - used,
		"cost": _as_int(base.get("cost", 0)),
	}


func set_damage_used(character: Dictionary, damage_type: String, used: int) -> void:
	var damage: Dictionary = character.get("damage", {})
	var durability_scores := durability(character)
	damage[damage_type] = clampi(used, 0, _as_int(durability_scores.get(damage_type, 0)))
	character["damage"] = damage


func set_last_resorts_used(character: Dictionary, used: int) -> void:
	var current := last_resorts(character)
	character["last_resorts_used"] = clampi(used, 0, _as_int(current.get("max", 0)))


func clamp_trackers(character: Dictionary) -> void:
	var damage: Dictionary = character.get("damage", {})
	var durability_scores := durability(character)
	for damage_type in ["stun", "wound", "mortal", "fatigue"]:
		damage[damage_type] = clampi(_as_int(damage.get(damage_type, 0)), 0, _as_int(durability_scores.get(damage_type, 0)))
	character["damage"] = damage
	set_last_resorts_used(character, _as_int(character.get("last_resorts_used", 0)))


func starting_skill_budget(character: Dictionary) -> int:
	var abilities := effective_abilities(character)
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var flaw_bonus := flaw_skill_points_bonus(character)
	if optional_rule_enabled(character, "2a"):
		var human_bonus := _as_int(current_species.get("skill_points", 0)) if String(current_species.get("name", "")) == "Human" else 0
		return 30 + (3 * _as_int(abilities.get("INT", 10))) + human_bonus + flaw_bonus
	return _as_int(data.get("base_skill_points", 50)) + _as_int(abilities.get("INT", 10)) + _as_int(current_species.get("skill_points", 0)) + flaw_bonus


func skill_budget(character: Dictionary) -> int:
	return starting_skill_budget(character) + _as_int(character.get("achievement_points", 0)) + achievement_skill_bonus(character)


func max_broad_skills(character: Dictionary) -> int:
	var abilities := effective_abilities(character)
	if optional_rule_enabled(character, "2b"):
		return racial_broad_skills_count(character) + additional_broad_skill_limit(character)
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var base_allowance: int = max(0, _as_int(data.get("base_broad_skill_allowance", 2)) - 1)
	return _as_int(abilities.get("INT", 10)) + base_allowance + _as_int(current_species.get("broad_skills", 0))


func racial_broad_skills_count(character: Dictionary) -> int:
	var count := 0
	for skill_id in get_free_skill_ids(character):
		if not skill_name_for_id(skill_id).is_empty():
			count += 1
	return count


func additional_broad_skill_limit(character: Dictionary) -> int:
	var abilities := effective_abilities(character)
	if optional_rule_enabled(character, "2b"):
		var intelligence_rm := resistance_modifier(_as_int(abilities.get("INT", 10)))
		return max(0, 6 + intelligence_rm)
	return max(0, max_broad_skills(character) - racial_broad_skills_count(character))


func profession_codes(character: Dictionary) -> Array:
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var codes := []
	var code := String(profession.get("code", ""))
	var secondary_code := String(profession.get("secondary_code", ""))
	if not code.is_empty():
		codes.append(code)
	if not secondary_code.is_empty():
		codes.append(secondary_code)
	return codes


func skill_cost(character: Dictionary, skill: Dictionary) -> int:
	if skill.get("type", "") == "broad" and is_free_species_skill(character, _as_int(skill.get("id", -1))):
		return 0

	var cost := _as_int(skill.get("base_price", 0))
	var skill_professions := String(skill.get("professions", ""))
	for code in profession_codes(character):
		if skill_professions.contains(String(code)):
			cost -= 1
			break
	return max(1, cost)


func skill_purchase_cost(character: Dictionary, skill: Dictionary, next_rank: int = 1) -> int:
	var free_rank := free_species_skill_rank(character, _as_int(skill.get("id", -1)))
	if next_rank <= free_rank:
		return 0
	if skill.get("type", "") == "broad":
		return skill_cost(character, skill) if next_rank <= 1 else 0

	var base_cost := skill_cost(character, skill)
	if next_rank <= 1 or optional_rule_enabled(character, "2c"):
		return base_cost
	return base_cost + max(0, next_rank - 1)


func skill_rank_total_cost(character: Dictionary, skill: Dictionary) -> int:
	var skill_id := _as_int(skill.get("id", -1))
	var rank := skill_rank(character, skill_id)
	if rank <= 0:
		return 0
	var free_rank := free_species_skill_rank(character, skill_id)
	if rank <= free_rank:
		return 0
	if skill.get("type", "") == "broad":
		return skill_cost(character, skill)

	var total := 0
	for next_rank in range(free_rank + 1, rank + 1):
		total += skill_purchase_cost(character, skill, next_rank)
	return total


func next_skill_rank_cost(character: Dictionary, skill: Dictionary) -> int:
	var skill_id := _as_int(skill.get("id", -1))
	var rank := skill_rank(character, skill_id)
	if skill.get("type", "") == "broad":
		return skill_purchase_cost(character, skill, 1) if rank <= 0 else 0
	if rank >= MAX_SPECIALTY_RANK:
		return 0
	return skill_purchase_cost(character, skill, rank + 1)


func is_free_species_skill(character: Dictionary, skill_id: int) -> bool:
	return free_species_skill_rank(character, skill_id) > 0


func skill_rank(character: Dictionary, skill_id: int) -> int:
	var free_rank := free_species_skill_rank(character, skill_id)

	var selected: Dictionary = character.get("selected_skills", {})
	if not selected.has(str(skill_id)):
		return free_rank

	var skill := get_skill_by_id(skill_id)
	var rank := _selected_skill_entry_rank(selected.get(str(skill_id)))
	if skill.get("type", "") == "broad":
		return 1 if rank > 0 or free_rank > 0 else 0
	return max(free_rank, clampi(rank, 0, MAX_SPECIALTY_RANK))


func is_skill_selected(character: Dictionary, skill_id: int) -> bool:
	return skill_rank(character, skill_id) > 0


func set_skill_selected(character: Dictionary, skill_id: int, selected: bool) -> void:
	set_skill_rank(character, skill_id, 1 if selected else 0)


func set_skill_rank(character: Dictionary, skill_id: int, rank: int) -> void:
	var selected_skills: Dictionary = character.get("selected_skills", {})
	var skill := get_skill_by_id(skill_id)
	if skill.is_empty():
		return
	var free_rank := free_species_skill_rank(character, skill_id)
	if skill.get("type", "") == "broad" and free_rank > 0:
		return

	if rank > free_rank:
		selected_skills[str(skill_id)] = 1 if skill.get("type", "") == "broad" else clampi(rank, 1, MAX_SPECIALTY_RANK)
		if skill.get("type", "") == "specialty":
			var broad_id := _as_int(skill.get("broad_id", -1))
			if not is_free_species_skill(character, broad_id):
				selected_skills[str(broad_id)] = 1
	else:
		selected_skills.erase(str(skill_id))
		if skill.get("type", "") == "broad":
			for specialty in specialty_skills_by_broad_id.get(skill_id, []):
				selected_skills.erase(str(_as_int(specialty.get("id", -1))))
	character["selected_skills"] = selected_skills


func change_skill_rank(character: Dictionary, skill_id: int, delta: int) -> void:
	set_skill_rank(character, skill_id, skill_rank(character, skill_id) + delta)


func set_perk_selected(character: Dictionary, perk_id: String, cost: int) -> void:
	_set_character_option_selected(character, "selected_perks", PERK_DEFINITIONS, "cost_options", perk_id, cost)


func set_flaw_selected(character: Dictionary, flaw_id: String, bonus: int) -> void:
	_set_character_option_selected(character, "selected_flaws", FLAW_DEFINITIONS, "bonus_options", flaw_id, bonus)


func selected_achievements(character: Dictionary) -> Array:
	var rows := []
	var selected: Array = character.get("selected_achievements", [])
	for entry_value in selected:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var achievement_id := String(entry.get("achievement_id", ""))
		var achievement := get_achievement_by_id(achievement_id)
		if achievement.is_empty():
			continue
		var row := entry.duplicate(true)
		row["achievement"] = achievement
		row["cost"] = _as_int(row.get("cost", achievement_purchase_cost(character, achievement, row.get("target_value", 0))))
		row["name"] = achievement_display_name(achievement, row)
		row["summary"] = achievement_effect_summary(achievement, row)
		rows.append(row)
	return rows


func achievement_purchase_count(character: Dictionary, achievement_id: String) -> int:
	var count := 0
	for entry in selected_achievements(character):
		if String(entry.get("achievement_id", "")) == achievement_id:
			count += 1
	return count


func achievement_effect_total(character: Dictionary, effect_type: String) -> int:
	var total := 0
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == effect_type:
			total += _as_int(effect.get("amount", 1))
	return total


func achievement_durability_bonus(character: Dictionary, track: String) -> int:
	var total := 0
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == "durability" and String(effect.get("track", "")) == track:
			total += _as_int(effect.get("amount", 1))
	return total


func achievement_points_spent(character: Dictionary) -> int:
	var total := 0
	for entry in selected_achievements(character):
		total += _as_int(entry.get("cost", 0))
	return total


func achievement_granted_perk_ids(character: Dictionary) -> Array:
	var ids := []
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) != "new_perk":
			continue
		var perk_id := String(effect.get("perk_id", ""))
		if not perk_id.is_empty() and not ids.has(perk_id):
			ids.append(perk_id)
	return ids


func is_perk_granted_by_achievement(character: Dictionary, perk_id: String) -> bool:
	return achievement_granted_perk_ids(character).has(perk_id)


func achievement_granted_perks(character: Dictionary) -> Array:
	var rows := []
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) != "new_perk":
			continue
		var perk := get_perk_by_id(String(effect.get("perk_id", "")))
		if perk.is_empty():
			continue
		var row := perk.duplicate(true)
		row["cost"] = 0
		row["granted_by_achievement"] = true
		row["achievement_name"] = String(achievement.get("name", "Achievement"))
		row["perk_value"] = _as_int(effect.get("perk_value", 0))
		rows.append(row)
	return rows


func can_purchase_achievement(character: Dictionary, achievement: Dictionary, target_id := "", target_value := 0) -> Dictionary:
	var achievement_id := String(achievement.get("id", ""))
	var cost_info := achievement_cost_entry(achievement, character)
	var min_level := _as_int(cost_info.get("min_level", 99))
	var current_level := achievement_level_for_points(_as_int(character.get("achievement_points", 0)))
	if current_level < min_level:
		return {"allowed": false, "reason": "Requires hero level %d." % min_level}

	var effect: Dictionary = achievement.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	var max_purchases := _as_int(achievement.get("max", 1))
	if effect_type == "monetary":
		var eligible_levels: Array = effect.get("levels", [])
		var eligible_count := 0
		for level_value in eligible_levels:
			if current_level >= _as_int(level_value):
				eligible_count += 1
		max_purchases = eligible_count
	if effect_type != "remove_flaw" and max_purchases >= 0 and achievement_purchase_count(character, achievement_id) >= max_purchases:
		return {"allowed": false, "reason": "Maximum purchases reached."}

	if effect_type == "ability":
		var ability := String(effect.get("ability", ""))
		var tier := _as_int(effect.get("tier", 1))
		if tier > 1 and achievement_ability_purchase_count(character, ability) < tier - 1:
			return {"allowed": false, "reason": "%s Increase %d requires the previous increase first." % [ability, tier]}
		var abilities := achievement_adjusted_abilities(character)
		var limits := ability_limits(character, ability)
		if _as_int(abilities.get(ability, 10)) >= _as_int(limits[1]):
			return {"allowed": false, "reason": "%s is already at the species maximum." % ability}
	if effect_type == "extra_action" and actions_per_round(character) >= 4:
		return {"allowed": false, "reason": "Actions per round are already at the maximum of 4."}
	if effect_type == "new_perk":
		var perk_id := String(effect.get("perk_id", ""))
		if is_perk_selected(character, perk_id):
			return {"allowed": false, "reason": "That perk is already selected."}
		if selected_perk_count(character) >= 3:
			return {"allowed": false, "reason": "The hero already has three perks."}
	if effect_type == "remove_flaw":
		if String(target_id).is_empty():
			return {"allowed": false, "reason": "Choose a flaw to remove."}
		if not is_flaw_selected(character, String(target_id)):
			return {"allowed": false, "reason": "That flaw is not currently selected."}
		for entry in selected_achievements(character):
			var prior_achievement: Dictionary = entry.get("achievement", {})
			var prior_effect: Dictionary = prior_achievement.get("effect", {})
			if String(prior_effect.get("type", "")) == "remove_flaw" and String(entry.get("target_id", "")) == String(target_id):
				return {"allowed": false, "reason": "That flaw has already been removed."}

	var cost := achievement_purchase_cost(character, achievement, target_value)
	var available_points := skill_budget(character) - skill_points_used(character)
	if effect_type == "remove_flaw":
		available_points -= max(0, _as_int(target_value))
	if available_points < cost:
		return {"allowed": false, "reason": "Requires %d available skill points." % cost}
	return {"allowed": true, "reason": "", "cost": cost, "min_level": min_level}


func achievement_ability_purchase_count(character: Dictionary, ability: String) -> int:
	var count := 0
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == "ability" and String(effect.get("ability", "")) == ability:
			count += 1
	return count


func add_achievement_purchase(character: Dictionary, achievement_id: String, target_id := "", target_value := 0, notes := "") -> Dictionary:
	var achievement := get_achievement_by_id(achievement_id)
	if achievement.is_empty():
		return {"ok": false, "reason": "Unknown achievement."}
	var cost := achievement_purchase_cost(character, achievement, target_value)
	var check := can_purchase_achievement(character, achievement, target_id, target_value)
	if not bool(check.get("allowed", false)):
		return {"ok": false, "reason": String(check.get("reason", ""))}

	var selected: Array = character.get("selected_achievements", [])
	var line_id := _next_achievement_line_id_from_list(selected)
	var entry := {
		"line_id": line_id,
		"achievement_id": achievement_id,
		"cost": cost,
		"level": achievement_level_for_points(_as_int(character.get("achievement_points", 0))),
		"target_id": String(target_id),
		"target_value": _as_int(target_value),
		"notes": String(notes),
	}
	selected.append(entry)
	character["selected_achievements"] = selected

	var effect: Dictionary = achievement.get("effect", {})
	if String(effect.get("type", "")) == "remove_flaw" and not String(target_id).is_empty():
		var flaws: Dictionary = character.get("selected_flaws", {})
		flaws.erase(String(target_id))
		character["selected_flaws"] = flaws
	clamp_trackers(character)
	return {"ok": true, "line_id": line_id}


func remove_achievement_purchase(character: Dictionary, line_id: String) -> void:
	var selected: Array = character.get("selected_achievements", [])
	var next := []
	for entry_value in selected:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("line_id", "")) == line_id:
			var achievement := get_achievement_by_id(String(entry.get("achievement_id", "")))
			var effect: Dictionary = achievement.get("effect", {})
			if String(effect.get("type", "")) == "remove_flaw":
				var target_id := String(entry.get("target_id", ""))
				var target_value := _as_int(entry.get("target_value", 0))
				if not target_id.is_empty() and target_value > 0:
					var flaws: Dictionary = character.get("selected_flaws", {})
					flaws[target_id] = target_value
					character["selected_flaws"] = flaws
			continue
		next.append(entry)
	character["selected_achievements"] = next
	clamp_trackers(character)


func achievement_display_name(achievement: Dictionary, entry: Dictionary = {}) -> String:
	var effect: Dictionary = achievement.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	if effect_type == "remove_flaw":
		var flaw := get_flaw_by_id(String(entry.get("target_id", "")))
		if not flaw.is_empty():
			return "Remove Flaw: %s" % String(flaw.get("name", "Flaw"))
	if effect_type == "contact" and not String(entry.get("notes", "")).strip_edges().is_empty():
		return "%s: %s" % [String(achievement.get("name", "")), String(entry.get("notes", "")).strip_edges()]
	return String(achievement.get("name", "Achievement"))


func achievement_effect_summary(achievement: Dictionary, entry: Dictionary = {}) -> String:
	var effect: Dictionary = achievement.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	if effect_type == "new_perk":
		var perk := get_perk_by_id(String(effect.get("perk_id", "")))
		if not perk.is_empty():
			return "Grants %s as a %d-point perk without charging the normal perk cost." % [
				String(perk.get("name", "Perk")),
				_as_int(effect.get("perk_value", 0)),
			]
	if effect_type == "remove_flaw":
		var flaw := get_flaw_by_id(String(entry.get("target_id", "")))
		if not flaw.is_empty():
			return "Removes %s and its +%d skill point flaw bonus." % [
				String(flaw.get("name", "Flaw")),
				_as_int(entry.get("target_value", 0)),
			]
	if effect_type == "contact":
		return "Adds one campaign contact. Contacts provide information, resources, or expert help when the GM agrees."
	return String(achievement.get("summary", ""))


func mutation_ability_bonus(character: Dictionary, ability: String) -> int:
	var total := 0
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "ability"):
			if String(effect.get("ability", "")) == ability:
				total += _as_int(effect.get("amount", 0))
	return total


func mutation_durability_bonus(character: Dictionary, track: String) -> int:
	var total := 0
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "durability"):
			if String(effect.get("track", "")) == track:
				total += _as_int(effect.get("amount", 0))
	return total


func mutation_action_check_step(character: Dictionary) -> int:
	var total := 0
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "action_check_step"):
			total += _as_int(effect.get("amount", 0))
	return total


func mutation_skill_step_bonus(character: Dictionary, skill_id: int) -> int:
	var total := 0
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "skill_step"):
			var skill_ids: Array = effect.get("skill_ids", [])
			for effect_skill_id in skill_ids:
				if _as_int(effect_skill_id) == skill_id:
					total += _as_int(effect.get("step", 0))
	return total


func mutation_movement_modes(character: Dictionary) -> Dictionary:
	var result := {}
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "movement"):
			var modes: Array = effect.get("modes", [])
			for mode in modes:
				result[String(mode)] = true
			if bool(effect.get("glide", false)):
				result["glide"] = true
			if bool(effect.get("fly", false)):
				result["fly"] = true
	return result


func mutation_roll_notes_for_character(character: Dictionary) -> Array:
	var notes := []
	if not mutations_enabled(character):
		return notes
	for mutation in _selected_mutation_effect_sources(character):
		for effect_type in ["roll_note", "damage_note"]:
			for effect in _mutation_effects(mutation, effect_type):
				var text := String(effect.get("text", "")).strip_edges()
				if text.is_empty():
					continue
				notes.append("%s: %s Source: %s" % [
					String(mutation.get("name", "Mutation")),
					text,
					String(mutation.get("reference", "")),
				])
	return _unique_strings(notes)


func mutation_armor_rows(character: Dictionary) -> Array:
	var rows := []
	if not mutations_enabled(character):
		return rows
	for mutation in selected_mutation_advantages(character):
		for effect in _mutation_effects(mutation, "armor"):
			var item := {
				"id": "mutation_%s" % String(mutation.get("id", "")),
				"kind": "armor",
				"name": String(mutation.get("name", "Mutation Armor")),
				"source": "Mutation",
				"source_code": "mutation",
				"reference": String(mutation.get("reference", "")),
				"category": "Mutation",
				"class": "Natural Armor",
				"availability": "-",
				"mass": 0,
				"cost": 0,
				"combat": {
					"role": "armor",
					"action_penalty": _as_int(effect.get("ap", 0)),
					"toughness": String(effect.get("toughness", "O")),
					"li": String(effect.get("li", "")),
					"hi": String(effect.get("hi", "")),
					"en": String(effect.get("en", "")),
				},
			}
			rows.append({
				"line_id": "mutation_%s" % String(mutation.get("id", "")),
				"item_id": String(item.get("id", "")),
				"quantity": 1,
				"equipped": true,
				"slot": "Mutation",
				"notes": String(mutation.get("summary", "")),
				"item": item,
				"total_mass": 0,
				"total_cost": 0,
			})
	return rows


func mutation_attack_forms(character: Dictionary) -> Array:
	var forms := []
	if not mutations_enabled(character):
		return forms
	for mutation in selected_mutation_advantages(character):
		for effect in _mutation_effects(mutation, "attack"):
			var skill_id := _as_int(effect.get("skill_id", 16))
			var score := _combat_skill_score(character, skill_id)
			score["step"] = _as_int(score.get("step", 0)) + _as_int(effect.get("step", 0))
			var damage := String(effect.get("damage", ""))
			if bool(effect.get("strength_bonus", false)):
				var abilities := effective_abilities(character)
				damage = _damage_with_bonus(damage, strength_damage_bonus(_as_int(abilities.get("STR", 10))))
			var form := {
				"name": String(effect.get("name", mutation.get("name", "Mutation Attack"))),
				"score": _score_text(score),
				"base_die": action_step_die(_as_int(score.get("step", 0))),
				"type": String(effect.get("damage_type", "")),
				"range": String(effect.get("range", "Personal")),
				"damage": damage,
				"hide": String(effect.get("hide", "-")),
				"clip_size": String(effect.get("clip_size", "-")),
				"mass": "",
				"mutation": String(mutation.get("name", "")),
				"note": String(effect.get("note", "")),
			}
			forms.append(form)
	return forms


func is_perk_selected(character: Dictionary, perk_id: String) -> bool:
	var selected: Dictionary = character.get("selected_perks", {})
	return selected.has(perk_id) or is_perk_granted_by_achievement(character, perk_id)


func is_flaw_selected(character: Dictionary, flaw_id: String) -> bool:
	var selected: Dictionary = character.get("selected_flaws", {})
	return selected.has(flaw_id)


func perk_cost_selected(character: Dictionary, perk_id: String) -> int:
	var selected: Dictionary = character.get("selected_perks", {})
	return _as_int(selected.get(perk_id, 0))


func flaw_bonus_selected(character: Dictionary, flaw_id: String) -> int:
	var selected: Dictionary = character.get("selected_flaws", {})
	return _as_int(selected.get(flaw_id, 0))


func selected_perks(character: Dictionary) -> Array:
	var rows := _selected_character_options(character, "selected_perks", PERK_DEFINITIONS, "cost")
	for granted in achievement_granted_perks(character):
		var granted_id := String(granted.get("id", ""))
		var already_listed := false
		for row in rows:
			if String(row.get("id", "")) == granted_id:
				already_listed = true
		if not already_listed:
			rows.append(granted)
	return rows


func selected_flaws(character: Dictionary) -> Array:
	return _selected_character_options(character, "selected_flaws", FLAW_DEFINITIONS, "bonus")


func perk_points_used(character: Dictionary) -> int:
	var total := 0
	for perk in _selected_character_options(character, "selected_perks", PERK_DEFINITIONS, "cost"):
		total += _as_int(perk.get("cost", 0))
	return total


func flaw_skill_points_bonus(character: Dictionary) -> int:
	var total := 0
	for flaw in selected_flaws(character):
		total += _as_int(flaw.get("bonus", 0))
	return total


func selected_perk_count(character: Dictionary) -> int:
	return selected_perks(character).size()


func selected_flaw_count(character: Dictionary) -> int:
	return selected_flaws(character).size()


func skill_purchase_points_used(character: Dictionary) -> int:
	var selected: Dictionary = character.get("selected_skills", {})
	var used := 0
	for key in selected.keys():
		var skill := get_skill_by_id(_as_int(key))
		if skill.is_empty():
			continue
		used += skill_rank_total_cost(character, skill)
	return used


func skill_points_used(character: Dictionary) -> int:
	return skill_purchase_points_used(character) + perk_points_used(character) + achievement_points_spent(character)


func broad_skills_used(character: Dictionary) -> int:
	var used_ids := {}
	for skill_id in get_free_skill_ids(character):
		if not skill_name_for_id(skill_id).is_empty():
			used_ids[_as_int(skill_id)] = true

	var selected: Dictionary = character.get("selected_skills", {})
	for key in selected.keys():
		var skill := get_skill_by_id(_as_int(key))
		if skill.get("type", "") == "broad":
			used_ids[_as_int(skill.get("id", -1))] = true
	return used_ids.size()


func additional_broad_skills_used(character: Dictionary) -> int:
	var used_ids := {}
	var selected: Dictionary = character.get("selected_skills", {})
	for key in selected.keys():
		var skill := get_skill_by_id(_as_int(key))
		if skill.get("type", "") == "broad" and not is_free_species_skill(character, _as_int(skill.get("id", -1))):
			used_ids[_as_int(skill.get("id", -1))] = true
	return used_ids.size()


func selected_skill_ids(character: Dictionary) -> Array:
	var ids := []
	for skill_id in get_free_skill_ids(character):
		if not ids.has(skill_id):
			ids.append(skill_id)
	for skill_id in get_free_specialty_skill_ids(character):
		if not ids.has(skill_id):
			ids.append(skill_id)

	var selected: Dictionary = character.get("selected_skills", {})
	for key in selected.keys():
		var id := _as_int(key)
		if not ids.has(id):
			ids.append(id)

	ids.sort()
	return ids


func selected_skills(character: Dictionary) -> Array:
	var rows := []
	for skill_id in selected_skill_ids(character):
		var skill := get_skill_by_id(skill_id)
		if skill.is_empty():
			continue
		var row := skill.duplicate(true)
		row["rank"] = skill_rank(character, skill_id)
		row["cost"] = skill_rank_total_cost(character, skill)
		row["next_cost"] = next_skill_rank_cost(character, skill)
		row["free"] = is_free_species_skill(character, skill_id)
		row["free_rank"] = free_species_skill_rank(character, skill_id)
		row["score"] = skill_score(character, skill)
		rows.append(row)
	return rows


func skill_score(character: Dictionary, skill: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var skill_id := _as_int(skill.get("id", -1))
	var ability := String(skill.get("stat", "STR"))
	var rank_bonus := 0 if skill.get("type", "") == "broad" else skill_rank(character, skill_id)
	var ordinary := _as_int(abilities.get(ability, 10)) + rank_bonus
	var good := int(floor(ordinary / 2.0))
	var step := 1 if skill.get("type", "") == "broad" else 0
	step += _species_skill_step_bonus(character, skill_id)
	step += mutation_skill_step_bonus(character, skill_id)
	return {
		"ordinary": ordinary,
		"good": good,
		"amazing": int(floor(good / 2.0)),
		"die": action_step_die(step),
	}


func _species_skill_step_bonus(character: Dictionary, skill_id: int) -> int:
	var species_id := _as_int(character.get("species_id", 0))
	if species_id == 2 and (skill_id == 62 or skill_id == 70):
		return -1
	if species_id == 4 and skill_id == 116:
		return -1
	return 0


func validate(character: Dictionary) -> Array:
	var messages := []
	var total := ability_total(character)
	var target := ability_point_total()
	if total != target:
		messages.append("Ability total must be %d; current total is %d." % [target, total])

	var abilities: Dictionary = character.get("abilities", {})
	for ability in ABILITIES:
		var limits := ability_limits(character, ability)
		var score := _as_int(abilities.get(ability, 0))
		if score < _as_int(limits[0]) or score > _as_int(limits[1]):
			messages.append("%s must be between %d and %d for this species and profession. Source: Player's Handbook Tables P1 and P3." % [ability, _as_int(limits[0]), _as_int(limits[1])])
		var achievement_adjusted_score := _as_int(achievement_adjusted_abilities(character).get(ability, score))
		if achievement_adjusted_score > _as_int(limits[1]):
			messages.append("%s achievement increases exceed the species maximum of %d." % [ability, _as_int(limits[1])])

	var remaining := skill_budget(character) - skill_points_used(character)
	if remaining < 0:
		messages.append("Skill points are overspent by %d." % abs(remaining))

	if selected_perk_count(character) > 3:
		messages.append("A starting hero can have no more than three perks. Source: Player's Handbook p. 103.")

	if selected_flaw_count(character) > 3:
		messages.append("A starting hero can have no more than three flaws. Source: Player's Handbook p. 107.")

	if optional_rule_enabled(character, "2b"):
		var additional_broad_remaining := additional_broad_skill_limit(character) - additional_broad_skills_used(character)
		if additional_broad_remaining < 0:
			messages.append("Additional broad skills exceed Optional Rule 2B by %d." % abs(additional_broad_remaining))
	else:
		var broad_remaining := max_broad_skills(character) - broad_skills_used(character)
		if broad_remaining < 0:
			messages.append("Broad skills exceed the allowed maximum by %d." % abs(broad_remaining))

	var selected: Dictionary = character.get("selected_skills", {})
	for key in selected.keys():
		var skill := get_skill_by_id(_as_int(key))
		var rank := skill_rank(character, _as_int(key))
		if skill.get("type", "") == "specialty" and rank > MAX_SPECIALTY_RANK:
			messages.append("%s cannot exceed rank %d." % [skill_label(skill), MAX_SPECIALTY_RANK])
		if skill.get("type", "") != "specialty":
			continue
		var broad_id := _as_int(skill.get("broad_id", -1))
		if not is_skill_selected(character, broad_id):
			var broad_skill := get_skill_by_id(broad_id)
			messages.append("%s requires the %s broad skill." % [skill.get("name", "Specialty"), broad_skill.get("name", "parent")])

	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var min_level := _as_int(achievement_cost_entry(achievement, character).get("min_level", 99))
		var bought_level := _as_int(entry.get("level", 1))
		if bought_level < min_level:
			messages.append("%s requires hero level %d for the current profession." % [String(entry.get("name", achievement.get("name", "Achievement"))), min_level])
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == "remove_flaw" and String(entry.get("target_id", "")).is_empty():
			messages.append("Remove Flaw requires a selected flaw target.")

	if mutations_enabled(character):
		var advantages := selected_mutation_advantages(character)
		var drawbacks := selected_mutation_drawbacks(character)
		if advantages.is_empty():
			messages.append("A mutant hero must have at least one advantageous mutation. Source: Player's Handbook p. 214.")
		if drawbacks.is_empty():
			messages.append("A mutant hero must have at least one mutation drawback. Source: Player's Handbook p. 214.")
		if mutation_advantage_points_remaining(character) < 0:
			messages.append("Advantageous mutation points are overspent by %d." % abs(mutation_advantage_points_remaining(character)))
		if mutation_drawback_points_remaining(character) < 0:
			messages.append("Mutation drawback points are overspent by %d." % abs(mutation_drawback_points_remaining(character)))
		for tier in ["Ordinary", "Good", "Amazing"]:
			var cap := _mutation_advantage_tier_cap(tier)
			var count := _mutation_tier_count(advantages, tier)
			var allowed_count := _as_int(mutation_distribution(character, "advantage").get(tier, 0))
			if count > allowed_count:
				messages.append("Advantageous mutations exceed the selected point distribution for %s by %d." % [tier, count - allowed_count])
			if cap > 0 and count > cap:
				messages.append("A mutant can have no more than %d %s advantageous mutation%s. Source: Player's Handbook p. 216." % [cap, tier, "" if cap == 1 else "s"])
		for tier in ["Slight", "Moderate", "Extreme"]:
			var count := _mutation_tier_count(drawbacks, tier)
			var allowed_count := _as_int(mutation_distribution(character, "drawback").get(tier, 0))
			if count > allowed_count:
				messages.append("Mutation drawbacks exceed the selected point distribution for %s by %d." % [tier, count - allowed_count])

	return messages


func summary(character: Dictionary) -> Dictionary:
	ensure_character_shape(character)
	var used_points := skill_points_used(character)
	var broad_used := broad_skills_used(character)
	var additional_broad_used := additional_broad_skills_used(character)
	var additional_broad_max := additional_broad_skill_limit(character)
	var achievement_points := _as_int(character.get("achievement_points", 0))
	var achievement_used := achievement_points_used(character)
	var achievement_available := achievement_points_available(character)
	var perk_points := perk_points_used(character)
	var flaw_bonus := flaw_skill_points_bonus(character)
	var skill_purchase_points := skill_purchase_points_used(character)
	var achievement_spending := achievement_points_spent(character)
	character["achievement_points_available"] = achievement_available
	return {
		"achievement_level": achievement_level_for_points(achievement_points),
		"achievement_points": achievement_points,
		"achievement_points_used": achievement_used,
		"achievement_points_available": achievement_available,
		"achievement_next_level_points": achievement_next_level_points(achievement_points),
		"achievement_skill_bonus": achievement_skill_bonus(character),
		"starting_skill_budget": starting_skill_budget(character),
		"ability_total": ability_total(character),
		"ability_target": ability_point_total(),
		"effective_abilities": effective_abilities(character),
		"skill_budget": skill_budget(character),
		"skill_points_used": used_points,
		"skill_purchase_points_used": skill_purchase_points,
		"skill_points_remaining": skill_budget(character) - used_points,
		"achievement_benefit_points_used": achievement_spending,
		"selected_achievements": selected_achievements(character),
		"perk_points_used": perk_points,
		"perk_count": selected_perk_count(character),
		"flaw_skill_points_bonus": flaw_bonus,
		"flaw_count": selected_flaw_count(character),
		"broad_skills_used": broad_used,
		"max_broad_skills": max_broad_skills(character),
		"broad_skills_remaining": max_broad_skills(character) - broad_used,
		"racial_broad_skills": racial_broad_skills_count(character),
		"additional_broad_skills_used": additional_broad_used,
		"additional_broad_skill_limit": additional_broad_max,
		"additional_broad_skills_remaining": additional_broad_max - additional_broad_used,
		"action_check": action_check(character),
		"durability": durability(character),
		"movement": movement(character),
		"last_resorts": last_resorts(character),
		"equipment": equipment_summary(character),
		"mutations": mutation_summary(character),
		"validations": validate(character),
	}


func skill_detail(skill: Dictionary, character: Dictionary = {}) -> Dictionary:
	var skill_id := _as_int(skill.get("id", -1))
	var broad := get_skill_by_id(_as_int(skill.get("broad_id", skill_id)))
	var type_label := "Broad skill" if skill.get("type", "") == "broad" else "Specialty skill"
	var ability := String(skill.get("stat", "STR"))
	var current_rank := skill_rank(character, skill_id) if not character.is_empty() else 0
	var summary_text := _skill_summary(skill)
	var roll_notes := _skill_roll_notes(skill)
	var complex_note := String(COMPLEX_SKILL_NOTES.get(skill_id, ""))
	var rank_benefits: Dictionary = RANK_BENEFIT_NOTES.get(skill_id, {})

	return {
		"id": skill_id,
		"name": skill_label(skill),
		"type_label": type_label,
		"ability": ability,
		"ability_name": ABILITY_NAMES.get(ability, ability),
		"broad_name": String(broad.get("name", "")),
		"rank": current_rank,
		"max_rank": MAX_SPECIALTY_RANK if skill.get("type", "") == "specialty" else 1,
		"base_price": _as_int(skill.get("base_price", 0)),
		"rank_one_cost": skill_cost(character, skill) if not character.is_empty() else _as_int(skill.get("base_price", 0)),
		"next_cost": next_skill_rank_cost(character, skill) if not character.is_empty() else _as_int(skill.get("base_price", 0)),
		"profession_codes": String(skill.get("professions", "")),
		"untrained": bool(skill.get("untrained", true)),
		"multi": bool(skill.get("multi", false)),
		"custom_name": bool(skill.get("custom_name", false)),
		"summary": summary_text,
		"roll_notes": roll_notes,
		"complex_check": complex_note,
		"rank_benefits": rank_benefits,
		"sources": _skill_sources(skill),
	}


func _skill_sources(skill: Dictionary) -> Array:
	var skill_id := _as_int(skill.get("id", -1))
	var broad_id := _as_int(skill.get("broad_id", skill_id))
	var sources := []
	if SKILL_SOURCE_REFERENCES.has(skill_id):
		sources.append_array(SKILL_SOURCE_REFERENCES[skill_id])
	elif SKILL_SOURCE_REFERENCES.has(broad_id):
		sources.append_array(SKILL_SOURCE_REFERENCES[broad_id])
	else:
		sources.append("Player's Handbook Chapter 4.")
	return _unique_strings(sources)


func skill_roll_notes_for_character(character: Dictionary) -> Array:
	var notes := []
	var selected := selected_skills(character)

	if not selected.is_empty():
		notes.append("Broad skills roll the ability score with a +d4 base situation die; specialty skills roll ability + rank with +d0. %s" % CORE_SKILL_ROLL_SOURCE)
		notes.append("A trained broad skill can be used for related specialties at the broad skill score unless the specialty is prohibited from untrained use. %s" % CORE_SKILL_ROLL_SOURCE)

	for note in species_roll_notes_for_character(character):
		notes.append(String(note))
	for note in mutation_roll_notes_for_character(character):
		notes.append(String(note))
	if selected.is_empty():
		return _unique_strings(notes)

	for skill in selected:
		var skill_id := _as_int(skill.get("id", -1))
		var complex_note := String(COMPLEX_SKILL_NOTES.get(skill_id, ""))
		if not complex_note.is_empty():
			notes.append("%s: %s %s %s %s" % [
				skill_label(skill),
				complex_note,
				COMPLEX_CHECK_RULES["successes"],
				COMPLEX_CHECK_RULES["failures"],
				COMPLEX_CHECK_SOURCE,
			])

		for note in _skill_summary_roll_notes(skill):
			notes.append("%s: %s" % [skill_label(skill), note])

	return _unique_strings(notes)


func skill_rank_benefit_summary(character: Dictionary) -> Array:
	var notes := []
	for group in skill_rank_benefit_groups(character):
		for entry in group.get("entries", []):
			notes.append("%s rank %d: %s" % [
				String(group.get("skill", "")),
				_as_int(entry.get("rank", 0)),
				String(entry.get("text", "")),
			])
	return notes


func skill_rank_benefit_groups(character: Dictionary) -> Array:
	var groups := []
	for skill in selected_skills(character):
		var skill_id := _as_int(skill.get("id", -1))
		var benefits: Dictionary = RANK_BENEFIT_NOTES.get(skill_id, {})
		if benefits.is_empty():
			continue

		var rank := _as_int(skill.get("rank", skill_rank(character, skill_id)))
		var entries := []
		var thresholds := benefits.keys()
		thresholds.sort()
		for threshold in thresholds:
			var required_rank := _as_int(threshold)
			if rank >= required_rank:
				entries.append({
					"rank": required_rank,
					"text": String(benefits[threshold]),
				})
		if not entries.is_empty():
			groups.append({
				"skill": skill_label(skill),
				"entries": entries,
			})
	return groups


func action_step_die(step: int) -> String:
	var step_dice := {
		-4: "-d20",
		-3: "-d12",
		-2: "-d8",
		-1: "-d4",
		0: "+d0",
		1: "+d4",
		2: "+d6",
		3: "+d8",
		4: "+d12",
		5: "+d20",
	}
	return step_dice.get(step, "+d0")


func skill_label(skill: Dictionary) -> String:
	if skill.get("type", "") == "broad":
		return String(skill.get("name", ""))
	var broad := get_skill_by_id(_as_int(skill.get("broad_id", -1)))
	if broad.is_empty():
		return String(skill.get("name", ""))
	return "%s - %s" % [broad.get("name", ""), skill.get("name", "")]


func _index_skills() -> void:
	skills_by_id.clear()
	broad_skills.clear()
	specialty_skills_by_broad_id.clear()

	for skill in skills:
		var id := _as_int(skill.get("id", -1))
		skills_by_id[id] = skill
		if skill.get("type", "") == "broad":
			broad_skills.append(skill)
		else:
			var broad_id := _as_int(skill.get("broad_id", -1))
			if not specialty_skills_by_broad_id.has(broad_id):
				specialty_skills_by_broad_id[broad_id] = []
			specialty_skills_by_broad_id[broad_id].append(skill)

	broad_skills.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))
	for broad_id in specialty_skills_by_broad_id.keys():
		specialty_skills_by_broad_id[broad_id].sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))


func _index_equipment() -> void:
	equipment_by_id.clear()
	for item in equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if item_id.is_empty():
			continue
		equipment_by_id[item_id] = item


func _index_achievements() -> void:
	achievements_by_id.clear()
	for item in achievement_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if item_id.is_empty():
			continue
		achievements_by_id[item_id] = item


func _normalize_selected_achievements(character: Dictionary) -> void:
	var selected_value = character.get("selected_achievements", [])
	var selected: Array = selected_value if typeof(selected_value) == TYPE_ARRAY else []
	var normalized := []
	for entry_value in selected:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var achievement_id := String(entry.get("achievement_id", ""))
		var achievement := get_achievement_by_id(achievement_id)
		if achievement.is_empty():
			continue
		normalized.append({
			"line_id": String(entry.get("line_id", _next_achievement_line_id_from_list(normalized))),
			"achievement_id": achievement_id,
			"cost": max(0, _as_int(entry.get("cost", achievement_purchase_cost(character, achievement, entry.get("target_value", 0))))),
			"level": max(1, _as_int(entry.get("level", achievement_level_for_points(_as_int(character.get("achievement_points", 0)))))),
			"target_id": String(entry.get("target_id", "")),
			"target_value": max(0, _as_int(entry.get("target_value", 0))),
			"notes": String(entry.get("notes", "")),
		})
	character["selected_achievements"] = normalized


func _normalize_mutations(character: Dictionary) -> void:
	var mutation_value = character.get("mutations", {})
	var mutations: Dictionary = mutation_value if typeof(mutation_value) == TYPE_DICTIONARY else {}
	var origin_id := String(mutations.get("origin", "engineered"))
	if get_mutation_origin_by_id(origin_id).is_empty():
		origin_id = "engineered"
	var uniqueness_id := String(mutations.get("uniqueness", ""))
	if get_mutation_uniqueness_by_id(origin_id, uniqueness_id).is_empty():
		var uniqueness_rows := mutation_uniqueness_options(origin_id)
		if not uniqueness_rows.is_empty() and typeof(uniqueness_rows[0]) == TYPE_DICTIONARY:
			var first_uniqueness: Dictionary = uniqueness_rows[0]
			uniqueness_id = String(first_uniqueness.get("id", "engineered_community"))
		else:
			uniqueness_id = "engineered_community"

	character["mutations"] = {
		"generation_mode": "player" if String(mutations.get("generation_mode", "random")) == "player" else "random",
		"origin": origin_id,
		"uniqueness": uniqueness_id,
		"advantage_points": max(0, _as_int(mutations.get("advantage_points", 0))),
		"drawback_points": max(0, _as_int(mutations.get("drawback_points", 0))),
		"advantage_distribution": _normalized_mutation_distribution(mutations.get("advantage_distribution", {}), "advantage", max(0, _as_int(mutations.get("advantage_points", 0)))),
		"drawback_distribution": _normalized_mutation_distribution(mutations.get("drawback_distribution", {}), "drawback", max(0, _as_int(mutations.get("drawback_points", 0)))),
		"advantages": _normalized_mutation_id_list(mutations.get("advantages", []), mutation_advantages_by_id),
		"drawbacks": _normalized_mutation_id_list(mutations.get("drawbacks", []), mutation_drawbacks_by_id),
	}
	_ensure_mutation_distributions(character)


func _mutation_data(character: Dictionary) -> Dictionary:
	if not character.has("mutations") or typeof(character.get("mutations")) != TYPE_DICTIONARY:
		character["mutations"] = {}
	_normalize_mutations(character)
	return character.get("mutations", {})


func _normalized_mutation_id_list(value, catalog: Dictionary) -> Array:
	var raw: Array = value if typeof(value) == TYPE_ARRAY else []
	var result := []
	var seen := {}
	for entry_value in raw:
		var mutation_id := ""
		if typeof(entry_value) == TYPE_DICTIONARY:
			mutation_id = String(entry_value.get("id", entry_value.get("mutation_id", "")))
		else:
			mutation_id = String(entry_value)
		if mutation_id.is_empty() or seen.has(mutation_id) or not catalog.has(mutation_id):
			continue
		seen[mutation_id] = true
		result.append(mutation_id)
	return result


func _normalized_mutation_distribution(value, kind: String, points: int) -> Dictionary:
	var order := MUTATION_DRAWBACK_TIERS if kind == "drawback" else MUTATION_ADVANTAGE_TIERS
	var raw: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var result := {}
	for tier in order:
		result[tier] = max(0, _as_int(raw.get(tier, 0)))
	var options := mutation_distribution_options(kind, points)
	var id := _mutation_distribution_id(result, order)
	for option_value in options:
		if typeof(option_value) == TYPE_DICTIONARY and String(option_value.get("id", "")) == id:
			return result
	if options.is_empty():
		return _empty_mutation_distribution(order)
	var first: Dictionary = options[0]
	return first.get("counts", {}).duplicate(true)


func _ensure_mutation_distributions(character: Dictionary) -> void:
	_ensure_mutation_distribution(character, "advantage")
	_ensure_mutation_distribution(character, "drawback")


func _ensure_mutation_distribution(character: Dictionary, kind: String) -> void:
	var mutations: Dictionary = character.get("mutations", {})
	var points_key := "drawback_points" if kind == "drawback" else "advantage_points"
	var distribution_key := "drawback_distribution" if kind == "drawback" else "advantage_distribution"
	mutations[distribution_key] = _normalized_mutation_distribution(mutations.get(distribution_key, {}), kind, _as_int(mutations.get(points_key, 0)))
	character["mutations"] = mutations


func _mutation_advantage_distribution_options(points: int) -> Array:
	var rows := []
	for amazing in range(mini(1, int(floor(points / 4.0))), -1, -1):
		for good in range(mini(2, int(floor((points - (4 * amazing)) / 2.0))), -1, -1):
			for ordinary in range(mini(3, points - (4 * amazing) - (2 * good)), -1, -1):
				if ordinary + (2 * good) + (4 * amazing) != points:
					continue
				var counts := {
					"Ordinary": ordinary,
					"Good": good,
					"Amazing": amazing,
				}
				rows.append(_mutation_distribution_option(counts, MUTATION_ADVANTAGE_TIERS, MUTATION_ADVANTAGE_LABEL_ORDER))
	return rows


func _mutation_drawback_distribution_options(points: int) -> Array:
	var rows := []
	for moderate in range(mini(8, int(floor(points / 2.0))), -1, -1):
		for extreme in range(mini(8, int(floor((points - (2 * moderate)) / 4.0))), -1, -1):
			for slight in range(mini(8, points - (2 * moderate) - (4 * extreme)), -1, -1):
				if slight + (2 * moderate) + (4 * extreme) != points:
					continue
				var counts := {
					"Slight": slight,
					"Moderate": moderate,
					"Extreme": extreme,
				}
				rows.append(_mutation_distribution_option(counts, MUTATION_DRAWBACK_TIERS, MUTATION_DRAWBACK_LABEL_ORDER))
	return rows


func _mutation_distribution_option(counts: Dictionary, id_order: Array, label_order: Array) -> Dictionary:
	return {
		"id": _mutation_distribution_id(counts, id_order),
		"label": _mutation_distribution_label(counts, label_order),
		"counts": counts.duplicate(true),
	}


func _mutation_distribution_id(counts: Dictionary, order: Array) -> String:
	var parts := []
	for tier_value in order:
		var tier := String(tier_value)
		parts.append("%s:%d" % [tier, _as_int(counts.get(tier, 0))])
	return "|".join(parts)


func _mutation_distribution_label(counts: Dictionary, order: Array) -> String:
	var parts := []
	for tier_value in order:
		var tier := String(tier_value)
		var count := _as_int(counts.get(tier, 0))
		if count <= 0:
			continue
		parts.append("%d %s" % [count, tier])
	return "None" if parts.is_empty() else " + ".join(parts)


func _empty_mutation_distribution(order: Array) -> Dictionary:
	var result := {}
	for tier in order:
		result[String(tier)] = 0
	return result


func _mutation_selected(character: Dictionary, selected_key: String, mutation_id: String) -> bool:
	var mutations := _mutation_data(character)
	for selected_id in mutations.get(selected_key, []):
		if String(selected_id) == mutation_id:
			return true
	return false


func _remove_mutation_selection(character: Dictionary, selected_key: String, mutation_id: String) -> void:
	var mutations := _mutation_data(character)
	var next := []
	for selected_id in mutations.get(selected_key, []):
		if String(selected_id) == mutation_id:
			continue
		next.append(String(selected_id))
	mutations[selected_key] = next
	character["mutations"] = mutations


func _mutation_advantage_tier_cap(tier: String) -> int:
	match tier:
		"Ordinary":
			return 3
		"Good":
			return 2
		"Amazing":
			return 1
	return 0


func _mutation_tier_count(rows: Array, tier: String) -> int:
	var count := 0
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY and String(row_value.get("tier", "")) == tier:
			count += 1
	return count


func _roll_mutation_selection(character: Dictionary, selected_key: String, catalog: Array, kind: String) -> Dictionary:
	var mutations := _mutation_data(character)
	mutations[selected_key] = []
	character["mutations"] = mutations

	var distribution := mutation_distribution(character, kind)
	var order := MUTATION_DRAWBACK_TIERS if kind == "drawback" else MUTATION_ADVANTAGE_TIERS
	var selected := []
	var failed := []
	for tier_value in order:
		var tier := String(tier_value)
		var needed := _as_int(distribution.get(tier, 0))
		for _index in range(needed):
			var mutation := _random_mutation_from_tier(catalog, tier, selected)
			if mutation.is_empty():
				failed.append(tier)
				continue
			var mutation_id := String(mutation.get("id", ""))
			var result := add_mutation_drawback(character, mutation_id) if kind == "drawback" else add_mutation_advantage(character, mutation_id)
			if bool(result.get("ok", false)):
				selected.append(mutation_id)
			else:
				failed.append("%s: %s" % [tier, String(result.get("reason", ""))])
	return {
		"selected": selected,
		"failed": failed,
	}


func _random_mutation_from_tier(catalog: Array, tier: String, excluded: Array) -> Dictionary:
	var candidates := []
	for mutation_value in catalog:
		if typeof(mutation_value) != TYPE_DICTIONARY:
			continue
		var mutation: Dictionary = mutation_value
		var mutation_id := String(mutation.get("id", ""))
		if String(mutation.get("tier", "")) == tier and not excluded.has(mutation_id):
			candidates.append(mutation)
	if candidates.is_empty():
		return {}
	return candidates[randi_range(0, candidates.size() - 1)]


func _selected_mutation_effect_sources(character: Dictionary) -> Array:
	var rows := []
	if not mutations_enabled(character):
		return rows
	for mutation in selected_mutation_advantages(character):
		rows.append(mutation)
	for drawback in selected_mutation_drawbacks(character):
		rows.append(drawback)
	return rows


func _mutation_effects(mutation: Dictionary, effect_type: String) -> Array:
	var result := []
	var effects: Array = mutation.get("effects", [])
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		if String(effect.get("type", "")) == effect_type:
			result.append(effect)
	return result


func _roll_mutation_formula(formula: String) -> int:
	var clean := formula.strip_edges().to_lower()
	if clean.is_empty():
		return 0
	var sign_index := clean.find("+")
	var sign := 1
	if sign_index < 0:
		sign_index = clean.find("-")
		sign = -1
	if clean.begins_with("d"):
		var die_length := sign_index - 1 if sign_index > 0 else clean.length() - 1
		var die_text := clean.substr(1, die_length)
		var die_size: int = max(1, _as_int(die_text, 1))
		var modifier := 0
		if sign_index > 0:
			modifier = sign * _as_int(clean.substr(sign_index + 1), 0)
		return max(0, randi_range(1, die_size) + modifier)
	return max(0, _as_int(clean, 0))


func _normalize_equipment(character: Dictionary) -> void:
	var equipment: Dictionary = character.get("equipment", {})
	if not equipment.has("custom_items"):
		equipment["custom_items"] = []
	if not equipment.has("carried"):
		equipment["carried"] = []

	var custom_items := []
	for custom_item in equipment.get("custom_items", []):
		if typeof(custom_item) != TYPE_DICTIONARY:
			continue
		var normalized := _normalize_equipment_item(custom_item.duplicate(true), _next_custom_equipment_id_from_list(custom_items))
		custom_items.append(normalized)
	equipment["custom_items"] = custom_items

	var carried := []
	for carried_item in equipment.get("carried", []):
		if typeof(carried_item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = carried_item
		var item_id := String(row.get("item_id", ""))
		if item_id.is_empty():
			continue
		var normalized_row := {
			"line_id": String(row.get("line_id", _next_equipment_line_id_from_list(carried))),
			"item_id": item_id,
			"quantity": max(1, _as_int(row.get("quantity", 1))),
			"equipped": bool(row.get("equipped", false)),
			"slot": String(row.get("slot", "")),
			"notes": String(row.get("notes", "")),
		}
		carried.append(normalized_row)
	equipment["carried"] = carried
	character["equipment"] = equipment


func _normalize_equipment_item(item: Dictionary, fallback_id: String) -> Dictionary:
	var combat = item.get("combat", null)
	if typeof(combat) != TYPE_DICTIONARY:
		combat = null
	var normalized := {
		"id": String(item.get("id", fallback_id)),
		"kind": String(item.get("kind", "equipment")),
		"name": String(item.get("name", "Custom Item")),
		"source": String(item.get("source", "Custom")),
		"source_code": String(item.get("source_code", "custom")),
		"reference": String(item.get("reference", "Character custom equipment.")),
		"page": String(item.get("page", "")),
		"table": String(item.get("table", "")),
		"pl": clampi(_as_int(item.get("pl", 0)), 0, 9),
		"category": String(item.get("category", "Custom")),
		"class": String(item.get("class", "Custom")),
		"availability": String(item.get("availability", "Com")),
		"mass": max(0.0, _as_float(item.get("mass", 0.0))),
		"cost": max(0, _as_int(item.get("cost", 0))),
		"combat": combat,
	}
	return normalized


func _equipment_string_options(key: String) -> Array:
	var options := []
	var seen := {}
	for item in equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var value := String(item.get(key, ""))
		if value.is_empty() or seen.has(value):
			continue
		seen[value] = true
		options.append(value)
	options.sort()
	return options


func _equipment_matches_search(item: Dictionary, search: String) -> bool:
	var haystack := "%s %s %s %s %s" % [
		String(item.get("name", "")),
		String(item.get("category", "")),
		String(item.get("class", "")),
		String(item.get("source", "")),
		String(item.get("availability", "")),
	]
	return haystack.to_lower().contains(search)


func _next_equipment_line_id(character: Dictionary) -> String:
	var equipment: Dictionary = character.get("equipment", {})
	return _next_equipment_line_id_from_list(equipment.get("carried", []))


func _next_equipment_line_id_from_list(carried: Array) -> String:
	var max_id := 0
	for row in carried:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var line_id := String(row.get("line_id", ""))
		if line_id.begins_with("line_"):
			max_id = maxi(max_id, _as_int(line_id.substr(5), 0))
	return "line_%04d" % (max_id + 1)


func _next_custom_equipment_id(character: Dictionary) -> String:
	var equipment: Dictionary = character.get("equipment", {})
	return _next_custom_equipment_id_from_list(equipment.get("custom_items", []))


func _next_custom_equipment_id_from_list(custom_items: Array) -> String:
	var max_id := 0
	for item in custom_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if item_id.begins_with("custom_"):
			max_id = maxi(max_id, _as_int(item_id.substr(7), 0))
	return "custom_%04d" % (max_id + 1)


func _next_achievement_line_id_from_list(selected: Array) -> String:
	var max_id := 0
	for item in selected:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var line_id := String(item.get("line_id", ""))
		if line_id.begins_with("ach_"):
			max_id = maxi(max_id, _as_int(line_id.substr(4), 0))
	return "ach_%04d" % (max_id + 1)


func _remove_unused_custom_equipment(character: Dictionary, item_id: String) -> void:
	if item_id.is_empty() or not item_id.begins_with("custom_"):
		return
	var equipment: Dictionary = character.get("equipment", {})
	for row in equipment.get("carried", []):
		if typeof(row) == TYPE_DICTIONARY and String(row.get("item_id", "")) == item_id:
			return
	var custom_items := []
	for item in equipment.get("custom_items", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if String(item.get("id", "")) == item_id:
			continue
		custom_items.append(item)
	equipment["custom_items"] = custom_items
	character["equipment"] = equipment


func _normalize_selected_skills(character: Dictionary) -> void:
	var selected: Dictionary = character.get("selected_skills", {})
	var normalized := {}
	for key in selected.keys():
		var skill_id := _as_int(key, -1)
		var skill := get_skill_by_id(skill_id)
		if skill.is_empty():
			continue

		var rank := _selected_skill_entry_rank(selected[key])
		if rank <= 0:
			continue
		normalized[str(skill_id)] = 1 if skill.get("type", "") == "broad" else clampi(rank, 1, MAX_SPECIALTY_RANK)
	character["selected_skills"] = normalized


func _normalize_selected_character_options(character: Dictionary, selected_key: String, definitions: Array, value_options_key: String) -> void:
	var selected: Dictionary = character.get(selected_key, {})
	var normalized := {}
	for key in selected.keys():
		var option_id := String(key)
		var definition := _get_character_option_by_id(definitions, option_id)
		if definition.is_empty():
			continue

		var value := _selected_character_option_entry_value(selected[key])
		if not _character_option_value_allowed(definition, value_options_key, value):
			continue
		normalized[option_id] = value
	character[selected_key] = normalized


func _get_character_option_by_id(definitions: Array, option_id: String) -> Dictionary:
	for item in definitions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = item
		if String(definition.get("id", "")) == option_id:
			return definition
	return {}


func _set_character_option_selected(character: Dictionary, selected_key: String, definitions: Array, value_options_key: String, option_id: String, value: int) -> void:
	var selected: Dictionary = character.get(selected_key, {})
	var definition := _get_character_option_by_id(definitions, option_id)
	if definition.is_empty() or value <= 0 or not _character_option_value_allowed(definition, value_options_key, value):
		selected.erase(option_id)
	else:
		selected[option_id] = value
	character[selected_key] = selected


func _selected_character_options(character: Dictionary, selected_key: String, definitions: Array, value_key: String) -> Array:
	var selected: Dictionary = character.get(selected_key, {})
	var rows := []
	for item in definitions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = item
		var option_id := String(definition.get("id", ""))
		if not selected.has(option_id):
			continue

		var row := definition.duplicate(true)
		row[value_key] = _as_int(selected.get(option_id, 0))
		rows.append(row)
	return rows


func _character_option_value_allowed(definition: Dictionary, value_options_key: String, value: int) -> bool:
	for option_value in definition.get(value_options_key, []):
		if _as_int(option_value) == value:
			return true
	return false


func _selected_character_option_entry_value(value) -> int:
	if typeof(value) == TYPE_DICTIONARY:
		var entry: Dictionary = value
		return _as_int(entry.get("value", entry.get("cost", entry.get("bonus", 0))))
	return _as_int(value, 0)


func _selected_skill_entry_rank(value) -> int:
	match typeof(value):
		TYPE_DICTIONARY:
			return _as_int(value.get("rank", value.get("level", 0)))
		TYPE_BOOL:
			return 1 if value else 0
	return _as_int(value, 0)


func _skill_summary(skill: Dictionary) -> String:
	var skill_id := _as_int(skill.get("id", -1))
	if SPECIALTY_SUMMARIES.has(skill_id):
		return String(SPECIALTY_SUMMARIES[skill_id])
	if skill.get("type", "") == "broad":
		return String(BROAD_SKILL_SUMMARIES.get(skill_id, "Use this broad skill for its related specialty skills."))

	var broad := get_skill_by_id(_as_int(skill.get("broad_id", -1)))
	var name := String(skill.get("name", "specialty"))
	if bool(skill.get("custom_name", false)) or name.contains("specific"):
		return "Choose a specific field when buying this specialty. It uses the %s broad skill and advances as a separate specialty." % broad.get("name", "parent")
	return "Specialized use of %s focused on %s." % [broad.get("name", "the parent broad skill"), name]


func _skill_roll_notes(skill: Dictionary) -> Array:
	var notes := []
	if skill.get("type", "") == "broad":
		notes.append("Score is the linked ability score. Base situation die is +d4.")
	else:
		notes.append("Score is linked ability + current specialty rank. Base situation die is +d0.")

	if not bool(skill.get("untrained", true)):
		notes.append("This skill is prohibited from untrained use; the broad skill alone is not enough.")
	elif skill.get("type", "") == "specialty":
		notes.append("If only the parent broad skill is trained, this specialty can be attempted at the broad skill score with +d4.")

	if bool(skill.get("multi", false)) or bool(skill.get("custom_name", false)):
		notes.append("This can be bought for multiple separate specialties or named fields.")

	for note in _skill_summary_roll_notes(skill):
		notes.append(note)

	return notes


func _skill_summary_roll_notes(skill: Dictionary) -> Array:
	var skill_id := _as_int(skill.get("id", -1))
	var notes := {
		0: ["Armor can impose action check and Dexterity resistance penalties; Armor Operation can reduce those penalties."],
		1: ["Combat armor ranks reduce armor penalties for standard combat armor."],
		2: ["Powered armor ranks reduce armor penalties for powered armor."],
		4: ["Combat climbing distance depends on success; long climbs can use complex checks."],
		5: ["Jump distance is based on the success level; critical failures can cause a hard fall."],
		11: ["Melee parries compare the defender's result to the attacker's result."],
		15: ["Overpowering is an unarmed attack used to grab and restrain; multiple attackers can assist."],
		20: ["Blocks compare the defender's Defensive Martial Arts result to the attacker's result."],
		21: ["Dodge adjusts the relevant resistance modifier based on success and costs an action unless a rank benefit changes that."],
		22: ["Fall checks reduce impact damage from falling."],
		24: ["Zero-g conditions penalize many physical actions unless the hero has enough training."],
		28: ["Higher ranks make it harder for a target to notice the attempt."],
		39: ["Stealth usually opposes Awareness or Investigate, depending on whether the observer is actively searching."],
		40: ["Hide is checked again when the situation changes, such as movement, light, or noise."],
		41: ["Shadow is usually opposed by the target's Awareness-intuition."],
		42: ["Sneak is used to move quietly while avoiding observation."],
		52: ["Fatigue and worsening mortal damage can call for Stamina-endurance checks."],
		54: ["Resist Pain can keep a hero acting under injury or pain."],
		61: ["Computer tasks often become complex checks when security, time, or quality matters."],
		85: ["Serious medical care often uses complex checks and can be affected by equipment and conditions."],
		114: ["Technical tasks can vary from one quick juryrig check to long complex checks."],
		125: ["Awareness is a common defensive skill for surprise, hidden details, and being followed."],
		130: ["Investigate often opposes concealment and can become complex when evidence is extensive."],
		142: ["Culture skills can set or change social reactions across cultures."],
		146: ["Deception is often resisted by a target's judgment or resistance modifiers."],
		155: ["Interaction skills often change attitudes, extract information, or impose social pressure."],
		162: ["Leadership affects other characters; exact benefits depend on the scene and GM judgment."],
	}
	var sourced_notes := []
	var source_text := _source_text_for_skill(skill)
	for note in notes.get(skill_id, []):
		var text := String(note)
		if text.contains("Source:"):
			sourced_notes.append(text)
		else:
			sourced_notes.append("%s Source: %s" % [text, source_text])
	return sourced_notes


func _source_text_for_skill(skill: Dictionary) -> String:
	var sources := []
	for source in _skill_sources(skill):
		var clean_source := String(source).strip_edges()
		if clean_source.ends_with("."):
			clean_source = clean_source.left(clean_source.length() - 1)
		sources.append(clean_source)
	return "; ".join(sources)


func _species_notes_for_character(character: Dictionary, note_map: Dictionary) -> Array:
	var species_id := _as_int(character.get("species_id", 0))
	var notes := []
	for note in note_map.get(species_id, []):
		notes.append(String(note))
	return _unique_strings(notes)


func _unique_strings(values: Array) -> Array:
	var seen := {}
	var result := []
	for value in values:
		var text := String(value)
		if text.is_empty() or seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	return result


func _last_resort_base(personality: int) -> Dictionary:
	if personality <= 7:
		return {"max": 0, "cost": 0}
	if personality <= 10:
		return {"max": 1, "cost": 3}
	if personality <= 12:
		return {"max": 2, "cost": 3}
	if personality <= 14:
		return {"max": 3, "cost": 2}
	return {"max": 4, "cost": 2}


func _as_int(value, default_value := 0) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			if String(value).is_valid_int():
				return int(value)
			if String(value).is_valid_float():
				return int(float(value))
	return default_value


func _as_float(value, default_value := 0.0) -> float:
	match typeof(value):
		TYPE_INT:
			return float(value)
		TYPE_FLOAT:
			return value
		TYPE_STRING:
			if String(value).is_valid_float():
				return float(value)
	return default_value
