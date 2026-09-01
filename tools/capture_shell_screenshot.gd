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

## Width, height, label.
const SIZES := [
	[390, 844, "phone"],
	[1280, 720, "desktop"],
]

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
		store.save(doc)
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
			_save(shell, "%s_sheet_perks" % label)

			var sheet = shell._screens.get_child(0)
			sheet._select_tab("cybertech")
			for _i in 12:
				await process_frame
			_save(shell, "%s_sheet_cybertech" % label)

	shell.queue_free()
	await process_frame


func _save(_shell, name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		printerr("no image for %s" % name)
		return
	var path := "%s%s.png" % [_out_dir, name]
	image.save_png(path)
	print("  %s  (%dx%d)" % [path, image.get_width(), image.get_height()])
