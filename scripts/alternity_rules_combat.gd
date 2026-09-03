class_name AlternityRulesCombat
extends RefCounted
##
## Tactical combat: defence, weapon failures, death, recovery and blasts.
##
## Its own submodule for the same reason equipment and mutations are -- the main
## rules file is already three thousand lines, and this is a coherent body of
## rules that a reader wants to find in one place.
##
## What is deliberately *not* here is anything the engine already does. Degrees
## of success, the step die chain, action check scores, and the whole damage
## pipeline -- armor on primary only, secondary derivation, both overflows --
## live in alternity_rules.gd and are called into rather than restated.
##
## These rules are sourced to the books through a reading assistant rather than
## verified page by page, and every one carries its citation so a later reader
## knows which claims to re-check first.
##

var _parent_ref: WeakRef


func _init(p_parent: RefCounted) -> void:
	_parent_ref = weakref(p_parent)


func _get_parent():
	return _parent_ref.get_ref()


# --- Defence ---------------------------------------------------------------

## What a target's own body is worth against an attack, in steps.
##
## The resistance modifier is a situation modifier like any other: it is added to
## the attacker's step total before the situation die is chosen. Ranged attacks
## are resisted by Dexterity, melee and unarmed by Strength.
##
## It is worth nothing at all against a target who cannot use it. Somebody
## unaware, immobilised or unconscious is not resisting -- which is most of why
## surprise and a rear attack are so much better than the step bonuses alone
## suggest. Source: Player's Handbook p. 32.
func resistance_step(target: Dictionary, is_melee: bool, target_aware: bool = true) -> int:
	if not target_aware:
		return 0
	var ability := "STR" if is_melee else "DEX"
	return AlternityNum.as_int(_get_parent().character_resistance_modifier(target, ability))


## What a dodge is worth, by how well it was rolled.
##
## Not an opposed check: the roll amplifies the dodger's own resistance modifier,
## and the result is a step penalty on everyone shooting at them. A failed dodge
## is simply worth nothing, and a critical failure hands the attacker a bonus --
## which is the risk that makes spending the action a decision.
##
## One dodge covers every attack against that character for the rest of the
## round, so this is rolled once and applied many times.
## Source: Player's Handbook p. 71.
func dodge_step(degree: String) -> int:
	match degree.to_lower():
		"amazing":
			return 3
		"good":
			return 2
		"ordinary":
			return 1
		"critical failure":
			return -2
	return 0


## Whether a parry stops an attack outright.
##
## An opposed comparison of degrees rather than of numbers: a parry equal to or
## better than the attack blocks it completely and no primary damage is
## inflicted. Unlike a dodge it covers exactly one attack.
## Source: Gamemaster Guide p. 45.
func parry_blocks(attack_degree: String, parry_degree: String) -> bool:
	var order := ["failure", "marginal", "ordinary", "good", "amazing"]
	var attack := order.find(attack_degree.to_lower())
	var parry := order.find(parry_degree.to_lower())
	if attack == -1 or parry == -1:
		return false
	# A parry that missed blocks nothing, however badly the attack was rolled.
	if parry <= order.find("marginal"):
		return false
	return parry >= attack


## Whether a target may defend at all.
##
## A character who did not see it coming cannot dodge or parry, and loses their
## passive resistance modifier as well. Source: Player's Handbook p. 32.
func can_defend(target_aware: bool) -> bool:
	return target_aware


# --- Critical failures -----------------------------------------------------

## What goes wrong on a natural 20 in combat.
##
## Table G8: Weapon Failures, Gamemaster Guide p. 45. `roll` is a d8; firearms
## and melee weapons read different columns off the same roll.
##
## Returns {result, detail}, where result is one of "breakage", "dropped",
## "jammed" or "out_of_ammo".
func weapon_failure(roll: int, is_firearm: bool = true) -> Dictionary:
	var clamped := clampi(roll, 1, 8)
	var result := ""
	if is_firearm:
		if clamped == 1:
			result = "breakage"
		elif clamped <= 4:
			result = "dropped"
		elif clamped <= 7:
			result = "jammed"
		else:
			result = "out_of_ammo"
	else:
		# A melee weapon cannot jam or run out of ammunition, so its column is
		# breakage twice and then dropped the rest of the way down.
		result = "breakage" if clamped <= 2 else "dropped"

	return {"result": result, "detail": WEAPON_FAILURE_DETAIL.get(result, "")}


const WEAPON_FAILURE_DETAIL := {
	"breakage": "A Personality feat check: on a failure the weapon breaks, on any success it holds together.",
	"dropped": "The weapon is dropped. Readying it again costs an action.",
	"jammed": "Jammed. Clearing it costs an action and an Ordinary check with the weapon's own skill.",
	"out_of_ammo": "The clip or magazine is spent and must be reloaded.",
}


# --- Death and dying -------------------------------------------------------

## Whether the character is dead.
##
## The last mortal box is the end: there is no dying state past it and nothing to
## stabilise. Source: Gamemaster Guide p. 54.
func is_dead(character: Dictionary) -> bool:
	var durability: Dictionary = _get_parent().durability(character)
	var damage: Dictionary = character.get("damage", {})
	var maximum := AlternityNum.as_int(durability.get("mortal", 0))
	if maximum <= 0:
		return false
	return AlternityNum.as_int(damage.get("mortal", 0)) >= maximum


## Whether the character is dying: some mortal damage taken, but a box still open.
##
## A dying character makes a Stamina-endurance check at the end of the scene and
## every hour after, or takes more mortal damage. Source: Gamemaster Guide p. 54.
func is_dying(character: Dictionary) -> bool:
	if is_dead(character):
		return false
	return AlternityNum.as_int(character.get("damage", {}).get("mortal", 0)) > 0


## Whether stun damage has filled and the character is unconscious.
## Source: Gamemaster Guide p. 54.
func is_knocked_out(character: Dictionary) -> bool:
	var durability: Dictionary = _get_parent().durability(character)
	var maximum := AlternityNum.as_int(durability.get("stun", 0))
	if maximum <= 0:
		return false
	return AlternityNum.as_int(character.get("damage", {}).get("stun", 0)) >= maximum


## A one-line description of how badly off a character is, for a GM's roster.
func condition_of(character: Dictionary) -> String:
	if is_dead(character):
		return "Dead"
	if is_knocked_out(character):
		return "Unconscious"
	if is_dying(character):
		return "Dying"
	var penalty := AlternityNum.as_int(_get_parent().dazed_penalty(character))
	if penalty > 0:
		return "Hurt (+%d step%s)" % [penalty, "" if penalty == 1 else "s"]
	return "Unhurt"


# --- Recovery --------------------------------------------------------------

## How each damage track comes back.
##
## The cadences are wildly different and that is the point: stun is gone by the
## end of the scene, wounds take weeks, and mortal damage does not heal on its
## own at all. A campaign that runs for months needs this to be right or a hero
## either never recovers or never suffers.
## Source: Gamemaster Guide p. 54.
const RECOVERY := {
	"stun": {
		"cadence": "scene",
		"skill": "",
		"note": "Recovers completely at the end of the scene. Knowledge-first aid can restore some of it sooner.",
	},
	"fatigue": {
		"cadence": "hour",
		"skill": "Resolve - physical resolve",
		"by_degree": {"marginal": 0, "ordinary": 1, "good": 2, "amazing": 3},
		"note": "Requires complete rest. One check per hour.",
	},
	"wound": {
		"cadence": "week",
		"skill": "Resolve - physical resolve",
		"by_degree": {"marginal": 1, "ordinary": 2, "good": 3, "amazing": 4},
		"note": "Requires rest. One check per week, or treatment with Medical Science.",
	},
	"mortal": {
		"cadence": "never",
		"skill": "Medical Science - surgery",
		"note": "Does not heal naturally. Only surgery repairs it.",
	},
}


## How much of a track one successful recovery check restores.
##
## Zero for a track that does not recover by checking -- stun comes back on its
## own and mortal damage does not come back at all.
func recovery_amount(track: String, degree: String) -> int:
	var row = RECOVERY.get(track, {})
	if typeof(row) != TYPE_DICTIONARY:
		return 0
	var by_degree = row.get("by_degree", {})
	if typeof(by_degree) != TYPE_DICTIONARY:
		return 0
	return AlternityNum.as_int(by_degree.get(degree.to_lower(), 0))


func recovers_naturally(track: String) -> bool:
	var row = RECOVERY.get(track, {})
	return typeof(row) == TYPE_DICTIONARY and String(row.get("cadence", "never")) != "never"


# --- Last resort points ----------------------------------------------------

## What spending a last resort point does to a result.
##
## Declared after the dice are rolled and before anything is worked out from
## them. One point shifts the outcome one grade; a critical failure is the
## exception, where one point only reaches an ordinary failure and it takes two
## -- which only some professions can spend at once -- to reach a success.
##
## `points` is how many are being spent. Source: Player's Handbook p. 59.
func last_resort_shift(degree: String, points: int = 1) -> String:
	var order := ["critical failure", "failure", "marginal", "ordinary", "good", "amazing"]
	var current := order.find(degree.to_lower())
	if current == -1 or points <= 0:
		return degree
	# A critical failure is stubborn: the first point spent only makes it an
	# ordinary failure, and a second is needed to buy a success.
	return String(order[mini(order.size() - 1, current + points)])


## The other direction: a defender spending a point to blunt an incoming hit.
##
## Shifts the attacker's result down a grade -- an Amazing hit becomes Good --
## before damage is rolled. It cannot absorb damage after the fact.
## Source: Player's Handbook p. 59.
func last_resort_blunt(attack_degree: String, points: int = 1) -> String:
	var order := ["failure", "marginal", "ordinary", "good", "amazing"]
	var current := order.find(attack_degree.to_lower())
	if current == -1 or points <= 0:
		return attack_degree
	return String(order[maxi(0, current - points)])


# --- Explosions ------------------------------------------------------------

## Which blast zone a target is standing in.
##
## An explosive lists three damage entries and the zones they apply to, measured
## outward from the point of impact: everything close takes the Amazing entry,
## the middle band takes Good, the outer band Ordinary, and past that nothing.
## Source: Player's Handbook p. 57 and the explosives table p. 182.
##
## Returns "amazing", "good", "ordinary", or "" for out of the blast entirely.
func blast_zone(metres: float, inner: float, middle: float, outer: float) -> String:
	if metres <= inner:
		return "amazing"
	if metres <= middle:
		return "good"
	if metres <= outer:
		return "ordinary"
	return ""


## Hitting the deck: a successful dodge drops the blast one grade.
##
## Ordinary is the bottom of the ladder, so a target in the outer band who throws
## themselves flat takes nothing at all. Source: Player's Handbook p. 71.
func blast_after_dodge(zone: String, dodged: bool) -> String:
	if not dodged:
		return zone
	match zone.to_lower():
		"amazing":
			return "good"
		"good":
			return "ordinary"
		"ordinary":
			return ""
	return zone
