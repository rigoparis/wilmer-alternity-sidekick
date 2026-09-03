class_name CombatAttack
extends RefCounted
##
## One attack, from the GM declaring it to the target's device applying it.
##
## The division of labour is the ownership rule again, and it is the whole reason
## this is a document that travels rather than a function call:
##
##   the GM's device      declares the attack, nets the modifiers, rolls to hit
##                        and rolls the damage. It is the attacker.
##   the target's device   rolls its own armor, applies the damage to its own
##                        sheet, and makes any knockout check. It owns the
##                        character and is the only thing that writes to it.
##
## So an attack crosses the wire once as a settled fact -- "a Good hit for seven
## points of high-impact wound damage" -- and comes back as what that did. The
## GM never touches the sheet, and the player never decides whether they were hit.
##
## The awareness flags travel with it because only the GM knows them: whether the
## target could see the shot coming decides both their resistance modifier and
## whether they may dodge, and neither is visible from the target's side.
##

const FORMAT_VERSION := 1

## Declared and rolled, waiting for the target to apply it.
const STATE_SENT := "sent"
## The target has applied it and said what happened.
const STATE_RESOLVED := "resolved"

## Damage tracks, as the weapon tables write them.
const DAMAGE_TYPES := {"s": "stun", "w": "wound", "m": "mortal", "f": "fatigue"}

var attack_id: String = ""
var state: String = STATE_SENT

## Who is swinging. Free text: the GM is running an enemy that has no sheet.
var attacker_name: String = "Someone"

## The seat this lands on. A stable player_id, never a peer id.
var target_player_id: String = ""

var weapon_name: String = ""

## Which of the target's three armor ratings answers this: "li", "hi" or "en".
var impact_type: String = "hi"

## The weapon's firepower grade, for the degradation comparison: "O", "G" or "A".
var firepower: String = "O"

var is_melee: bool = false

## How well it landed, after any called-shot or firepower promotion.
var degree: String = ""

## The damage the attacker rolled, before the target's armor.
var damage: int = 0

## Which track it goes on: "s", "w", "m" or "f".
var damage_type: String = "w"

## What the target could do about it. Set by the GM, because only the GM knows.
var sees_attacker: bool = true
var from_rear: bool = false
var pinned: bool = false

## What the target's device made of it. See resolve().
var result: Dictionary = {}

var at: int = 0


func _init() -> void:
	attack_id = CampaignSession.new_id()
	at = int(Time.get_unix_time_from_system())


## Build a declared attack. Everything here is already decided and rolled.
static func declare(
	target: String,
	attacker: String,
	weapon: String,
	hit_degree: String,
	rolled_damage: int,
	track: String,
	impact: String,
	firepower_grade: String
) -> CombatAttack:
	var attack := CombatAttack.new()
	attack.target_player_id = target
	attack.attacker_name = attacker
	attack.weapon_name = weapon
	attack.degree = hit_degree
	attack.damage = maxi(0, rolled_damage)
	attack.damage_type = track
	attack.impact_type = impact
	attack.firepower = firepower_grade
	return attack


## Whether this landed at all.
##
## A miss still travels, because the target should be told they were shot at and
## the log should say so. It simply has nothing to apply.
func hits() -> bool:
	return degree.to_lower() in ["ordinary", "good", "amazing"]


func is_amazing() -> bool:
	return degree.to_lower() == "amazing"


## The track this marks, spelled out.
func track_name() -> String:
	return String(DAMAGE_TYPES.get(damage_type.to_lower(), "stun"))


## Record what the target's device made of it.
##
## `outcome` is whatever apply_damage returned, plus what the armor soaked and
## whether the target went down -- everything the GM needs to see without being
## handed the character.
func resolve(outcome: Dictionary) -> void:
	result = outcome.duplicate(true)
	state = STATE_RESOLVED


func is_resolved() -> bool:
	return state == STATE_RESOLVED


# --- Wire and log ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"attack_id": attack_id,
		"state": state,
		"attacker_name": attacker_name,
		"target_player_id": target_player_id,
		"weapon_name": weapon_name,
		"impact_type": impact_type,
		"firepower": firepower,
		"is_melee": is_melee,
		"degree": degree,
		"damage": damage,
		"damage_type": damage_type,
		"sees_attacker": sees_attacker,
		"from_rear": from_rear,
		"pinned": pinned,
		"result": result.duplicate(true),
		"at": at,
	}


static func from_dict(data: Dictionary) -> CombatAttack:
	var attack := CombatAttack.new()
	attack.attack_id = String(data.get("attack_id", attack.attack_id))
	attack.state = String(data.get("state", STATE_SENT))
	attack.attacker_name = String(data.get("attacker_name", "Someone"))
	attack.target_player_id = String(data.get("target_player_id", ""))
	attack.weapon_name = String(data.get("weapon_name", ""))
	attack.impact_type = String(data.get("impact_type", "hi"))
	attack.firepower = String(data.get("firepower", "O"))
	attack.is_melee = bool(data.get("is_melee", false))
	attack.degree = String(data.get("degree", ""))
	attack.damage = AlternityNum.as_int(data.get("damage", 0))
	attack.damage_type = String(data.get("damage_type", "w"))
	attack.sees_attacker = bool(data.get("sees_attacker", true))
	attack.from_rear = bool(data.get("from_rear", false))
	attack.pinned = bool(data.get("pinned", false))
	attack.at = AlternityNum.as_int(data.get("at", 0))
	var stored = data.get("result", {})
	attack.result = stored.duplicate(true) if typeof(stored) == TYPE_DICTIONARY else {}
	return attack


## One line for a feed, readable without knowing the payload shape.
func describe() -> String:
	var weapon := weapon_name if not weapon_name.is_empty() else "an attack"
	if not hits():
		return "%s missed with %s" % [attacker_name, weapon]

	var line := "%s hit with %s -- %s, %d %s" % [
		attacker_name, weapon, degree.capitalize(), damage, track_name()
	]
	if not is_resolved():
		return line

	var taken := AlternityNum.as_int(result.get("primary_damage", 0))
	var soaked := AlternityNum.as_int(result.get("absorbed", 0))
	if bool(result.get("negated", false)):
		return line + ", stopped entirely"
	if soaked > 0:
		line += " (armor soaked %d, %d got through)" % [soaked, taken]
	else:
		line += " (%d got through)" % taken
	if bool(result.get("knocked_out", false)):
		line += " -- and they went down"
	return line
