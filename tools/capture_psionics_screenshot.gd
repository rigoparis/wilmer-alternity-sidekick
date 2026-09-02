extends SceneTree
##
## Renders the Skills tab for a Mindwalker who owns a discipline but has bought
## no specialty ranks yet -- the exact state the discipline gate and the
## broad-covers-its-specialties rule change.
##
##     godot --path . -s tools/capture_psionics_screenshot.gd
##
## Not headless: rendering has to actually happen. Uses a scratch store so it
## never touches real saved characters.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const STORE_DIR := "user://__psi_shot_store__/"

const SIZES := [
	[390, 844, "phone"],
	[1920, 1080, "wide"],
]

const PROFESSION_MINDWALKER := 6
const SKILL_ESP := 903
const SKILL_TELEPATHY := 901

var _out_dir := "user://shots/"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_seed_store()

	for spec in SIZES:
		await _capture(spec[0], spec[1], String(spec[2]))

	print("Screenshots written to %s" % ProjectSettings.globalize_path(_out_dir))
	quit(0)


func _seed_store() -> void:
	var rules = load("res://scripts/alternity_rules.gd").new()
	rules.load_core_data()
	var store = CharacterStore.new(rules, STORE_DIR)
	for entry in store.list():
		store.delete(String(entry["file_name"]))

	var doc := CharacterDoc.new(rules)
	doc.set_hero_name("Sela Anwar")
	doc.set_profession_id(PROFESSION_MINDWALKER)
	doc.apply(CharacterDoc.ALL, func(c):
		c["abilities"]["INT"] = 12
		c["abilities"]["WIL"] = 12
		c["abilities"]["PER"] = 11
		c["abilities"]["CON"] = 11
		# Two disciplines held, and one specialty bought inside one of them.
		# That single sheet then shows all three states side by side: a bought
		# specialty, a specialty carried by its discipline, and -- under the
		# discipline she does not own -- powers that are simply shut.
		rules.force_skill_rank(c, SKILL_ESP, 1)
		rules.force_skill_rank(c, SKILL_TELEPATHY, 1)
		rules.force_skill_rank(c, 90302, 2)   # Clairaudience, rank 2
		var tracks: Dictionary = c.get("damage", {})
		tracks["stun"] = 2
		c["damage"] = tracks)
	store.save(doc)
	store.clear_last_opened()


func _capture(width: int, height: int, label: String) -> void:
	var window := root.get_window()
	window.size = Vector2i(width, height)
	window.content_scale_size = Vector2i(width, height)
	await process_frame
	await process_frame

	var shell = SHELL.instantiate()
	shell.store_directory = STORE_DIR
	root.add_child(shell)
	for _i in 12:
		await process_frame

	var listing: Array = shell.store.list()
	if listing.is_empty():
		printerr("no seeded hero to open")
		shell.queue_free()
		return

	var doc = shell.store.load_doc(String(listing[0]["file_name"]))
	if doc == null:
		printerr("could not load the seeded hero")
		shell.queue_free()
		return

	shell._open_sheet(doc)
	for _i in 12:
		await process_frame

	var sheet = shell._screens.get_child(0)
	for id in ["skills", "psionics", "summary"]:
		for definition in sheet._available_tabs():
			if String(definition["id"]) != id:
				continue
			sheet._select_tab(id)
			for _i in 14:
				await process_frame
			_save("%s_psi_%s" % [label, id])

	shell.queue_free()
	await process_frame


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		printerr("no image for %s" % name)
		return
	var path := "%s%s.png" % [_out_dir, name]
	image.save_png(path)
	print("  %s  (%dx%d)" % [path, image.get_width(), image.get_height()])
