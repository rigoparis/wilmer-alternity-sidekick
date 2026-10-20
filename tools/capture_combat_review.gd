extends SceneTree

const BUILDS_DIR := "res://builds/encounter_review/"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("Starting combat UI capture with GPU rendering...")
	DirAccess.make_dir_recursive_absolute(BUILDS_DIR)

	for size in [Vector2i(390, 844), Vector2i(1280, 720)]:
		root.size = size
		root.content_scale_size = size

		var shell = preload("res://scenes/ui/app_shell.tscn").instantiate()
		shell.store_directory = "user://__combat_capture__/heroes/"
		shell.campaign_directory = "user://__combat_capture__/campaigns/"
		root.add_child(shell)
		await process_frame
		await process_frame

		var session := CampaignSession.new("Station Breach")
		var fight := ActionRound.new(1)

		# Setup 3 combatants with portraits
		var sela_doc := CharacterDoc.new(shell.rules)
		sela_doc.set_hero_name("Sela Anwar")
		var sela_id: String = session.add_seat("Sela Anwar")
		session.commit_character(sela_id, CharacterSnapshot.of_doc(sela_doc))
		fight.add_combatant(sela_id, "Sela Anwar", 2, ActionRound.KIND_PLAYER)
		fight.record_check(sela_id, "Amazing", 14, 3)

		var vance_doc := CharacterDoc.new(shell.rules)
		vance_doc.set_hero_name("Vance Kellar")
		var vance_id: String = session.add_seat("Vance Kellar")
		session.commit_character(vance_id, CharacterSnapshot.of_doc(vance_doc))
		fight.add_combatant(vance_id, "Vance Kellar", 2, ActionRound.KIND_PLAYER)
		fight.record_check(vance_id, "Amazing", 13, 6)

		var guard_doc := CharacterDoc.new(shell.rules)
		guard_doc.set_hero_name("Station Guard")
		var guard_id: String = session.add_npc(guard_doc.to_dict())
		fight.add_combatant(guard_id, "Station Guard", 1, ActionRound.KIND_NPC)
		fight.record_check(guard_id, "Ordinary", 11, 9)

		fight.start()
		# Vance postponed in Amazing phase -> shows Undo button
		fight.postpone(vance_id, "amazing")
		var vance_comb: Dictionary = fight.combatant(vance_id)
		vance_comb["action_type_amazing"] = "manual"

		session.set_round(fight.to_dict())

		shell._open_campaign(session)
		await process_frame
		await process_frame
		var gm: GmScreen = shell._gm
		gm._open_encounter()
		await process_frame
		await process_frame

		var encounter = shell.router._host.top_route()
		var scroll: ScrollContainer = encounter._body.get_parent().get_parent()

		# --- 1. Top of Encounter Page (Overview & Acting this phase) ---
		scroll.scroll_vertical = 0
		await _render_frames(15)
		_save_viewport("encounter_%d.png" % size.x)

		# --- 2. Combat Controls (Done, Pass, Undo, Attack, Actions dial) ---
		# Scroll down to reveal the controls section containing actor controls
		scroll.scroll_vertical = 460 if size.x == 390 else 240
		await _render_frames(15)
		_save_viewport("controls_%d.png" % size.x)

		# --- 3. Offline Defense Pending & Advance Barrier Warning ---
		var pending_atk := CombatAttack.declare(sela_id, "Station Guard", "Laser Rifle", "Amazing", 4, "w", "hi", "O")
		pending_atk.round_id = fight.round_id
		pending_atk.phase = "amazing"
		session.queue_attack(pending_atk.to_dict(), sela_id)
		gm._on_advance_phase_pressed()
		encounter._render()
		scroll.scroll_vertical = 460 if size.x == 390 else 240
		await _render_frames(15)
		_save_viewport("offline_%d.png" % size.x)

		# --- 4. Phase Closing In-Flight State ---
		session.pending_attacks.erase(pending_atk.attack_id)
		session.begin_phase_closing(fight.round_id, "amazing")
		gm._closing_in_flight = true
		gm._status.text = "Awaiting phase commit acknowledgment from players..."
		gm._status.add_theme_color_override("font_color", shell._palette.warning)
		encounter._render()
		scroll.scroll_vertical = 460 if size.x == 390 else 240
		await _render_frames(15)
		_save_viewport("closing_%d.png" % size.x)

		# --- 5. Participants Route Modal ---
		scroll.scroll_vertical = 0
		var picker = shell.router.present_modal(preload("res://scenes/ui/routes/encounter_participants_route.tscn"), {
			"palette": shell._palette,
			"participants": fight.combatants
		})
		await _render_frames(15)
		_save_viewport("participants_%d.png" % size.x)
		shell.router.dismiss_modal(picker)

		shell.router.pop_all()
		shell.queue_free()
		await process_frame
		await process_frame

	print("All combat UI captures completed successfully!")
	quit()

func _render_frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw

func _save_viewport(filename: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(BUILDS_DIR + filename)
	print("Saved capture: ", filename)
