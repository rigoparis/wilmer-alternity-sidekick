extends "res://tools/test_harness.gd"
##
## The Dexterity chapter, pinned to the manual.
##
## Companion to smoke_str_chapter: costs, trained-only flags, the species that
## begin with each broad skill, Table P2 as it applies to ranged attacks, the
## whole of Table P8 movement, and the rank benefits that change a roll.
##
## Transcribed from the Player's Handbook breakdown rather than read back out of
## the data.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

## Catalog name -> [base cost, untrained allowed]
const DEX_SKILLS := {
	"Acrobatics": [7, true],
	"Daredevil": [4, true],
	"Defensive Martial Arts": [5, false],
	"Dodge": [4, true],
	"Fall": [3, true],
	"Flight": [2, false],
	"Zero-G Training": [2, false],
	"Manipulation": [6, true],
	"Lockpick": [4, true],
	"Pickpocket": [4, true],
	"Prestidigitation": [3, true],
	"Modern Ranged Weapons": [6, true],
	"Pistol": [4, true],
	"Rifle": [4, true],
	"SMG": [4, true],
	"Primitive Ranged Weapons": [7, true],
	"Bow": [4, true],
	"Crossbow": [3, true],
	"Flintlock": [3, true],
	"Sling": [4, true],
	"Stealth": [7, true],
	"Hide": [4, true],
	"Shadow": [4, true],
	"Sneak": [5, true],
	"Vehicle Operation": [3, true],
	"Air Vehicle": [5, false],
	"Land Vehicle": [3, true],
	"Space Vehicle": [5, false],
	"Water Vehicle": [3, true],
}

## Table P2, as it applies to ranged attacks made against the hero.
const RESISTANCE_MODIFIER := {
	4: -2, 5: -1, 6: -1, 7: 0, 10: 0,
	11: 1, 12: 1, 13: 2, 14: 2, 15: 3, 16: 3,
	17: 4, 18: 4, 19: 5, 24: 5,
}

## Table P8, keyed by STR + DEX: [sprint, run, walk, easy swim] in metres.
const MOVEMENT := {
	6: [6, 4, 2, 1],
	8: [8, 6, 2, 1],
	10: [10, 6, 2, 1],
	12: [12, 8, 2, 1],
	14: [14, 10, 4, 2],
	16: [16, 10, 4, 2],
	18: [18, 12, 4, 2],
	20: [20, 12, 4, 2],
	22: [22, 14, 4, 2],
	24: [24, 16, 6, 3],
	26: [26, 16, 6, 3],
	28: [28, 18, 6, 3],
	30: [30, 20, 8, 4],
	32: [32, 22, 8, 4],
}

const SKILL_ACROBATICS := 18
const SKILL_DEFENSIVE_MARTIAL_ARTS := 20

var _rules


func _init() -> void:
	begin("dexterity chapter")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_costs_and_training()
	_test_free_broad_skills()
	_test_ranged_resistance()
	_test_movement_table()
	_test_defensive_martial_arts()
	_test_action_check_and_untrained_scores()

	finish()


func _skill_named(skill_name: String) -> Dictionary:
	for skill in _rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and String(skill.get("name", "")) == skill_name:
			return skill
	return {}


func _test_costs_and_training() -> void:
	for skill_name in DEX_SKILLS:
		var skill: Dictionary = _skill_named(String(skill_name))
		if not check(not skill.is_empty(), "%s is in the catalog" % skill_name):
			continue
		var expected: Array = DEX_SKILLS[skill_name]
		check_eq(
			AlternityNum.as_int(skill.get("base_price", -1)),
			AlternityNum.as_int(expected[0]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			bool(skill.get("untrained", true)), bool(expected[1]),
			"%s untrained use is %s" % [skill_name, "allowed" if bool(expected[1]) else "prohibited"]
		)
		check_eq(String(skill.get("stat", "")), "DEX", "%s is a Dexterity skill" % skill_name)

	# Every Dexterity skill in the catalog is one the breakdown lists, apart from
	# the unnamed Acrobatics specialty a player fills in themselves.
	for skill in _rules.skills:
		if typeof(skill) != TYPE_DICTIONARY or String(skill.get("stat", "")) != "DEX":
			continue
		var name := String(skill.get("name", ""))
		check_true(
			DEX_SKILLS.has(name) or bool(skill.get("custom_name", false)),
			"%s is a Dexterity skill the manual describes" % name
		)


## Sesheyans begin with Acrobatics, t'sa with Manipulation, and humans, fraal
## and mechalus with Vehicle Operation.
func _test_free_broad_skills() -> void:
	var expected := {
		"Acrobatics": ["Sesheyan"],
		"Manipulation": ["T'sa"],
		"Vehicle Operation": ["Human", "Fraal", "Mechalus"],
	}
	for skill_name in expected:
		var skill: Dictionary = _skill_named(String(skill_name))
		if not check(not skill.is_empty(), "%s resolves" % skill_name):
			continue
		var skill_id := AlternityNum.as_int(skill.get("id", -1))
		for species_name in expected[skill_name]:
			var species: Dictionary = _species_named(String(species_name))
			if not check(not species.is_empty(), "%s resolves" % species_name):
				continue
			var has := false
			for id in species.get("free_skill_ids", []):
				if AlternityNum.as_int(id) == skill_id:
					has = true
			check_true(has, "%s begins with %s" % [species_name, skill_name])

	# And a species the manual does not name for a skill does not get it.
	var acrobatics: Dictionary = _skill_named("Acrobatics")
	var acrobatics_id := AlternityNum.as_int(acrobatics.get("id", -1))
	for species_name in ["Human", "Fraal", "Mechalus", "Weren"]:
		var species: Dictionary = _species_named(species_name)
		var has := false
		for id in species.get("free_skill_ids", []):
			if AlternityNum.as_int(id) == acrobatics_id:
				has = true
		check_false(has, "%s does not begin with Acrobatics" % species_name)


func _species_named(species_name: String) -> Dictionary:
	for species in _rules.species:
		if typeof(species) == TYPE_DICTIONARY and String(species.get("name", "")) == species_name:
			return species
	return {}


func _test_ranged_resistance() -> void:
	for score in RESISTANCE_MODIFIER:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 0
		character["abilities"]["DEX"] = AlternityNum.as_int(score)
		_rules.ensure_character_shape(character)
		# Species limits would clamp an extreme score, so read the table directly
		# as well as through the character.
		check_eq(
			_rules.resistance_modifier(AlternityNum.as_int(score)),
			AlternityNum.as_int(RESISTANCE_MODIFIER[score]),
			"DEX %d gives a %+d step ranged resistance modifier" % [
				AlternityNum.as_int(score), AlternityNum.as_int(RESISTANCE_MODIFIER[score]),
			]
		)


func _test_movement_table() -> void:
	# The table itself, every row. Some totals are out of reach for any core
	# species -- a Human cannot go below 4 in an ability or above 14, so STR+DEX
	# of 6 or 30 is unreachable -- so the data is checked directly as well as
	# through a character.
	for total in MOVEMENT:
		var row: Dictionary = AlternityRules.MOVEMENT_RATES_TABLE.get(AlternityNum.as_int(total), {})
		if not check(not row.is_empty(), "Table P8 has a row for STR + DEX %d" % AlternityNum.as_int(total)):
			continue
		var expected: Array = MOVEMENT[total]
		for index in 4:
			var key: String = ["sprint", "run", "walk", "easy_swim"][index]
			check_eq(
				AlternityNum.as_int(row.get(key, -1)), AlternityNum.as_int(expected[index]),
				"STR + DEX %d gives %s %d m" % [
					AlternityNum.as_int(total), key, AlternityNum.as_int(expected[index]),
				]
			)

	# And the plumbing: a real character reads the row their scores land on.
	for total in [12, 20, 24, 28]:
		var half: int = AlternityNum.as_int(total) / 2
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 5   # Weren, whose limits reach a 28 total
		character["abilities"]["STR"] = half
		character["abilities"]["DEX"] = AlternityNum.as_int(total) - half
		_rules.ensure_character_shape(character)

		var abilities: Dictionary = _rules.effective_abilities(character)
		var reached := AlternityNum.as_int(abilities.get("STR", 0)) + AlternityNum.as_int(abilities.get("DEX", 0))
		var rates: Dictionary = _rules.movement(character)
		check_eq(
			AlternityNum.as_int(rates.get("total", -1)), reached,
			"a hero with STR + DEX of %d reads that total" % reached
		)
		var row: Dictionary = AlternityRules.MOVEMENT_RATES_TABLE.get(reached, {})
		if not row.is_empty():
			check_eq(
				AlternityNum.as_int(rates.get("sprint", -1)),
				AlternityNum.as_int(row.get("sprint", -1)),
				"and sprints at the rate its row gives (%d)" % AlternityNum.as_int(row.get("sprint", -1))
			)


## Defensive Martial Arts hardens the hero against close combat: the Strength
## resistance modifier improves by one step at rank 4, another at 8, another
## at 12.
func _test_defensive_martial_arts() -> void:
	var expected := {0: 0, 3: 0, 4: 1, 7: 1, 8: 2, 11: 2, 12: 3}
	for rank in expected:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 0
		character["abilities"]["STR"] = 10   # base modifier of 0
		_rules.ensure_character_shape(character)
		_rules.achievements.set_achievement_points(character, 200)
		_rules.force_skill_rank(character, SKILL_ACROBATICS, 1)
		if AlternityNum.as_int(rank) > 0:
			_rules.force_skill_rank(character, SKILL_DEFENSIVE_MARTIAL_ARTS, AlternityNum.as_int(rank))
		check_eq(
			_rules.character_resistance_modifier(character, "STR"),
			AlternityNum.as_int(expected[rank]),
			"Defensive Martial Arts rank %d gives a %+d step Strength resistance modifier" % [
				AlternityNum.as_int(rank), AlternityNum.as_int(expected[rank]),
			]
		)


## Dexterity sets the action check with Intelligence, and halves for untrained use.
func _test_action_check_and_untrained_scores() -> void:
	for pair in [[10, 10], [12, 14], [9, 15], [16, 11]]:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 0
		character["profession_id"] = 0   # Combat Spec, +3 action bonus
		character["abilities"]["DEX"] = AlternityNum.as_int(pair[0])
		character["abilities"]["INT"] = AlternityNum.as_int(pair[1])
		_rules.ensure_character_shape(character)

		var abilities: Dictionary = _rules.effective_abilities(character)
		var dex := AlternityNum.as_int(abilities.get("DEX", 0))
		var intellect := AlternityNum.as_int(abilities.get("INT", 0))
		var profession: Dictionary = _rules.get_profession_by_id(0)
		var expected := int(floor((dex + intellect) / 2.0)) \
			+ AlternityNum.as_int(profession.get("action_bonus", 0))

		var action: Dictionary = _rules.action_check(character)
		check_eq(
			AlternityNum.as_int(action.get("ordinary", -1)), expected,
			"DEX %d with INT %d gives an action check of %d" % [dex, intellect, expected]
		)
		check_eq(
			_rules.untrained_score(dex), int(floor(dex / 2.0)),
			"an untrained Dexterity check uses half of %d" % dex
		)
