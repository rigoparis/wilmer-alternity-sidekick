extends "res://tools/test_harness.gd"
##
## Table P1: Profession Requirements, pinned to the scan.
##
## Transcribed straight from the Player's Handbook page 30 table -- not read
## back out of the data -- with the Mindwalker row cross-checked against the
## Chapter 14 prose on p. 227 ("Hero Mindwalkers must have the following scores
## or greater in these Abilities: Will 11, Intelligence 9, Constitution 9.").
##
##   Profession    STR  DEX  CON  INT  WIL  PER
##   Combat Spec    11   --    9   --   --   --
##   Diplomat       --   --   --   --    9   11
##   Free Agent     --   11   --   --    9   --
##   Tech Op        --    9   --   11   --   --
##   Mindwalker*    --   --    9    9   11   --
##
## Each entry has exactly the minimums the table prints and no others. Adepts
## carry no static block of their own (Beyond Science: A Guide to FX p. 6) -- an
## Adept must meet the requirements of the secondary profession it pairs with --
## so each pre-composed Adept/Diplomat mix here is pinned to the stat set of its
## parent profession. Non-Professionals have no minimums (Gamemaster Guide p. 89).

const RulesScript := preload("res://scripts/alternity_rules.gd")

## profession id -> the complete ability_minimums dict Table P1 calls for.
const EXPECTED_MINIMUMS := {
	0: {"STR": 11, "CON": 9},              # Combat Spec
	1: {"WIL": 9, "PER": 11},              # Diplomat (Combat Spec)
	2: {"WIL": 9, "PER": 11},              # Diplomat (Free Agent)
	3: {"WIL": 9, "PER": 11},              # Diplomat (Tech Op)
	7: {"WIL": 9, "PER": 11},              # Diplomat (Mindwalker)
	4: {"DEX": 11, "WIL": 9},              # Free Agent
	5: {"DEX": 9, "INT": 11},              # Tech Op
	6: {"CON": 9, "INT": 9, "WIL": 11},    # Mindwalker
	8: {"WIL": 9, "PER": 11},              # Diplomat (Adept)
	9: {"STR": 11, "CON": 9},              # Adept (Combat Spec)
	10: {"WIL": 9, "PER": 11},             # Adept (Diplomat)
	11: {"DEX": 11, "WIL": 9},             # Adept (Free Agent)
	12: {"DEX": 9, "INT": 11},             # Adept (Tech Op)
	13: {"CON": 9, "INT": 9, "WIL": 11},   # Adept (Mindwalker)
	14: {},                                # Non-Professional
}

var _rules


func _init() -> void:
	begin("profession requirements")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_table_p1_is_transcribed_exactly()
	_test_no_phantom_floor_on_the_ability_steppers()

	finish()


## Every profession's ability_minimums is exactly what Table P1 prints -- no
## missing entry, and no spurious extra requirement padded on.
func _test_table_p1_is_transcribed_exactly() -> void:
	var seen: Array = []
	for profession in RulesScript.PROFESSION_DEFINITIONS:
		var id := AlternityNum.as_int(profession.get("id", -1), -1)
		seen.append(id)
		if not check(EXPECTED_MINIMUMS.has(id), "profession id %d is a known Table P1 row" % id):
			continue
		var expected: Dictionary = EXPECTED_MINIMUMS[id]
		var actual: Dictionary = profession.get("ability_minimums", {})
		var name := String(profession.get("name", "id %d" % id))

		check_eq(actual.size(), expected.size(),
			"%s lists exactly %d ability minimum(s)" % [name, expected.size()])
		for ability in ["STR", "DEX", "CON", "INT", "WIL", "PER"]:
			check_eq(
				AlternityNum.as_int(actual.get(ability, 0)),
				AlternityNum.as_int(expected.get(ability, 0)),
				"%s %s minimum" % [name, ability]
			)

	for id in EXPECTED_MINIMUMS:
		check(seen.has(id), "Table P1 row id %d is present in the catalog" % id)


## ability_limits() folds the profession minimum into the floor the Basics-tab
## stepper enforces. A phantom requirement there forbids a legal hero, so prove
## the floor for a stat the table leaves blank stays at the species minimum.
func _test_no_phantom_floor_on_the_ability_steppers() -> void:
	var species: Dictionary = _rules.get_species_by_id(0) # Human, 4-14 on every ability
	var cases := [
		{"profession_id": 0, "ability": "DEX", "note": "Combat Spec does not require Dexterity"},
		{"profession_id": 2, "ability": "INT", "note": "a Diplomat does not require Intelligence"},
		{"profession_id": 4, "ability": "INT", "note": "a Free Agent does not require Intelligence"},
		{"profession_id": 5, "ability": "CON", "note": "a Tech Op does not require Constitution"},
	]
	for case in cases:
		var hero: Dictionary = _rules.default_character()
		hero["species_id"] = 0
		hero["profession_id"] = case["profession_id"]
		_rules.ensure_character_shape(hero)
		var species_floor := AlternityNum.as_int(
			species.get("ability_limits", {}).get(case["ability"], [4, 14])[0]
		)
		check_eq(
			AlternityNum.as_int(_rules.ability_limits(hero, case["ability"])[0]),
			species_floor,
			"%s, so its floor stays at the species minimum (%d)" % [case["note"], species_floor]
		)
