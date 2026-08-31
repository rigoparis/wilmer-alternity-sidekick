extends "res://tools/test_harness.gd"
##
## CharacterDoc is the ownership boundary the UI rewrite is built on, so this
## covers three things: that wrapping a character does not alter it, that
## mutations announce themselves accurately, and that the per-document summary
## cache behaves where the old single-slot one did not.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Support := preload("res://tools/golden_support.gd")
const Doc := preload("res://scripts/core/character_doc.gd")


func _init() -> void:
	begin("character doc")

	_test_roundtrip_matches_golden()
	_test_summary_matches_rules()
	_test_change_signals()
	_test_dirty_tracking()
	_test_summary_cache()
	_test_multiple_documents()
	_test_typed_accessors()

	finish()


func _fresh_rules():
	var rules = RulesScript.new()
	rules.load_core_data()
	return rules


## Wrapping a stored character must not change it. Compared against the same
## goldens the rules engine is held to, so the doc cannot quietly normalize
## something differently.
func _test_roundtrip_matches_golden() -> void:
	for name in Support.fixture_names():
		var raw = Support.load_json(Support.fixture_path(name))
		var golden = JSON.parse_string(_read(Support.golden_path(name)))
		if not check(typeof(golden) == TYPE_DICTIONARY, "golden loads for %s" % name):
			continue

		var doc = Doc.from_dict(_fresh_rules(), raw, name + ".json")
		# summary() settles the character: it writes achievement_points_available
		# back onto it, which the golden captured after the same call.
		doc.summary()

		# Both sides go through the same encode/decode cycle: Godot parses every
		# JSON number as a float, so a live Dictionary holding int 9 and the
		# same value read from disk (9.0) would otherwise differ everywhere.
		var actual = JSON.parse_string(JSON.stringify(doc.to_dict()))
		var differences := Support.diff(golden["normalized"], actual)
		if not check(
			differences.is_empty(),
			"%s round-trips through CharacterDoc unchanged (%d differences)" % [name, differences.size()]
		):
			for line in differences.slice(0, 6):
				printerr("        %s" % line)


func _test_summary_matches_rules() -> void:
	var name := "real_tech_op_marco"
	var doc = Doc.from_dict(_fresh_rules(), Support.load_json(Support.fixture_path(name)))

	var direct_rules = _fresh_rules()
	var direct_character = Support.load_json(Support.fixture_path(name))
	direct_rules.ensure_character_shape(direct_character)

	check_eq(
		Support.canonical(doc.summary()),
		Support.canonical(direct_rules.summary(direct_character)),
		"doc.summary() matches rules.summary() exactly"
	)


func _test_change_signals() -> void:
	var doc = Doc.new(_fresh_rules())
	var received: Array = []
	doc.changed.connect(func(sections: PackedStringArray): received.append(Array(sections)))

	doc.set_hero_name("Renamed")
	check_eq(received.size(), 1, "setting hero_name emits once")
	check_eq(received[0], [String(Doc.META)], "hero_name reports the meta section only")

	# Setting the same value again must not emit.
	doc.set_hero_name("Renamed")
	check_eq(received.size(), 1, "setting an unchanged value emits nothing")

	doc.set_notes("Session 4 notes")
	check_eq(received[1], [String(Doc.NOTES)], "notes reports the notes section only")

	# Profession reshapes skill costs and ability minimums, so it is global.
	received.clear()
	doc.set_profession_id(5)
	check_eq(received.size(), 1, "profession change emits once")
	check_eq(received[0].size(), Doc.ALL.size(), "profession change reports every section")

	# apply() reports whatever the caller declares, and passes the return value back.
	received.clear()
	var rules = _fresh_rules()
	var line_id = doc.apply([Doc.EQUIPMENT], func(c):
		return rules.equipment.add_equipment_to_character(c, "armor_core_001", 1))
	check_eq(received[0], [String(Doc.EQUIPMENT)], "apply reports the declared sections")
	check_true(not String(line_id).is_empty(), "apply returns the value from the action")


func _test_dirty_tracking() -> void:
	var doc = Doc.new(_fresh_rules())
	check_false(doc.is_dirty(), "a new document starts clean")

	var flips: Array = []
	doc.dirty_changed.connect(func(value: bool): flips.append(value))

	doc.set_hero_name("Edited")
	check_true(doc.is_dirty(), "editing marks the document dirty")
	check_eq(flips, [true], "dirty_changed fires once on the first edit")

	doc.set_career("Marine")
	check_eq(flips.size(), 1, "further edits do not re-emit dirty_changed")

	doc.mark_saved()
	check_false(doc.is_dirty(), "mark_saved clears dirty")
	check_eq(flips, [true, false], "dirty_changed fires on the way back to clean")


func _test_summary_cache() -> void:
	var doc = Doc.new(_fresh_rules())
	var first := doc.summary()

	# The returned dictionary must be a copy: the old implementation handed out
	# the live cache, so a caller could corrupt it.
	first["skill_points_remaining"] = -9999
	check_ne(
		AlternityNum.as_int(doc.summary().get("skill_points_remaining", 0)), -9999,
		"summary returns a copy, not the live cache"
	)

	# A mutation must invalidate it.
	var before := AlternityNum.as_int(doc.summary().get("skill_points_remaining", 0))
	doc.set_ability(&"INT", doc.get_ability(&"INT") + 2)
	check_ne(
		AlternityNum.as_int(doc.summary().get("skill_points_remaining", 0)), before,
		"summary recomputes after an ability change"
	)


## The old cache was a single slot on AlternityRules keyed on character.hash(),
## so alternating between characters missed every time -- the case a GM viewing
## several players hits constantly. Per-document caches must stay independent.
func _test_multiple_documents() -> void:
	var rules = _fresh_rules()
	var a = Doc.from_dict(rules, Support.load_json(Support.fixture_path("real_tech_op_marco")))
	var b = Doc.from_dict(rules, Support.load_json(Support.fixture_path("synthetic_mutant")))

	var a_first := JSON.stringify(a.summary(), "", true)
	var b_first := JSON.stringify(b.summary(), "", true)
	check_ne(a_first, b_first, "two different characters summarize differently")

	# Interleave: each must keep returning its own result.
	check_eq(JSON.stringify(a.summary(), "", true), a_first, "document A is stable after B was summarized")
	check_eq(JSON.stringify(b.summary(), "", true), b_first, "document B is stable after A was summarized")

	# Editing one must not disturb the other.
	a.set_hero_name("Changed A")
	check_eq(JSON.stringify(b.summary(), "", true), b_first, "editing A does not affect B")


func _test_typed_accessors() -> void:
	var doc = Doc.new(_fresh_rules())

	doc.set_hero_name("Vance")
	check_eq(doc.get_hero_name(), "Vance", "hero_name round-trips")
	doc.set_player_name("Fixture")
	check_eq(doc.get_player_name(), "Fixture", "player_name round-trips")
	doc.set_career("Pilot")
	check_eq(doc.get_career(), "Pilot", "career round-trips")
	doc.set_notes("note")
	check_eq(doc.get_notes(), "note", "notes round-trips")

	doc.set_species_id(1)
	check_eq(doc.get_species_id(), 1, "species_id round-trips")

	# set_ability clamps into the legal range rather than storing junk.
	var limits: Array = _fresh_rules().ability_limits(doc.raw(), "STR")
	doc.set_ability(&"STR", 99)
	check_eq(
		doc.get_ability(&"STR"), AlternityNum.as_int(limits[1]),
		"set_ability clamps above the maximum"
	)
	doc.set_ability(&"STR", -5)
	check_eq(
		doc.get_ability(&"STR"), AlternityNum.as_int(limits[0]),
		"set_ability clamps below the minimum"
	)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
