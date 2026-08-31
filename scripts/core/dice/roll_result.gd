class_name RollResult
extends RefCounted
##
## The outcome of one roll, in a form that can be stored and sent over the wire.
##
## This is the object a player's device broadcasts to the GM. It is deliberately
## a record of what happened rather than a description of what to do: the
## individual die faces are kept alongside the total so the GM sees the same
## thing the player saw, without re-rolling or re-simulating anything.
##
## `source` distinguishes how the faces were obtained. Both are legitimate:
## rules-internal rolls (mutation tables) resolve through a seeded RNG headless,
## while rolls made at the table come from the physics tray. Recording which
## matters because only the RNG path is reproducible from its seed.
##

## Faces came from a seeded RandomNumberGenerator.
const SOURCE_RNG := "rng"

## Faces were read from settled physical dice. Not reproducible from a seed --
## the simulation is authoritative and is never replayed elsewhere.
const SOURCE_PHYSICAL := "physical"

## The notation this roll resolved, e.g. "d4+2w".
var notation: String = ""

## Individual face values, in the order rolled.
var dice: Array[int] = []

## Constant added after the dice.
var modifier: int = 0

## +1, or -1 for a subtracted situation die such as "-d4".
var sign: int = 1

## Signed sum of dice plus modifier.
var total: int = 0

## "s", "w", "m", "f", or "" when the roll is not damage.
var damage_type: String = ""

var source: String = SOURCE_RNG

## Seed that produced this roll, for SOURCE_RNG only. -1 when not applicable.
var seed_used: int = -1

## Unix timestamp, for ordering a session log spanning months of play.
var timestamp: int = 0

## Who rolled, and for which character. Both are stable identifiers that
## outlive a connection -- never a peer id, which is regenerated per session.
var player_id: String = ""
var character_id: String = ""

## Free-text label for the log, e.g. "Pistol attack" or "Mutation origin".
var label: String = ""

## Number of times the dice had to be re-thrown because they landed cocked or
## left the tray. Physical rolls only; kept so the log is honest about it.
var rerolls: int = 0


static func from_dict(data: Dictionary) -> RollResult:
	var result := RollResult.new()
	result.notation = String(data.get("notation", ""))
	result.modifier = AlternityNum.as_int(data.get("modifier", 0))
	result.sign = AlternityNum.as_int(data.get("sign", 1), 1)
	result.total = AlternityNum.as_int(data.get("total", 0))
	result.damage_type = String(data.get("damage_type", ""))
	result.source = String(data.get("source", SOURCE_RNG))
	result.seed_used = AlternityNum.as_int(data.get("seed_used", -1), -1)
	result.timestamp = AlternityNum.as_int(data.get("timestamp", 0))
	result.player_id = String(data.get("player_id", ""))
	result.character_id = String(data.get("character_id", ""))
	result.label = String(data.get("label", ""))
	result.rerolls = AlternityNum.as_int(data.get("rerolls", 0))

	var faces: Array[int] = []
	for face in data.get("dice", []):
		faces.append(AlternityNum.as_int(face))
	result.dice = faces
	return result


func to_dict() -> Dictionary:
	return {
		"notation": notation,
		"dice": dice.duplicate(),
		"modifier": modifier,
		"sign": sign,
		"total": total,
		"damage_type": damage_type,
		"source": source,
		"seed_used": seed_used,
		"timestamp": timestamp,
		"player_id": player_id,
		"character_id": character_id,
		"label": label,
		"rerolls": rerolls,
	}


## Recompute total from the recorded faces. Called after the faces are set,
## so the total can never disagree with the dice it claims to sum.
func recompute_total() -> void:
	var sum := 0
	for face in dice:
		sum += face
	total = (sign * sum) + modifier


## Human-readable breakdown for the log, e.g. "d4+2w: [3] +2 = 5w".
func describe() -> String:
	var faces := ", ".join(dice.map(func(v): return str(v)))
	var out := "%s: [%s]" % [notation, faces]
	if modifier != 0:
		out += " %+d" % modifier
	out += " = %d%s" % [total, damage_type]
	if rerolls > 0:
		out += " (after %d reroll(s))" % rerolls
	return out
