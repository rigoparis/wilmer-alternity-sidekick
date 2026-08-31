extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("achievement purchases")

	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()
	rules.ensure_character_shape(character)
	rules.achievements.set_achievement_points(character, 30)

	check_true(rules.achievement_catalog.size() >= 30, "achievement catalog loaded (>=30 entries)")

	# Action Check Increase: purchasable for a Combat Spec at level 5, costs 4 SP,
	# and raises the ordinary action check score by 1.
	var base_action: Dictionary = rules.action_check(character)
	var increase := rules.get_achievement_by_id("action_check_increase")
	var check_result = rules.achievements.can_purchase_achievement(character, increase)
	check_true(
		bool(check_result.get("allowed", false)),
		"Action Check Increase is purchasable at Combat Spec level 5"
	)

	var result = rules.achievements.add_achievement_purchase(character, "action_check_increase")
	check_true(bool(result.get("ok", false)), "Action Check Increase purchase succeeds")

	var improved_action: Dictionary = rules.action_check(character)
	check_eq(
		rules._as_int(improved_action.get("ordinary", 0)),
		rules._as_int(base_action.get("ordinary", 0)) + 1,
		"Action Check Increase raises the ordinary score by 1"
	)
	check_eq(
		rules.achievements.achievement_points_spent(character), 4,
		"Action Check Increase costs 4 points for Combat Spec"
	)

	# WIL Increase for a Free Agent (profession 4) raises effective WIL by 1.
	character["profession_id"] = 4
	var wil_before := rules._as_int(rules.effective_abilities(character).get("WIL", 0))
	result = rules.achievements.add_achievement_purchase(character, "wil_increase_1")
	check_true(bool(result.get("ok", false)), "WIL Increase 1 purchase succeeds for Free Agent level 5")
	check_eq(
		rules._as_int(rules.effective_abilities(character).get("WIL", 0)), wil_before + 1,
		"WIL Increase raises effective WIL by 1"
	)

	# Remove Flaw drops the selected flaw and bills for it.
	rules.set_flaw_selected(character, "obsessed", 4)
	rules.achievements.set_achievement_points(character, 51)
	character["profession_id"] = 0
	result = rules.achievements.add_achievement_purchase(character, "remove_flaw", "obsessed", 4)
	check_true(bool(result.get("ok", false)), "Remove Flaw purchase succeeds")
	check_false(rules.is_flaw_selected(character, "obsessed"), "Remove Flaw clears the selected flaw")
	check_true(
		rules.achievements.achievement_points_spent(character) >= 22,
		"spend total includes the Remove Flaw cost"
	)

	finish()
