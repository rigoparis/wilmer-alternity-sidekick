extends SceneTree


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	scene.character["species_id"] = scene.rules.mutant_species_id()
	scene.rules.set_mutation_points(scene.character, 3, 2)
	scene.active_tab = "Mutations"
	scene._render()
	await process_frame

	if not bool(scene.tab_buttons.get("Mutations").visible):
		_fail("Mutations tab should be visible for Mutant species.")
	if scene.content.get_child_count() <= 0:
		_fail("Mutations tab did not render content.")

	scene.rules.add_mutation_advantage(scene.character, "improved_str")
	scene.rules.add_mutation_drawback(scene.character, "slow_reflexes")
	scene.active_tab = "Summary"
	scene._render()
	await process_frame

	if scene.content.get_child_count() <= 0:
		_fail("Summary did not render after mutation selections.")

	quit()
