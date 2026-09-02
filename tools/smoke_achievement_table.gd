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

## Benefits that exist but are not priced by Table P29.
##
## Remove Flaw costs twice the flaw's bonus rather than a flat figure, and the
## FX energy pool increase is from Beyond Science and is priced in achievement
## points, not skill points.
const OFF_TABLE := {
	"remove_flaw": true,
	"fx_energy_pool_increase": true,
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
	_test_fx_energy_pool_spends_achievement_points()
	_test_monetary_award_ceiling()
	_test_gm_granted_benefits()
	_test_perk_career_limit()


func _test_every_entry_present() -> void:
	var catalog: Array = _rules.achievement_catalog
	var ids: Dictionary = {}
	for entry in catalog:
		if typeof(entry) == TYPE_DICTIONARY:
			ids[String(entry.get("id", ""))] = true

	for id in TABLE_P29:
		check_true(ids.has(id), "the catalog carries %s" % id)
	check_true(ids.has("remove_flaw"), "the catalog carries remove_flaw")

	# Nothing invented either: an id neither table lists is a transcription gap
	# here or an entry that should not be purchasable.
	for id in ids:
		var known: bool = TABLE_P29.has(id) or OFF_TABLE.has(id)
		check_true(known, "%s is a benefit the manuals describe" % id)


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


## The FX energy pool increase is the one benefit bought with achievement points.
##
## Alternity has no parallel spendable-AP pool: the points come straight off the
## hero's unbanked track, so buying one costs progress toward the next level.
## The pool can never be enlarged past twice its starting value.
## Source: Beyond Science ch. 1 p. 8.
func _test_fx_energy_pool_spends_achievement_points() -> void:
	var character: Dictionary = _rules.default_character()
	character["species_id"] = 0
	character["profession_id"] = 0
	_rules.ensure_character_shape(character)

	var achievement: Dictionary = _rules.get_achievement_by_id("fx_energy_pool_increase")
	if not check(not achievement.is_empty(), "the FX energy pool benefit exists"):
		return

	check_eq(
		_rules.fx_campaign_scale(character), "heroic",
		"a new hero defaults to the heroic FX scale"
	)
	for scale in [["realistic", 15], ["heroic", 10], ["superheroic", 5]]:
		_rules.set_fx_campaign_scale(character, String(scale[0]))
		check_eq(
			_rules.achievements.fx_energy_pool_ap_cost(character),
			AlternityNum.as_int(scale[1]),
			"a %s campaign charges %d AP per point" % [String(scale[0]), AlternityNum.as_int(scale[1])]
		)
	_rules.set_fx_campaign_scale(character, "heroic")

	# A hero who does not use FX cannot buy it at all.
	var refusal: Dictionary = _rules.achievements.can_purchase_achievement(character, achievement)
	check_false(bool(refusal.get("allowed", false)), "a non-FX hero cannot buy pool points")

	_rules.fx.set_fx_talent(character, true)
	_rules.fx.set_energy_pool(character, 4)

	# Unbanked points can never exceed the width of the current level band, and
	# those widths are 6, 7, 8, 9, 10, 11 ... so a 10 AP purchase is first
	# affordable at 7th level, where the band to 8th is 12 wide.
	var cost := 10
	var level := 7
	var banked: int = _rules.achievements.achievement_points_for_level(level)

	# One short.
	_rules.achievements.set_achievement_points(character, banked + cost - 1)
	check_eq(
		_rules.achievements.achievement_points_available(character), cost - 1,
		"the hero is one achievement point short"
	)
	refusal = _rules.achievements.can_purchase_achievement(character, achievement)
	check_false(bool(refusal.get("allowed", false)), "%d AP will not buy a %d AP point" % [cost - 1, cost])

	# Exactly enough: the points come off the track and the level is unchanged.
	_rules.achievements.set_achievement_points(character, banked + cost)
	var budget_before: int = _rules.skill_budget(character)
	var used_before: int = _rules.skill_points_used(character)

	if not check(
		bool(_rules.achievements.can_purchase_achievement(character, achievement).get("allowed", false)),
		"%d banked achievement points buy a %d AP point" % [cost, cost]
	):
		return
	var result: Dictionary = _rules.achievements.add_achievement_purchase(
		character, "fx_energy_pool_increase"
	)
	check_true(bool(result.get("ok", false)), "the purchase applies")

	check_eq(
		AlternityNum.as_int(character.get("achievement_points", 0)), banked,
		"the cost comes off the track, leaving the banked points"
	)
	check_eq(
		_rules.achievements.achievement_level_for_points(
			AlternityNum.as_int(character.get("achievement_points", 0))
		),
		level,
		"spending unbanked points does not cost the hero a level"
	)
	check_eq(_rules.fx.energy_pool(character), 4, "the recorded starting pool is untouched")
	check_eq(_rules.fx.total_energy_pool(character), 5, "the total pool grew by one")

	# It is not a skill-point purchase, so the skill budget must not move.
	check_eq(_rules.skill_budget(character), budget_before, "the skill budget is unchanged")
	check_eq(_rules.skill_points_used(character), used_before, "no skill points were spent")
	check_eq(
		_rules.achievements.achievement_points_spent(character), 0,
		"an AP purchase is not counted as achievement skill-point spending"
	)

	# Giving it up puts the points back.
	_rules.achievements.remove_achievement_purchase(character, String(result.get("line_id", "")))
	check_eq(
		AlternityNum.as_int(character.get("achievement_points", 0)), banked + cost,
		"removing the benefit refunds its achievement points"
	)
	check_eq(_rules.fx.total_energy_pool(character), 4, "the pool returns to its starting value")

	# The pool can never pass twice its starting value: a base of 4 allows four
	# increases and no more, however many points the hero banks.
	var bought := 0
	for _i in 12:
		_rules.achievements.set_achievement_points(character, banked + cost)
		var attempt: Dictionary = _rules.achievements.add_achievement_purchase(
			character, "fx_energy_pool_increase"
		)
		if not bool(attempt.get("ok", false)):
			break
		bought += 1
	check_eq(bought, 4, "a starting pool of 4 allows exactly 4 increases")
	check_eq(_rules.fx.total_energy_pool(character), 8, "the pool tops out at twice its base")


## Monetary Award stops at eight purchases by the printed text, and continues on
## the every-third-level pattern when the campaign opts in.
func _test_monetary_award_ceiling() -> void:
	var character: Dictionary = _rules.default_character()
	character["species_id"] = 0
	character["profession_id"] = 0
	_rules.ensure_character_shape(character)

	var achievement: Dictionary = _rules.get_achievement_by_id("monetary_award")
	if not check(not achievement.is_empty(), "the monetary award exists"):
		return

	var levels: Array = achievement.get("effect", {}).get("levels", [])
	check_eq(levels.size(), 8, "the printed table lists eight levels")
	check_eq(AlternityNum.as_int(levels[0]), 3, "the first is 3rd level")
	check_eq(AlternityNum.as_int(levels[levels.size() - 1]), 24, "the last is 24th level")

	check_false(
		_rules.optional_rule_enabled(character, "monetary_awards_uncapped"),
		"awards are capped unless the campaign says otherwise"
	)


## A Gamemaster award skips the price and the level, but not physiology.
##
## The Gamemaster Guide lets the GM hand out a perk, remove a flaw or grant a
## windfall as a story reward. Table P29 prices purchases, not gifts, so a
## granted benefit ignores both the skill-point cost and the achievement-level
## prerequisite -- while species ability maximums and the four-action ceiling
## still apply, being physiology rather than economics.
func _test_gm_granted_benefits() -> void:
	var character: Dictionary = _rules.default_character()
	character["species_id"] = 0      # Human, ability ceiling 14
	character["profession_id"] = 0   # Combat Spec
	_rules.ensure_character_shape(character)

	# A 1st-level hero with no points cannot buy an increase that needs 3rd.
	var achievement: Dictionary = _rules.get_achievement_by_id("str_increase_1")
	if not check(not achievement.is_empty(), "STR Increase #1 resolves"):
		return
	var bought: Dictionary = _rules.achievements.can_purchase_achievement(character, achievement)
	check_false(bool(bought.get("allowed", false)), "a 1st-level hero cannot buy STR Increase #1")

	# The Gamemaster may still award it.
	var granted: Dictionary = _rules.achievements.can_purchase_achievement(
		character, achievement, "", 0, true
	)
	check_true(bool(granted.get("allowed", false)), "the Gamemaster may grant it regardless of level")
	check_eq(AlternityNum.as_int(granted.get("cost", -1)), 0, "a granted benefit costs nothing")

	var before: int = _rules.effective_abilities(character).get("STR", 0)
	var used_before: int = _rules.skill_points_used(character)
	var result: Dictionary = _rules.achievements.add_achievement_purchase(
		character, "str_increase_1", "", 0, "", true
	)
	check_true(bool(result.get("ok", false)), "the award applies")
	check_eq(
		AlternityNum.as_int(_rules.effective_abilities(character).get("STR", 0)), before + 1,
		"a granted ability increase raises the score"
	)
	check_eq(
		_rules.skill_points_used(character), used_before,
		"a granted benefit spends no skill points"
	)

	# Hard ceilings still hold. Push STR to the Human maximum and the award is
	# refused even from the Gamemaster.
	var limits: Array = _rules.ability_limits(character, "STR")
	character["abilities"]["STR"] = AlternityNum.as_int(limits[1])
	var capped: Dictionary = _rules.achievements.can_purchase_achievement(
		character, _rules.get_achievement_by_id("str_increase_2"), "", 0, true
	)
	check_false(
		bool(capped.get("allowed", false)),
		"even a granted increase respects the species ability maximum"
	)


## Three purchased perks is a career limit; gifts do not spend it.
##
## An achievement-bought perk is still a purchase and counts. Every
## achievement-granted perk used to be exempt, which let a hero buy an unlimited
## number of them after creation.
func _test_perk_career_limit() -> void:
	var character: Dictionary = _rules.default_character()
	character["species_id"] = 0
	character["profession_id"] = 0
	_rules.ensure_character_shape(character)
	# High enough level and budget that only the perk limit can refuse.
	_rules.achievements.set_achievement_points(character, 200)

	check_eq(_rules.non_gm_perk_count(character), 0, "a new hero has no perks")

	var perk_benefits := [
		"new_perk_fortitude", "new_perk_observant", "new_perk_tough_as_nails",
	]
	var taken := 0
	for id in perk_benefits:
		var achievement: Dictionary = _rules.get_achievement_by_id(id)
		if achievement.is_empty():
			continue
		if bool(_rules.achievements.add_achievement_purchase(character, id).get("ok", false)):
			taken += 1
	check_eq(taken, 3, "three perks can be bought as achievement benefits")
	check_eq(
		_rules.non_gm_perk_count(character), 3,
		"perks bought as achievement benefits count toward the career limit"
	)

	# A fourth purchase is refused.
	var fourth: Dictionary = _rules.get_achievement_by_id("new_perk_reflexes")
	if not check(not fourth.is_empty(), "a fourth perk benefit exists"):
		return
	check_false(
		bool(_rules.achievements.can_purchase_achievement(character, fourth).get("allowed", false)),
		"a fourth purchased perk is refused"
	)

	# But the Gamemaster may still hand one over, and it does not count.
	check_true(
		bool(_rules.achievements.can_purchase_achievement(character, fourth, "", 0, true).get("allowed", false)),
		"the Gamemaster may still grant a perk beyond the limit"
	)
	check_true(
		bool(_rules.achievements.add_achievement_purchase(
			character, "new_perk_reflexes", "", 0, "", true
		).get("ok", false)),
		"the granted perk applies"
	)
	check_eq(
		_rules.non_gm_perk_count(character), 3,
		"a granted perk does not spend the career limit"
	)
