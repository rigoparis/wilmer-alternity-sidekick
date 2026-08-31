extends "res://tools/test_harness.gd"
##
## The only test that instantiates the real UI. Async: it needs the main loop to
## run so that deferred layout passes complete, so it uses begin_async()'s frame
## watchdog rather than a pessimistic quit -- otherwise a scene that fails to
## load would hang CI indefinitely.
##

func _init() -> void:
	begin_async("mutation UI render", 300)
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://main.tscn")
	if not check(packed != null, "main.tscn loads"):
		finish()
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	# Mutations tab only applies to the Mutant species.
	scene.character["species_id"] = scene.rules.mutations.mutant_species_id()
	scene.rules.mutations.set_mutation_points(scene.character, 3, 2)
	scene.active_tab = "Mutations"
	scene._render()
	await process_frame

	check_true(bool(scene.tab_buttons.get("Mutations").visible), "Mutations tab visible for Mutant species")
	check_true(scene.content.get_child_count() > 0, "Mutations tab rendered content")

	scene.rules.mutations.add_mutation_advantage(scene.character, "improved_str")
	scene.rules.mutations.add_mutation_drawback(scene.character, "slow_reflexes")
	scene.active_tab = "Summary"
	scene._render()
	await process_frame

	check_true(scene.content.get_child_count() > 0, "Summary rendered after mutation selections")

	finish()
