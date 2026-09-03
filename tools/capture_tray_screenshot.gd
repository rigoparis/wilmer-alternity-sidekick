extends SceneTree
##
## Renders the dice tray and the check dial, so they can be looked at rather than
## only asserted about.
##
##     godot --path . -s tools/capture_tray_screenshot.gd
##
## Not headless: the tray is the one part of this app that has to be seen. Every
## layout defect in this project so far passed the full suite first.
##

const TRAY_ROUTE := preload("res://scenes/ui/routes/dice_tray_route.tscn")
const STEP_ROUTE := preload("res://scenes/ui/routes/check_step_route.tscn")
const Check := preload("res://scripts/core/session/skill_check.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")

const SIZES := [
	[390, 844, "phone"],
	[1280, 720, "desktop"],
]

var _out_dir := "user://shots/"
var _rules


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_rules = RulesScript.new()
	_rules.load_core_data()

	for spec in SIZES:
		await _capture(spec[0], spec[1], String(spec[2]))

	print("Screenshots written to %s" % ProjectSettings.globalize_path(_out_dir))
	quit(0)


func _check_data() -> Dictionary:
	var check = Check.request("player-1", {"id": 1}, {
		"ordinary": 12, "good": 6, "amazing": 3, "step": 1,
	}, "Athletics - Climb")
	check.rule(2, "the ledge is wet")
	return check.to_dict()


func _capture(width: int, height: int, label: String) -> void:
	var window := root.get_window()
	window.size = Vector2i(width, height)
	# As in capture_shell_screenshot: the project stretches against a 1280x720
	# base, so resizing alone leaves narrow layouts on the wide path.
	window.content_scale_size = Vector2i(width, height)
	await process_frame
	await process_frame

	var palette := ThemePalette.new()

	# The step dial, which both the GM and a solo player use.
	var dial = STEP_ROUTE.instantiate()
	root.add_child(dial)
	dial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dial.configure({
		"palette": palette,
		"rules": _rules,
		"check": _check_data(),
		"title": "How hard is it?",
		"confirm_text": "Send",
	})
	for _i in 10:
		await process_frame
	_save("%s_check_step" % label)
	dial.queue_free()
	await process_frame

	# The tray, before the throw and after it.
	var tray = TRAY_ROUTE.instantiate()
	root.add_child(tray)
	tray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tray.configure({"palette": palette, "rules": _rules, "check": _check_data()})
	for _i in 12:
		await process_frame
	_save("%s_tray_ready" % label)

	tray._on_roll_pressed()
	# Long enough for the dice to settle, whatever they do.
	for _i in 400:
		await process_frame
		if not tray._resolved.is_empty():
			break
	for _i in 6:
		await process_frame
	_save("%s_tray_settled" % label)

	tray.queue_free()
	await process_frame


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		printerr("no image for %s" % name)
		return
	var path := "%s%s.png" % [_out_dir, name]
	image.save_png(path)
	print("  %s  (%dx%d)" % [path, image.get_width(), image.get_height()])
