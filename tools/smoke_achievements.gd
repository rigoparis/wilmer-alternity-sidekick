extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()
	rules.ensure_character_shape(character)
	rules.achievements.set_achievement_points(character, 30)

	if rules.achievement_catalog.size() < 30:
		_fail("Achievement catalog did not load.")

	var base_action: Dictionary = rules.action_check(character)
	var increase := rules.get_achievement_by_id("action_check_increase")
	var check = rules.achievements.can_purchase_achievement(character, increase)
	if not bool(check.get("allowed", false)):
		_fail("Action Check Increase should be purchasable at Combat Spec level 5.")
	var result = rules.achievements.add_achievement_purchase(character, "action_check_increase")
	if not bool(result.get("ok", false)):
		_fail("Action Check Increase purchase failed.")
	var improved_action: Dictionary = rules.action_check(character)
	if rules._as_int(improved_action.get("ordinary", 0)) != rules._as_int(base_action.get("ordinary", 0)) + 1:
		_fail("Action Check Increase did not affect the action check score.")
	if rules.achievements.achievement_points_spent(character) != 4:
		_fail("Action Check Increase did not spend 4 skill points for Combat Spec.")

	character["profession_id"] = 4
	var wil_before := rules._as_int(rules.effective_abilities(character).get("WIL", 0))
	result = rules.achievements.add_achievement_purchase(character, "wil_increase_1")
	if not bool(result.get("ok", false)):
		_fail("WIL Increase 1 purchase failed for Free Agent level 5.")
	var wil_after := rules._as_int(rules.effective_abilities(character).get("WIL", 0))
	if wil_after != wil_before + 1:
		_fail("WIL Increase did not affect effective abilities.")

	rules.set_flaw_selected(character, "obsessed", 4)
	rules.achievements.set_achievement_points(character, 51)
	character["profession_id"] = 0
	result = rules.achievements.add_achievement_purchase(character, "remove_flaw", "obsessed", 4)
	if not bool(result.get("ok", false)):
		_fail("Remove Flaw purchase failed.")
	if rules.is_flaw_selected(character, "obsessed"):
		_fail("Remove Flaw did not remove the selected flaw.")
	if rules.achievements.achievement_points_spent(character) < 22:
		_fail("Achievement spending did not include Remove Flaw cost.")

	quit()
