extends SceneTree
##
## Renders the new shell at a few sizes and saves PNGs, so the rewritten UI can
## be looked at rather than only asserted about.
##
##     godot --path . -s tools/capture_shell_screenshot.gd
##
## Not headless: rendering has to actually happen. Writes into a scratch
## directory passed as OUT_DIR below, and uses a scratch store so it never
## touches real saved characters.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const STORE_DIR := "user://__shot_store__/"
const CAMPAIGN_DIR := "user://__shot_campaigns__/"

## Width, height, label.
const SIZES := [
	[390, 844, "phone"],
	[1280, 720, "desktop"],
	# A maximised window on a 1080p monitor. The layout problems that only show
	# up at real desktop width -- rows stretched until a label and its value sit
	# at opposite edges -- are invisible at 1280.
	[1920, 1080, "wide"],
]

var _out_dir := "user://shots/"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_seed_store()
	_seed_campaigns()

	for spec in SIZES:
		await _capture(spec[0], spec[1], String(spec[2]))

	print("Screenshots written to %s" % ProjectSettings.globalize_path(_out_dir))
	quit(0)


## Give the list something to show, so the screenshots are not of an empty app.
func _seed_store() -> void:
	var rules = load("res://scripts/alternity_rules.gd").new()
	rules.load_core_data()
	var store = CharacterStore.new(rules, STORE_DIR)
	for entry in store.list():
		store.delete(String(entry["file_name"]))

	for hero in ["Vance Kellar", "Mira Sostrand"]:
		var doc := CharacterDoc.new(rules)
		doc.set_hero_name(hero)
		doc.set_profession_id(5)
		# A blank hero renders every budget bar at zero and every damage track
		# empty, which is exactly the state that hides a broken widget. Spend
		# something so the screenshots show the controls doing their job.
		doc.apply(CharacterDoc.ALL, func(c):
			var bought := 0
			for broad in rules.broad_skills:
				if bought >= 4:
					break
				if typeof(broad) != TYPE_DICTIONARY or rules.is_psionic_skill(broad):
					continue
				if not rules.is_entry_available(c, broad):
					continue
				rules.set_skill_rank(c, AlternityNum.as_int(broad.get("id", 0)), 1)
				bought += 1
			var tracks: Dictionary = c.get("damage", {})
			tracks["stun"] = 3
			tracks["wound"] = 1
			c["damage"] = tracks

			# FX and Equipment both render an empty shell until something is in
			# them, which is the state that hides a broken layout.
			rules.fx.set_fx_talent(c, true)
			rules.fx.set_energy_pool(c, 8)
			for broad in rules.fx.get_broad_skills_for_character(c):
				rules.fx.add_fx_skill(c, String(broad.get("name", "")))
				for power in rules.fx.get_specialty_skills_for_broad_and_character(
					String(broad.get("name", "")), c
				):
					var power_name := String(power.get("name", ""))
					rules.fx.add_fx_skill(c, power_name)
					# Make one power always-active. Without a permanent power the
					# permanent-effects block never renders, which is how a crash
					# in it survived every screenshot pass.
					if rules.fx.can_fx_skill_be_permanent(power_name):
						rules.fx.set_fx_skill_permanent(c, power_name, true)
					break
				break

			var stocked := 0
			for item in rules.equipment.filtered_equipment({}):
				if stocked >= 3:
					break
				rules.equipment.add_equipment_to_character(
					c, String(item.get("id", "")), 1 + stocked
				)
				stocked += 1)
		store.save(doc)
	store.clear_last_opened()


## A campaign with seats, a bound hero, AP and a log, so the GM screen is
## photographed doing its job rather than showing three empty sections.
func _seed_campaigns() -> void:
	var store := CampaignStore.new(CAMPAIGN_DIR)
	for entry in store.list():
		store.delete(String(entry["campaign_id"]))

	var session := CampaignSession.new("The Verge")
	var gm := session.add_seat("Rodri")
	session.set_gm(gm)
	var alice := session.add_seat("Alice")
	var bob := session.add_seat("Bob")

	# What a player's device sends when it commits a character. Seats have no
	# hero until somebody joins and chooses one, so without this the roster is a
	# row of "no character yet" and the screenshot shows nothing worth seeing.
	var seed_rules = load("res://scripts/alternity_rules.gd").new()
	seed_rules.load_core_data()
	var character_store = CharacterStore.new(seed_rules, STORE_DIR)
	for pair in [[alice, "Vance_Kellar.json"], [bob, "Mira_Sostrand.json"]]:
		var doc = character_store.load_doc(String(pair[1]))
		if doc != null:
			session.commit_character(String(pair[0]), CharacterSnapshot.of_doc(doc))

	# A table that has checked a few things, so the shortcut row has something in
	# it -- an empty one hides how the main screen actually looks in use.
	for skill_id in [1, 18, 42]:
		for _i in skill_id % 4 + 1:
			session.note_check(skill_id)

	session.append_event(CampaignSession.EVENT_JOIN, alice, {"player_name": "Alice"})
	session.append_chat(alice, "We break for the airlock.")
	session.append_roll(alice, {"notation": "d20", "total": 14, "label": "Action check"})
	session.append_chat(gm, "The seal is rusted through -- roll Strength.", alice)
	session.append_roll(bob, {"notation": "d20+d4", "total": 9, "label": "Athletics"})
	session.award_ap(alice, 3, CampaignSession.AP_REASON_HEROISM)
	session.award_table_ap(1, CampaignSession.AP_REASON_COMPLETION)
	store.save(session)

	var quiet := CampaignSession.new("Dark Matter: Session Zero")
	store.save(quiet)
	store.clear_last_opened()


func _capture(width: int, height: int, label: String) -> void:
	var window := root.get_window()
	window.size = Vector2i(width, height)

	# Resizing the window is not enough to reach the compact layout.
	#
	# The project stretches with mode "canvas_items" against a 1280x720 base, so
	# get_viewport_rect() reports roughly the base size however small the window
	# gets -- the content is scaled, not reflowed. Anything keying off viewport
	# width therefore stays on the wide path. On Android the base itself is
	# overridden to 390x844 (viewport_width.mobile), which is why the app does
	# reflow on a real phone.
	#
	# Setting content_scale_size makes the desktop viewport genuinely narrow, so
	# these screenshots show what a phone shows.
	window.content_scale_size = Vector2i(width, height)
	await process_frame
	await process_frame

	var shell = SHELL.instantiate()
	shell.store_directory = STORE_DIR
	shell.campaign_directory = CAMPAIGN_DIR
	root.add_child(shell)

	# Several frames: containers settle their layout over more than one pass.
	for _i in 12:
		await process_frame

	_save(shell, "%s_select" % label)

	# Open the first hero to capture the sheet and its tabs.
	var listing: Array = shell.store.list()
	if not listing.is_empty():
		var doc = shell.store.load_doc(String(listing[0]["file_name"]))
		if doc != null:
			shell._open_sheet(doc)
			for _i in 12:
				await process_frame
			_save(shell, "%s_sheet_first" % label)

			# Shoot every migrated tab, so a broken one is visible rather than
			# merely untested.
			var sheet = shell._screens.get_child(0)
			# Only the tabs this character actually gets.
			for definition in sheet._available_tabs():
				var id := String(definition["id"])
				sheet._select_tab(id)
				for _i in 12:
					await process_frame
				_save(shell, "%s_tab_%s" % [label, id])

	# The campaign list and the GM screen, which are the multiplayer feature's
	# single-device half and have the same reasons to be looked at as the sheet.
	shell._show_campaigns()
	for _i in 12:
		await process_frame
	_save(shell, "%s_campaigns" % label)

	var campaigns: Array = shell.campaigns.list()
	for entry in campaigns:
		var session = shell.campaigns.load_session(String(entry["campaign_id"]))
		if session == null:
			continue
		shell._open_campaign(session)
		for _i in 12:
			await process_frame
		# Both a populated campaign and an empty one: the empty states are where
		# a section collapses to nothing and nobody notices.
		var slug := "busy" if session.seats.size() > 0 else "empty"
		_save(shell, "%s_gm_%s" % [label, slug])

	# The player's half of the multiplayer feature. Joining is photographed with
	# nothing found, which is the state a player actually opens it in and the one
	# where an empty section is easiest to get wrong.
	shell._show_table_join()
	for _i in 12:
		await process_frame
	_save(shell, "%s_join" % label)

	# And the screen a player spends the evening on. Built directly with a
	# transport that never connected: what is being photographed is the layout,
	# and standing up a loopback host inside a screenshot pass would make this
	# tool depend on the network working.
	shell._clear_screens()
	var table = load("res://scenes/ui/screens/player_table.tscn").instantiate()
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell._screens.add_child(table)
	table.setup(EnetTransport.new(), shell.identity, shell.store, shell.rules, shell._palette, "The Verge")
	_seed_table_feed(table)
	for _i in 12:
		await process_frame
	_save(shell, "%s_player_table" % label)

	shell.queue_free()
	await process_frame


## A table mid-session: chat, a roll, and an award waiting to be claimed. The
## empty states are already covered by the GM screen shots.
func _seed_table_feed(table) -> void:
	var seq := 0
	for spec in [
		[CampaignSession.EVENT_JOIN, {}],
		[CampaignSession.EVENT_CHAT, {"text": "We break for the airlock.", "to": ""}],
		[CampaignSession.EVENT_ROLL, {"notation": "d20+d4", "total": 14, "label": "Action check"}],
		[CampaignSession.EVENT_CHAT, {"text": "The seal is rusted through.", "to": "gm"}],
		[CampaignSession.EVENT_AP_AWARD, {"amount": 3, "reason": CampaignSession.AP_REASON_HEROISM}],
	]:
		seq += 1
		table._events.append({
			"seq": seq,
			"kind": String(spec[0]),
			"player_id": "",
			"at": int(Time.get_unix_time_from_system()),
			"payload": spec[1],
		})
	# The award is addressed to this device, so it lands as claimable.
	table._unclaimed = 3
	table._render()


func _save(_shell, name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		printerr("no image for %s" % name)
		return
	var path := "%s%s.png" % [_out_dir, name]
	image.save_png(path)
	print("  %s  (%dx%d)" % [path, image.get_width(), image.get_height()])
