extends "res://tools/test_harness.gd"
##
## The Constitution chapter, pinned to the manual.
##
## Third of the ability-chapter suites. Constitution is the one ability with no
## passive resistance modifier -- it is rolled actively instead -- so what it
## governs is durability, actions per round, cyber tolerance and three broad
## skills.
##
## Transcribed from the Player's Handbook breakdown rather than read back out of
## the data.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

## Catalog name -> [base cost, untrained allowed]
const CON_SKILLS := {
	"Movement": [3, true],
	"Race": [2, true],
	"Swim": [1, true],
	"Trailblazing": [3, true],
	"Stamina": [3, true],
	"Endurance": [4, true],
	"Resist Pain": [4, true],
	"Survival": [5, true],
	"Survival Training": [3, true],
}

## Table P7: actions per round, from CON + WIL.
const ACTIONS_PER_ROUND := {
	8: 1, 15: 1,
	16: 2, 23: 2,
	24: 3, 31: 3,
	32: 4, 36: 4,
}

const SKILL_STAMINA := 52
const SPECIES_HUMAN := 0
const SPECIES_MECHALUS := 2
const SPECIES_WEREN := 5

var _rules


func _init() -> void:
	begin("constitution chapter")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_costs_and_training()
	_test_no_passive_resistance()
	_test_durability()
	_test_weren_durability()
	_test_actions_per_round()
	_test_cyber_tolerance()
	_test_profession_minimums()
	_test_stamina_rank_benefits()
	_test_old_age_costs_constitution()

	finish()


func _skill_named(skill_name: String) -> Dictionary:
	for skill in _rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and String(skill.get("name", "")) == skill_name:
			return skill
	return {}


func _character(species_id: int, con: int) -> Dictionary:
	var character: Dictionary = _rules.default_character()
	character["species_id"] = species_id
	character["abilities"]["CON"] = con
	_rules.ensure_character_shape(character)
	return character


func _test_costs_and_training() -> void:
	for skill_name in CON_SKILLS:
		var skill: Dictionary = _skill_named(String(skill_name))
		if not check(not skill.is_empty(), "%s is in the catalog" % skill_name):
			continue
		var expected: Array = CON_SKILLS[skill_name]
		check_eq(
			AlternityNum.as_int(skill.get("base_price", -1)),
			AlternityNum.as_int(expected[0]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			bool(skill.get("untrained", true)), bool(expected[1]),
			"%s may be used untrained" % skill_name
		)
		check_eq(String(skill.get("stat", "")), "CON", "%s is a Constitution skill" % skill_name)

	# Psionics are Constitution-governed too -- Biokinesis and its powers -- but
	# they are their own chapter, so only the core skills are checked here.
	for skill in _rules.skills:
		if typeof(skill) != TYPE_DICTIONARY or String(skill.get("stat", "")) != "CON":
			continue
		if _rules.is_psionic_skill(skill):
			continue
		check_true(
			CON_SKILLS.has(String(skill.get("name", ""))),
			"%s is a Constitution skill the manual describes" % String(skill.get("name", ""))
		)


## Constitution alone grants no passive resistance: it is rolled, not applied.
func _test_no_passive_resistance() -> void:
	for con in [4, 8, 12, 16, 18]:
		var character: Dictionary = _character(SPECIES_HUMAN, con)
		check_eq(
			_rules.character_resistance_modifier(character, "CON"), 0,
			"CON %d gives no passive resistance modifier" % con
		)


## Stun and Wound equal Constitution; Mortal and Fatigue are half, rounded up.
func _test_durability() -> void:
	for con in [4, 7, 9, 10, 13, 14]:
		var character: Dictionary = _character(SPECIES_HUMAN, con)
		var effective := AlternityNum.as_int(_rules.effective_abilities(character).get("CON", 0))
		var durability: Dictionary = _rules.durability(character)
		check_eq(
			AlternityNum.as_int(durability.get("stun", -1)), effective,
			"CON %d gives a stun rating of %d" % [effective, effective]
		)
		check_eq(
			AlternityNum.as_int(durability.get("wound", -1)), effective,
			"CON %d gives a wound rating of %d" % [effective, effective]
		)
		var half := int(ceil(effective / 2.0))
		check_eq(
			AlternityNum.as_int(durability.get("mortal", -1)), half,
			"CON %d gives a mortal rating of %d" % [effective, half]
		)
		check_eq(
			AlternityNum.as_int(durability.get("fatigue", -1)), half,
			"CON %d gives a fatigue rating of %d" % [effective, half]
		)


## A weren is tougher than their Constitution alone: every track is built from
## CON x 1.5, rounded down, before the halving.
func _test_weren_durability() -> void:
	for con in [8, 9, 12, 16]:
		var character: Dictionary = _character(SPECIES_WEREN, con)
		var effective := AlternityNum.as_int(_rules.effective_abilities(character).get("CON", 0))
		var base := int(floor(effective * 1.5))
		var durability: Dictionary = _rules.durability(character)
		check_eq(
			AlternityNum.as_int(durability.get("stun", -1)), base,
			"a weren with CON %d has a stun rating of %d" % [effective, base]
		)
		check_eq(
			AlternityNum.as_int(durability.get("mortal", -1)), int(ceil(base / 2.0)),
			"a weren with CON %d has a mortal rating of %d" % [effective, int(ceil(base / 2.0))]
		)


func _test_actions_per_round() -> void:
	for total in ACTIONS_PER_ROUND:
		# Read the thresholds directly: a Human cannot reach a CON + WIL of 32,
		# so building every total as a character would skip the top row.
		var half := AlternityNum.as_int(total) / 2
		var character: Dictionary = _rules.default_character()
		character["species_id"] = SPECIES_HUMAN
		character["abilities"]["CON"] = half
		character["abilities"]["WIL"] = AlternityNum.as_int(total) - half
		_rules.ensure_character_shape(character)

		var abilities: Dictionary = _rules.effective_abilities(character)
		var reached := AlternityNum.as_int(abilities.get("CON", 0)) + AlternityNum.as_int(abilities.get("WIL", 0))
		var expected := 1
		if reached >= 32:
			expected = 4
		elif reached >= 24:
			expected = 3
		elif reached >= 16:
			expected = 2
		check_eq(
			_rules.actions_per_round(character), expected,
			"CON + WIL of %d gives %d action(s) per round" % [reached, expected]
		)

	# And the printed boundaries, whether or not a hero can be built on them.
	check_eq(_rules.actions_per_round(_totals(15)), 1, "a total of 15 gives one action")
	check_eq(_rules.actions_per_round(_totals(16)), 2, "a total of 16 gives two actions")
	check_eq(_rules.actions_per_round(_totals(23)), 2, "a total of 23 gives two actions")
	check_eq(_rules.actions_per_round(_totals(24)), 3, "a total of 24 gives three actions")


## A bare character dictionary with the two scores set and nothing normalised,
## so species limits cannot clamp the total being tested.
func _totals(total: int) -> Dictionary:
	var half := total / 2
	return {"abilities": {"CON": half, "WIL": total - half}}


func _test_cyber_tolerance() -> void:
	for con in [8, 10, 14]:
		var human: Dictionary = _character(SPECIES_HUMAN, con)
		var effective := AlternityNum.as_int(_rules.effective_abilities(human).get("CON", 0))
		check_eq(
			_rules.cybertech.cyber_tolerance_total(human), effective,
			"cyber tolerance equals CON (%d)" % effective
		)

	var mechalus: Dictionary = _character(SPECIES_MECHALUS, 10)
	var mech_con := AlternityNum.as_int(_rules.effective_abilities(mechalus).get("CON", 0))
	check_eq(
		_rules.cybertech.cyber_tolerance_total(mechalus), mech_con + 4,
		"a mechalus tolerates CON + 4 (%d)" % (mech_con + 4)
	)


func _test_profession_minimums() -> void:
	var expected := {
		"Combat Spec": 9,
		"Tech Op": 9,
		"Mindwalker": 9,
	}
	for profession in AlternityRules.PROFESSION_DEFINITIONS:
		var name := String(profession.get("name", ""))
		var minimums: Dictionary = profession.get("ability_minimums", {})
		if expected.has(name):
			check_eq(
				AlternityNum.as_int(minimums.get("CON", 0)),
				AlternityNum.as_int(expected[name]),
				"%s requires CON %d" % [name, AlternityNum.as_int(expected[name])]
			)
		elif name.begins_with("Diplomat") or name == "Free Agent":
			check_false(
				minimums.has("CON"),
				"%s has no Constitution requirement" % name
			)


## Stamina's specialties harden the hero against exhaustion and knockout: one
## step at rank 4, two at 8, three at 12.
func _test_stamina_rank_benefits() -> void:
	for specialty in ["Endurance", "Resist Pain"]:
		var skill: Dictionary = _skill_named(specialty)
		if not check(not skill.is_empty(), "%s is in the catalog" % specialty):
			continue
		var detail: Dictionary = _rules.skill_detail(skill)
		var benefits: Dictionary = detail.get("rank_benefits", {})
		for rank in [4, 8, 12]:
			var has := benefits.has(rank) or benefits.has(str(rank))
			check_true(has, "%s has a rank %d benefit" % [specialty, rank])


## Age costs Constitution: an old hero is down a point.
func _test_old_age_costs_constitution() -> void:
	var character: Dictionary = _character(SPECIES_HUMAN, 12)
	_rules.set_optional_rule(character, "age_effects", true)
	character["age_category"] = "young_adult"
	var young := AlternityNum.as_int(_rules.effective_abilities(character).get("CON", 0))

	character["age_category"] = "old"
	var old := AlternityNum.as_int(_rules.effective_abilities(character).get("CON", 0))
	check_eq(old, young - 1, "an old hero loses a point of Constitution")
