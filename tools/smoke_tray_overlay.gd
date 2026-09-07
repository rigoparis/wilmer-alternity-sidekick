extends "res://tools/test_harness.gd"

const TRAY_ROUTE := preload("res://scenes/ui/routes/dice_tray_route.tscn")
const Check := preload("res://scripts/core/session/skill_check.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")

var _tray_scene


func _init() -> void:
	begin_async("tray pull gesture and results", 2400)
	_run.call_deferred()


func _run() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()

	var check = Check.request("player-1", {"id": 1}, {
		"ordinary": 12, "good": 6, "amazing": 3, "step": 1,
	}, "Athletics - Climb")

	_tray_scene = TRAY_ROUTE.instantiate()
	_tray_scene.configure({
		"palette": ThemePalette.new(),
		"rules": rules,
		"check": check.to_dict(),
	})
	root.add_child(_tray_scene)
	await process_frame
	await process_frame

	# 1. Verify overlay exists and mouse_filter is STOP
	var overlay = _tray_scene._aim_overlay
	check_true(overlay != null, "aim overlay is created")
	check_eq(overlay.mouse_filter, Control.MOUSE_FILTER_STOP, "overlay mouse_filter must be STOP")

	# A tap and a short pull must not commit the throw.
	var grip: Vector2 = overlay._grip()
	_mouse(overlay, grip, true)
	_mouse(overlay, grip + Vector2(0, 5), false)
	check_false(_tray_scene._rolling, "tap does not launch")
	check_true(_tray_scene._resolved.is_empty(), "no result before a real throw")
	# A second finger cannot release another pointer's pull.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = grip
	touch.pressed = true
	overlay._gui_input(touch)
	touch = InputEventScreenTouch.new()
	touch.index = 1
	touch.position = grip + Vector2(0, 60)
	touch.pressed = false
	overlay._gui_input(touch)
	check_true(overlay._dragging, "second finger cannot finish gesture")
	touch.index = 0
	touch.canceled = true
	overlay._gui_input(touch)
	check_false(overlay._dragging, "canceled touch clears gesture")
	check_false(_tray_scene._rolling, "canceled touch never launches")
	# Mouse release launches once and hides the setup controls.
	_mouse(overlay, grip, true)
	_mouse(overlay, grip + Vector2(20, 65), false)
	check_true(_tray_scene._rolling, "pull and release launches")
	check_false(overlay.visible, "gesture disappears while rolling")
	check_false(_tray_scene._outcome_card.visible, "no premature result")
	await _tray_scene._tray.settled
	await process_frame
	check_false(_tray_scene._resolved.is_empty(), "physical throw resolves")
	check_true(_tray_scene._outcome_card.visible, "result appears beside tray")
	check_eq(_tray_scene._scroll.scroll_vertical, 0, "result does not scroll tray away")
	var result: Dictionary = _tray_scene._resolved.duplicate(true)
	_tray_scene._on_roll_pressed()
	check_eq(_tray_scene._resolved, result, "completed throw cannot be launched again")
	for body in _tray_scene._tray._bodies:
		check_true(body.freeze, "visible dice hold the recorded faces")
	_tray_scene.queue_free()
	await process_frame
	# Real touch launch and timeout path, using a plain roll.
	_tray_scene = TRAY_ROUTE.instantiate()
	root.add_child(_tray_scene)
	_tray_scene.configure({
		"palette": ThemePalette.new(),
		"terms": [DiceNotation.parse("d6+2w")],
		"label": "Damage",
		"allow_reroll": true,
	})
	await process_frame
	await process_frame
	overlay = _tray_scene._aim_overlay
	grip = overlay._grip()
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = grip
	touch.pressed = true
	overlay._gui_input(touch)
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = grip + Vector2(0, 75)
	touch.pressed = false
	overlay._gui_input(touch)
	check_true(_tray_scene._rolling, "real touchscreen release launches")
	await physics_frame
	_tray_scene._tray._finish_attempt(true)
	await process_frame
	check_true(_tray_scene._tray.was_forced(), "timeout is distinguished from natural settling")
	check_true(_tray_scene._tray_status.text.contains("time limit"), "timeout is honestly presented")
	var faces: Array = _tray_scene._tray.read_now()
	check_eq(_tray_scene._resolved.total, faces[0].number + 2, "plain roll preserves modifier")
	check_true(_tray_scene._reroll_button.visible, "GM review offers another throw")
	check_eq(_tray_scene._done_button.text, "Send Result", "GM accepts before the result is sent")
	await physics_frame
	await physics_frame
	check_eq(_tray_scene._tray.read_now(), faces, "timeout faces stay fixed after more physics frames")
	_tray_scene._on_reroll_pressed()
	check_true(_tray_scene._rolling, "throwing again starts a fresh physical roll")
	check_true(_tray_scene._resolved.is_empty(), "discarded result is no longer available to send")
	check_false(_tray_scene._done_button.visible, "result cannot be sent while replacement dice roll")
	await physics_frame
	_tray_scene._tray._finish_attempt(true)
	await process_frame
	check_false(_tray_scene._resolved.is_empty(), "replacement throw becomes the result to send")
	check_true(_tray_scene._done_button.visible, "replacement result can be accepted")
	_tray_scene.queue_free()
	await process_frame
	await _test_viewport_dispatch(false)
	await _test_viewport_dispatch(true)
	finish()


func _mouse(overlay: Control, pos: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.pressed = down
	overlay._gui_input(event)


## Exercise hit testing through the actual stacked controls, not the handler.
func _test_viewport_dispatch(touch: bool) -> void:
	var dimensions := Vector2i(390, 844) if touch else Vector2i(1280, 720)
	root.size = dimensions
	root.content_scale_size = dimensions
	var shell := TouchInputShell.new()
	shell._touch_pass_enabled = touch
	root.add_child(shell)
	var host := ModalHost.new()
	shell.add_child(host)
	var route = TRAY_ROUTE.instantiate()
	route.configure({"palette": ThemePalette.new(), "terms": [DiceNotation.parse("2d6")], "label": "Input test"})
	host.present(route, UiRouter.Presentation.PAGE)
	for i in 5:
		await process_frame
	shell._update_mouse_filters_for_touch(shell, touch)
	var overlay: Control = route._aim_overlay
	var grip: Vector2 = overlay.get_global_transform_with_canvas() * overlay._grip()
	var kind := "touch" if touch else "mouse"
	_dispatch_pointer(grip, touch, true)
	await process_frame
	check_true(overlay._dragging, "%s press reaches grip through result overlay" % kind)
	var motion: InputEvent
	if touch:
		motion = InputEventScreenDrag.new()
		motion.index = 0
	else:
		motion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = grip + Vector2(0, 60)
	motion.relative = Vector2(0, 60)
	root.push_input(motion, true)
	await process_frame
	check_true(overlay._pull.y > 14, "%s drag moves the grip" % kind)
	check_true(is_equal_approx(overlay._power(), 1.0), "%s 60-pixel pull fills the power ring" % kind)
	check_true(overlay._grip().y + overlay._pull.y + 38.0 < overlay.size.y, "%s full-power ring stays inside tray" % kind)
	_dispatch_pointer(grip + Vector2(0, 60), touch, false)
	if route._rolling:
		# Inspect the spawn before the next physics step moves the dice.
		var positions: Array[Vector3] = route._tray.die_positions()
		var center := (positions[0] + positions[1]) * 0.5
		var entry: Vector2 = overlay.get_global_transform_with_canvas() * route._camera.unproject_position(center)
		check_true(entry.distance_to(grip) < 1.0, "%s dice originate at the visible entry point" % kind)
		check_true(positions[0].distance_to(positions[1]) > DiceTray.DIE_RADIUS * 2.0, "%s starting dice do not overlap" % kind)
	await process_frame
	check_true(route._rolling, "%s release launches physical dice through viewport" % kind)
	check_true(is_equal_approx(route._throw_strength, 1.0), "%s full ring launches at maximum power" % kind)
	if route._rolling:
		route._tray._finish_attempt(true)
		await process_frame
	if touch:
		var ordinary_scroll := ScrollContainer.new()
		shell.add_child(ordinary_scroll)
		var ordinary_button := Button.new()
		ordinary_scroll.add_child(ordinary_button)
		check_eq(ordinary_button.mouse_filter, Control.MOUSE_FILTER_PASS, "ordinary scrolling controls still get touch pass on attachment")
		shell._update_mouse_filters_for_touch(shell, false)
		check_eq(ordinary_button.mouse_filter, Control.MOUSE_FILTER_STOP, "ordinary controls restore desktop input")
		shell._update_mouse_filters_for_touch(shell, true)
		check_eq(route._result_labels.mouse_filter, Control.MOUSE_FILTER_IGNORE, "responsive reapplication keeps tray decoration transparent to input")
		check_eq(overlay.mouse_filter, Control.MOUSE_FILTER_STOP, "responsive reapplication preserves tray gesture ownership")
	shell.queue_free()
	await process_frame


func _dispatch_pointer(pos: Vector2, touch: bool, down: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.global_position = pos
	event.position = pos
	event.pressed = down
	root.push_input(event, true)


## Use the production global touch-filter lifecycle without opening stores.
class TouchInputShell extends AppShell:
	func _ready() -> void:
		get_tree().node_added.connect(_on_tree_node_added)
