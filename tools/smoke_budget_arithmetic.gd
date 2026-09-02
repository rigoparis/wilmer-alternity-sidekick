extends "res://tools/test_harness.gd"
##
## The books balance.
##
## Every other suite checks that a particular figure matches a particular table.
## This one checks that the figures agree with each other: that a total really is
## the sum of the parts it is displayed as, for every shipped fixture and for
## characters built to stress each contributor in turn.
##
## The point is arithmetic self-consistency, not rule correctness. A wrong table
## value is caught by smoke_rules_audit and smoke_achievement_table; a total that
## silently disagrees with its own breakdown is caught here, and is the failure a
## player actually notices -- the Skills tab saying one thing and the Summary
## another.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Support := preload("res://tools/golden_support.gd")

var _rules


func _init() -> void:
	begin("budget arithmetic")
	_run()
	finish()


func _run() -> void:
	for name in Support.fixture_names():
		_audit(name, Support.load_json(Support.fixture_path(name)))

	_audit("built: fx and cybertech", _built_character())
	_audit("built: perks and flaws", _perked_character())
	_audit("built: levelled", _levelled_character())

	_test_rank_costs_are_the_sum_of_their_ranks()


## A fresh rules instance per character: summary() caches on a single slot, so
## sharing one would let characters affect each other's figures.
func _fresh() -> Object:
	var rules = RulesScript.new()
	rules.load_core_data()
	return rules


func _audit(label: String, character: Dictionary) -> void:
	_rules = _fresh()
	_rules.ensure_character_shape(character)

	# --- the budget is the sum of what makes it up -------------------------
	var starting: int = _rules.starting_skill_budget(character)
	var ap_for_sp: int = _rules.achievements.achievement_points_for_current_level(
		AlternityNum.as_int(character.get("achievement_points", 0))
	)
	var level_bonus: int = _rules.achievements.achievement_skill_bonus(character)
	check_eq(
		_rules.skill_budget(character), starting + ap_for_sp + level_bonus,
		"%s: skill budget is starting + banked AP + level bonus" % label
	)

	# --- spending is the sum of every spender ------------------------------
	var lr_rebought := AlternityNum.as_int(character.get("last_resorts_rebought", 0))
	var lr_cost := AlternityNum.as_int(_rules.last_resorts(character).get("cost", 0))
	var parts: int = (
		_rules.skill_purchase_points_used(character)
		+ _rules.perk_points_used(character)
		+ _rules.achievements.achievement_points_spent(character)
		+ _rules.cybertech.cybertech_skill_points_used(character)
		+ _rules.fx.fx_skill_purchase_points_used(character)
		+ lr_rebought * lr_cost
	)
	check_eq(
		_rules.skill_points_used(character), parts,
		"%s: points used is the sum of skills, perks, benefits, cybertech, FX and last resorts" % label
	)

	# --- the summary agrees with the rules it summarises --------------------
	var summary: Dictionary = _rules.summary(character)
	check_eq(
		AlternityNum.as_int(summary.get("skill_points_used", -1)),
		_rules.skill_points_used(character),
		"%s: summary reports the same points used" % label
	)
	check_eq(
		AlternityNum.as_int(summary.get("skill_budget", -1)),
		_rules.skill_budget(character),
		"%s: summary reports the same budget" % label
	)
	check_eq(
		AlternityNum.as_int(summary.get("skill_points_remaining", 0)),
		_rules.skill_budget(character) - _rules.skill_points_used(character),
		"%s: remaining is budget minus used" % label
	)

	# --- per-skill costs add up to the skill total --------------------------
	var per_skill := 0
	for skill in _rules.selected_skills(character):
		per_skill += AlternityNum.as_int(skill.get("cost", 0))
	check_eq(
		per_skill, _rules.skill_purchase_points_used(character),
		"%s: the listed skill costs sum to the skill spend" % label
	)

	# --- broad skills counted once each -------------------------------------
	check_eq(
		AlternityNum.as_int(summary.get("broad_skills_remaining", 0)),
		AlternityNum.as_int(summary.get("max_broad_skills", 0))
			- AlternityNum.as_int(summary.get("broad_skills_used", 0)),
		"%s: broad skills remaining is the cap minus those used" % label
	)

	# --- achievement track ---------------------------------------------------
	var points := AlternityNum.as_int(character.get("achievement_points", 0))
	check_eq(
		_rules.achievements.achievement_points_available(character),
		points - _rules.achievements.achievement_points_for_current_level(points),
		"%s: unbanked AP is total minus what the current level banked" % label
	)
	check_true(
		_rules.achievements.achievement_points_available(character) >= 0,
		"%s: unbanked AP is never negative" % label
	)

	# --- durability tracks are consistent with their damage -----------------
	var durability: Dictionary = summary.get("durability", {})
	var damage: Dictionary = character.get("damage", {})
	for track in ["stun", "wound", "mortal", "fatigue"]:
		var total := AlternityNum.as_int(durability.get(track, 0))
		var taken := AlternityNum.as_int(damage.get(track, 0))
		check_true(
			taken <= total,
			"%s: %s damage (%d) never exceeds the track (%d)" % [label, track, taken, total]
		)

	# --- action check thresholds keep their order ---------------------------
	var action: Dictionary = summary.get("action_check", {})
	var ordinary := AlternityNum.as_int(action.get("ordinary", 0))
	check_eq(
		AlternityNum.as_int(action.get("good", -1)), int(floor(ordinary / 2.0)),
		"%s: Good is half Ordinary" % label
	)
	check_eq(
		AlternityNum.as_int(action.get("amazing", -1)), int(floor(ordinary / 4.0)),
		"%s: Amazing is a quarter of Ordinary" % label
	)
	check_eq(
		AlternityNum.as_int(action.get("marginal", -1)), ordinary + 1,
		"%s: Marginal is one past Ordinary" % label
	)


## A skill's recorded cost must equal what its ranks actually cost, one by one.
##
## This is where an escalating-cost bug would hide: the per-rank prices and the
## stored total are computed by different code paths.
func _test_rank_costs_are_the_sum_of_their_ranks() -> void:
	for flat in [false, true]:
		_rules = _fresh()
		var character: Dictionary = _rules.default_character()
		character["species_id"] = 0
		character["profession_id"] = 0
		_rules.ensure_character_shape(character)
		_rules.set_optional_rule(character, "2c", flat)
		# High enough that the rank ceiling is not what stops us.
		_rules.achievements.set_achievement_points(character, 200)

		var label := "flat cost (2C)" if flat else "escalating cost"
		var checked := 0
		for skill_entry in _rules.skills:
			if typeof(skill_entry) != TYPE_DICTIONARY or skill_entry.get("type", "") != "specialty":
				continue
			var skill_id := AlternityNum.as_int(skill_entry.get("id", -1), -1)
			var broad_id := AlternityNum.as_int(skill_entry.get("broad_id", -1), -1)
			_rules.force_skill_rank(character, broad_id, 1)
			_rules.force_skill_rank(character, skill_id, 4)

			var skill: Dictionary = _rules.get_skill_by_id(skill_id)
			var expected := 0
			for rank in range(1, 5):
				expected += _rules.skill_purchase_cost(character, skill, rank)
			check_eq(
				_rules.skill_rank_total_cost(character, skill), expected,
				"%s: %s at rank 4 costs the sum of its four ranks" % [label, _rules.skill_label(skill)]
			)

			# And the two pricing rules differ in the direction they should.
			if flat:
				var base: int = _rules.skill_cost(character, skill)
				check_eq(
					_rules.skill_rank_total_cost(character, skill), base * 4,
					"%s: four ranks cost four times list price" % label
				)

			checked += 1
			if checked >= 6:
				break
		check_true(checked > 0, "%s: exercised some specialties" % label)


## A hero who spends through FX and cybertech as well as skills.
func _built_character() -> Dictionary:
	var rules = _fresh()
	var character: Dictionary = rules.default_character()
	character["species_id"] = 0
	character["profession_id"] = 0
	rules.ensure_character_shape(character)
	rules.achievements.set_achievement_points(character, 60)

	rules.fx.set_fx_talent(character, true)
	rules.fx.set_energy_pool(character, 6)
	for broad in rules.fx.get_broad_skills_for_character(character):
		var broad_name := String(broad.get("name", ""))
		rules.fx.add_fx_skill(character, broad_name)
		for power in rules.fx.get_specialty_skills_for_broad_and_character(broad_name, character):
			rules.fx.add_fx_skill(character, String(power.get("name", "")))
			break
		break

	rules.cybertech.set_cybertech_enabled(character, true)
	for item in rules.cybertech_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if bool(rules.cybertech.can_install_cybertech(character, item_id, "ordinary").get("allowed", false)):
			rules.cybertech.install_cybertech(character, item_id, "ordinary")
			break

	character["last_resorts_rebought"] = 1
	return character


## A hero carrying perks, flaws and a purchased benefit.
func _perked_character() -> Dictionary:
	var rules = _fresh()
	var character: Dictionary = rules.default_character()
	character["species_id"] = 0
	character["profession_id"] = 0
	rules.ensure_character_shape(character)
	rules.achievements.set_achievement_points(character, 120)

	for perk in AlternityRules.PERK_DEFINITIONS:
		var costs: Array = perk.get("cost_options", [])
		rules.set_perk_selected(
			character, String(perk.get("id", "")),
			AlternityNum.as_int(costs[0] if not costs.is_empty() else 0)
		)
		break
	for flaw in AlternityRules.FLAW_DEFINITIONS:
		var bonuses: Array = flaw.get("bonus_options", [])
		rules.set_flaw_selected(
			character, String(flaw.get("id", "")),
			AlternityNum.as_int(bonuses[0] if not bonuses.is_empty() else 0)
		)
		break

	rules.achievements.add_achievement_purchase(character, "action_check_increase")
	return character


## A hero far enough along that banked points and the level bonus both matter.
func _levelled_character() -> Dictionary:
	var rules = _fresh()
	var character: Dictionary = rules.default_character()
	character["species_id"] = 0
	character["profession_id"] = 5   # Tech Op, the profession with a level skill bonus
	rules.ensure_character_shape(character)
	rules.set_optional_rule(character, "2a", true)
	rules.set_optional_rule(character, "2c", true)
	rules.achievements.set_achievement_points(character, 90)

	var bought := 0
	for broad in rules.broad_skills:
		if typeof(broad) != TYPE_DICTIONARY or rules.is_psionic_skill(broad):
			continue
		if bought >= 3:
			break
		rules.force_skill_rank(character, AlternityNum.as_int(broad.get("id", 0)), 1)
		bought += 1
	return character
