extends "res://tools/test_harness.gd"
##
## Dice notation parsing and seeded rolling.
##
## The most valuable part is _test_real_data_notation: rather than only checking
## invented strings, it parses every situation die the step table can emit and
## every damage string in the shipped equipment catalog. Those are the forms the
## roller will actually meet.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Notation := preload("res://scripts/core/dice/dice_notation.gd")
const Rng := preload("res://scripts/core/dice/rng_source.gd")
const Result := preload("res://scripts/core/dice/roll_result.gd")


func _init() -> void:
	begin("dice")

	_test_parse_mutation_formulas()
	_test_parse_situation_dice()
	_test_parse_damage()
	_test_invalid_notation()
	_test_bounds_and_format()
	_test_rolling()
	_test_seeded_reproducibility()
	_test_result_serialization()
	_test_real_data_notation()

	finish()


func _expect(text: String, count: int, sides: int, modifier: int, sign: int, damage_type: String) -> void:
	var term := Notation.parse(text)
	if not check(bool(term.get("ok", false)), "%s parses" % text):
		return
	check_eq(term["count"], count, "%s -> count" % text)
	check_eq(term["sides"], sides, "%s -> sides" % text)
	check_eq(term["modifier"], modifier, "%s -> modifier" % text)
	check_eq(term["sign"], sign, "%s -> sign" % text)
	check_eq(term["damage_type"], damage_type, "%s -> damage_type" % text)


## The forms _roll_mutation_formula handled: dN, dN+M, dN-M, and bare integers.
func _test_parse_mutation_formulas() -> void:
	_expect("d8", 1, 8, 0, 1, "")
	_expect("d6+2", 1, 6, 2, 1, "")
	_expect("d4-1", 1, 4, -1, 1, "")
	_expect("3", 0, 0, 3, 1, "")
	_expect("-2", 0, 0, -2, 1, "")
	_expect("D6", 1, 6, 0, 1, "")  # case-insensitive


## The situation dice action_step_die emits, including the multi-die forms at
## high steps and the "no die" +d0.
func _test_parse_situation_dice() -> void:
	_expect("+d4", 1, 4, 0, 1, "")
	_expect("-d4", 1, 4, 0, -1, "")
	_expect("-d20", 1, 20, 0, -1, "")
	_expect("+2d20", 2, 20, 0, 1, "")
	_expect("+3d20", 3, 20, 0, 1, "")
	_expect("+d0", 1, 0, 0, 1, "")


func _test_parse_damage() -> void:
	_expect("d4s", 1, 4, 0, 1, "s")
	_expect("d4+2w", 1, 4, 2, 1, "w")
	_expect("d6+2m", 1, 6, 2, 1, "m")
	_expect("d4-1f", 1, 4, -1, 1, "f")

	# An ordinary/good/amazing triple splits into three aligned terms.
	var track := Notation.parse_damage_track("d4s/d4+2w/d6+2m")
	check_eq(track.size(), 3, "damage track splits into three segments")
	check_eq(track[0]["damage_type"], "s", "first segment is stun")
	check_eq(track[1]["damage_type"], "w", "second segment is wound")
	check_eq(track[2]["damage_type"], "m", "third segment is mortal")
	check_eq(track[1]["modifier"], 2, "second segment keeps its modifier")

	check_eq(Notation.parse_damage_track("").size(), 0, "empty damage track yields nothing")


func _test_invalid_notation() -> void:
	for bad in ["", "   ", "hello", "d", "dd6", "4d", "d6++2", "2d6x3"]:
		check_false(Notation.is_valid(bad), "%s is rejected" % ("(empty)" if bad.strip_edges().is_empty() else bad))


func _test_bounds_and_format() -> void:
	check_eq(Notation.bounds(Notation.parse("d6")), [1, 6], "d6 bounds")
	check_eq(Notation.bounds(Notation.parse("2d6")), [2, 12], "2d6 bounds")
	check_eq(Notation.bounds(Notation.parse("d6+2")), [3, 8], "d6+2 bounds")
	# A subtracted situation die inverts its range.
	check_eq(Notation.bounds(Notation.parse("-d4")), [-4, -1], "-d4 bounds are negative")
	# "+d0" rolls nothing.
	check_eq(Notation.bounds(Notation.parse("+d0")), [0, 0], "+d0 contributes nothing")
	check_eq(Notation.bounds(Notation.parse("5")), [5, 5], "a flat value has no range")

	check_eq(Notation.format(Notation.parse("d6+2")), "d6+2", "format round-trips d6+2")
	check_eq(Notation.format(Notation.parse("2d20")), "2d20", "format round-trips 2d20")
	check_eq(Notation.format(Notation.parse("-d4")), "-d4", "format keeps the sign")
	check_eq(Notation.format(Notation.parse("d4+2w")), "d4+2w", "format keeps the damage type")


func _test_rolling() -> void:
	var source = Rng.new(12345)

	# Every roll must land inside the notation bounds, checked over enough
	# samples to catch an off-by-one in the range.
	for text in ["d4", "d6", "d20", "2d6", "d6+2", "-d4"]:
		var term := Notation.parse(text)
		var limits := Notation.bounds(term)
		var lowest: int = limits[0]
		var highest: int = limits[1]
		var all_in_range := true
		var seen := {}
		for _i in 200:
			var result = source.roll(term)
			if result.total < lowest or result.total > highest:
				all_in_range = false
			seen[result.total] = true
		check_true(all_in_range, "%s always rolls within %d..%d" % [text, lowest, highest])
		check_true(seen.size() > 1, "%s produces more than one distinct total" % text)

	# A d20 should reach both extremes within 500 rolls; if it never does, the
	# range is wrong even though every sample looked "in range".
	var d20 := Notation.parse("d20")
	var lowest_seen := 999
	var highest_seen := -999
	for _i in 500:
		var total = source.roll(d20).total
		lowest_seen = mini(lowest_seen, total)
		highest_seen = maxi(highest_seen, total)
	check_eq(lowest_seen, 1, "d20 reaches 1")
	check_eq(highest_seen, 20, "d20 reaches 20")

	# "+d0" must not call randi_range(1, 0).
	var zero = source.roll(Notation.parse("+d0"))
	check_eq(zero.total, 0, "+d0 totals zero")
	check_eq(zero.dice.size(), 0, "+d0 rolls no dice")

	# Faces and total must agree.
	var multi = source.roll(Notation.parse("3d6+1"))
	check_eq(multi.dice.size(), 3, "3d6+1 rolls three dice")
	var sum := 0
	for face in multi.dice:
		sum += face
	check_eq(multi.total, sum + 1, "total equals the sum of faces plus the modifier")

	# A subtracted die subtracts.
	var negative = source.roll(Notation.parse("-d4"))
	check_true(negative.total < 0, "-d4 produces a negative total")


func _test_seeded_reproducibility() -> void:
	var term := Notation.parse("3d20+2")
	var first: Array = []
	var second: Array = []
	var a = Rng.new(999)
	var b = Rng.new(999)
	for _i in 20:
		first.append(a.roll(term).total)
		second.append(b.roll(term).total)
	check_eq(first, second, "the same seed reproduces the same sequence")

	var different = Rng.new(1000)
	var third: Array = []
	for _i in 20:
		third.append(different.roll(term).total)
	check_ne(first, third, "a different seed produces a different sequence")

	check_eq(a.get_seed(), 999, "the seed is readable back")
	check_eq(Rng.new(999).roll(term).seed_used, 999, "results record the seed that produced them")


func _test_result_serialization() -> void:
	var source = Rng.new(7)
	var result = source.roll(Notation.parse("d4+2w"), "Pistol damage")
	result.player_id = "player-abc"
	result.character_id = "char-xyz"

	var restored = Result.from_dict(result.to_dict())
	check_eq(restored.notation, result.notation, "notation survives serialization")
	check_eq(restored.dice, result.dice, "faces survive serialization")
	check_eq(restored.total, result.total, "total survives serialization")
	check_eq(restored.damage_type, "w", "damage type survives serialization")
	check_eq(restored.source, Result.SOURCE_RNG, "source survives serialization")
	check_eq(restored.seed_used, 7, "seed survives serialization")
	check_eq(restored.player_id, "player-abc", "player id survives serialization")
	check_eq(restored.character_id, "char-xyz", "character id survives serialization")
	check_eq(restored.label, "Pistol damage", "label survives serialization")

	# It has to survive a JSON hop, since this is what goes over the wire.
	var through_json = Result.from_dict(JSON.parse_string(JSON.stringify(result.to_dict())))
	check_eq(through_json.total, result.total, "total survives a JSON round trip")
	check_eq(through_json.dice, result.dice, "faces survive a JSON round trip")

	check_true(result.describe().contains("w"), "describe includes the damage type")


## Parse every notation form the shipped data can actually produce.
func _test_real_data_notation() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()

	# Situation dice across the whole step range, including the extrapolated
	# high steps and the clamp below -5.
	var bad_steps: Array = []
	for step in range(-8, 13):
		var die: String = rules.action_step_die(step)
		if not Notation.is_valid(die):
			bad_steps.append("step %d -> %s" % [step, die])
	check_true(bad_steps.is_empty(), "every action_step_die output parses (bad: %s)" % str(bad_steps))

	# Every damage string in the equipment catalog.
	#
	# A few entries are deliberately prose rather than notation: launchers deal
	# whatever they are loaded with, and smoke has no damage at all. Those are
	# pinned here rather than tolerated, so a new unrollable form appearing in
	# the data shows up as a failure and gets handled in the roller UI instead
	# of silently becoming a dead "roll" button.
	var known_prose := ["As Load", "Special"]
	var checked := 0
	var unexpected: Array = []
	var prose_seen := {}

	for item in rules.equipment_catalog:
		var combat = item.get("combat", null)
		if typeof(combat) != TYPE_DICTIONARY:
			continue
		var damage := String(combat.get("damage", "")).strip_edges()
		if damage.is_empty():
			continue
		for term in Notation.parse_damage_track(damage):
			checked += 1
			if bool(term.get("ok", false)):
				continue
			var text := String(term.get("source", ""))
			if known_prose.has(text):
				prose_seen[text] = true
			elif unexpected.size() < 8:
				unexpected.append("%s: %s" % [item.get("name", "?"), text])

	check_true(checked > 100, "found damage strings in the equipment catalog (%d segments)" % checked)
	check_true(
		unexpected.is_empty(),
		"every catalog damage segment is notation or a known prose value (%d checked, unexpected: %s)"
			% [checked, str(unexpected)]
	)
	check_eq(prose_seen.size(), known_prose.size(), "all known prose damage values are still present")

	# Unrollable damage must fail cleanly, keeping the original text so the UI
	# can show it, rather than coming back as a bogus zero-damage term.
	for text in known_prose:
		var term := Notation.parse(text)
		check_false(bool(term.get("ok", false)), "%s is not treated as notation" % text)
		check_eq(String(term.get("source", "")), text, "%s keeps its text for display" % text)
