extends "res://tools/test_harness.gd"
##
## Table P29 pinned to the shipped achievement catalog.
##
## Every purchasable benefit, its skill-point cost and its minimum achievement
## level, for all five professions. Transcribed from the Player's Handbook
## breakdown rather than from the data, so this fails if the catalog drifts --
## which is how a wrong entry gets noticed rather than quietly costing someone
## the wrong number of points mid-campaign.
##
## It caught new_perk_powerful_ally sitting at 4th level for a Free Agent where
## the table says 7th.
##
## Profession order matches achievements_core.json's "profiles":
## combat_spec, diplomat, free_agent, tech_op, mindwalker.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

const PROFESSIONS := ["Combat Spec", "Diplomat", "Free Agent", "Tech Op", "Mindwalker"]

## id -> [[cost, min_level] x 5]
const TABLE_P29 := {
	# Ability increases. Each ability may be raised twice in a career, and the
	# second tier requires the first.
	"str_increase_1": [[10, 3], [15, 6], [15, 6], [15, 9], [15, 9]],
	"str_increase_2": [[20, 6], [30, 9], [30, 9], [30, 12], [30, 12]],
	"dex_increase_1": [[15, 5], [15, 7], [10, 3], [10, 3], [15, 6]],
	"dex_increase_2": [[30, 8], [30, 10], [20, 6], [20, 6], [30, 9]],
	"con_increase_1": [[10, 3], [15, 9], [15, 5], [15, 6], [10, 4]],
	"con_increase_2": [[20, 6], [30, 12], [30, 8], [30, 9], [20, 7]],
	"int_increase_1": [[15, 6], [10, 5], [15, 4], [10, 3], [10, 3]],
	"int_increase_2": [[30, 9], [20, 8], [30, 7], [20, 6], [20, 6]],
	"wil_increase_1": [[15, 7], [10, 3], [10, 3], [10, 5], [10, 3]],
	"wil_increase_2": [[30, 10], [20, 6], [20, 6], [20, 8], [20, 6]],
	"per_increase_1": [[10, 4], [10, 3], [10, 5], [15, 7], [15, 4]],
	"per_increase_2": [[20, 7], [20, 6], [20, 8], [30, 10], [30, 7]],

	"action_check_bonus": [[10, 3], [12, 5], [10, 3], [10, 3], [10, 3]],
	"action_check_increase": [[4, 3], [4, 3], [3, 3], [4, 4], [4, 6]],
	"extra_action": [[6, 6], [6, 6], [5, 4], [6, 5], [6, 4]],

	"stun_rating_increase": [[4, 4], [4, 4], [4, 3], [4, 5], [4, 5]],
	"wound_rating_increase": [[6, 5], [7, 5], [7, 4], [7, 4], [8, 6]],
	"mortal_rating_increase": [[8, 3], [10, 6], [20, 5], [20, 6], [12, 7]],
	"fatigue_rating_increase": [[4, 3], [5, 4], [10, 3], [10, 4], [6, 5]],

	"monetary_award": [[6, 3], [5, 3], [6, 3], [6, 3], [6, 3]],
	"acquire_contact": [[5, 4], [3, 2], [4, 3], [5, 4], [5, 6]],

	# Only these fourteen perks may be bought after character creation. The ones
	# printed in italics on Table P26 -- Alien Artifact, Faith, Filthy Rich, Good
	# Luck, Great Looks, Heightened Ability, Psionic Awareness, Vigor -- cannot,
	# which is why no achievement exists for them.
	"new_perk_ambidextrous": [[6, 7], [6, 6], [5, 3], [5, 6], [6, 6]],
	"new_perk_animal_friend": [[3, 3], [3, 4], [3, 4], [4, 4], [4, 5]],
	"new_perk_celebrity": [[4, 6], [4, 3], [4, 5], [4, 9], [4, 8]],
	"new_perk_concentration": [[5, 5], [5, 4], [5, 5], [4, 3], [4, 3]],
	"new_perk_danger_sense": [[5, 6], [6, 7], [5, 3], [6, 7], [5, 6]],
	"new_perk_fists_of_iron_2": [[3, 5], [4, 9], [3, 4], [4, 9], [4, 9]],
	"new_perk_fists_of_iron_5": [[6, 5], [8, 9], [6, 4], [8, 9], [8, 9]],
	"new_perk_fortitude": [[5, 3], [6, 5], [6, 5], [5, 5], [6, 8]],
	"new_perk_observant": [[5, 3], [5, 4], [5, 3], [6, 5], [5, 5]],
	"new_perk_photo_memory": [[5, 8], [4, 5], [5, 7], [4, 7], [4, 3]],
	"new_perk_powerful_ally": [[5, 4], [5, 6], [5, 7], [6, 7], [6, 8]],
	"new_perk_reflexes": [[6, 4], [6, 6], [5, 3], [5, 4], [6, 6]],
	"new_perk_reputation": [[4, 4], [5, 5], [5, 5], [5, 4], [4, 6]],
	"new_perk_tough_as_nails": [[5, 3], [6, 9], [6, 6], [5, 5], [6, 9]],
	"new_perk_willpower": [[6, 8], [6, 5], [6, 6], [6, 5], [5, 4]],
}

## Remove Flaw is priced at twice the flaw's bonus rather than a flat cost, so
## only its level requirement is fixed: 6th, for every profession.
const REMOVE_FLAW_LEVEL := 6

## How many times each benefit may be bought in a career.
const PURCHASE_LIMITS := {
	"action_check_bonus": 1,
	"action_check_increase": 3,
	"extra_action": 1,
	"stun_rating_increase": 3,
	"wound_rating_increase": 2,
	"mortal_rating_increase": 1,
	"fatigue_rating_increase": 1,
}

var _rules


func _init() -> void:
	begin("achievement table P29")
	_run()
	finish()


func _run() -> void:
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_every_entry_present()
	_test_costs_and_levels()
	_test_remove_flaw_level()
	_test_purchase_limits()
	_test_italic_perks_are_unavailable()


func _test_every_entry_present() -> void:
	var catalog: Array = _rules.achievement_catalog
	var ids: Dictionary = {}
	for entry in catalog:
		if typeof(entry) == TYPE_DICTIONARY:
			ids[String(entry.get("id", ""))] = true

	for id in TABLE_P29:
		check_true(ids.has(id), "the catalog carries %s" % id)
	check_true(ids.has("remove_flaw"), "the catalog carries remove_flaw")

	# Nothing invented either: an id the table does not list is either a
	# transcription gap here or an entry that should not be purchasable.
	for id in ids:
		var known: bool = TABLE_P29.has(id) or id == "remove_flaw"
		check_true(known, "%s appears in Table P29" % id)


func _test_costs_and_levels() -> void:
	for id in TABLE_P29:
		var achievement: Dictionary = _rules.get_achievement_by_id(String(id))
		if not check(not achievement.is_empty(), "%s resolves" % id):
			continue
		var costs: Array = achievement.get("costs", [])
		if not check(costs.size() == 5, "%s prices all five professions" % id):
			continue

		var expected: Array = TABLE_P29[id]
		for index in 5:
			var want: Array = expected[index]
			var got: Array = costs[index]
			check_eq(
				AlternityNum.as_int(got[0]), AlternityNum.as_int(want[0]),
				"%s costs %d SP for a %s" % [id, AlternityNum.as_int(want[0]), PROFESSIONS[index]]
			)
			check_eq(
				AlternityNum.as_int(got[1]), AlternityNum.as_int(want[1]),
				"%s needs level %d for a %s" % [id, AlternityNum.as_int(want[1]), PROFESSIONS[index]]
			)


func _test_remove_flaw_level() -> void:
	var achievement: Dictionary = _rules.get_achievement_by_id("remove_flaw")
	if not check(not achievement.is_empty(), "remove_flaw resolves"):
		return
	var costs: Array = achievement.get("costs", [])
	if not check(costs.size() == 5, "remove_flaw prices all five professions"):
		return
	for index in 5:
		check_eq(
			AlternityNum.as_int(costs[index][1]), REMOVE_FLAW_LEVEL,
			"remove_flaw needs level %d for a %s" % [REMOVE_FLAW_LEVEL, PROFESSIONS[index]]
		)


func _test_purchase_limits() -> void:
	for id in PURCHASE_LIMITS:
		var achievement: Dictionary = _rules.get_achievement_by_id(String(id))
		if not check(not achievement.is_empty(), "%s resolves" % id):
			continue
		check_eq(
			AlternityNum.as_int(achievement.get("max", -1)),
			AlternityNum.as_int(PURCHASE_LIMITS[id]),
			"%s may be bought %d time(s)" % [id, AlternityNum.as_int(PURCHASE_LIMITS[id])]
		)

	# Each ability may be raised twice, as two separate one-purchase entries.
	for ability in ["str", "dex", "con", "int", "wil", "per"]:
		for tier in [1, 2]:
			var id := "%s_increase_%d" % [ability, tier]
			var achievement: Dictionary = _rules.get_achievement_by_id(id)
			if achievement.is_empty():
				continue
			check_eq(
				AlternityNum.as_int(achievement.get("max", -1)), 1,
				"%s is a single purchase" % id
			)


## The eight perks printed in italics on Table P26 cannot be bought after
## character creation, so no achievement may offer them.
func _test_italic_perks_are_unavailable() -> void:
	var forbidden := [
		"alien_artifact", "faith", "filthy_rich", "good_luck",
		"great_looks", "heightened_ability", "psionic_awareness", "vigor",
	]
	var offered: Dictionary = {}
	for entry in _rules.achievement_catalog:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = entry.get("effect", {})
		if String(effect.get("type", "")) == "new_perk":
			offered[String(effect.get("perk_id", ""))] = true

	for perk_id in forbidden:
		check_false(
			offered.has(perk_id),
			"%s is not purchasable as an achievement benefit" % perk_id
		)
