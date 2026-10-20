extends SceneTree
## Render the real encounter route using scratch campaign data.
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var shell = preload("res://scenes/ui/app_shell.tscn").instantiate()
	shell.store_directory = "user://__encounter_capture__/heroes/"
	shell.campaign_directory = "user://__encounter_capture__/campaigns/"
	root.add_child(shell)
	await process_frame
	var session := CampaignSession.new("Station breach")
	var fight := ActionRound.new()
	for i in 3:
		var actor_name: String = ["Sela Anwar", "Vance Kellar", "Station guard"][i]
		var doc := CharacterDoc.new(shell.rules)
		doc.set_hero_name(actor_name)
		var id: String
		if i < 2:
			id = session.add_seat(actor_name)
			session.commit_character(id, CharacterSnapshot.of_doc(doc))
		else:
			id = session.add_npc(doc.to_dict())
		fight.add_combatant(id, actor_name, 2, ActionRound.KIND_NPC if i == 2 else ActionRound.KIND_PLAYER)
		fight.record_check(id, ["Amazing", "Good", "Ordinary"][i], 14 - i, 3 + i)
	fight.start()
	session.set_round(fight.to_dict())
	var gm := GmScreen.new()
	shell.add_child(gm)
	gm.setup(session, shell.campaigns, shell.store, shell.rules, shell.router, shell._palette)
	gm.hide()
	gm._open_encounter()
	DirAccess.make_dir_recursive_absolute("res://builds/encounter_review")
	for size in [Vector2i(390, 844), Vector2i(1280, 720)]:
		root.size = size
		root.content_scale_size = size
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png("res://builds/encounter_review/encounter_%d.png" % size.x)
		var encounter = shell.router._host.top_route()
		var scroll: ScrollContainer = encounter._body.get_parent().get_parent()
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/encounter_review/controls_%d.png" % size.x)
		scroll.scroll_vertical = 0
		var picker = shell.router.present_modal(preload("res://scenes/ui/routes/encounter_participants_route.tscn"), {
			"palette": shell._palette, "participants": fight.combatants})
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/encounter_review/participants_%d.png" % size.x)
		shell.router.dismiss_modal(picker)
	shell.router.pop_all()
	shell.queue_free()
	await process_frame
	quit()
