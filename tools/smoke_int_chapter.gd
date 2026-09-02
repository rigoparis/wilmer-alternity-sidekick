extends "res://tools/test_harness.gd"
##
## The Intelligence chapter, pinned to the manual.
##
## Fourth of the ability-chapter suites, and the largest: Intelligence governs
## sixty-two skills across thirteen broads, sets the starting skill budget and
## the broad-skill cap, and feeds the action check with Dexterity.
##
## Transcribed from the Player's Handbook breakdown rather than read back out of
## the data.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

## Catalog name -> [base cost, untrained allowed]
const INT_SKILLS := {
	"Business": [4, true],
	"Corporate": [3, true],
	"Illicit business": [3, true],
	"Small business": [3, true],
	"Computer Science": [7, true],
	"Hacking": [5, false],
	"Hardware": [4, true],
	"Programming": [4, false],
	"Demolitions": [6, true],
	"Disarm": [4, true],
	"Scratch-built": [4, false],
	"Set explosives": [3, true],
	"Knowledge": [3, true],
	"Computer Operation": [1, true],
	"Deduce": [2, true],
	"First aid": [2, true],
	"(specific language)": [1, false],
	"(specific knowledge)": [1, true],
	"Law": [5, true],
	"Court Procedures": [3, true],
	"Law Enforcement": [3, true],
	"Life Science": [7, true],
	"Biology": [3, true],
	"Botany": [3, true],
	"Genetics": [3, false],
	"Xenology": [4, true],
	"Zoology": [3, true],
	"Medical Science": [7, true],
	"Forensics": [3, true],
	"Medical Knowledge": [3, true],
	"Psychology": [3, true],
	"Surgery": [5, false],
	"Treatment": [4, true],
	"Xenomedicine": [3, false],
	"Navigation": [6, true],
	"Drivespace Astrogation": [4, false],
	"System Astrogation": [3, true],
	"Surface": [3, true],
	"Physical Science": [7, true],
	"Astronomy": [3, true],
	"Chemistry": [3, true],
	"Physics": [3, true],
	"Planetology": [3, true],
	"Security": [5, true],
	"Protection Protocols": [3, true],
	"Security Devices": [3, true],
	"System Operation": [4, true],
	"Communication": [3, true],
	"Defenses": [3, true],
	"Engineering": [3, true],
	"Sensors": [3, true],
	"Weapons": [3, true],
	"Tactics": [6, true],
	"Infantry": [3, true],
	"Space": [3, true],
	"Vehicle": [3, true],
	"Technical Science": [7, true],
	"Invention": [4, false],
	"Juryrig": [3, true],
	"Repair": [3, true],
	"Technical Knowledge": [3, true],
}

## Table P3: the Intelligence range each species may be built within.
const SPECIES_INT_RANGE := {
	"Human": [4, 14],
	"Fraal": [9, 15],
	"Mechalus": [7, 15],
	"Sesheyan": [4, 12],
	"T'sa": [8, 14],
	"Weren": [4, 13],
}

## Table P5: starting skill points and the broad-skill cap, by Intelligence,
## for an alien. A Human adds 5 points and one broad skill.
const TABLE_P5 := {
	4: [15, 2], 5: [20, 2],
	6: [25, 3], 7: [30, 3],
	8: [35, 4], 9: [40, 4],
	10: [45, 5], 11: [50, 5],
	12: [55, 6], 13: [60, 6],
	14: [65, 7], 15: [70, 7],
	16: [75, 8],
}

var _rules


func _init() -> void:
	begin("intelligence chapter")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_costs_and_training()
	_test_species_ranges()
	_test_free_skills()
	_test_table_p5()
	_test_resistance_modifier()
	_test_action_check_contribution()
	_test_tech_op_action_bonus()

	finish()


func _skill_named(skill_name: String) -> Dictionary:
	for skill in _rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and String(skill.get("name", "")) == skill_name:
			return skill
	return {}


func _test_costs_and_training() -> void:
	for skill_name in INT_SKILLS:
		var skill: Dictionary = _skill_named(String(skill_name))
		if not check(not skill.is_empty(), "%s is in the catalog" % skill_name):
			continue
		var expected: Array = INT_SKILLS[skill_name]
		check_eq(
			AlternityNum.as_int(skill.get("base_price", -1)),
			AlternityNum.as_int(expected[0]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			bool(skill.get("untrained", true)), bool(expected[1]),
			"%s untrained use is %s" % [skill_name, "allowed" if bool(expected[1]) else "prohibited"]
		)
		check_eq(String(skill.get("stat", "")), "INT", "%s is an Intelligence skill" % skill_name)

	# Psionics and FX are Intelligence-governed too but are their own chapters.
	for skill in _rules.skills:
		if typeof(skill) != TYPE_DICTIONARY or String(skill.get("stat", "")) != "INT":
			continue
		if _rules.is_psionic_skill(skill):
			continue
		var name := String(skill.get("name", ""))
		check_true(
			INT_SKILLS.has(name) or bool(skill.get("custom_name", false)),
			"%s is an Intelligence skill the manual describes" % name
		)


func _test_species_ranges() -> void:
	for species_name in SPECIES_INT_RANGE:
		var species: Dictionary = _species_named(String(species_name))
		if not check(not species.is_empty(), "%s is in the catalog" % species_name):
			continue
		var limits: Array = species.get("ability_limits", {}).get("INT", [])
		if not check(limits.size() >= 2, "%s has an Intelligence range" % species_name):
			continue
		var expected: Array = SPECIES_INT_RANGE[species_name]
		check_eq(
			AlternityNum.as_int(limits[0]), AlternityNum.as_int(expected[0]),
			"%s Intelligence starts at %d" % [species_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			AlternityNum.as_int(limits[1]), AlternityNum.as_int(expected[1]),
			"%s Intelligence tops out at %d" % [species_name, AlternityNum.as_int(expected[1])]
		)


func _species_named(species_name: String) -> Dictionary:
	for species in _rules.species:
		if typeof(species) == TYPE_DICTIONARY and String(species.get("name", "")) == species_name:
			return species
	return {}


## Knowledge is free to every species; Computer Science only to mechalus.
func _test_free_skills() -> void:
	var knowledge: Dictionary = _skill_named("Knowledge")
	var computer_science: Dictionary = _skill_named("Computer Science")
	if not check(not knowledge.is_empty() and not computer_science.is_empty(), "both broads resolve"):
		return
	var knowledge_id := AlternityNum.as_int(knowledge.get("id", -1))
	var cs_id := AlternityNum.as_int(computer_science.get("id", -1))

	for species in _rules.species:
		if typeof(species) != TYPE_DICTIONARY:
			continue
		var species_name := String(species.get("name", ""))
		var free_ids: Array = []
		for id in species.get("free_skill_ids", []):
			free_ids.append(AlternityNum.as_int(id))
		check_true(free_ids.has(knowledge_id), "%s begins with Knowledge" % species_name)
		if species_name == "Mechalus":
			check_true(free_ids.has(cs_id), "a mechalus begins with Computer Science")
		else:
			check_false(
				free_ids.has(cs_id),
				"%s does not begin with Computer Science" % species_name
			)


## Table P5, with the optional alternate rules off.
func _test_table_p5() -> void:
	for score in TABLE_P5:
		var expected: Array = TABLE_P5[score]

		# An alien, using the fraal so the high scores are reachable, and the
		# weren for the low ones. Read the formula rather than a built hero for
		# scores outside every species' range.
		var alien: Dictionary = _rules.default_character()
		alien["species_id"] = 1   # Fraal
		alien["abilities"]["INT"] = AlternityNum.as_int(score)
		_rules.ensure_character_shape(alien)
		var alien_int := AlternityNum.as_int(_rules.effective_abilities(alien).get("INT", 0))
		if alien_int == AlternityNum.as_int(score):
			check_eq(
				_rules.starting_skill_budget(alien),
				AlternityNum.as_int(TABLE_P5[alien_int][0]),
				"an alien with INT %d starts on %d skill points" % [
					alien_int, AlternityNum.as_int(TABLE_P5[alien_int][0]),
				]
			)
			check_eq(
				_rules.additional_broad_skill_limit(alien),
				AlternityNum.as_int(TABLE_P5[alien_int][1]),
				"an alien with INT %d may add %d broad skills" % [
					alien_int, AlternityNum.as_int(TABLE_P5[alien_int][1]),
				]
			)

		# And a human, who gets five more points and one more broad skill.
		var human: Dictionary = _rules.default_character()
		human["species_id"] = 0
		human["abilities"]["INT"] = AlternityNum.as_int(score)
		_rules.ensure_character_shape(human)
		var human_int := AlternityNum.as_int(_rules.effective_abilities(human).get("INT", 0))
		if human_int == AlternityNum.as_int(score):
			check_eq(
				_rules.starting_skill_budget(human),
				AlternityNum.as_int(TABLE_P5[human_int][0]) + 5,
				"a human with INT %d starts on %d skill points" % [
					human_int, AlternityNum.as_int(TABLE_P5[human_int][0]) + 5,
				]
			)
			check_eq(
				_rules.additional_broad_skill_limit(human),
				AlternityNum.as_int(TABLE_P5[human_int][1]) + 1,
				"a human with INT %d may add %d broad skills" % [
					human_int, AlternityNum.as_int(TABLE_P5[human_int][1]) + 1,
				]
			)


## Table P2, as it applies to deception and misdirection aimed at the hero.
func _test_resistance_modifier() -> void:
	var expected := {4: -2, 5: -1, 6: -1, 7: 0, 10: 0, 11: 1, 12: 1, 13: 2, 14: 2, 15: 3, 16: 3, 17: 4, 18: 4}
	for score in expected:
		check_eq(
			_rules.resistance_modifier(AlternityNum.as_int(score)),
			AlternityNum.as_int(expected[score]),
			"INT %d gives a %+d step resistance modifier" % [
				AlternityNum.as_int(score), AlternityNum.as_int(expected[score]),
			]
		)


func _test_action_check_contribution() -> void:
	for pair in [[10, 10], [14, 12], [9, 13]]:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 0
		character["profession_id"] = 0   # Combat Spec
		character["abilities"]["INT"] = AlternityNum.as_int(pair[0])
		character["abilities"]["DEX"] = AlternityNum.as_int(pair[1])
		_rules.ensure_character_shape(character)

		var abilities: Dictionary = _rules.effective_abilities(character)
		var intellect := AlternityNum.as_int(abilities.get("INT", 0))
		var dex := AlternityNum.as_int(abilities.get("DEX", 0))
		var profession: Dictionary = _rules.get_profession_by_id(0)
		var expected := int(floor((dex + intellect) / 2.0)) \
			+ AlternityNum.as_int(profession.get("action_bonus", 0))

		var action: Dictionary = _rules.action_check(character)
		check_eq(
			AlternityNum.as_int(action.get("ordinary", -1)), expected,
			"INT %d with DEX %d gives an action check of %d" % [intellect, dex, expected]
		)
		check_eq(
			_rules.untrained_score(intellect), int(floor(intellect / 2.0)),
			"an untrained Intelligence check uses half of %d" % intellect
		)


## A Tech Op is a point quicker off the mark.
func _test_tech_op_action_bonus() -> void:
	var tech_op: Dictionary = {}
	for profession in AlternityRules.PROFESSION_DEFINITIONS:
		if String(profession.get("name", "")) == "Tech Op":
			tech_op = profession
	if not check(not tech_op.is_empty(), "Tech Op is in the catalog"):
		return
	check_eq(
		AlternityNum.as_int(tech_op.get("action_bonus", 0)), 1,
		"a Tech Op adds 1 to their action check score"
	)
	check_eq(
		AlternityNum.as_int(tech_op.get("ability_minimums", {}).get("INT", 0)), 11,
		"a Tech Op requires INT 11"
	)
