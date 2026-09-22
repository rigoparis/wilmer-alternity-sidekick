extends SceneTree
##
## Renders the Android Back "Leave the table?" confirmation at phone and desktop
## width, so its wording can be looked at rather than only asserted about.
##
##     godot --path . -s tools/capture_leave_table_dialog.gd
##
## Not headless: the dialog has to be laid out and drawn to show whether the
## message wraps sanely and the two buttons still fit side by side on a phone.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const CONFIRM_ROUTE := preload("res://scenes/ui/routes/confirm_route.tscn")
const STORE_DIR := "user://__leave_shot_store__/"
const CAMPAIGN_DIR := "user://__leave_shot_campaigns__/"

const SIZES := [
	[390, 844, "phone"],
	[1280, 720, "desktop"],
]

var _out_dir := "user://shots/"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	for spec in SIZES:
		await _capture(spec[0], spec[1], String(spec[2]))
	print("Written to %s" % ProjectSettings.globalize_path(_out_dir))
	quit(0)


func _capture(width: int, height: int, label: String) -> void:
	var window := root.get_window()
	window.size = Vector2i(width, height)
	# Narrow the viewport itself, not just the window: the project stretches
	# canvas_items against a 1280x720 base, so without this the compact layout
	# is never reached. Same reason as capture_shell_screenshot.gd.
	window.content_scale_size = Vector2i(width, height)
	await process_frame
	await process_frame

	var shell = SHELL.instantiate()
	shell.store_directory = STORE_DIR
	shell.campaign_directory = CAMPAIGN_DIR
	root.add_child(shell)
	for _i in 10:
		await process_frame

	# The exact props AppShell._confirm_leave_table() pushes.
	shell.router.push(CONFIRM_ROUTE, {
		"palette": shell._palette,
		"title": "Leave the table?",
		"message": "You will disconnect from the GM. Your character and campaign identity stay saved, so you can rejoin later.",
		"confirm_text": "Leave table",
		"cancel_text": "Stay",
	})
	for _i in 14:
		await process_frame

	var image := root.get_texture().get_image()
	if image != null:
		var path := "%sleave_table_%s.png" % [_out_dir, label]
		image.save_png(path)
		print("  %s  (%dx%d)" % [path, image.get_width(), image.get_height()])

	shell.queue_free()
	await process_frame
