class_name DiceNotation
extends RefCounted
##
## Parses the dice notation used throughout the Alternity data.
##
## Three forms appear in the rules, previously handled by three separate pieces
## of ad-hoc string work:
##
##   mutation formulas   d8, d6+2, d4-1, or a bare integer
##                       (alternity_rules_mutations._roll_mutation_formula,
##                        which handled only these)
##   situation dice      -d20, -d4, +d0, +d4, +2d20, +3d20
##                       (alternity_rules.action_step_die)
##   damage              d4s, d4+2w, d6+2m -- a die plus a damage-type suffix,
##                       written as ordinary/good/amazing triples like
##                       "d4s/d4+2w/d6+2m"
##                       (alternity_rules_equipment._damage_segment_with_bonus)
##
##   random abilities    10+d4, 8+d6, 4+d10 -- constant first, die second.
##                       Tables G2 and G3 are written this way throughout;
##                       "10+d4" parses to the same term as "d4+10".
##
## Parsing is separated from rolling on purpose: what dice a notation describes
## is pure string work, and stays the same whether the roll is resolved by a
## seeded RNG (headless, tests, mutation tables) or by tumbling physical dice on
## the table. See random_source.gd.
##
## Not every damage value is rollable. Of the 291 damage segments in the shipped
## equipment catalog, three are prose: "As Load" on the Bantam and Grenade
## launchers (they deal whatever grenade is loaded) and "Special" on smoke
## grenades (no damage). parse() rejects these and preserves the original text
## in `source`, so a caller can display them instead of offering a roll. Callers
## must handle ok=false rather than assuming every weapon can be rolled.
##

## Damage type suffixes: stun, wound, mortal, fatigue.
const DAMAGE_TYPES := ["s", "w", "m", "f"]

## Dice group: optional sign, optional count, d<sides>, optional modifier,
## optional damage-type suffix. Examples: d8, +2d20, -d4, d4+2w, d6-1m
const _DICE_PATTERN := "^([+-])?([0-9]*)[dD]([0-9]+)([+-][0-9]+)?([swmfSWMF])?$"

## A flat value with no die at all: 3, -2, 5w
const _FLAT_PATTERN := "^([+-]?[0-9]+)([swmfSWMF])?$"

## Leading-constant form used by the random ability tables (G2/G3): the constant
## comes first and the die second -- 10+d4, 8+d6, 4+d10, 3-d6. Equivalent to
## d4+10 but written the other way round throughout those tables.
const _LEADING_CONSTANT_PATTERN := "^([+-]?[0-9]+)([+-])([0-9]*)[dD]([0-9]+)([swmfSWMF])?$"

static var _dice_regex: RegEx
static var _flat_regex: RegEx
static var _leading_constant_regex: RegEx


## Parse one notation term.
##
## Returns a dictionary with:
##   ok           false if the text is not recognisable notation
##   count        number of dice (0 when the term is a flat value)
##   sides        faces per die (0 for "+d0", which contributes nothing)
##   modifier     signed constant added after the dice
##   sign         +1 or -1, applied to the whole term; -d4 subtracts its roll
##   damage_type  "s", "w", "m", "f", or "" when absent
##   source       the original text
static func parse(text: String) -> Dictionary:
	var clean := text.strip_edges()
	var empty := {
		"ok": false, "count": 0, "sides": 0, "modifier": 0,
		"sign": 1, "damage_type": "", "source": text,
	}
	if clean.is_empty():
		return empty

	_ensure_regexes()

	var match_result := _dice_regex.search(clean)
	if match_result != null:
		var sign := -1 if match_result.get_string(1) == "-" else 1
		var count_text := match_result.get_string(2)
		# "d6" means one die; "2d20" means two.
		var count := 1 if count_text.is_empty() else AlternityNum.as_int(count_text, 1)
		var sides := AlternityNum.as_int(match_result.get_string(3), 0)
		var modifier := AlternityNum.as_int(match_result.get_string(4), 0)
		return {
			"ok": true,
			"count": count,
			"sides": sides,
			"modifier": modifier,
			"sign": sign,
			"damage_type": match_result.get_string(5).to_lower(),
			"source": text,
		}

	var flat_match := _flat_regex.search(clean)
	if flat_match != null:
		return {
			"ok": true,
			"count": 0,
			"sides": 0,
			"modifier": AlternityNum.as_int(flat_match.get_string(1), 0),
			"sign": 1,
			"damage_type": flat_match.get_string(2).to_lower(),
			"source": text,
		}

	# "10+d4" is the same term as "d4+10"; the ability tables write the constant
	# first. A minus ("3-d6") subtracts the die, which the sign field carries.
	var leading_match := _leading_constant_regex.search(clean)
	if leading_match != null:
		var lead_count_text := leading_match.get_string(3)
		return {
			"ok": true,
			"count": 1 if lead_count_text.is_empty() else AlternityNum.as_int(lead_count_text, 1),
			"sides": AlternityNum.as_int(leading_match.get_string(4), 0),
			"modifier": AlternityNum.as_int(leading_match.get_string(1), 0),
			"sign": -1 if leading_match.get_string(2) == "-" else 1,
			"damage_type": leading_match.get_string(5).to_lower(),
			"source": text,
		}

	return empty


static func is_valid(text: String) -> bool:
	return bool(parse(text).get("ok", false))


## Split an "ordinary/good/amazing" damage string into its parsed terms.
##
## Returns one entry per segment, in order, so callers can index by degree of
## success. Segments that fail to parse come back with ok=false rather than
## being dropped, keeping the positions aligned.
static func parse_damage_track(text: String) -> Array:
	var terms: Array = []
	if text.strip_edges().is_empty():
		return terms
	for segment in text.split("/"):
		terms.append(parse(String(segment).strip_edges()))
	return terms


## Smallest and largest totals a term can produce, before any external bonus.
## Useful for validating a physical roll landed in a possible range.
static func bounds(term: Dictionary) -> Array:
	if not bool(term.get("ok", false)):
		return [0, 0]
	var count: int = AlternityNum.as_int(term.get("count", 0))
	var sides: int = AlternityNum.as_int(term.get("sides", 0))
	var modifier: int = AlternityNum.as_int(term.get("modifier", 0))
	var sign: int = AlternityNum.as_int(term.get("sign", 1), 1)

	# A zero-sided die ("+d0") is a real notation meaning "no die".
	var lowest := count + modifier if sides > 0 else modifier
	var highest := (count * sides) + modifier if sides > 0 else modifier
	if sign < 0:
		return [-highest, -lowest]
	return [lowest, highest]


## Render a parsed term back to notation. format(parse(x)) normalises spacing
## and case rather than reproducing the input exactly.
static func format(term: Dictionary) -> String:
	if not bool(term.get("ok", false)):
		return String(term.get("source", ""))

	var count: int = AlternityNum.as_int(term.get("count", 0))
	var sides: int = AlternityNum.as_int(term.get("sides", 0))
	var modifier: int = AlternityNum.as_int(term.get("modifier", 0))
	var sign: int = AlternityNum.as_int(term.get("sign", 1), 1)
	var damage_type := String(term.get("damage_type", ""))

	var out := ""
	if count > 0:
		if sign < 0:
			out += "-"
		if count > 1:
			out += str(count)
		out += "d%d" % sides
		if modifier != 0:
			out += "%+d" % modifier
	else:
		out += str(modifier)
	return out + damage_type


static func _ensure_regexes() -> void:
	if _dice_regex == null:
		_dice_regex = RegEx.new()
		_dice_regex.compile(_DICE_PATTERN)
	if _flat_regex == null:
		_flat_regex = RegEx.new()
		_flat_regex.compile(_FLAT_PATTERN)
	if _leading_constant_regex == null:
		_leading_constant_regex = RegEx.new()
		_leading_constant_regex.compile(_LEADING_CONSTANT_PATTERN)
