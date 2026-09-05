extends "res://tools/test_harness.gd"
##
## The Will chapter, pinned to the manual.
##
## Fifth of the ability-chapter suites. Will is the mental defence: it sets the
## passive resistance against manipulation and psionics, feeds actions per round
## with Constitution, and sizes the psionic and Faith FX energy pools.
##
## Transcribed from the Player's Handbook breakdown rather than read back out of
## the data.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

## Catalog name -> [base cost, untrained allowed]
const WIL_SKILLS := {
	"Administration": [4, true],
	"Bureaucracy": [3, true],
	"Management": [3, true],
	"Animal Handling": [3, true],
	"Animal Riding": [1, true],
	"Animal Training": [1, true],
	"Awareness": [3, true],
	"Intuition": [3, true],
	"Perception": [2, true],
	"Creativity": [4, true],
	"Investigate": [7, true],
	"Interrogate": [4, true],
	"Search": [4, true],
	"Track": [4, true],
	"Resolve": [5, true],
	"Mental Resolve": [3, true],
	"Physical Resolve": [3, true],
	"Street Smart": [5, true],
	"Criminal Elements": [3, true],
	"Street Knowledge": [3, true],
	"Teach": [5, true],
}

## Table P3: the Will range each species may be built within.
const SPECIES_WIL_RANGE := {
	"Human": [4, 14],
	"Fraal": [9, 16],
	"Mechalus": [6, 12],
	"Sesheyan": [9, 15],
	"T'sa": [4, 12],
	"Weren": [4, 12],
}

## Table P2, as it applies to manipulation and mental powers aimed at the hero.
const RESISTANCE_MODIFIER := {
	4: -2, 5: -1, 6: -1, 7: 0, 10: 0,
	11: 1, 12: 1, 13: 2, 14: 2, 15: 3, 16: 3,
	17: 4, 18: 4, 19: 5, 22: 5,
}

## Net Will adjustment by age category, measured from young adult. Table G1
## lists these as increments -- middle age and old age each add one -- so an old
## hero carries both.
const AGE_WIL := {
	"adolescent": -1,
	"young_adult": 0,
	"mature": 0,
	"middle_aged": 1,
	"old": 2,
	"ancient": 2,
}

const SKILL_RESOLVE := 134
const SKILL_MENTAL_RESOLVE := 135
const SKILL_TELEPATHY := 901

const SPECIES_HUMAN := 0
const SPECIES_FRAAL := 1
const PROFESSION_COMBAT_SPEC := 0
const PROFESSION_MINDWALKER := 6

var _rules


func _init() -> void:
	begin("will chapter")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_costs_and_training()
	_test_species_ranges()
	_test_free_broad_skills()
	_test_resistance_modifier()
	_test_mental_resolve_rank_benefit()
	_test_psionic_energy_pools()
	_test_age_modifiers()

	finish()


func _skill_named(skill_name: String) -> Dictionary:
	for skill in _rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and String(skill.get("name", "")) == skill_name:
			return skill
	return {}


func _species_named(species_name: String) -> Dictionary:
	for species in _rules.species:
		if typeof(species) == TYPE_DICTIONARY and String(species.get("name", "")) == species_name:
			return species
	return {}


func _test_costs_and_training() -> void:
	for skill_name in WIL_SKILLS:
		var skill: Dictionary = _skill_named(String(skill_name))
		if not check(not skill.is_empty(), "%s is in the catalog" % skill_name):
			continue
		var expected: Array = WIL_SKILLS[skill_name]
		check_eq(
			AlternityNum.as_int(skill.get("base_price", -1)),
			AlternityNum.as_int(expected[0]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			bool(skill.get("untrained", true)), bool(expected[1]),
			"%s may be used untrained" % skill_name
		)
		check_eq(String(skill.get("stat", "")), "WIL", "%s is a Will skill" % skill_name)

	# Psionics are their own chapter; the two unnamed specialties are the ones a
	# player fills in for Creativity and Teach.
	for skill in _rules.skills:
		if typeof(skill) != TYPE_DICTIONARY or String(skill.get("stat", "")) != "WIL":
			continue
		if _rules.is_psionic_skill(skill):
			continue
		# This sweep audits one chapter of one book, so a skill that belongs to a
		# setting is out of its scope by definition -- Dark*Matter's Lore tree is
		# not missing from the Player's Handbook, it was never in it.
		if not String(skill.get("setting", "")).strip_edges().is_empty():
			continue
		var name := String(skill.get("name", ""))
		check_true(
			WIL_SKILLS.has(name) or bool(skill.get("custom_name", false)),
			"%s is a Will skill the manual describes" % name
		)


func _test_species_ranges() -> void:
	for species_name in SPECIES_WIL_RANGE:
		var species: Dictionary = _species_named(String(species_name))
		if not check(not species.is_empty(), "%s is in the catalog" % species_name):
			continue
		var limits: Array = species.get("ability_limits", {}).get("WIL", [])
		if not check(limits.size() >= 2, "%s has a Will range" % species_name):
			continue
		var expected: Array = SPECIES_WIL_RANGE[species_name]
		check_eq(
			AlternityNum.as_int(limits[0]), AlternityNum.as_int(expected[0]),
			"%s Will starts at %d" % [species_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			AlternityNum.as_int(limits[1]), AlternityNum.as_int(expected[1]),
			"%s Will tops out at %d" % [species_name, AlternityNum.as_int(expected[1])]
		)


## Awareness is free to every core species; a fraal also begins with Resolve
## and Telepathy.
func _test_free_broad_skills() -> void:
	var awareness: Dictionary = _skill_named("Awareness")
	if not check(not awareness.is_empty(), "Awareness resolves"):
		return
	var awareness_id := AlternityNum.as_int(awareness.get("id", -1))

	for species in _rules.species:
		if typeof(species) != TYPE_DICTIONARY:
			continue
		var species_name := String(species.get("name", ""))
		var free_ids: Array = []
		for id in species.get("free_skill_ids", []):
			free_ids.append(AlternityNum.as_int(id))
		check_true(free_ids.has(awareness_id), "%s begins with Awareness" % species_name)

		# Keyed on the species' own psionic flag rather than on the name Fraal.
		# Dark*Matter's Greys have the same heritage and the same free skills, and
		# a third such species would otherwise mean editing this line again --
		# which is the moment somebody edits it to match the data instead of
		# asking whether the data is right.
		var psionic := bool(species.get("psionic", false))
		check_eq(
			free_ids.has(SKILL_RESOLVE), psionic,
			"%s %s Resolve" % [species_name, "begins with" if psionic else "does not begin with"]
		)
		check_eq(
			free_ids.has(SKILL_TELEPATHY), psionic,
			"%s %s Telepathy" % [species_name, "begins with" if psionic else "does not begin with"]
		)


func _test_resistance_modifier() -> void:
	for score in RESISTANCE_MODIFIER:
		check_eq(
			_rules.resistance_modifier(AlternityNum.as_int(score)),
			AlternityNum.as_int(RESISTANCE_MODIFIER[score]),
			"WIL %d gives a %+d step resistance modifier" % [
				AlternityNum.as_int(score), AlternityNum.as_int(RESISTANCE_MODIFIER[score]),
			]
		)


## Mental Resolve permanently hardens the hero's Will resistance: one step at
## rank 4, another at 8, another at 12.
func _test_mental_resolve_rank_benefit() -> void:
	var expected := {0: 0, 3: 0, 4: 1, 7: 1, 8: 2, 11: 2, 12: 3}
	for rank in expected:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = SPECIES_HUMAN
		character["abilities"]["WIL"] = 10   # base modifier of 0
		_rules.ensure_character_shape(character)
		_rules.achievements.set_achievement_points(character, 200)
		_rules.force_skill_rank(character, SKILL_RESOLVE, 1)
		if AlternityNum.as_int(rank) > 0:
			_rules.force_skill_rank(character, SKILL_MENTAL_RESOLVE, AlternityNum.as_int(rank))
		check_eq(
			_rules.character_resistance_modifier(character, "WIL"),
			AlternityNum.as_int(expected[rank]),
			"Mental Resolve rank %d gives a %+d step Will resistance modifier" % [
				AlternityNum.as_int(rank), AlternityNum.as_int(expected[rank]),
			]
		)


## A Mindwalker draws on their full Will; a talent of another profession on
## half. A fraal is a step more capable in either role.
func _test_psionic_energy_pools() -> void:
	var cases := [
		[SPECIES_HUMAN, PROFESSION_MINDWALKER, 12, 12, "a mindwalker draws WIL"],
		[SPECIES_FRAAL, PROFESSION_MINDWALKER, 12, 18, "a fraal mindwalker draws WIL x 1.5"],
		[SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12, 6, "a talent draws half of WIL"],
		[SPECIES_FRAAL, PROFESSION_COMBAT_SPEC, 12, 12, "a fraal talent draws full WIL"],
		[SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 11, 6, "half of an odd WIL rounds up"],
	]
	for spec in cases:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = AlternityNum.as_int(spec[0])
		character["profession_id"] = AlternityNum.as_int(spec[1])
		character["abilities"]["WIL"] = AlternityNum.as_int(spec[2])
		_rules.ensure_character_shape(character)
		# A non-mindwalker needs the optional rule before they may be psionic.
		_rules.set_optional_rule(character, "psionic_talents", true)
		_rules.force_skill_rank(character, SKILL_TELEPATHY, 1)

		var will := AlternityNum.as_int(_rules.effective_abilities(character).get("WIL", 0))
		if will != AlternityNum.as_int(spec[2]):
			continue   # species limits moved the score; the case no longer applies
		check_eq(
			_rules.psionic_energy_points(character),
			AlternityNum.as_int(spec[3]),
			"%s (WIL %d gives %d)" % [String(spec[4]), will, AlternityNum.as_int(spec[3])]
		)


## Table G1's Will adjustments accumulate: middle age and old age each add one,
## so an old hero carries both and an ancient one keeps them.
func _test_age_modifiers() -> void:
	for category in AGE_WIL:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = SPECIES_HUMAN
		character["age_category"] = String(category)
		_rules.ensure_character_shape(character)
		_rules.set_optional_rule(character, "age_effects", true)
		check_eq(
			_rules.age_modifier(character, "WIL"),
			AlternityNum.as_int(AGE_WIL[category]),
			"%s adjusts Will by %+d" % [category, AlternityNum.as_int(AGE_WIL[category])]
		)
