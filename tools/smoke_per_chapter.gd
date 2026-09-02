extends "res://tools/test_harness.gd"
##
## The Personality chapter, pinned to the manual.
##
## Last of the six ability-chapter suites. Personality is the other ability with
## no passive resistance modifier: it is deployed actively to shift attitudes,
## and an opponent resisting a Personality skill rolls against their own
## Intelligence or Will instead.
##
## Transcribed from the Player's Handbook breakdown rather than read back out of
## the data.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

## Catalog name -> [base cost, untrained allowed]
const PER_SKILLS := {
	"Culture": [5, true],
	"Diplomacy": [3, true],
	"Etiquette (specific)": [2, false],
	"First Encounter": [3, true],
	"Deception": [5, true],
	"Bluff": [3, true],
	"Bribe": [3, true],
	"Gamble": [3, true],
	"Entertainment": [4, true],
	"Act": [2, true],
	"Dance": [2, true],
	"Musical Instrument": [2, false],
	"Sing": [2, true],
	"Interaction": [3, true],
	"Bargain": [3, true],
	"Charm": [3, true],
	"Interview": [3, true],
	"Intimidate": [3, true],
	"Seduce": [3, true],
	"Taunt": [2, true],
	"Leadership": [4, true],
	"Command": [4, true],
	"Inspire": [4, false],
}

## Table P3: the Personality range each species may be built within.
const SPECIES_PER_RANGE := {
	"Human": [4, 14],
	"Fraal": [4, 15],
	"Mechalus": [4, 12],
	"Sesheyan": [4, 12],
	"T'sa": [4, 13],
	"Weren": [4, 12],
}

## Table P6: Personality -> [maximum last resort points, skill points to recover one]
const LAST_RESORTS := {
	4: [0, 0], 7: [0, 0],
	8: [1, 3], 10: [1, 3],
	11: [2, 2], 12: [2, 2],
	13: [3, 1], 14: [3, 1],
	15: [4, 1], 16: [4, 1],
}

const SPECIES_HUMAN := 0
const SPECIES_FRAAL := 1
const PROFESSION_COMBAT_SPEC := 0
const PROFESSION_FREE_AGENT := 4

var _rules


func _init() -> void:
	begin("personality chapter")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_costs_and_training()
	_test_species_ranges()
	_test_no_passive_resistance()
	_test_last_resorts()
	_test_free_agent_last_resort_bonus()
	_test_untrained_score()
	_test_leadership_rank_benefits()

	finish()


func _skill_named(skill_name: String) -> Dictionary:
	for skill in _rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and String(skill.get("name", "")) == skill_name:
			return skill
	return {}


func _character(species_id: int, profession_id: int, per: int) -> Dictionary:
	var character: Dictionary = _rules.default_character()
	character["species_id"] = species_id
	character["profession_id"] = profession_id
	character["abilities"]["PER"] = per
	_rules.ensure_character_shape(character)
	return character


func _test_costs_and_training() -> void:
	for skill_name in PER_SKILLS:
		var skill: Dictionary = _skill_named(String(skill_name))
		if not check(not skill.is_empty(), "%s is in the catalog" % skill_name):
			continue
		var expected: Array = PER_SKILLS[skill_name]
		check_eq(
			AlternityNum.as_int(skill.get("base_price", -1)),
			AlternityNum.as_int(expected[0]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			bool(skill.get("untrained", true)), bool(expected[1]),
			"%s untrained use is %s" % [skill_name, "allowed" if bool(expected[1]) else "prohibited"]
		)
		check_eq(String(skill.get("stat", "")), "PER", "%s is a Personality skill" % skill_name)

	# Telepathy is Personality-governed psionics and belongs to its own chapter.
	for skill in _rules.skills:
		if typeof(skill) != TYPE_DICTIONARY or String(skill.get("stat", "")) != "PER":
			continue
		if _rules.is_psionic_skill(skill):
			continue
		var name := String(skill.get("name", ""))
		check_true(
			PER_SKILLS.has(name) or bool(skill.get("custom_name", false)),
			"%s is a Personality skill the manual describes" % name
		)


func _test_species_ranges() -> void:
	for species_name in SPECIES_PER_RANGE:
		var species: Dictionary = _species_named(String(species_name))
		if not check(not species.is_empty(), "%s is in the catalog" % species_name):
			continue
		var limits: Array = species.get("ability_limits", {}).get("PER", [])
		if not check(limits.size() >= 2, "%s has a Personality range" % species_name):
			continue
		var expected: Array = SPECIES_PER_RANGE[species_name]
		check_eq(
			AlternityNum.as_int(limits[0]), AlternityNum.as_int(expected[0]),
			"%s Personality starts at %d" % [species_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			AlternityNum.as_int(limits[1]), AlternityNum.as_int(expected[1]),
			"%s Personality tops out at %d" % [species_name, AlternityNum.as_int(expected[1])]
		)


func _species_named(species_name: String) -> Dictionary:
	for species in _rules.species:
		if typeof(species) == TYPE_DICTIONARY and String(species.get("name", "")) == species_name:
			return species
	return {}


## Personality has no entry on Table P2 at any score, and the Free Agent's
## resistance pick cannot conjure one.
func _test_no_passive_resistance() -> void:
	for per in [4, 8, 11, 13, 14]:
		var character: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, per)
		check_eq(
			_rules.character_resistance_modifier(character, "PER"), 0,
			"PER %d gives no passive resistance modifier" % per
		)

	var free_agent: Dictionary = _character(SPECIES_HUMAN, PROFESSION_FREE_AGENT, 13)
	free_agent["free_agent_rm_bonus"] = "PER"
	check_eq(
		_rules.character_resistance_modifier(free_agent, "PER"), 0,
		"the Free Agent resistance pick cannot raise Personality"
	)


func _test_last_resorts() -> void:
	for per in LAST_RESORTS:
		var character: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, AlternityNum.as_int(per))
		var effective := AlternityNum.as_int(_rules.effective_abilities(character).get("PER", 0))
		if effective != AlternityNum.as_int(per):
			continue   # species or profession limits moved the score
		var expected: Array = LAST_RESORTS[per]
		var resorts: Dictionary = _rules.last_resorts(character)
		check_eq(
			AlternityNum.as_int(resorts.get("base_max", -1)),
			AlternityNum.as_int(expected[0]),
			"PER %d allows %d last resort point(s)" % [effective, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			AlternityNum.as_int(resorts.get("cost", -1)),
			AlternityNum.as_int(expected[1]),
			"PER %d recovers a point for %d SP" % [effective, AlternityNum.as_int(expected[1])]
		)


## A Free Agent carries one more last resort point than their Personality alone
## would allow.
func _test_free_agent_last_resort_bonus() -> void:
	for per in [8, 12, 14]:
		var ordinary: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, per)
		var agent: Dictionary = _character(SPECIES_HUMAN, PROFESSION_FREE_AGENT, per)
		var ordinary_per := AlternityNum.as_int(_rules.effective_abilities(ordinary).get("PER", 0))
		var agent_per := AlternityNum.as_int(_rules.effective_abilities(agent).get("PER", 0))
		if ordinary_per != agent_per:
			continue   # profession minimums moved one of the two scores
		check_eq(
			AlternityNum.as_int(_rules.last_resorts(agent).get("max", -1)),
			AlternityNum.as_int(_rules.last_resorts(ordinary).get("max", -1)) + 1,
			"a Free Agent with PER %d carries one extra last resort point" % agent_per
		)


func _test_untrained_score() -> void:
	for per in [8, 11, 13]:
		check_eq(
			_rules.untrained_score(per), int(floor(per / 2.0)),
			"an untrained Personality check uses half of %d" % per
		)


## Command and Inspire sharpen Leadership itself: one step at rank 4, two at 8,
## three at 12.
func _test_leadership_rank_benefits() -> void:
	for specialty in ["Command", "Inspire"]:
		var skill: Dictionary = _skill_named(specialty)
		if not check(not skill.is_empty(), "%s is in the catalog" % specialty):
			continue
		var benefits: Dictionary = _rules.skill_detail(skill).get("rank_benefits", {})
		for rank in [4, 8, 12]:
			check_true(
				benefits.has(rank) or benefits.has(str(rank)),
				"%s has a rank %d benefit" % [specialty, rank]
			)
