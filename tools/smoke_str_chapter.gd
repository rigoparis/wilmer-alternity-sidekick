extends "res://tools/test_harness.gd"
##
## The Strength chapter, pinned to the manual.
##
## Costs, trained-only flags, the two Strength tables, lifting thresholds, and
## the rank benefits of every Strength skill -- transcribed from the Player's
## Handbook breakdown rather than read back out of the data, so a wrong figure
## fails here instead of quietly costing someone the wrong number of points or
## the wrong damage at the table.
##
## Written after a review of the Skills tab. The mechanics all proved correct;
## what was wrong was that none of this reached the screen. Pinning it means the
## next change to the catalog has to stay correct too.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

## name -> [base cost, untrained allowed]
const STR_SKILLS := {
	"Armor Operation": [7, true],
	"Combat armor": [3, true],
	"Powered armor": [4, false],
	"Athletics": [3, true],
	"Climb": [2, true],
	"Jump": [1, true],
	"Throw": [2, true],
	"Heavy Weapons": [6, true],
	"Direct Fire": [4, true],
	"Indirect Fire": [4, true],
	"Melee Weapons": [6, true],
	"Blade": [3, true],
	"Bludgeon": [3, true],
	"Powered weapon": [4, true],
	"Unarmed Attack": [5, true],
	"Brawl": [3, true],
	"Power Martial Arts": [5, false],
}

## Table P9: the flat adjustment added to unarmed, melee and thrown damage.
const DAMAGE_ADJUSTMENT := {
	3: -1, 6: -1,
	7: 0, 10: 0,
	11: 1, 12: 1,
	13: 2, 14: 2,
	15: 3, 16: 3,
	17: 4, 18: 4,
	19: 5, 22: 5,
}

## Table P2: the step penalty an attacker takes against this hero.
const RESISTANCE_MODIFIER := {
	3: -2, 4: -2,
	5: -1, 6: -1,
	7: 0, 10: 0,
	11: 1, 12: 1,
	13: 2, 14: 2,
	15: 3, 16: 3,
	17: 4, 18: 4,
	19: 5, 22: 5,
}

## Armor Operation, by specialty rank: total step reduction including the one
## the broad skill already grants, and the stun damage soaked while armoured.
const ARMOR_BY_RANK := {
	#        total steps, stun points
	1: [2, 0],
	2: [2, 1],
	3: [2, 1],
	4: [3, 2],
	6: [3, 3],
	7: [4, 3],
	8: [4, 4],
	10: [5, 5],
	12: [5, 6],
}

const SKILL_ARMOR_OPERATION := 0
const SKILL_COMBAT_ARMOR := 1
const SKILL_UNARMED_ATTACK := 15
const SKILL_BRAWL := 16
const SKILL_POWER_MARTIAL_ARTS := 17

var _rules


func _init() -> void:
	begin("strength chapter")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_costs_and_training()
	_test_athletics_is_granted_by_the_right_species()
	_test_damage_adjustment()
	_test_resistance_modifier()
	_test_lifting_thresholds()
	_test_armor_operation()
	_test_unarmed_damage()
	_test_power_martial_arts_resistance()
	_test_melee_weapons_grant_no_resistance()
	_test_heightened_ability()

	finish()


func _skill_named(skill_name: String) -> Dictionary:
	for skill in _rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and String(skill.get("name", "")) == skill_name:
			return skill
	return {}


func _test_costs_and_training() -> void:
	for skill_name in STR_SKILLS:
		var skill: Dictionary = _skill_named(String(skill_name))
		if not check(not skill.is_empty(), "%s is in the catalog" % skill_name):
			continue
		var expected: Array = STR_SKILLS[skill_name]
		check_eq(
			AlternityNum.as_int(skill.get("base_price", -1)),
			AlternityNum.as_int(expected[0]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			bool(skill.get("untrained", true)), bool(expected[1]),
			"%s untrained use is %s" % [skill_name, "allowed" if bool(expected[1]) else "prohibited"]
		)
		check_eq(
			String(skill.get("stat", "")), "STR",
			"%s is a Strength skill" % skill_name
		)


## Athletics is free at creation to humans, mechalus, t'sa and weren.
func _test_athletics_is_granted_by_the_right_species() -> void:
	var athletics: Dictionary = _skill_named("Athletics")
	if not check(not athletics.is_empty(), "Athletics is in the catalog"):
		return
	var athletics_id := AlternityNum.as_int(athletics.get("id", -1))

	var granted := ["Human", "Mechalus", "T'sa", "Weren"]
	var withheld := ["Fraal", "Sesheyan"]

	for species in _rules.species:
		if typeof(species) != TYPE_DICTIONARY:
			continue
		var species_name := String(species.get("name", ""))
		var free_ids: Array = species.get("free_skill_ids", [])
		var has := false
		for id in free_ids:
			if AlternityNum.as_int(id) == athletics_id:
				has = true
		if granted.has(species_name):
			check_true(has, "%s begins with Athletics" % species_name)
		elif withheld.has(species_name):
			check_false(has, "%s does not begin with Athletics" % species_name)


func _test_damage_adjustment() -> void:
	for score in DAMAGE_ADJUSTMENT:
		check_eq(
			_rules.equipment.strength_damage_bonus(AlternityNum.as_int(score)),
			AlternityNum.as_int(DAMAGE_ADJUSTMENT[score]),
			"STR %d adjusts damage by %+d" % [
				AlternityNum.as_int(score), AlternityNum.as_int(DAMAGE_ADJUSTMENT[score]),
			]
		)


func _test_resistance_modifier() -> void:
	for score in RESISTANCE_MODIFIER:
		check_eq(
			_rules.resistance_modifier(AlternityNum.as_int(score)),
			AlternityNum.as_int(RESISTANCE_MODIFIER[score]),
			"STR %d gives a %+d step resistance modifier" % [
				AlternityNum.as_int(score), AlternityNum.as_int(RESISTANCE_MODIFIER[score]),
			]
		)


func _test_lifting_thresholds() -> void:
	var capacity: Dictionary = _rules.lifting_capacity(12)
	check_eq(AlternityNum.as_int(capacity.get("automatic_carry_kg", 0)), 24, "STR 12 carries 24 kg unchecked")
	check_eq(AlternityNum.as_int(capacity.get("marginal_feat_kg", 0)), 60, "a marginal feat lifts STR x 5")
	check_eq(AlternityNum.as_int(capacity.get("slight_feat_kg", 0)), 120, "a slight feat lifts STR x 10")
	check_eq(AlternityNum.as_int(capacity.get("moderate_feat_kg", 0)), 180, "a moderate feat lifts STR x 15")
	check_eq(AlternityNum.as_int(capacity.get("extreme_feat_kg", 0)), 240, "an extreme feat lifts STR x 20")
	check_eq(
		AlternityNum.as_int(capacity.get("clean_and_jerk_extra_steps", 0)), 2,
		"a clean and jerk adds two steps"
	)


## The broad skill reduces armor penalties by one step; a specialty adds one
## more at ranks 1-3, two at 4-6, three at 7-9 and four at 10-12. Stun soaked
## while armoured is one point per two ranks, to a maximum of six.
func _test_armor_operation() -> void:
	for rank in ARMOR_BY_RANK:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 0
		_rules.ensure_character_shape(character)
		# Ranks above 3 are unreachable while the hero is being created, so the
		# fixture is levelled before the rank is set.
		_rules.achievements.set_achievement_points(character, 200)
		_rules.force_skill_rank(character, SKILL_ARMOR_OPERATION, 1)
		_rules.force_skill_rank(character, SKILL_COMBAT_ARMOR, AlternityNum.as_int(rank))

		var expected: Array = ARMOR_BY_RANK[rank]
		check_eq(
			_rules.equipment.armor_operation_penalty_reduction(character, SKILL_COMBAT_ARMOR),
			AlternityNum.as_int(expected[0]),
			"Combat armor rank %d reduces armor penalties by %d steps in total" % [
				AlternityNum.as_int(rank), AlternityNum.as_int(expected[0]),
			]
		)
		check_eq(
			_rules.equipment.armor_stun_damage_reduction(character, SKILL_COMBAT_ARMOR),
			AlternityNum.as_int(expected[1]),
			"Combat armor rank %d soaks %d points of stun" % [
				AlternityNum.as_int(rank), AlternityNum.as_int(expected[1]),
			]
		)

	# The broad alone is worth one step and no stun reduction.
	var broad_only: Dictionary = _rules.default_character()
	broad_only["species_id"] = 0
	_rules.ensure_character_shape(broad_only)
	_rules.force_skill_rank(broad_only, SKILL_ARMOR_OPERATION, 1)
	check_eq(
		_rules.equipment.armor_operation_penalty_reduction(broad_only, SKILL_COMBAT_ARMOR), 1,
		"the broad skill alone reduces armor penalties by one step"
	)
	check_eq(
		_rules.equipment.armor_stun_damage_reduction(broad_only, SKILL_COMBAT_ARMOR), 0,
		"the broad skill alone soaks no stun"
	)


## Unarmed damage before the Strength adjustment, by training.
func _test_unarmed_damage() -> void:
	var cases := [
		["untrained", 0, 0, "d4s/d4+1s/d4+2s"],
		["Brawl rank 1", 1, 0, "d4s/d4+1s/d4+2s"],
		["Brawl rank 8", 8, 0, "d6s/d6+2s/d4w"],
		["Power Martial Arts rank 1", 0, 1, "d6s/d6+2s/d4w"],
		["Power Martial Arts rank 7", 0, 7, "d6+2s/d4w/d4+2w"],
	]
	for spec in cases:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 0
		character["abilities"]["STR"] = 10   # no damage adjustment at STR 10
		_rules.ensure_character_shape(character)
		_rules.achievements.set_achievement_points(character, 200)
		_rules.force_skill_rank(character, SKILL_UNARMED_ATTACK, 1)
		if AlternityNum.as_int(spec[1]) > 0:
			_rules.force_skill_rank(character, SKILL_BRAWL, AlternityNum.as_int(spec[1]))
		if AlternityNum.as_int(spec[2]) > 0:
			_rules.force_skill_rank(character, SKILL_POWER_MARTIAL_ARTS, AlternityNum.as_int(spec[2]))

		var damage := ""
		for form in _rules.equipment.attack_forms_for_character(character):
			if String(form.get("range", "")) == "Personal":
				damage = String(form.get("damage", ""))
				break
		check_eq(
			damage, String(spec[3]),
			"%s does %s" % [String(spec[0]), String(spec[3])]
		)


## Power Martial Arts hardens the hero: one extra step of Strength resistance at
## rank 4, another at rank 8, and a third at rank 12.
func _test_power_martial_arts_resistance() -> void:
	var expected := {0: 0, 3: 0, 4: 1, 7: 1, 8: 2, 11: 2, 12: 3}
	for rank in expected:
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 0
		character["abilities"]["STR"] = 10   # base resistance modifier of 0
		_rules.ensure_character_shape(character)
		_rules.achievements.set_achievement_points(character, 200)
		_rules.force_skill_rank(character, SKILL_UNARMED_ATTACK, 1)
		if AlternityNum.as_int(rank) > 0:
			_rules.force_skill_rank(character, SKILL_POWER_MARTIAL_ARTS, AlternityNum.as_int(rank))
		check_eq(
			_rules.character_resistance_modifier(character, "STR"),
			AlternityNum.as_int(expected[rank]),
			"Power Martial Arts rank %d gives a %+d step Strength resistance modifier" % [
				AlternityNum.as_int(rank), AlternityNum.as_int(expected[rank]),
			]
		)


## Blade, Bludgeon and Powered Weapon grant no passive resistance.
##
## All three carried the +1/+2/+3 template copied from Power Martial Arts, in
## the calculation and in their rank benefit text, with a citation to the page
## that describes their real benefits. Those are combat manoeuvres -- reaction
## parry at rank 4, a second strike at 6, a third at 9, disarms and damage.
## Source: Player's Handbook p. 68.
func _test_melee_weapons_grant_no_resistance() -> void:
	var melee := {"Blade": 12, "Bludgeon": 13, "Powered weapon": 14}
	for name in melee:
		for rank in [4, 8, 12]:
			var character: Dictionary = _rules.default_character()
			character["species_id"] = 0
			character["abilities"]["STR"] = 10   # base modifier of 0
			_rules.ensure_character_shape(character)
			_rules.achievements.set_achievement_points(character, 200)
			_rules.force_skill_rank(character, 11, 1)   # Melee Weapons broad
			_rules.force_skill_rank(character, AlternityNum.as_int(melee[name]), rank)
			check_eq(
				_rules.character_resistance_modifier(character, "STR"), 0,
				"%s rank %d grants no passive Strength resistance" % [name, rank]
			)

		# The genuine benefits are still described.
		var skill: Dictionary = _skill_named(String(name))
		var benefits: Dictionary = _rules.skill_detail(skill).get("rank_benefits", {})
		for rank in [4, 6, 9]:
			check_true(
				benefits.has(rank) or benefits.has(str(rank)),
				"%s keeps its rank %d combat manoeuvre" % [name, rank]
			)


## Heightened Ability raises the ability the player chose, and says nothing
## until they choose one.
##
## The choice was read from four places and written in none: no screen made it,
## nothing defaulted it, and selected_perks holds a plain cost rather than a
## dictionary, so the perk-level lookups could never have found it. Ten skill
## points bought nothing.
func _test_heightened_ability() -> void:
	var character: Dictionary = _rules.default_character()
	character["species_id"] = 0
	for ability in ["STR", "DEX", "CON", "INT", "WIL", "PER"]:
		character["abilities"][ability] = 10
	_rules.ensure_character_shape(character)

	var before: int = AlternityNum.as_int(_rules.effective_abilities(character).get("WIL", 0))
	_rules.set_perk_selected(character, "heightened_ability", 10)

	# Taken but unassigned, it does nothing -- and says so rather than silently
	# picking an ability.
	check_eq(
		_rules.heightened_ability_target(character), "",
		"a freshly taken Heightened Ability has no target yet"
	)
	check_eq(
		AlternityNum.as_int(_rules.effective_abilities(character).get("WIL", 0)), before,
		"and raises nothing until one is chosen"
	)

	_rules.set_heightened_ability_target(character, "WIL")
	check_eq(_rules.heightened_ability_target(character), "WIL", "the choice is recorded")
	check_eq(
		AlternityNum.as_int(_rules.effective_abilities(character).get("WIL", 0)), before + 1,
		"the chosen ability rises by one"
	)
	check_eq(
		AlternityNum.as_int(_rules.effective_abilities(character).get("INT", 0)), 10,
		"and no other ability moves"
	)

	# It cannot push past the species maximum.
	var limits: Array = _rules.ability_limits(character, "WIL")
	character["abilities"]["WIL"] = AlternityNum.as_int(limits[1])
	check_eq(
		AlternityNum.as_int(_rules.effective_abilities(character).get("WIL", 0)),
		AlternityNum.as_int(limits[1]),
		"Heightened Ability cannot exceed the species maximum"
	)

	# An unknown ability is refused rather than stored.
	_rules.set_heightened_ability_target(character, "LUCK")
	check_eq(_rules.heightened_ability_target(character), "", "an unknown ability is not recorded")
