extends "res://tools/test_harness.gd"
##
## Exercises the optional random ability generation panel (GMG Chapter 2,
## Methods I/II/III) through the real UI, so the engine functions behind it stay
## reachable from the app rather than only from tests.
##
## Async for the same reason as smoke_mutation_ui: instantiating main.tscn needs
## the main loop to run its deferred layout passes.
##

func _init() -> void:
	begin_async("ability generation UI", 300)
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://main.tscn")
	if not check(packed != null, "main.tscn loads"):
		finish()
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	scene.active_tab = "Basics"
	scene.character["species_id"] = 0 # Human
	scene.character["profession_id"] = 0 # Combat Spec
	scene._render()
	await process_frame
	check_true(scene.content.get_child_count() > 0, "Basics tab renders with the generation panel")

	# --- Method I: roll by profession ---
	scene._apply_rolled_abilities(scene.rules.roll_abilities_method_1(0))
	await process_frame
	var after_m1: Dictionary = scene.character["abilities"]
	check_eq(after_m1.size(), AlternityRules.ABILITIES.size(), "Method I writes all six abilities")
	check_eq(
		scene.rules._as_int(scene.character.get("custom_ability_target", 0)),
		scene.rules.ability_total(scene.character),
		"Rolling retargets the point pool to the rolled total so the sheet validates"
	)
	for ability in AlternityRules.ABILITIES:
		var limits: Array = scene.rules.ability_limits(scene.character, ability)
		var score: int = scene.rules._as_int(after_m1.get(ability, 0))
		check_true(
			score >= scene.rules._as_int(limits[0]) and score <= scene.rules._as_int(limits[1]),
			"Method I %s (%d) lands inside the legal range %d-%d" % [ability, score, limits[0], limits[1]]
		)

	# --- Method II: roll by species ---
	scene._apply_rolled_abilities(scene.rules.roll_abilities_method_2(5)) # Weren
	await process_frame
	check_true(scene.content.get_child_count() > 0, "Method II leaves the sheet renderable")

	# An empty roll must be a no-op rather than blanking the sheet.
	var kept: Dictionary = scene.character["abilities"].duplicate(true)
	scene._apply_rolled_abilities({})
	check_eq(scene.character["abilities"], kept, "An empty roll changes nothing")

	# --- Method III: die allocation pool ---
	scene.method3_pool = scene.rules.roll_method_3_dice()
	scene.method3_assignments = []
	for _i in scene.method3_pool.size():
		scene.method3_assignments.append(-1)
	check_eq(scene.method3_pool.size(), 7, "Method III rolls 7 dice")
	for die in scene.method3_pool:
		var value: int = scene.rules._as_int(die)
		check_true(value >= 1 and value <= 6, "Method III die %d is a d6 result" % value)

	scene._render()
	await process_frame
	check_true(scene.content.get_child_count() > 0, "Method III allocation panel renders")

	# Unassigned dice leave every ability at the baseline of 5.
	var baseline: Dictionary = scene._method3_totals()
	for ability in AlternityRules.ABILITIES:
		check_eq(scene.rules._as_int(baseline.get(ability, 0)), 5, "%s starts at the Method III baseline of 5" % ability)

	# Assign every die to STR and confirm the total tracks the pool.
	var pool_sum := 0
	for index in scene.method3_pool.size():
		scene.method3_assignments[index] = 0 # STR
		pool_sum += scene.rules._as_int(scene.method3_pool[index])
	var loaded: Dictionary = scene._method3_totals()
	check_eq(scene.rules._as_int(loaded.get("STR", 0)), 5 + pool_sum, "All seven dice land on STR")
	check_eq(scene.rules._as_int(loaded.get("DEX", 0)), 5, "Unassigned abilities stay at 5")

	scene._render()
	await process_frame
	check_true(scene.content.get_child_count() > 0, "Allocation panel survives a full assignment")

	# --- Strength feat reference on the Summary tab ---
	scene.method3_pool = []
	scene.method3_assignments = []
	scene.active_tab = "Summary"
	scene._render()
	await process_frame
	check_true(scene.content.get_child_count() > 0, "Summary tab renders the Strength Feats section")

	finish()
