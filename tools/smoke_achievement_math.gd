extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("achievement math")

	var rules = RulesScript.new()
	var achievements = rules.achievements

	# achievement_points_for_level: level -> cumulative points required.
	for case in [[-5, 0], [0, 0], [1, 0], [2, 6], [3, 13], [4, 21], [5, 30]]:
		check_eq(
			achievements.achievement_points_for_level(case[0]), case[1],
			"achievement_points_for_level(%d)" % case[0]
		)

	# achievement_level_for_points: the inverse, clamped to a minimum of level 1.
	for case in [[-10, 1], [0, 1], [5, 1], [6, 2], [12, 2], [13, 3], [30, 5], [100, 10]]:
		check_eq(
			achievements.achievement_level_for_points(case[0]), case[1],
			"achievement_level_for_points(%d)" % case[0]
		)

	# achievement_next_level_points: points needed to reach the next level.
	for case in [[0, 6], [5, 6], [6, 13], [30, 40]]:
		check_eq(
			achievements.achievement_next_level_points(case[0]), case[1],
			"achievement_next_level_points(%d)" % case[0]
		)

	finish()
