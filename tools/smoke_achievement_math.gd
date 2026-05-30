extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var rules = RulesScript.new()
	var achievements = rules.achievements

	# Test achievement_points_for_level
	if achievements.achievement_points_for_level(-5) != 0:
		_fail("achievement_points_for_level failed for negative number")
	if achievements.achievement_points_for_level(0) != 0:
		_fail("achievement_points_for_level failed for 0")
	if achievements.achievement_points_for_level(1) != 0:
		_fail("achievement_points_for_level failed for 1")
	if achievements.achievement_points_for_level(2) != 6:
		_fail("achievement_points_for_level failed for 2")
	if achievements.achievement_points_for_level(3) != 13:
		_fail("achievement_points_for_level failed for 3")
	if achievements.achievement_points_for_level(4) != 21:
		_fail("achievement_points_for_level failed for 4")
	if achievements.achievement_points_for_level(5) != 30:
		_fail("achievement_points_for_level failed for 5")

	# Test achievement_level_for_points
	if achievements.achievement_level_for_points(-10) != 1:
		_fail("achievement_level_for_points failed for negative points")
	if achievements.achievement_level_for_points(0) != 1:
		_fail("achievement_level_for_points failed for 0 points")
	if achievements.achievement_level_for_points(5) != 1:
		_fail("achievement_level_for_points failed for 5 points")
	if achievements.achievement_level_for_points(6) != 2:
		_fail("achievement_level_for_points failed for 6 points")
	if achievements.achievement_level_for_points(12) != 2:
		_fail("achievement_level_for_points failed for 12 points")
	if achievements.achievement_level_for_points(13) != 3:
		_fail("achievement_level_for_points failed for 13 points")
	if achievements.achievement_level_for_points(30) != 5:
		_fail("achievement_level_for_points failed for 30 points")
	if achievements.achievement_level_for_points(100) != 10:
		_fail("achievement_level_for_points failed for 100 points")

	# Test achievement_next_level_points
	if achievements.achievement_next_level_points(0) != 6:
		_fail("achievement_next_level_points failed for 0 points")
	if achievements.achievement_next_level_points(5) != 6:
		_fail("achievement_next_level_points failed for 5 points")
	if achievements.achievement_next_level_points(6) != 13:
		_fail("achievement_next_level_points failed for 6 points")
	if achievements.achievement_next_level_points(30) != 40:
		_fail("achievement_next_level_points failed for 30 points")

	print("Smoke achievement math tests passed successfully.")
	quit(0)
